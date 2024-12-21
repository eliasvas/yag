
// TODO: make this a deferred pipeline with a last pass for forward rendered geometry
// TODO: probably instead of pointers we should have some asset system or something
// TODO: should lights be stored here??

xRenderableBundle :: struct {
  mesh : xMesh;
  mat : xMaterial;
  model : m4;
};

xRend3D :: struct {
  bundles : [..]xRenderableBundle;
  bp_sp : oglSP;
  shadow_sp : oglSP;
  shadow_rt : oglRT;
};



xr3d_init :: (using rend : *xRend3D) {
  // create Blinn-Phong Shader
  ogl_sp_init(*bp_sp, BP_VERT_SHADER, BP_FRAG_SHADER);
  ogl_sp_add_attrib(*bp_sp, ogl_attrib_make(0,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code pos),false));
  ogl_sp_add_attrib(*bp_sp, ogl_attrib_make(1,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code norm),false));
  ogl_sp_add_attrib(*bp_sp, ogl_attrib_make(2,oglShaderDataType.VEC2,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code tc),false));

  // create Shadow-Pass Shader
  ogl_sp_init(*shadow_sp, CSM_VERT_SHADER, CSM_GEOM_SHADER, CSM_FRAG_SHADER);
  ogl_sp_add_attrib(*shadow_sp, ogl_attrib_make(0,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code pos),false));
  ogl_sp_add_attrib(*shadow_sp, ogl_attrib_make(1,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code norm),false));
  ogl_sp_add_attrib(*shadow_sp, ogl_attrib_make(2,oglShaderDataType.VEC2,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code tc),false));

  // initialize the shadow Render Target
  assert(ogl_rt_init(*shadow_rt, .{2048,2048}, .D32F));
}

xr3d_push_bundle :: (using rend : *xRend3D, mesh : xMesh, mat : xMaterial, model : m4) {
  array_add(*bundles, .{mesh, mat, model});
}

xr3d_clear_bundles :: (using rend :*xRend3D) {
  bundles.count = 0;
  //array_clear(*bundles);
}

xr3d_set_light_uniforms :: (using rend : *xRend3D, sp : *oglSP) {
  // Directional Light
  xlight_set_to_shader(*xeng().dir_light, sp);
  // Point Light (TODO: add more point lights!)
  light_pos := v3.{3,2,3};
  point_light := xpoint_light_make_basic(light_pos);
  xlight_set_to_shader(*point_light, sp);
}

xr3d_do_shadow_pass :: (using rend : *xRend3D) {
  ogl_clear_all_state();
  ogl_rt_clear(*shadow_rt);
  ogl_rt_bind(*shadow_rt);
  ogl_set_viewport(0,0,shadow_rt.dim.x, shadow_rt.dim.y);
  ogl_bind_sp(*shadow_sp);
  xr3d_set_light_uniforms(rend, *shadow_sp);
  xcsm_data_set_to_shader(*shadow_sp, *xeng().csm_data, xeng().dir_light.dl, false);

  for bundle : bundles {
    xmesh_render(*bundle.mesh, *shadow_sp, *bundle.mat, bundle.model);
  }
}

xr3d_do_main_pass :: (using rend : *xRend3D) {
  ogl_clear_all_state();
  ogl_rt_bind(null);
  ogl_set_viewport(xwin_get_viewport(*xeng().win));
  //ogl_rt_clear(null);
  ogl_bind_sp(*bp_sp);
  xr3d_set_light_uniforms(rend, *bp_sp);

  ogl_sp_set_uniform(*bp_sp, "view_pos", oglShaderDataType.VEC3, *xeng().c.pos);
  shadow_map := ogl_rt_get_attachment(*shadow_rt, .DS);
  shadow_map_slot :s32 = 3;
  ogl_bind_tex_to_slot(*shadow_map, xx shadow_map_slot);
  ogl_sp_set_uniform(*bp_sp, "shadow_map", oglShaderDataType.INT, *shadow_map_slot);
  xcsm_data_set_to_shader(*bp_sp, *xeng().csm_data, xeng().dir_light.dl, true);

  for bundle : bundles {
    xmesh_render(*bundle.mesh, *bp_sp, *bundle.mat, bundle.model);
  }
}
