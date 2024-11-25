xLightKind :: enum {
  DIRECTIONAL;
  POINT;
  AREA;
};

xPointLight :: struct {
  pos : v3;

  ambient  : v3;
  diffuse  : v3;
  specular : v3;

  constant  : float32;
  linear    : float32;
  quadratic : float32;
}

xDirectionalLight :: struct {
  dir : v3;

  ambient  : v3;
  diffuse  : v3;
  specular : v3;
}

xLight :: struct {
  union {
    pl : xPointLight;
    dl : xDirectionalLight;
  }
  kind : xLightKind;
}

xpoint_light_make_basic :: (pos : v3) -> xLight {
  light : xLight;
  using light;
  kind = .POINT;
  pl.pos = pos;

  pl.ambient  = .{0.2,0.2,0.9};
  pl.diffuse  = .{0.2,0.2,0.9};
  pl.specular = .{1.0,1.0,1.0};

  pl.constant = 1.0;
  pl.linear = 0.09;
  pl.quadratic = 0.032;
 
  return light;
}
xdir_light_make_basic :: () -> xLight {
  light : xLight;
  using light;
  kind = .DIRECTIONAL;
  dl.dir = v3.{-0.2,-1.0,-0.3};
  dl.ambient  = .{0.2,0.2,0.2};
  dl.diffuse  = .{0.9,0.2,0.2};
  dl.specular = .{1.0,1.0,1.0};
  return light;
}

xlight_set_to_shader :: (light : *xLight, sp : *oglSP) {
  using light;
  if kind == {
    case .DIRECTIONAL;
      ogl_sp_set_uniform(sp, "dir_light.ambient", oglShaderDataType.VEC3, *dl.ambient);
      ogl_sp_set_uniform(sp, "dir_light.diffuse", oglShaderDataType.VEC3, *dl.diffuse);
      ogl_sp_set_uniform(sp, "dir_light.specular", oglShaderDataType.VEC3, *dl.specular);
      ogl_sp_set_uniform(sp, "dir_light.dir", oglShaderDataType.VEC3, *dl.dir);
    case .POINT;
      ogl_sp_set_uniform(sp, "point_light.ambient", oglShaderDataType.VEC3, *pl.ambient);
      ogl_sp_set_uniform(sp, "point_light.diffuse", oglShaderDataType.VEC3, *pl.diffuse);
      ogl_sp_set_uniform(sp, "point_light.specular", oglShaderDataType.VEC3, *pl.specular);
      ogl_sp_set_uniform(sp, "point_light.pos", oglShaderDataType.VEC3, *pl.pos);
      ogl_sp_set_uniform(sp, "point_light.constant", oglShaderDataType.FLOAT, *pl.constant);
      ogl_sp_set_uniform(sp, "point_light.linear", oglShaderDataType.FLOAT, *pl.linear);
      ogl_sp_set_uniform(sp, "point_light.quadratic", oglShaderDataType.FLOAT, *pl.quadratic);
    case;
  }
}

