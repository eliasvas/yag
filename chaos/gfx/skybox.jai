// @NOTE: I also think we need to pass in the viewport we are rendering? or no?
// Tried this, should revisit https://www.youtube.com/watch?v=RqrkVmj-ntM
xSkybox :: struct {
  sp  : oglSP;
  noise_tex : oglTex; // This is optional right?
  sky_color   : v3 = .{0.3,0.5,0.8};
  cloud_color : v3 = .{1,1,1};
  sun_color   : v3 = .{1,0.7,0.4};
  cloud_speed : float = 1.0;

  // @TODO: should this be in a different file? e.g grid.jai
  grid_sp  : oglSP;
  grid_thickness : float = 1.0;
};

xskybox_make :: () -> xSkybox {
  using skybox : xSkybox;
  ogl_sp_init(*sp, SKYBOX_VERT_SHADER, SKYBOX_FRAG_SHADER);
  ogl_sp_init(*grid_sp, GRID_VERT_SHADER, GRID_FRAG_SHADER);
  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
  ogl_tex_init(*noise_tex, .{1,1}, white.data, oglTexFormat.RGBA8U);
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

  // draw the grid
  ogl_rt_bind(null);
  ogl_clear_all_state();
  ogl_bind_vertex_buffer(null);
  ogl_bind_sp(*grid_sp);
  ogl_set_viewport(viewport.x, viewport.y, viewport.width, viewport.height); // TODO: make an API for this
  viewm := xcam_get_view_mat(cam);
  vp := m4_mult(proj, viewm);
  ogl_sp_set_uniform(*grid_sp, "cam_pos", oglShaderDataType.VEC3, *cam.pos);
  ogl_sp_set_uniform(*grid_sp, "VP", oglShaderDataType.MAT4, *vp);
  ogl_sp_set_dyn_state(*grid_sp, .BLEND2);
  ogl_sp_set_dyn_state(*grid_sp, .DEPTH);
  ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);
}

GRID_VERT_SHADER :: #string DONE
#version 430 core
vec3 grid_plane[4] = vec3[](
    vec3(+1.0,0,-1.0),
    vec3(+1.0,0,+1.0),
    vec3(-1.0,0,+1.0),
    vec3(-1.0,0,-1.0)
);
uniform vec3 cam_pos;
uniform float grid_stretch_factor = 10.0;
uniform mat4 VP; // proj * view
out vec3 world_pos;

void main() {
   vec4 p = vec4(grid_stretch_factor * grid_plane[gl_VertexID].xyz, 1.0);
   p.x += cam_pos.x;
   p.z += cam_pos.z;
   world_pos = p.xyz;
   gl_Position = VP * p;
}
DONE

GRID_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;
in vec3 world_pos;

uniform float grid_cell_size = 1.0;
uniform vec4 grid_color_thick = vec4(1.0,1.0,1.0,1.0);

float satf(float x) { float f = clamp(x, 0.0, 1.0); return f; }
vec2 satv(vec2 x) { vec2 v = clamp(x, vec2(0.0), vec2(1.0)); return v; }
float max2(vec2 v) { float f = max(v.x, v.y); return f; }


void main() {
  vec2 dvx = vec2(dFdx(world_pos.x), dFdy(world_pos.x));
  vec2 dvy = vec2(dFdx(world_pos.z), dFdy(world_pos.z));
  float lx = length(dvx);
  float ly = length(dvy);
  vec2 dudv = vec2(lx, ly);
  vec2 mod_div_dudv = mod(world_pos.xz, grid_cell_size) / dudv;
  float lod0a = max2(vec2(1.0) - abs(satv(mod_div_dudv) * 2.0 - vec2(1.0)) );

  vec4 col = grid_color_thick;
  col.a *= lod0a;
  FragColor = col;

  //FragColor = vec4(world_pos,1);
}
DONE


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
