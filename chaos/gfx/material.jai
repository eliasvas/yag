
// TODO: dont use raw pointers, make a simple asset pipeline with handles and stuff

// TODO: should we add option for raw colors along with textures? how should that carry over to shaders?

xSimpleMaterial :: struct {
  diffuse_tex : *oglTex;
  diffuse_mod : v4 = .{1.0,1.0,1.0,1.0};
  specular_tex : *oglTex;
  specular_mod : v4 = .{1.0,1.0,1.0,1.0};
  shininess : float32 = 8;
}

xsimple_material_make :: ( diffuse_tex : *oglTex, specular_tex : *oglTex, shininess : float32 = 8) -> xSimpleMaterial {
  mat : xSimpleMaterial;

  mat.diffuse_tex = diffuse_tex;
  mat.specular_tex = specular_tex;
  mat.shininess = shininess;
  
  return mat;
}

xsimple_material_make :: ( diffuse_color : v4, specular_color : v4 = v4.{1,1,1,1}, shininess : float32 = 8) -> xSimpleMaterial {
  mat : xSimpleMaterial;

  // FIXME: this should be done by the asset system, WHY do we keep making 1x1 white textures!
  white_tex :*oglTex= alloc(size_of(oglTex));
  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];

  ogl_tex_init(white_tex, .{1,1}, white.data, oglTexFormat.RGBA8U);
  mat.diffuse_tex = white_tex;
  mat.specular_tex = white_tex;
  mat.diffuse_mod = diffuse_color;
  mat.specular_mod = specular_color;
  mat.shininess = shininess;
  
  return mat;
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
  ogl_sp_set_uniform(sp, "material.diffuse_mod", oglShaderDataType.VEC4, *diffuse_mod);
  ogl_sp_set_uniform(sp, "material.specular_mod", oglShaderDataType.VEC4, *specular_mod);
  ogl_sp_set_dyn_state(sp, .DEPTH);
}

