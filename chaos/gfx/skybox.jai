// skydome based on this paper:
// https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-16-accurate-atmospheric-scattering
// TODO: keep reading the paper (after HDR is done)
// TODO: Its really slow, we need to do the trick where we draw OVER other triangles, see leanropengl skybox chapter i think?

// TODO: make a color.jai for HSV and stuff
xSkydome :: struct {
  sp  : oglSP;
  ub_b1  : oglUBlock;
  noise_tex : oglTex; // This is optional right?
  sky_color   : v3 = .{0.3,0.5,0.8};
  cloud_color : v3 = .{1,1,1};
  sun_color   : v3 = .{1,0.7,0.4};
  cloud_speed : float = 1.0;
  sphere_mesh : xMesh;

  grid : xGrid;
};

xskydome_make :: () -> xSkydome {
  using skydome : xSkydome;

  ogl_sp_init(*sp, SKYDOME_VERT_SHADER, SKYDOME_FRAG_SHADER);


  ogl_ublock_load(*ub_b1, *sp, 1);
  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
  ogl_tex_init(*noise_tex, .{1,1}, white.data, oglTexFormat.RGBA8U);
  sphere_mesh = xmesh_gen_sphere(1,8,8,true);
  grid = xgrid_make();
  return skydome;
}

xskydome_render :: (using skydome : *xSkydome) {
  // we cancel translation, the skydome is to be rendered at the center
  view := xcam_get_view_mat(*xeng().c);
  view._14 = 0;
  view._24 = 0;
  view._34 = 0;
  // draw the skybox
  ogl_rt_bind(null);
  ogl_clear_all_state();

  viewt := m4_transpose(view);
  ogl_ublock_set(*ub_b1, "view", xx viewt.raw.data);
  projt := m4_transpose(xeng().proj);
  ogl_ublock_set(*ub_b1, "proj", xx projt.raw.data);
  color_bottom := v3.{0.2,0.05, 0.05};
  ogl_ublock_set(*ub_b1, "color_bottom", xx *color_bottom);
  color_top := v3.{0.05, 0.05, 0.2};
  ogl_ublock_set(*ub_b1, "color_top", xx *color_top);
  ogl_ublock_bind_to_slot(*ub_b1);

  //vec3 color_bottom = vec3(0.2,0.05,0.05);
  //vec3 color_top = vec3(0.05,0.05,0.2);

  ogl_bind_sp(*sp);
  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    flags = .DEPTH
  };
  ogl_sp_apply_dyn_state(*sp, dyn_state);
  xmesh_render(*sphere_mesh, *sp, null, m4_I);

  xgrid_render(*skydome.grid);
}


SKYDOME_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_norm;
layout (location = 2) in vec2 in_tc;

out VS_OUT {
  vec3 world_pos;
  vec3 norm;
  vec2 tc;
} vs_out;

layout(std140, binding = 1) uniform SkyboxData {
  mat4 proj;
  mat4 view;
  vec3 color_bottom;
  vec3 color_top;
};

void main() {
  vs_out.world_pos = in_pos;
  vs_out.norm = in_norm;
  vs_out.tc = in_tc;
  gl_Position = vec4(proj*view*vec4(in_pos,1.0)).xyww;
}
DONE

SKYDOME_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

in VS_OUT {
  vec3 world_pos;
  vec3 norm;
  vec2 tc;
} fs_in;


layout(std140, binding = 1) uniform SkyboxData {
  mat4 proj;
  mat4 view;
  vec3 color_bottom;
  vec3 color_top;
};

void main() {
  vec3 col = mix(color_bottom, color_top, fs_in.world_pos.y + 1.0 / 2.0);
  FragColor = vec4(col, 1.0);
}
DONE

xHDR_Skybox :: struct {
  hdr_eq_tex : oglTex;
  cubemap : oglTex;
  irradiance_map : oglTex;
  sp  : oglSP;
  ub1  : oglUBlock;
  cube_mesh : xMesh;
};

xhdr_skybox_generate :: (hdr_eq_image_path : string) -> xHDR_Skybox {
  skybox : xHDR_Skybox;

  // create the needed shaders/buffers/etc
  ogl_sp_init(*skybox.sp, SKYBOX_VERT_SHADER, SKYBOX_FRAG_SHADER);
  ogl_ublock_load(*skybox.ub1, *skybox.sp, 1);

  gen_irradiance_sp : oglSP;
  ogl_sp_init(*gen_irradiance_sp, GENERATE_CONVOLUTION_VERT_SHADER, GENERATE_CONVOLUTION_FRAG_SHADER);

  gen_irradiance_ub1 : oglUBlock;
  ogl_ublock_load(*gen_irradiance_ub1, *gen_irradiance_sp, 1);

  eq_to_rt_sp : oglSP;
  assert(ogl_sp_init(*eq_to_rt_sp, EQ_TO_RT_VERT_SHADER, EQ_TO_RT_FRAG_SHADER));
  eq_to_rt_ub1 : oglUBlock;
  ogl_ublock_load(*eq_to_rt_ub1, *eq_to_rt_sp, 1);
  skybox.cube_mesh = xmesh_gen_cube_multi_vbos();

  // create the base equirectangular HDR texture
  {
    hdr_data, succ := read_entire_file(hdr_eq_image_path);
    assert(succ);
    tex_w, tex_h, channels : s32;
    assert(stbi_is_hdr(hdr_eq_image_path.data) != 0);
    stbi_set_flip_vertically_on_load(1);
    assert(stbi_is_hdr_from_memory(hdr_data.data, cast(s32)hdr_data.count) != 0);
    raw_image_data := stbi_loadf_from_memory(hdr_data.data, cast(s32)hdr_data.count, *tex_w, *tex_h, *channels, 4);
    stbi_set_flip_vertically_on_load(0);
    //defer free(raw_image_data);
    ogl_tex_init(*skybox.hdr_eq_tex, .{cast(float)tex_w,cast(float)tex_h}, xx raw_image_data, oglTexFormat.RGBA16F);
  }
  // write all 6 sides of cubemap to a render target
  junk_rt : oglRT;
  {
    ogl_rt_init(*junk_rt, .{512,512}, oglTexFormat.RGBA16F, 6);
    ogl_rt_clear(*junk_rt, .{1,0,0,1});

    ogl_rt_bind(*junk_rt);
    ogl_bind_sp(*eq_to_rt_sp);
    projt := m4_transpose(m4_persp(90.0, 1.0, 0.1, 10));
    ogl_ublock_set(*eq_to_rt_ub1, "proj", xx projt.raw.data);
    view_mats := m4.[
      m4_look_at(.{0,0,0}, .{0,0,1}, .{0,-1,0}),
      m4_look_at(.{0,0,0}, .{0,0,-1}, .{0,-1,0}),
      m4_look_at(.{0,0,0}, .{0,1,0}, .{-1,0,0}),
      m4_look_at(.{0,0,0}, .{0,-1,0}, .{1,0,0}),
      m4_look_at(.{0,0,0}, .{-1,0,0}, .{0,-1,0}),
      m4_look_at(.{0,0,0}, .{1,0,0}, .{0,-1,0}),
    ];
    for i : 0..5 {
      ogl_rt_bind(*junk_rt, .[xx(i)]);
      viewt := m4_transpose(view_mats[i]);
      ogl_ublock_set(*eq_to_rt_ub1, "view", xx viewt.raw.data);
      ogl_sp_bind_sampler_to_slot(*eq_to_rt_sp, "eq_tex", *skybox.hdr_eq_tex, 0);
      ogl_ublock_bind_to_slot(*eq_to_rt_ub1);
      dyn_state := oglDynState.{
        viewport = .{0,0,512,512},
        scissor = .{},
        flags = .DEPTH
      };
      ogl_sp_apply_dyn_state(*eq_to_rt_sp, dyn_state);
      //xmesh_render(*skybox.cube_mesh, *eq_to_rt_sp, null, m4_scale(.{0.5,0.5,0.5}));
      xmesh_render(*skybox.cube_mesh, *eq_to_rt_sp, null, m4_I);
    }
  }
  // copy these from the RT to a cubemap!
  skybox.cubemap = ogl_tex_convert_rt_to_cubemap(*junk_rt);
  // now generate the irradiance map (convoluted cubemap)
  junk_rt2 : oglRT;
  {
    ogl_rt_init(*junk_rt2, .{32,32}, oglTexFormat.RGBA16F, 6);
    ogl_rt_clear(*junk_rt2, .{1,0,0,1});

    ogl_rt_bind(*junk_rt2);
    ogl_bind_sp(*gen_irradiance_sp);
    projt := m4_transpose(m4_persp(90.0, 1.0, 0.1, 10));
    ogl_ublock_set(*gen_irradiance_ub1, "proj", xx projt.raw.data);
    view_mats := m4.[
      m4_look_at(.{0,0,0}, .{0,0,1}, .{0,-1,0}),
      m4_look_at(.{0,0,0}, .{0,0,-1}, .{0,-1,0}),
      m4_look_at(.{0,0,0}, .{0,1,0}, .{-1,0,0}),
      m4_look_at(.{0,0,0}, .{0,-1,0}, .{1,0,0}),
      m4_look_at(.{0,0,0}, .{-1,0,0}, .{0,-1,0}),
      m4_look_at(.{0,0,0}, .{1,0,0}, .{0,-1,0}),
    ];
    for i : 0..5 {
      ogl_rt_bind(*junk_rt2, .[xx(i)]);
      viewt := m4_transpose(view_mats[i]);
      ogl_ublock_set(*gen_irradiance_ub1, "view", xx viewt.raw.data);
      ogl_sp_bind_sampler_to_slot(*gen_irradiance_sp, "env_map", *skybox.cubemap, 0);
      ogl_ublock_bind_to_slot(*gen_irradiance_ub1);
      dyn_state := oglDynState.{
        viewport = .{0,0,512,512},
        scissor = .{},
        flags = .DEPTH
      };
      ogl_sp_apply_dyn_state(*gen_irradiance_sp, dyn_state);
      //xmesh_render(*skybox.cube_mesh, *eq_to_rt_sp, null, m4_scale(.{0.5,0.5,0.5}));
      xmesh_render(*skybox.cube_mesh, *gen_irradiance_sp, null, m4_I);
    }
  }
  skybox.irradiance_map = ogl_tex_convert_rt_to_cubemap(*junk_rt2);

  // optional: deinit the RT

  return skybox;
}

xhdr_skybox_render :: (using skybox : *xHDR_Skybox) {
  // we cancel translation, the skydome is to be rendered at the center
  view := xcam_get_view_mat(*xeng().c);
  ogl_rt_bind(null);
  viewt := m4_transpose(view);
  ogl_ublock_set(*ub1, "view", xx viewt.raw.data);
  projt := m4_transpose(xeng().proj);
  ogl_ublock_set(*ub1, "proj", xx projt.raw.data);
  ogl_ublock_bind_to_slot(*ub1);

  ogl_bind_sp(*sp);
  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    flags = .DEPTH
  };
  ogl_sp_apply_dyn_state(*sp, dyn_state);
  ogl_sp_bind_sampler_to_slot(*sp, "cubemap", *cubemap, 0);
  //ogl_sp_bind_sampler_to_slot(*sp, "cubemap", *irradiance_map, 0);
  xmesh_render(*cube_mesh, *sp, null, m4_I);
}

xhdr_skybox_deinit :: (hdr_equi_image_path : string) {
  // delete hdr_eq_tex
  // delete cubemap 
  // delete sp
}

// @FIXME: clean this up
xhdr_skybox_bind_cubemap_to_sp :: (using skybox : *xHDR_Skybox, shader : *oglSP) {
  ogl_sp_bind_sampler_to_slot(shader, "irradiance_map", *irradiance_map, 5);
}

EQ_TO_RT_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;

out VS_OUT {
  vec3 world_pos;
} vs_out;

layout(std140, binding = 1) uniform SkyboxData {
  mat4 proj;
  mat4 view;
};

void main() {
  vs_out.world_pos = in_pos;
  gl_Position = vec4(proj*view*vec4(in_pos,1.0)).xyww;
  //gl_Position = vec4(in_pos,1.0);
}
DONE

EQ_TO_RT_GEOM_SHADER :: #string DONE
#version 430 core
layout(triangles) in;
layout(triangle_strip, max_vertices = 18) out;

in VS_OUT {
  vec3 world_pos;
} gs_in[];


out GS_OUT {
  vec3 world_pos;
  flat int layer;
} gs_out;


layout(std140, binding = 1) uniform SkyboxData {
  mat4 proj;
  mat4 view[6];
};


void main() {          
  //gl_Layer = gl_InvocationID;
  for (int layer = 0; layer < 6; ++layer){
    for (int i = 0; i < gl_in.length(); ++i) {
      gl_Position = (proj*view[gl_InvocationID] * gl_in[i].gl_Position).xyww;
      gs_out.layer = layer;
      gs_out.world_pos = gs_in[i].world_pos;
      EmitVertex();
    }
    EndPrimitive();
  }
  
}
DONE

EQ_TO_RT_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

const vec2 invAtan = vec2(0.1591, 0.3183);
vec2 sample_spherical_map(vec3 v) {
  vec2 uv = vec2(atan(v.z, v.x), asin(v.y));
  uv *= invAtan;
  uv += 0.5;
  return uv;
}

in VS_OUT {
  vec3 world_pos;
} fs_in;

layout(std140, binding = 1) uniform SkyboxData {
  mat4 proj;
  mat4 view;
};

uniform sampler2D eq_tex;

void main() {
  vec2 uv = sample_spherical_map(normalize(fs_in.world_pos));
  FragColor = vec4(texture(eq_tex, uv).rgb,1.0);
}
DONE

SKYBOX_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;

out VS_OUT {
  vec3 world_pos;
} vs_out;

layout(std140, binding = 1) uniform SkyboxData {
  mat4 proj;
  mat4 view;
};

void main() {
  vs_out.world_pos = in_pos;
  mat4 rot_view = mat4(mat3(view));
  gl_Position = vec4(proj*rot_view*vec4(in_pos,1.0)).xyww;
}
DONE

SKYBOX_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

in VS_OUT {
  vec3 world_pos;
} fs_in;


layout(std140, binding = 1) uniform SkyboxData {
  mat4 proj;
  mat4 view;
};
uniform samplerCube cubemap;

void main() {
  vec3 color = texture(cubemap, fs_in.world_pos).rgb;
  color = color / (color + vec3(1.0));
  color = pow(color , vec3(1.0/2.2));
  FragColor = vec4(color , 1.0);
}
DONE


GENERATE_CONVOLUTION_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;

out VS_OUT {
  vec3 world_pos;
} vs_out;

layout(std140, binding = 1) uniform SharedData {
  mat4 proj;
  mat4 view;
};

void main()
{
  vs_out.world_pos = in_pos;  
  gl_Position =  proj * view * vec4(in_pos, 1.0);
}
DONE

GENERATE_CONVOLUTION_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

in VS_OUT {
  vec3 world_pos;
} fs_in;

layout(std140, binding = 1) uniform SharedData {
  mat4 proj;
  mat4 view;
};

uniform samplerCube env_map;

const float PI = 3.14159265359;

void main() {   
  vec3 N = normalize(fs_in.world_pos);
  vec3 irradiance = vec3(0.0);   
  
  // tangent space calculation from origin point
  vec3 up    = vec3(0.0, 1.0, 0.0);
  vec3 right = normalize(cross(up, N));
  up         = normalize(cross(N, right));
     
  float sample_delta = 0.025;
  float nr_samples = 0.0;
  for(float phi = 0.0; phi < 2.0 * PI; phi += sample_delta) {
    for(float theta = 0.0; theta < 0.5 * PI; theta += sample_delta) {
      vec3 tang_sample = vec3(sin(theta) * cos(phi),  sin(theta) * sin(phi), cos(theta));
      vec3 sample_vec = tang_sample.x * right + tang_sample.y * up + tang_sample.z * N; 
      irradiance += texture(env_map, sample_vec).rgb * cos(theta) * sin(theta);
      nr_samples++;
    }
  }
  irradiance = PI * irradiance * (1.0 / float(nr_samples));
  FragColor = vec4(irradiance, 1.0);
}
DONE

