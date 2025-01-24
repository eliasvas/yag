// FIXME: currently, in xgltf we don't set the factors if textures are provided.. FIX this and provide also good default values according to the standard
// TODO: these raw pointers should become id's in our resource system probably
xPBR_Material :: struct {
  base_col_tex : *oglTex; // binding 0
  base_factor : v4 = v4.{1,1,1,1};
  metal_rough_tex : *oglTex; // binding 1
  metal_factor : float = 1.0;
  rough_factor : float = 1.0;
  normal_tex : *oglTex; // binding 2
  emissive_tex : *oglTex; // binding 3
  emissive_factor : v3 = v3.{1,1,1};
  occlusion_tex : *oglTex; // binding 4
}

//@FIXME: this is retarded - move over to actual PBR pipeline
xpbr_material_set_to_shader :: (using mat : *xPBR_Material, sp : *oglSP) {
  if base_col_tex then ogl_sp_bind_sampler_to_slot(sp, "albedo_map", base_col_tex, 0);
  if metal_rough_tex then ogl_sp_bind_sampler_to_slot(sp, "metal_rough_map", metal_rough_tex, 1);
  if normal_tex then ogl_sp_bind_sampler_to_slot(sp, "normal_map", normal_tex, 2);
}

xpbr_material_set_to_ublock:: (using mat : *xPBR_Material, mat_ublock : *oglUBlock) {
  ogl_ublock_set(mat_ublock, "base_factor", xx *base_factor);
  ogl_ublock_set(mat_ublock, "metallic_factor", xx *metal_factor);
  ogl_ublock_set(mat_ublock, "roughness_factor", xx *rough_factor);
  ogl_ublock_set(mat_ublock, "emissive_factor", xx *emissive_factor);
}

/*
layout(std140, binding = 3) uniform MaterialData {
  vec4 base_factor;
  float metallic_factor;
  float roughness_factor;
  vec3 emissive_factor;
};
*/

