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
  arr : [8]v2;
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
  pl.diffuse  = .{0.95,0.95,0.95};
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
  dl.dir = v3_norm(v3.{1,1,0});
  dl.ambient  = .{0.2,0.2,0.2};
  dl.diffuse  = .{1.0,1.0,1.0};
  dl.specular = .{1.0,1.0,1.0};
  return light;
}

xlight_set_to_ub :: (light : *xLight, ub : *oglUBlock) {
  using light;
  if kind == {
    case .DIRECTIONAL;
      ogl_ublock_set(ub, "dir_light.ambient", xx *dl.ambient);
      ogl_ublock_set(ub, "dir_light.diffuse", xx *dl.diffuse);
      ogl_ublock_set(ub, "dir_light.specular", xx *dl.specular);
      ogl_ublock_set(ub, "dir_light.dir", xx *dl.dir);
    case .POINT;
      ogl_ublock_set(ub, "point_light.ambient", xx *pl.ambient);
      ogl_ublock_set(ub, "point_light.diffuse", xx *pl.diffuse);
      ogl_ublock_set(ub, "point_light.specular", xx *pl.specular);
      ogl_ublock_set(ub, "point_light.pos", xx *pl.pos);
      ogl_ublock_set(ub, "point_light.constant", xx *pl.constant);
      ogl_ublock_set(ub, "point_light.linear", xx *pl.linear);
      ogl_ublock_set(ub, "point_light.quadratic", xx *pl.quadratic);
    case;
  }
}

