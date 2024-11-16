// @NOTE: I also think we need to pass in the viewport we are rendering? or no?
// TODO: Fixme, this should be a SKYDOME! like https://www.youtube.com/watch?v=I0jI_d1jORc
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

xskybox_render :: (skybox : *xSkybox, cam : *xCam) {
  using skybox;
  // draw the skybox
  ogl_rt_bind(null);
  ogl_clear_all_state();
  ogl_bind_vertex_buffer(null);
  ogl_bind_sp(*sp);
  ogl_set_viewport(0,0,600,400);
  ogl_sp_set_uniform(*sp, "sky_color", oglShaderDataType.VEC3, *sky_color);
  ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);

  // draw the grid
  ogl_rt_bind(null);
  ogl_clear_all_state();
  ogl_bind_vertex_buffer(null);
  ogl_bind_sp(*grid_sp);
  ogl_set_viewport(0,0,600,400);
  pm := m4_persp(90.0, 600.0/400.0, 0.01, 10000);
  viewm := xcam_get_view_mat(cam);
  ogl_sp_set_uniform(*grid_sp, "pos", oglShaderDataType.VEC3, *cam.pos);
  ogl_sp_set_uniform(*grid_sp, "proj", oglShaderDataType.MAT4, *pm);
  ogl_sp_set_uniform(*grid_sp, "view", oglShaderDataType.MAT4, *viewm);
  ogl_sp_set_dyn_state(*grid_sp, .BLEND);
  ogl_sp_set_dyn_state(*grid_sp, .DEPTH);
  ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);
}

GRID_VERT_SHADER :: #string DONE
#version 430 core
vec2 grid_plane[4] = vec2[](
    vec2(+1.0,-1.0),
    vec2(+1.0,+1.0),
    vec2(-1.0,+1.0),
    vec2(-1.0,-1.0)
);
uniform mat4 view;
uniform mat4 proj;
uniform vec3 pos;
out vec3 near_point;
out vec3 far_point;
out mat4 frag_proj;
out mat4 frag_view;

vec3 unproject_point(vec3 p, mat4 view, mat4 projection) {
  // @FIXME: This is really slow! make matrix inverse calculations CPU side!
  mat4 view_inv = inverse(view);
  mat4 proj_inv = inverse(projection);
  vec4 unprojected_point = view_inv * proj_inv * vec4(p.xyz, 1.0);
  return unprojected_point.xyz / unprojected_point.w;
}

void main() {
   vec3 p = vec3(grid_plane[gl_VertexID].xy, 0.0);
   near_point = unproject_point(vec3(p.xy,0.0), view, proj).xyz;
   far_point = unproject_point(vec3(p.xy,1.0), view, proj).xyz;
   gl_Position = vec4(p, 1.0);
   frag_proj = proj;
   frag_view = view;
}
DONE

GRID_FRAG_SHADER :: #string DONE
#version 430 core
in vec3 near_point;
in vec3 far_point;
in mat4 frag_proj;
in mat4 frag_view;
out vec4 FragColor;

vec4 grid(vec3 fragPos3D, float scale, bool drawAxis) {
    vec2 coord = fragPos3D.xz * scale;
    vec2 derivative = fwidth(coord);
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / derivative;
    float line = min(grid.x, grid.y);
    float minimumz = min(derivative.y, 1);
    float minimumx = min(derivative.x, 1);
    vec4 color = vec4(0.2, 0.2, 0.2, 1.0 - min(line, 1.0));
    if(fragPos3D.x > -0.5 * minimumx && fragPos3D.x < 0.5 * minimumx) color.z = 1.0;
    if(fragPos3D.z > -0.5 * minimumz && fragPos3D.z < 0.5 * minimumz) color.x = 1.0;
    return color;
}

float computeDepth(vec3 pos) {
    vec4 clip_space_pos = frag_proj * frag_view * vec4(pos.xyz, 1.0);
    return (clip_space_pos.z / clip_space_pos.w);
}

// FIXME: These should be uniforms!
float near = 0.01;
float far = 10000;
float computeLinearDepth(vec3 pos) {
    vec4 clip_space_pos = frag_proj * frag_view * vec4(pos.xyz, 1.0);
    float clip_space_depth = (clip_space_pos.z / clip_space_pos.w) * 2.0 - 1.0; // put back between -1 and 1
    float linearDepth = (2.0 * near * far) / (far + near - clip_space_depth * (far - near)); // get linear value between 0.01 and 100
    return linearDepth / far; // normalize
}

float rand(vec2 co){ return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
  float t = -near_point.y / (far_point.y - near_point.y);
  vec3 fragPos3D = near_point + t * (far_point - near_point);

  gl_FragDepth = computeDepth(fragPos3D);

  float linearDepth = computeLinearDepth(fragPos3D);
  float fading = max(0, (0.5 - linearDepth));

  FragColor = (grid(fragPos3D, 0.1, true) + grid(fragPos3D, 1, true))* float(t > 0); // adding multiple resolution for the grid
  FragColor.a *= fading;
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
