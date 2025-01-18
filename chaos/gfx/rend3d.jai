// TODO: probably instead of pointers we should have some asset system or something

// TODO: Support shader permutations, remove all the zero-checking JUNK!

// TODO: should lights be stored here??

xRenderableBundle :: struct {
  mesh : xMesh;
  model : m4;
};

xRend3D :: struct {
  bundles : [..]xRenderableBundle;


  g_sp  : oglSP;
  g_ub1 : oglUBlock;

  def_sp : oglSP;
  def_ub1 : oglUBlock;

  shadow_sp : oglSP;
  shadow_ub1 : oglUBlock;

  copy_to_depth_sp : oglSP;

  shadow_rt : oglRT;
  g_buffer  : oglRT;
};



xr3d_init :: (using rend : *xRend3D) {
  // create Shadow-Pass Shader
  ogl_sp_init(*shadow_sp, CSM_VERT_SHADER, CSM_GEOM_SHADER, CSM_FRAG_SHADER);
  ogl_ublock_load(*shadow_ub1, *shadow_sp, 1);
  // create G-Buffer Shader
  ogl_sp_init(*g_sp, G_BUF_VERT_SHADER, G_BUF_FRAG_SHADER);
  ogl_ublock_load(*g_ub1, *g_sp, 1);
  // create Fullscreen Deferred Shader
  ogl_sp_init(*def_sp, DEF_VERT_SHADER, DEF_FRAG_SHADER);
  ogl_ublock_load(*def_ub1, *def_sp, 1);
  // create copy_to_depth Shader
  ogl_sp_init(*copy_to_depth_sp, DEF_VERT_SHADER, COPY_TO_DEPTH_FRAG_SHADER);
  // initialize the shadow Render Target
  assert(ogl_rt_init(*shadow_rt, .{2048,2048}, .D32F));
  assert(ogl_rt_init(*g_buffer, .{xeng().win.dim.x,xeng().win.dim.y}, .RGBA32F));
}

xr3d_push_bundle :: (using rend : *xRend3D, mesh : xMesh, model : m4) {
  array_add(*bundles, .{mesh, model});
}

xr3d_clear_bundles :: (using rend :*xRend3D) {
  bundles.count = 0;
  //array_clear(*bundles);
}

xr3d_set_light_uniforms :: (using rend : *xRend3D, ub : *oglUBlock) {
  // Directional Light
  dl : xDirectionalLight = xeng().dir_light.dl;
  ogl_ublock_set_uniformable_struct(ub, *dl, "dir_light");

  //xlight_set_to_ub(*xeng().dir_light, ub);
  // Point Light (TODO: add more point lights!)
  //light_pos := v3.{3,2,3};
  //point_light := xpoint_light_make_basic(light_pos);
  //xlight_set_to_shader(*point_light, ub);
}

xr3d_do_shadow_pass :: (using rend : *xRend3D) {
  ogl_rt_clear(*shadow_rt);
  ogl_rt_bind(*shadow_rt);
  ogl_bind_sp(*shadow_sp);
  dyn_state := oglDynState.{
    viewport = .{0,0,shadow_rt.dim.x, shadow_rt.dim.y},
    scissor = .{},
    flags = .BLEND | .DEPTH
  };
  ogl_sp_apply_dyn_state(*shadow_sp, dyn_state);

  xcsm_data_set_to_ub(*shadow_ub1, *xeng().csm_data, xeng().dir_light.dl, false);

  for bundle : bundles {
    m := m4_transpose(bundle.model);
    ogl_ublock_set(*shadow_ub1, "model", xx m.raw.data);
    ogl_ublock_bind_to_slot(*shadow_ub1);
    if xmesh_has_skin(*bundle.mesh) {
      // FIXME: this shouldn't be here!
      jm := xmesh_animation_calculate_joint_matrices(*bundle.mesh);
      for idx : 0..127 {
        name := tprint("joint_mat[%]", idx);
        ogl_sp_set_uniform(*shadow_sp, name, oglShaderDataType.MAT4 , *jm[idx]);
        m := m4_I;
      }
      xmesh_render(*bundle.mesh, *shadow_sp, bundle.model);
    } else {
      xmesh_render(*bundle.mesh, *shadow_sp, bundle.model);
    }
  }
}

xr3d_do_g_pass :: (using rend : *xRend3D) {
  ogl_rt_clear(*g_buffer);
  ogl_rt_bind(*g_buffer);
  ogl_bind_sp(*g_sp);
  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    flags = .DEPTH
  };
  ogl_sp_apply_dyn_state(*g_sp, dyn_state);

  for bundle : bundles {

    sp := g_sp;
    ublock := g_ub1;

    ogl_bind_sp(*sp); // FIXME: this bind is hacky
    ogl_sp_apply_dyn_state(*sp, dyn_state);

    // set the g_pass uniform block
    m := m4_transpose(bundle.model);
    ogl_ublock_set(*ublock, "model", xx m.raw.data);
    ogl_ublock_bind_to_slot(*ublock);
    if xmesh_has_skin(*bundle.mesh) {
      // FIXME: this shouldn't be here!
      jm := xmesh_animation_calculate_joint_matrices(*bundle.mesh);
      for idx : 0..127 {
        name := tprint("joint_mat[%]", idx);
        ogl_sp_set_uniform(*sp, name, oglShaderDataType.MAT4 , *jm[idx]);
        m := m4_I;
        //ogl_sp_set_uniform(*sp, name, oglShaderDataType.MAT4 , *m);
      }
      xmesh_render(*bundle.mesh, *sp, bundle.model);
    } else {
      xmesh_render(*bundle.mesh, *sp, bundle.model);
    }
  }
}


// This enables forward shading!
xr3d_do_copy_depth_from_g_buf_to_d0 :: (using rend : *xRend3D) {
  ogl_rt_bind(null);
  ogl_bind_sp(*copy_to_depth_sp);
  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    flags = .DEPTH,
    extra_flags = 1
  };
  ogl_sp_apply_dyn_state(*def_sp, dyn_state);

  bindings : oglBindingDesc = .{};
  ogl_sp_apply_bindings(*copy_to_depth_sp, bindings);

  g_ds := ogl_rt_get_attachment(*g_buffer, .DS);
  ogl_sp_bind_sampler_to_slot(*copy_to_depth_sp, "depth_tex", *g_ds, 0);

  ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);
}

xr3d_do_def_pass :: (using rend : *xRend3D) {
  ogl_rt_bind(null);
  ogl_bind_sp(*def_sp);
  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    flags = .NONE
  };

  bindings : oglBindingDesc = .{};
  ogl_sp_apply_bindings(*def_sp, bindings);

  g_pos_tex := ogl_rt_get_attachment(*g_buffer, .A0);
  ogl_sp_bind_sampler_to_slot(*def_sp, "g_pos", *g_pos_tex, 0);

  g_norm_tex := ogl_rt_get_attachment(*g_buffer, .A1);
  ogl_sp_bind_sampler_to_slot(*def_sp, "g_norm", *g_norm_tex, 1);

  g_albedo_spec_tex := ogl_rt_get_attachment(*g_buffer, .A2);
  ogl_sp_bind_sampler_to_slot(*def_sp, "g_albedo_spec", *g_albedo_spec_tex, 2);

  shadow_map := ogl_rt_get_attachment(*shadow_rt, .DS);
  ogl_sp_bind_sampler_to_slot(*def_sp, "shadow_map", *shadow_map, 3);

  xcsm_data_set_to_ub(*def_ub1, *xeng().csm_data, xeng().dir_light.dl, true);


  ogl_ublock_set(*def_ub1, "view_pos", xx *xeng().c.pos);

  ogl_ublock_set(*def_ub1, "cascade_count", xx *xeng().csm_data.cascade_count);

  vv :m4= m4_transpose(xeng().csm_data.cview);
  ogl_ublock_set(*def_ub1, "view_csm", xx vv.raw.data);

  xr3d_set_light_uniforms(rend, *def_ub1);

  ogl_ublock_bind_to_slot(*def_ub1);
  ogl_sp_apply_dyn_state(*def_sp, dyn_state);
  ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);
}

G_BUF_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_norm;
layout (location = 2) in vec2 in_tc;
layout (location = 3) in ivec4 in_joint_ids;
layout (location = 4) in vec4 in_weights;


layout(std140, binding = 0) uniform GlobalData {
   mat4 proj;
   mat4 view;
};

layout(std140, binding = 1) uniform GData {
  mat4 model;
};

out VS_OUT
{
   vec2 tc;
   vec3 world_pos;
   vec3 normal;
} vs_out;


// FIXME: make this a UBO!
uniform mat4 joint_mat[128];

void main()
{
  vec4 pos;
  if (in_weights[0].x > 0.0) {
    for (int i = 0; i < 4; i++) {
      pos += joint_mat[in_joint_ids[i]] * vec4(in_pos,1.0) * in_weights[i];
    }
    pos /= dot(in_weights, vec4(1.0));
  } else {
    pos = vec4(in_pos, 1.0);
  }

  gl_Position = proj*view*model*vec4(pos.xyz, 1.0);
  vs_out.world_pos = vec3(model*vec4(pos.xyz, 1.0));
  vs_out.normal = mat3(transpose(inverse(model))) * in_norm;
  vs_out.tc = in_tc;
}
DONE

G_BUF_FRAG_SHADER :: #string DONE
#version 430 core
layout (location = 0) out vec3 g_pos;
layout (location = 1) out vec3 g_norm;
layout (location = 2) out vec4 g_albedo_spec;

in VS_OUT
{
   vec2 tc;
   vec3 world_pos;
   vec3 normal;
} fs_in;

uniform sampler2D diffuse;
uniform sampler2D specular;

void main()
{    
    g_pos = fs_in.world_pos;
    g_norm = normalize(fs_in.normal);
    g_albedo_spec.rgb = texture(diffuse, fs_in.tc).rgb;
    g_albedo_spec.a = texture(specular, fs_in.tc).r;
}
DONE

DEF_VERT_SHADER :: #string DONE
#version 430 core
vec2 quad[4] = vec2[](
  vec2(+1.0,-1.0),
  vec2(+1.0,+1.0),
  vec2(-1.0,+1.0),
  vec2(-1.0,-1.0)
);

out VS_OUT {
   vec2 tc;
} vs_out;


void main()
{
    gl_Position = vec4(quad[gl_VertexID], 0.0, 1.0);
    vs_out.tc = quad[gl_VertexID] / 2.0 + 0.5;
}
DONE

DEF_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

uniform sampler2D g_pos;
uniform sampler2D g_norm;
uniform sampler2D g_albedo_spec;
uniform sampler2DArray shadow_map;

struct DirLight {
    vec3 dir;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};


layout(std140, binding = 1) uniform DefData {
  mat4 lsm[4]; // World Space -> light's Clip Space
  mat4 view_csm; //for debug purposes we might want our view matrix to be different
  DirLight dir_light;
  vec3 view_pos;
  float cascade_plane_distances[4];
  int cascade_count;
};

in VS_OUT {
   vec2 tc;
} fs_in;


float g_shadow_bias = 0.005;
float calc_shadow(vec4 light_space_coords, int cascade_index) {
   vec3 ndc_coords = light_space_coords.xyz / light_space_coords.w;
   vec3 coords01 = ndc_coords * 0.5 + 0.5;
   vec2 light_tc = coords01.xy;
   float depth_in_shadow_map = texture(shadow_map, vec3(light_tc,cascade_index)).r;
   // 1. if our fragment is further that shadow maps far plane, we disable shadow
   if (coords01.z > 1.0) {
      return 0.0;
   }
   // 2. if the depth in shadow map is less than our fragment's, the fragment is in shadow
   float shadow = 0.0;
   vec2 texel_size = 1.0 / textureSize(shadow_map, 0).xy;
   for(int x = -1; x <= 1; ++x)
   {
     for(int y = -1; y <= 1; ++y)
     {
       float pcf_d = texture(shadow_map, vec3(coords01.xy + vec2(x, y) * texel_size,cascade_index)).r; 
       shadow += coords01.z - g_shadow_bias > pcf_d ? 1.0 : 0.0;        
     }
   }
   shadow /= 9.0;
   return shadow;
}
int calc_cascade_map_layer_index(vec3 world_pos) {
   vec4 frag_pos_lsp = view_csm * vec4(world_pos,1.0);
   float frag_depth = abs(frag_pos_lsp).z;
   int layer = -1;
   for (int i = 0; i < cascade_count; ++i) {
      if (frag_depth < cascade_plane_distances[i]) {
         layer = i;
         break;
      }
   }
   if (layer == -1) {
      layer = cascade_count;
   }
   return layer;
}

vec3 calc_dir_light(DirLight light, vec3 normal, vec3 view_dir, vec3 diffuse_col, float specular_col, vec3 world_pos)
{
    float shininess = 8.0;
    vec3 light_dir = normalize(light.dir);
    // diffuse factor 
    float diff = max(dot(normal, light_dir), 0.0);
    vec3 halfway_dir = normalize(light_dir + view_dir);  
    float spec = pow(max(dot(normal, halfway_dir), 0.0), shininess);
    // combine results
    vec3 ambient  = light.ambient  * diffuse_col;
    vec3 diffuse  = light.diffuse  * diff *diffuse_col;
    vec3 specular = light.specular * spec * specular_col;

    vec4 light_space_coord[4];
    for (int i = 0; i < 4; ++i) {
      light_space_coord[i] = lsm[i] * vec4(world_pos,1.0);
    }


    int layer = calc_cascade_map_layer_index(world_pos);
    float s = calc_shadow(light_space_coord[layer], layer);

    return (ambient + (1.0-s)*(diffuse + specular));
}

void main() {
  vec3 world_pos = texture(g_pos, fs_in.tc).xyz;
  vec3 norm = texture(g_norm, fs_in.tc).xyz;
  vec3 diff = texture(g_albedo_spec, fs_in.tc).xyz;
  float spec = texture(g_albedo_spec, fs_in.tc).w;
  g_shadow_bias = max(0.05 * (1.0 - dot(norm, dir_light.dir)), 0.005);

  vec3 view_dir = normalize(view_pos - world_pos);
  vec3 dl = calc_dir_light(dir_light, norm, view_dir, diff, spec, world_pos);
  FragColor = vec4(dl,1.0);
}
DONE

COPY_TO_DEPTH_FRAG_SHADER :: #string DONE
#version 430 core

in VS_OUT {
   vec2 tc;
} fs_in;

uniform sampler2D depth_tex;

void main() {
  gl_FragDepth = texture(depth_tex, fs_in.tc).r;
}
DONE


