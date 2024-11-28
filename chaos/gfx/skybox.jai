xSkybox :: struct {
  sp  : oglSP;
  noise_tex : oglTex; // This is optional right?
  sky_color   : v3 = .{0.3,0.5,0.8};
  cloud_color : v3 = .{1,1,1};
  sun_color   : v3 = .{1,0.7,0.4};
  cloud_speed : float = 1.0;

  grid : xGrid;
};

xskybox_make :: () -> xSkybox {
  using skybox : xSkybox;
  ogl_sp_init(*sp, SKYBOX_VERT_SHADER, SKYBOX_FRAG_SHADER);
  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
  ogl_tex_init(*noise_tex, .{1,1}, white.data, oglTexFormat.RGBA8U);
  skybox.grid = xgrid_make();
  return skybox;
}

xskybox_render :: (skybox : *xSkybox, viewport : v4, cam : *xCam, proj : m4) {
  using skybox;
  // draw the skybox
  ogl_rt_bind(null);
  ogl_clear_all_state();
  ogl_bind_vertex_buffer(null);
  ogl_bind_sp(*sp);
  ogl_set_viewport(viewport.x, viewport.y, viewport.width, viewport.height); // TODO: make an API for this
  ogl_sp_set_uniform(*sp, "sky_color", oglShaderDataType.VEC3, *cloud_color);
  //ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);

  xgrid_render(*skybox.grid, viewport, cam, proj);

}


SKYBOX_VERT_SHADER :: #string DONE
#version 430 core
vec2 grid_plane[4] = vec2[](
    vec2(+1.0,-1.0),
    vec2(+1.0,+1.0),
    vec2(-1.0,+1.0),
    vec2(-1.0,-1.0)
);
void main() {
   vec3 p = vec3(grid_plane[gl_VertexID].xy, 0.0);
   gl_Position = vec4(p, 1.0);
}
DONE

SKYBOX_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

uniform vec3 sky_color;

void main() {
  FragColor = vec4(sky_color, 1.0);
}
DONE
