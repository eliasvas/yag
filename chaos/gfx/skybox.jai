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

  ogl_sp_init(*sp, SKYBOX_VERT_SHADER, SKYBOX_FRAG_SHADER);


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


SKYBOX_VERT_SHADER :: #string DONE
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

SKYBOX_FRAG_SHADER :: #string DONE
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
  sp  : oglSP;
  ub_b1  : oglUBlock;
};

xhdr_skybox_generate :: (hdr_eq_image_path : string) -> xHDR_Skybox {
  skybox : xHDR_Skybox;

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
  }
  // copy these from the RT to a cubemap!
  skybox.cubemap = ogl_tex_convert_rt_to_cubemap(*junk_rt);

  // optional: deinit the RT

  return skybox;
}

xhdr_skybox_render :: (using skybox : *xHDR_Skybox) {

}

xhdr_skybox_deinit :: (hdr_equi_image_path : string) {
  // delete hdr_eq_tex
  // delete cubemap 
  // delete sp
}

// @FIXME: clean this up
xhdr_skybox_bind_cubemap_to_sp :: (using skybox : *xHDR_Skybox, shader : *oglSP) {
  ogl_sp_bind_sampler_to_slot(shader, "irradiance_map", *hdr_eq_tex, 5);
  ogl_sp_bind_sampler_to_slot(shader, "cubemap", *cubemap, 6);
}


