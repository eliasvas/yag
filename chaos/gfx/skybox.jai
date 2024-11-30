// skydome based on this paper: 
// https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-16-accurate-atmospheric-scattering
// TODO: keep reading the paper (after HDR is done)
// TODO: Its really slow, we need to do the trick where we draw OVER other triangles, see leanropengl skybox chapter i think?

xSkydome :: struct {
  sp  : oglSP;
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
  ogl_sp_add_attrib(*sp, ogl_attrib_make(0,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code pos),false));
  ogl_sp_add_attrib(*sp, ogl_attrib_make(1,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code norm),false));
  ogl_sp_add_attrib(*sp, ogl_attrib_make(2,oglShaderDataType.VEC2,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code tc),false));
  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
  ogl_tex_init(*noise_tex, .{1,1}, white.data, oglTexFormat.RGBA8U);
  sphere_mesh = xmesh_gen_sphere(1,8,8,true);
  grid = xgrid_make();
  return skydome;
}

xskydome_render :: (skydome : *xSkydome, viewport : v4, cam : *xCam, proj : m4) {
  using skydome;
  // we cancel translation, the skydome is to be rendered at the center
  view := xcam_get_view_mat(cam);
  view._14 = 0;
  view._24 = 0;
  view._34 = 0;
  // draw the skybox
  ogl_rt_bind(null);
  ogl_clear_all_state();
  ogl_bind_vertex_buffer(null);
  ogl_bind_sp(*sp);
  ogl_set_viewport(viewport.x, viewport.y, viewport.width, viewport.height); // TODO: make an API for this
  ogl_sp_set_uniform(*sp, "sky_color", oglShaderDataType.VEC3, *cloud_color);
  ogl_sp_set_uniform(*sp, "view", oglShaderDataType.MAT4, view.raw.data);
  ogl_sp_set_uniform(*sp, "proj", oglShaderDataType.MAT4, proj.raw.data);
  //ogl_sp_set_dyn_state(*sp, .DEPTH);

  xmesh_render(*sphere_mesh, *sp, m4_I);

  xgrid_render(*skydome.grid, viewport, cam, proj);

}


SKYBOX_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_norm;
layout (location = 2) in vec2 in_tc;
out vec3 f_world_pos;

uniform mat4 view;
uniform mat4 proj;
void main() {
  f_world_pos = in_pos;
  gl_Position = proj*view*vec4(in_pos,1.0);
}
DONE

SKYBOX_FRAG_SHADER :: #string DONE
#version 430 core
in vec3 f_world_pos;
out vec4 FragColor;

uniform vec3 color_bottom = vec3(0.2,0.05,0.05);
uniform vec3 color_top = vec3(0.05,0.05,0.2);

void main() {
  vec3 col = mix(color_bottom, color_top, f_world_pos.y + 1.0 / 2.0);
  FragColor = vec4(col, 1.0);
}
DONE
