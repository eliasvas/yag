// @NOTE: I also think we need to pass in the viewport we are rendering? or no?
// Tried this, should revisit https://www.youtube.com/watch?v=RqrkVmj-ntM
// also, look into fwidth a bit more https://www.ronja-tutorials.com/post/046-fwidth/

xGrid :: struct {
  sp : oglSP;
  grid_thick1 : float = 1.0;
  grid_thick2 : float = 5.0;
  ub1 : oglUBlock;
}

xgrid_make :: () -> xGrid {
  grid : xGrid;
  ogl_sp_init(*grid.sp, GRID_VERT_SHADER, GRID_FRAG_SHADER);
  ogl_ublock_load(*grid.ub1, *grid.sp, 1);
  return grid;
}

xgrid_render :: (using grid : *xGrid) {
  ogl_rt_bind(null);
  ogl_bind_sp(*sp);

  ogl_ublock_set(*ub1, "cam_pos",xx *xeng().c.pos);
  grid_stretch_factor :float= 300;
  ogl_ublock_set(*ub1, "grid_stretch_factor",xx *grid_stretch_factor);
  cell_line_thickness :float= 0.1;
  ogl_ublock_set(*ub1, "cell_line_thickness",xx *cell_line_thickness);
  subcell_line_thickness :float= 0.05;
  ogl_ublock_set(*ub1, "subcell_line_thickness",xx *subcell_line_thickness);
  cell_color :v4= .{0.6,0.6,0.6,1.0};
  ogl_ublock_set(*ub1, "cell_color",xx *cell_color);
  subcell_color :v4= .{0.2,0.2,0.2,1.0};
  ogl_ublock_set(*ub1, "subcell_color",xx *subcell_color);
  ogl_ublock_bind_to_slot(*ub1);


  bindings : oglBindingDesc = .{};
  ogl_sp_apply_bindings(*sp, bindings);


  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    //flags = .BLEND | .DEPTH
    flags = .BLEND
  };
  ogl_sp_apply_dyn_state(*sp, dyn_state);
  ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);
}



GRID_VERT_SHADER :: #string DONE
#version 430 core

/*
vec3 grid_plane[4] = vec3[](
  vec3(+1.0,0,-1.0),
  vec3(+1.0,0,+1.0),
  vec3(-1.0,0,+1.0),
  vec3(-1.0,0,-1.0)
);
*/

vec3 grid_plane[4] = vec3[](
  vec3(+1.0,-1.0,0),
  vec3(+1.0,+1.0,0),
  vec3(-1.0,+1.0,0),
  vec3(-1.0,-1.0,0)
);

layout(std140, binding = 0) uniform GlobalData {
  mat4 proj;
  mat4 view;
};

layout(std140, binding = 1) uniform GridData {
  vec4 cell_color;
  vec4 subcell_color;
  vec3 cam_pos;
  float grid_stretch_factor;
  float cell_line_thickness;
  float subcell_line_thickness;
};


out VS_OUT {
  vec3 world_pos;
} vs_out;

void main() {
  vec4 p = vec4(grid_stretch_factor * grid_plane[gl_VertexID].xyz, 1.0);
  p.x += cam_pos.x;
  p.z += cam_pos.z;
  vs_out.world_pos = p.xyz;
  gl_Position = proj * view * p;
}
DONE

GRID_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

in VS_OUT {
  vec3 world_pos;
} fs_in;

layout(std140, binding = 1) uniform GridData {
  vec4 cell_color;
  vec4 subcell_color;
  vec3 cam_pos;
  float grid_stretch_factor;
  float cell_line_thickness;
  float subcell_line_thickness;
};


float fwidth_hlsl(vec2 v) {
  return max(max(abs(dFdx(v.x)), abs(dFdx(v.y))), max(abs(dFdy(v.x)), abs(dFdy(v.y))));
}

void main() {
  vec4 color = vec4(0);

  // This is used for a small fixup, for intuition dont take into account
  //float d = fwidth_hlsl(world_pos.xz);
  //float d = fwidth(world_pos.xz).x;
  vec3 world_pos = fs_in.world_pos;
  float d = 0;

  vec2 subcell_size = vec2(1.0,1.0);
  vec2 subcell_coords = mod(world_pos.xz, subcell_size);
  vec2 subcell_dist = abs(subcell_coords);

  vec2 cell_size = vec2(10.0,10.0);
  // 0. calculate all cell coordinates
  vec2 cell_coords = mod(world_pos.xz, cell_size);
  // 1. calculate distance to cell boundaries [0-1]
  vec2 cell_dist = abs(cell_coords);


  // 2. if distance is 'thickness' close to each edge, paint it
  if (cell_dist.x < (d+cell_line_thickness)*0.5 || cell_dist.y < cell_line_thickness*0.5) color = cell_color;
  else if (subcell_dist.x < (d + subcell_line_thickness)*0.5 || subcell_dist.y < subcell_line_thickness*0.5) color = subcell_color;
  // 3. else discard fragment entirely
  else discard;

  // 4. perform simple opacity fall-off to fix moire patterns (maybe we need to revisit this)
  float min_fade_dist = grid_stretch_factor * 0.05;
  float max_fade_dist = grid_stretch_factor * 0.5;
  float fade_dist = abs(cam_pos.y)* 25.0; // height_to_fade_distance_ratio
  fade_dist = max(fade_dist, min_fade_dist);
  fade_dist = min(fade_dist, max_fade_dist);
  float dist_to_cam = length(world_pos.xz  - cam_pos.xz);
  float opacity_falloff = smoothstep(1.0, 0.0, dist_to_cam / fade_dist);
  // 4.5 DONT :D
  opacity_falloff = 1.0;

  //5. if within bounds we paint the x-axis red and z-axis blue
  if (abs(world_pos.x) < (d+cell_line_thickness)*0.5) color = vec4(0.9,0.25,0.25,1);
  if (abs(world_pos.z) < (d+cell_line_thickness)*0.5) color = vec4(0.25,0.25,0.9,1);

  FragColor = vec4(color.xyz * opacity_falloff, color.w);
}
DONE








