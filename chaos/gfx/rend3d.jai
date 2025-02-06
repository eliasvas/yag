// TODO: probably instead of pointera  we should have some asset system or something

// TODO: Support shader permutations, remove all the zero-checking JUNK!

// TODO: should lights be stored here??

// TODO: Add bindings to samplers shader code!

// TODO: Add SSAO pass (optional)

xRenderableBundle :: struct {
  mesh : xMesh;
  model : m4;
};

xRend3D :: struct {
  bundles : [..]xRenderableBundle;

  white_tex : oglTex;

  g_sp  : oglSP;
  g_ub1 : oglUBlock; // model
  g_ub2 : oglUBlock; // joint_mats
  g_ub3 : oglUBlock; // material data

  def_sp : oglSP;
  def_ub1 : oglUBlock;

  shadow_sp : oglSP;
  shadow_ub1 : oglUBlock;
  shadow_ub2 : oglUBlock;

  copy_to_depth_sp : oglSP;

  shadow_rt : oglRT;
  g_buffer  : oglRT;
  hdr_skybox : xHDR_Skybox;
};



xr3d_init :: (using rend : *xRend3D) {
  // create the white tex
  white := u8.[ 0xFF,0xFF,0xFF,0xFF ]; ogl_tex_init(*white_tex, .{1,1}, white.data, oglTexFormat.RGBA8U);
  // create Shadow-Pass Shader
  ogl_sp_init(*shadow_sp, CSM_VERT_SHADER, CSM_GEOM_SHADER, CSM_FRAG_SHADER);
  ogl_ublock_load(*shadow_ub1, *shadow_sp, 1);
  ogl_ublock_load(*shadow_ub2, *shadow_sp, 2);  
  // create G-Buffer Shader
  ogl_sp_init(*g_sp, G_BUF_VERT_SHADER, G_BUF_FRAG_SHADER);
  ogl_ublock_load(*g_ub1, *g_sp, 1);
  ogl_ublock_load(*g_ub2, *g_sp, 2);
  ogl_ublock_load(*g_ub3, *g_sp, 3);
  // create Fullscreen Deferred Shader
  ogl_sp_init(*def_sp, DEF_VERT_SHADER, DEF_FRAG_SHADER);
  ogl_ublock_load(*def_ub1, *def_sp, 1);
  // create copy_to_depth Shader
  ogl_sp_init(*copy_to_depth_sp, DEF_VERT_SHADER, COPY_TO_DEPTH_FRAG_SHADER);
  // initialize the shadow Render Target
  assert(ogl_rt_init(*shadow_rt, .{2048,2048}, .D32F));
  assert(ogl_rt_init(*g_buffer, .{xeng().win.dim.x,xeng().win.dim.y}, .RGBA16F));

  rend.hdr_skybox = xhdr_skybox_generate("../assets/boma_4k.hdr");
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
        m := m4_transpose(jm[idx]);
        ogl_ublock_set(*shadow_ub2, name, xx *m);
      }
      ogl_ublock_bind_to_slot(*shadow_ub2);
      xmesh_render(*bundle.mesh, *shadow_sp, null, bundle.model);
    } else {
      xmesh_render(*bundle.mesh, *shadow_sp, null, bundle.model);
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
    for *prim : bundle.mesh.primitives {if prim.material.base_col_tex == null then prim.material.base_col_tex = *white_tex;}

    sp := g_sp;
    ogl_bind_sp(*sp); // FIXME: this bind is hacky
    ogl_sp_apply_dyn_state(*sp, dyn_state);

    // set the g_pass uniform block
    m := m4_transpose(bundle.model);
    ogl_ublock_set(*g_ub1, "model", xx m.raw.data);
    ogl_ublock_bind_to_slot(*g_ub1);
    if xmesh_has_skin(*bundle.mesh) {
      // FIXME: this shouldn't be here!
      jm := xmesh_animation_calculate_joint_matrices(*bundle.mesh);
      for idx : 0..127 {
        name := tprint("joint_mat[%]", idx);
        m := m4_transpose(jm[idx]);
        ogl_ublock_set(*g_ub2, name, xx *m);
      }
      ogl_ublock_bind_to_slot(*g_ub2);
      xmesh_render(*bundle.mesh, *sp, *g_ub3, bundle.model);
    } else {
      xmesh_render(*bundle.mesh, *sp, *g_ub3, bundle.model);
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

  g_occ_rough_met_tex := ogl_rt_get_attachment(*g_buffer, .A3);
  ogl_sp_bind_sampler_to_slot(*def_sp, "g_occ_rough_met", *g_occ_rough_met_tex, 3);

  shadow_map := ogl_rt_get_attachment(*shadow_rt, .DS);
  ogl_sp_bind_sampler_to_slot(*def_sp, "shadow_map", *shadow_map, 4);

  xhdr_skybox_bind_cubemap_to_sp(*hdr_skybox, *def_sp);

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
layout (location = 5) in vec4 in_tangent;


layout(std140, binding = 0) uniform GlobalData {
   mat4 proj;
   mat4 view;
};

layout(std140, binding = 1) uniform GData {
  mat4 model;
};

layout(std140, binding = 2) uniform JointData {
  mat4 joint_mat[128];
};

layout(std140, binding = 3) uniform MaterialData {
  vec4 base_factor;
  float metallic_factor;
  float roughness_factor;
  vec3 emissive_factor;
};


out VS_OUT
{
   vec2 tc;
   vec3 world_pos;
   vec3 normal;
   mat3 TBN;
} vs_out;

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

  vec3 bitangent = cross(in_norm, in_tangent.xyz) * in_tangent.w;
  vec3 T = normalize(vec3(model * vec4(in_tangent.xyz,0.0)));
  vec3 B = normalize(vec3(model * vec4(bitangent,0.0)));
  vec3 N = normalize(vec3(model * vec4(in_norm,0.0)));
  vs_out.TBN = mat3(T,B,N);
}
DONE

G_BUF_FRAG_SHADER :: #string DONE
#version 430 core
layout (location = 0) out vec3 g_pos;
layout (location = 1) out vec3 g_norm;
layout (location = 2) out vec4 g_albedo_spec;
layout (location = 3) out vec4 g_occ_rough_met;

layout(std140, binding = 3) uniform MaterialData {
  vec4 base_factor;
  float metallic_factor;
  float roughness_factor;
  vec3 emissive_factor;
};

in VS_OUT
{
   vec2 tc;
   vec3 world_pos;
   vec3 normal;
   mat3 TBN;
} fs_in;

uniform sampler2D albedo_map;
uniform sampler2D normal_map;
uniform sampler2D metal_rough_map;
uniform sampler2D ao_map;

void main()
{    
    vec3 normal = texture(normal_map, fs_in.tc).rgb;
    normal = normal * 2.0 - 1.0;   
    normal = normalize(fs_in.TBN * normal);

    //vec3 normal = fs_in.normal;

    g_pos = fs_in.world_pos;
    g_norm = normalize(normal);
    g_albedo_spec.rgb = vec3(base_factor*texture(albedo_map, fs_in.tc));
    g_albedo_spec.a = 1.0;

    g_occ_rough_met = vec4(0,0,0,0);
    vec4 metal_rough_px = texture(metal_rough_map, fs_in.tc);
    g_occ_rough_met.r = texture(ao_map, fs_in.tc).r; // ao
    g_occ_rough_met.g = roughness_factor * metal_rough_px.g; // roughness
    g_occ_rough_met.b = metallic_factor * metal_rough_px.b; // metallic
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
// TODO: Add options for the gamma and HDR and also add saturation and contrast post-proc
// TODO: Add bloom..
#version 430 core
out vec4 FragColor;

uniform sampler2D g_pos;
uniform sampler2D g_norm;
uniform sampler2D g_albedo_spec;
uniform sampler2D g_occ_rough_met;
uniform sampler2DArray shadow_map;

uniform samplerCube irradiance_map;
uniform samplerCube prefilter_map;
uniform sampler2D brdf_lut;

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

const float PI = 3.14159265359;
float DistributionGGX(vec3 N, vec3 H, float roughness) { float a = roughness*roughness; float a2 = a*a; float NdotH = max(dot(N, H), 0.0); float NdotH2 = NdotH*NdotH; float nom   = a2; float denom = (NdotH2 * (a2 - 1.0) + 1.0); denom = PI * denom * denom; return nom / denom; }
float GeometrySchlickGGX(float NdotV, float roughness) { float r = (roughness + 1.0); float k = (r*r) / 8.0; float nom   = NdotV; float denom = NdotV * (1.0 - k) + k; return nom / denom; }
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) { float NdotV = max(dot(N, V), 0.0); float NdotL = max(dot(N, L), 0.0); float ggx2 = GeometrySchlickGGX(NdotV, roughness); float ggx1 = GeometrySchlickGGX(NdotL, roughness); return ggx1 * ggx2;}
vec3 fresnelSchlick(float cosTheta, vec3 F0) { return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0); }
vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) { return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0); }   


void main() {
  vec3 world_pos = texture(g_pos, fs_in.tc).xyz;
  vec3 normal = texture(g_norm, fs_in.tc).xyz;
  vec2 tex_coords = fs_in.tc;

  vec3 albedo     = pow(texture(g_albedo_spec, fs_in.tc).xyz, vec3(2.2));
  //vec3 albedo     = texture(g_albedo_spec, fs_in.tc).xyz;
  float ao        = texture(g_occ_rough_met, fs_in.tc).r;
  float roughness = texture(g_occ_rough_met, fs_in.tc).g;
  float metallic  = texture(g_occ_rough_met, fs_in.tc).b;
  //float ao        = 1.0;
  vec3 N = texture(g_norm, fs_in.tc).xyz;
  vec3 V = normalize(view_pos - world_pos);
  vec3 R = reflect(-V, N); 
  g_shadow_bias = max(0.05 * (1.0 - dot(N, dir_light.dir)), 0.005);

  vec3 F0 = vec3(0.04); 
  F0 = mix(F0, albedo, metallic);

  // Calculate directional light
  vec3 Lo = vec3(0.0);
  {
    vec3 L = normalize(dir_light.dir);
    vec3 H = normalize(V + L);
    vec3 radiance = dir_light.diffuse;
    // Cook-Torrance BRDF
    float NDF = DistributionGGX(N, H, roughness);   
    float G   = GeometrySmith(N, V, L, roughness);      
    vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);
    vec3 numerator    = NDF * G * F; 
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001; // + 0.0001 to prevent divide by zero
    vec3 specular = numerator / denominator;
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - metallic;	  
    float NdotL = max(dot(N, L), 0.0);        
    Lo += (kD * albedo / PI + specular) * radiance * NdotL;  // note that we already multiplied the BRDF by the Fresnel (kS) so we won't multiply by kS again
  }

  // Do shadow mapping..
  vec4 light_space_coord[4];
  for (int i = 0; i < 4; ++i) {
    light_space_coord[i] = lsm[i] * vec4(world_pos,1.0);
  }
  int layer = calc_cascade_map_layer_index(world_pos);
  float shadowed = calc_shadow(light_space_coord[layer], layer);

  // ambient lighting (via IBL)
  //vec3 ambient = vec3(0.002);

  // diffuse term
  vec3 F = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);
  vec3 kS = F;
  vec3 kD = 1.0 - kS;
  kD *= 1.0 - metallic;
  vec3 irradiance = texture(irradiance_map, N).rgb; 
  vec3 diffuse = irradiance * albedo; 

  // specular term
  const float MAX_REFLECTION_LOD = 4.0;
  vec3 prefilteredColor = textureLod(prefilter_map, R,  roughness * MAX_REFLECTION_LOD).rgb;    
  vec2 brdf  = texture(brdf_lut, vec2(max(dot(N, V), 0.0), roughness)).rg;
  vec3 specular = prefilteredColor * (kS * brdf.x + brdf.y);

  // combine
  vec3 ambient = (kD * diffuse + specular) * ao;


  vec3 color = ambient + Lo * (1-shadowed);


  // HDR tonemapping
  color = color / (color + vec3(1.0));
  // gamma correct
  color = pow(color, vec3(1.0/2.2)); 
  FragColor = vec4(color, 1.0);
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


