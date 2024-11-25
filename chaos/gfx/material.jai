
// TODO: dont use raw pointers, make a simple asset pipeline with handles and stuff

// TODO: should we add option for raw colors along with textures? how should that carry over to shaders?

xSimpleMaterial :: struct {
  diffuse_tex : *oglTex;
  specular_tex : *oglTex;
  shininess : float32;
}

xsimple_material_set_to_shader :: (mat : *xSimpleMaterial, sp : *oglSP) {
  using mat;
  // bind diffuse/specular textures
  diff_slot :s32 = 0;
  ogl_bind_tex_to_slot(diffuse_tex, xx diff_slot);
  ogl_sp_set_uniform(sp, "material.diffuse", oglShaderDataType.INT, *diff_slot);
  spec_slot :s32 = 1;
  ogl_bind_tex_to_slot(specular_tex, xx spec_slot);
  ogl_sp_set_uniform(sp, "material.specular", oglShaderDataType.INT, *spec_slot);
  ogl_sp_set_uniform(sp, "material.shininess", oglShaderDataType.FLOAT, *shininess);
}

