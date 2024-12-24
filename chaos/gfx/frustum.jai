xfrustum_get_ndc_cube_corners:: () -> [8]v3 {
  corners : [8]v3;
  corner_count := 0;
  for z : 0..1 {
    for y : 0..1 {
      for x : 0..1 {
        corner_ndc : v3 = .{x*2.0-1.0,y*2.0-1.0,z*2.0-1.0};
        corners[corner_count] = corner_ndc;
        corner_count+=1;
      }
    }
  }
  return corners;
}
// these are the same indices that will be used for the WS frustum
xfrustum_get_ndc_cube_indices :: () -> [36]u32 {
  indices : [36]u32;
  indices_count := 0;

  ndc_corners := #run xfrustum_get_ndc_cube_corners();
  // get the indices of every 'face' of the NDC cube (frustum is the same) vertices
  faces := iv4.[
    .{0,1,3,2}, // back
    .{4,5,7,6}, // front
    .{0,1,5,4}, // bottom
    .{2,3,7,6}, // top
    .{0,2,6,4}, // near
    .{1,3,7,5}, // far
  ];
  for f : faces {
    indices[indices_count] = f.arr[0];
    indices_count+=1;
    indices[indices_count] = f.arr[1];
    indices_count+=1;
    indices[indices_count] = f.arr[2];
    indices_count+=1;

    indices[indices_count] = f.arr[0];
    indices_count+=1;
    indices[indices_count] = f.arr[2];
    indices_count+=1;
    indices[indices_count] = f.arr[3];
    indices_count+=1;
  }

  assert(indices_count == 36);
  return indices;
}


/*
  We unproject the frustum corners from NDC to world-space by applying the reverse
  of the ViewProj transform to cube NDC coords.
  This should produce an array of all the corners for a given view and projection matrix.
*/
xfrustum_get_corners_in_ws :: (proj : m4, view : m4) -> [8]v3 {
  corners := #run xfrustum_get_ndc_cube_corners();
  corner_count := 0;

  inv : m4 = m4_inverse(m4_mult(proj, view));
  for *c : corners {
      corner_ndc : v4 = .{c.x,c.y,c.z,1.0};
      corner_wc := m4_multv(inv, corner_ndc);
      corner_wc /= corner_wc.w;
      c.* = .{corner_wc.x,corner_wc.y,corner_wc.z};
  }
  return corners;
}

// calculating the center of a frustum is simple AF
xfrustum_calc_center_in_ws :: (corners : []v3) -> v3 {
  center : v3 = .{0,0,0};
  for c : corners {
    center += c;
  }
  center = center / cast(float)corners.count;
  return center;
}

// The view matrix should be a look_at from dl.direction to the center of the frustum
// proj and view are projection and view of the frustum we want to 'enclose'
xfrustum_calc_vm_for_dir_light :: (corners : []v3, dl : xDirectionalLight) -> m4 {
  center := xfrustum_calc_center_in_ws(corners);
  // TODO: look into how i implement look_at
  light_view := m4_look_at(center, center - dl.dir, .{0,1,0});
  //light_view := m4_look_at(center + dl.dir, center, .{0,1,0});
  return light_view;
}

// here we calculate the bounds of the ortho projection by taking into account ws coords
// and transforming them to light's coordinate system, so we are producing an AABB
xfrustum_calc_pm_for_dir_light :: (corners : []v3, dl_view : m4, dl : xDirectionalLight, z_mult : float32 = 1.0) -> m4 {
  min_x := FLOAT32_MAX;
  min_y := FLOAT32_MAX;
  min_z := FLOAT32_MAX;

  max_x := FLOAT32_MIN;
  max_y := FLOAT32_MIN;
  max_z := FLOAT32_MIN;

  for c : corners {
    v := m4_multv(dl_view, .{c.x,c.y,c.z,1.0});
    min_x = min(min_x, v.x);
    min_y = min(min_y, v.y);
    min_z = min(min_z, v.z);
    max_x = max(max_x, v.x);
    max_y = max(max_y, v.y);
    max_z = max(max_z, v.z);
  }

  min_z = ifx min_z < 0.0 then min_z*z_mult else min_z/z_mult;
  max_z = ifx max_z < 0.0 then max_z/z_mult else max_z*z_mult;

  light_proj := m4_ortho(min_x,max_x,min_y,max_y,min_z,max_z);
  return light_proj;
}


xfrustum_debug_draw_corners :: (corners : []v3, col : v4 = .{0.5,0.5,0.5,0.5}) {
  frustum_indices := #run xfrustum_get_ndc_cube_indices(); // 36 indices

  // a frustum is 12 triangles
  for t_i : 0..11 {
    t : xImmPrimitiveTriangle = .{
      corners[frustum_indices[t_i*3+0]],
      corners[frustum_indices[t_i*3+1]],
      corners[frustum_indices[t_i*3+2]],
    };
    ximm_triangle(t, col);
  }
}


xFrustumDefaultColor :: v4.{0,0,1,0.5};

xFrustumCascadeColors :: v4.[
  v4.{1,0,0,0.5},
  v4.{0.4,0,0.6,0.5},
  v4.{0.2,0.9,0.2,0.5},
  v4.{1,1,0.5,0.5}
];

xfrustum_calc_lsm :: (view : m4, proj : m4, dir_light : xDirectionalLight, cascade_index : u32, z_mult : float32 = 1.0, debug_draw : bool = true) -> m4 {
  // here we get the world space coordinates of our frustum, for the view and proj we specified
  corners := xfrustum_get_corners_in_ws(proj,view);
  if debug_draw then xfrustum_debug_draw_corners(corners, xFrustumDefaultColor);
  // here we calculate the view and projection of the frustum for the shadow_map(s),
  // so it can enclose the whole sub-frustum we calculated above
  light_view := xfrustum_calc_vm_for_dir_light(corners, dir_light);
  light_proj := xfrustum_calc_pm_for_dir_light(corners, light_view, dir_light, z_mult);
  if debug_draw {
      corners_lsm := xfrustum_get_corners_in_ws(light_proj,light_view);
      xfrustum_debug_draw_corners(corners_lsm, xFrustumCascadeColors[cascade_index]);
  }
  // we combine light_view and light_proj to get a light_space_matrix for all sub-frusta
  lsm := m4_mult(light_proj, light_view);
  return lsm;
}

xfrustum_calc_lsms_and_set_to_ub :: (ub : *oglUBlock, view : m4, proj : []m4, dir_light : xDirectionalLight, z_mult : float32 = 1.0, debug_draw : bool = true){
  for p,idx : proj {
    lsm_i := xfrustum_calc_lsm(view,p,dir_light, xx idx, z_mult, debug_draw);
    name := sprint("lsm[%]", idx);
    lsm_i = m4_transpose(lsm_i);
    ogl_ublock_set(ub, name, xx lsm_i.raw.data);
    dist := sprint("cascade_plane_distances[%]", idx);
    far := persp_get_far(proj[idx]);
    ogl_ublock_set(ub, dist, xx *far);
  }

}

xCSMData :: struct {
  cview : m4; // the view matrix use as Cameras view (for frustum generation) 
  cproj : m4; // the projection matrix used as Cameras projection (for cascade generation)
  cascade_count : u32 = 3;
  z_mult : float32 = 1.0;
  debug_draw : bool = false;
  debug_frustum : bool = false;
  enabled : bool = false;
}

xcsm_data_calc :: (csm_data : *xCSMData) {
  using csm_data;

  debug_frust_pos :v3= .{0,0,50} + .{xeng().view._14, xeng().view._24,xeng().view._34};
  cview = ifx debug_frustum then m4_trans(debug_frust_pos) else xeng().view;

  debug_proj := m4_persp_gen_cascades(xeng().proj, 4)[0];
  cproj = ifx debug_frustum then debug_proj else xeng().proj;
}

xcsm_data_set_to_ub :: (ub : *oglUBlock, csm_data : *xCSMData, dir_light : xDirectionalLight, draw : bool) {
  using csm_data;
  proj_cascades := m4_persp_gen_cascades(cproj, cascade_count);
  xfrustum_calc_lsms_and_set_to_ub(ub, cview, proj_cascades, dir_light, z_mult, draw & debug_draw);
}


CSM_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_norm;
layout (location = 2) in vec2 in_tc;

out VS_OUT
{
   vec3 world_pos;
   vec3 normal;
   vec2 tc;
} vs_out;

layout(std140, binding = 1) uniform ShadowData {
  mat4 lsm[4];
  mat4 model;
  float cascade_plane_distances[4];
};


void main() {
  gl_Position = model*vec4(in_pos.xyz, 1.0);
  // we need these so that shader introspection finds norm/tc :(
  vs_out.world_pos = gl_Position.xyz;
  vs_out.normal = in_norm;
  vs_out.tc = in_tc;
}
DONE

CSM_FRAG_SHADER :: #string DONE
#version 430 core
void main(){
}
DONE

CSM_GEOM_SHADER :: #string DONE
#version 430 core
layout(triangles, invocations = 4) in;
layout(triangle_strip, max_vertices = 3) out;
 
layout(std140, binding = 1) uniform ShadowData {
  mat4 lsm[4];
  mat4 model;
  float cascade_plane_distances[4];
};

void main() {          
    for (int i = 0; i < 4; ++i) {
        gl_Position = lsm[gl_InvocationID] * gl_in[i].gl_Position;
        gl_Layer = gl_InvocationID;
        EmitVertex();
    }
    EndPrimitive();
}
DONE
