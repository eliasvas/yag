// TODO: these raw pointers should become id's in our resource system probably
xPBR_Material :: struct {
  base_col_tex : *oglTex; // binding 0
  metal_tex : *oglTex; // binding 1
  rough_tex : *oglTex; // binding 2
  emissive_tex : *oglTex; // binding 3
  occlusion_tex : *oglTex; // binding 4
  normal_tex : *oglTex; // binding 5
}

xpbr_material_set_to_shader :: (using mat : *xPBR_Material, sp : *oglSP) {
  if base_col_tex then ogl_sp_bind_sampler_to_slot(sp, "diffuse", base_col_tex, 0);
  if metal_tex then ogl_sp_bind_sampler_to_slot(sp, "specular", metal_tex, 1);
}


