#import "Basic";
#import "String";
#import "chaos";
// TODO: get a good bitmap font, like in microui, and BAKE it in font rendering code path
// TODO: instead of xeng(), do just xeng

bp_sp : oglSP;
light_sp : oglSP;
white_img : oglTex;
blue_img : oglTex;
diff_img : oglTex;
spec_img : oglTex;
trans_red_img : oglTex;

cube_mesh : xMesh;
sphere_mesh : xMesh;
skydome : xSkydome;

shadow_sp : oglSP;
shadow_rt : oglRT;


main :: () {
  xeng_init();

  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
  ogl_tex_init(*white_img, .{1,1}, white.data, oglTexFormat.RGBA8U);

  blue := u8.[ 0x00,0x00,0xFF,0xFF ];
  ogl_tex_init(*blue_img, .{1,1}, blue.data, oglTexFormat.RGBA8U);

  trans_red := u8.[ 0xFF,0x00,0x00,0x7F ];
  ogl_tex_init(*trans_red_img, .{1,1}, trans_red.data, oglTexFormat.RGBA8U);

  assert(ogl_rt_init(*shadow_rt, .{2048,2048}, .D32F));



  cutoff := 50;
  // generate diffuse and specular textures
  diffuse_tex := cast(*u32)alloc(400*400*size_of(u32)); 
  defer free(diffuse_tex);
  for y : 0..400-1 {
    for x : 0..400-1 {
      c1 := u8.[ 0xFF,0x3F,0x3F,0xFF ];
      c2 := u8.[ 0x3F,0x3F,0x3F,0xFF ];
      col : *u32 = *diffuse_tex[x + y * 400];
      if x < cutoff || y < cutoff || x + cutoff > 400 || y + cutoff > 400 {
        col.* = (cast(*u32)c1.data).*;
      } else {
        col.* = (cast(*u32)c2.data).*;
      }
    }
  }
  ogl_tex_init(*diff_img, .{400,400}, xx diffuse_tex, oglTexFormat.RGBA8U);
  // generate specular texture
  spec_tex := cast(*u32)alloc(400*400*size_of(u32)); 
  defer free(spec_tex);
  for y : 0..400-1 {
    for x : 0..400-1 {
      white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
      grey := u8.[ 0x00,0x00,0x00,0x00 ];
      col : *u32 = *spec_tex[x + y * 400];
      if x < cutoff || y < cutoff || x + cutoff > 400 || y + cutoff > 400 {
        col.* = (cast(*u32)white.data).*;
      } else {
        col.* = (cast(*u32)grey.data).*;
      }
    }
  }
  ogl_tex_init(*spec_img, .{400,400}, xx spec_tex, oglTexFormat.RGBA8U);


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

  // Uniform Blocks

  ogl_ublock_load(*xeng().global_data_ub, *bp_sp, 0);


  // json tests
  root_json := xjson_parse_wholefile_string(SAMPLE_JSON);
  node, found := xjson_node_get(root_json, "mesh.tri_count");
  assert(found);
  xjson_print_node(node);

  sample_timer_cb :: (retries : u32, usr_ctx : *void) {print("cb triggered!\n");}
  t := xtimer_make(100, 5, sample_timer_cb, null);

  skydome = xskydome_make();
  cube_mesh = xmesh_gen_cube();
  sphere_mesh = xmesh_gen_sphere(1.0, 64,64);

  while true {
    xeng_frame_init();
    if (xim_kkey_pressed(.SC_ESCAPE)) exit(1); 

    // Do the CSM ImGui menu
    ImGui.Begin("CSM");
    ImGui.SliderFloat3("light dir", xx *xeng().dir_light.dl.dir, -1.0, 1.0); 
    xeng().dir_light.dl.dir = v3_norm(xeng().dir_light.dl.dir);
    ImGui.SliderInt("cascade count",xx *xeng().csm_data.cascade_count, 1, 4);
    ImGui.SliderFloat("zMult factor", xx *xeng().csm_data.z_mult, 1.0, 10.0); 
    ImGui.Checkbox("CSM debug draw", *xeng().csm_data.debug_draw);
    ImGui.Checkbox("CSM debug frustum", *xeng().csm_data.debug_frustum);
    ImGui.End();

    // render the skydome/grid
    ogl_rt_clear(null);
    ogl_rt_clear(*shadow_rt);
    xskydome_render(*skydome);
    ogl_rt_bind(null);
    ogl_clear_all_state();

    // render the shadow map first
    ogl_set_viewport(0,0,shadow_rt.dim.x,shadow_rt.dim.y);
    ogl_rt_bind(*shadow_rt);
    ogl_bind_sp(*shadow_sp);
    render_sample_scene(*shadow_sp);

    // then render the scene with the shadow map bound
    ogl_set_viewport(xwin_get_viewport(*xeng().win));
    ogl_rt_bind(null);
    ogl_bind_sp(*bp_sp);
    ogl_sp_set_uniform(*bp_sp, "view_pos", oglShaderDataType.VEC3, *xeng().c.pos);
    render_sample_scene(*bp_sp);

    xeng_frame_end();
  }

}

render_sample_scene :: (sp : *oglSP) {
  shadow_map := ogl_rt_get_attachment(*shadow_rt, .DS);
  shadow_map_slot :s32 = 3;
  ogl_bind_tex_to_slot(*shadow_map, xx shadow_map_slot);
  ogl_sp_set_uniform(sp, "shadow_map", oglShaderDataType.INT, *shadow_map_slot);

  // Directional Light
  xlight_set_to_shader(*xeng().dir_light, sp);
  // Point Light
  light_pos := v3.{3,2,3};
  point_light := xpoint_light_make_basic(light_pos);
  xlight_set_to_shader(*point_light, sp);

  // render frustum / lsm
  debug_draw : bool = (sp != *shadow_sp);
  xcsm_data_set_to_shader(sp, *xeng().csm_data, xeng().dir_light.dl, debug_draw);

  // render big cube 
  big_cube_mat := xMaterial.{sm=xsimple_material_make(*trans_red_img,*white_img, 8), kind=.SIMPLE};
  bmodel := m4_mult(m4_trans(.{0,-2,0}),m4_scale(.{100,1,100}));
  xmesh_render(*cube_mesh, sp, *big_cube_mat, bmodel);

  // render light source cube (we are overloading the diffuse component for full white)
  light_source_model := m4_mult(m4_trans(light_pos), m4_scale(.{0.2,0.1,0.5}));
  light_mat := xMaterial.{sm=xsimple_material_make(*white_img,*white_img, 8), kind=.SIMPLE};
  light_mat.sm.diffuse_mod = .{1000.0,1000.0,1000.0,1000.0};
  xmesh_render(*cube_mesh, sp, *light_mat, light_source_model);


  // render the cube
  model := m4_mult(m4_trans(.{0,2,0}),m4_rotate(90.0 * cast(float)seconds_since_init()/40.0, .{0,1,0}));
  cube_mat := xMaterial.{sm=xsimple_material_make(*diff_img, *spec_img, 8), kind=.SIMPLE};
  xmesh_render(*cube_mesh, sp, *cube_mat, model);


  // render the cube
  model2 := m4_mult(m4_trans(light_pos),m4_rotate(-90.0 * cast(float)seconds_since_init()/40.0, .{0,1,0}));
  xmesh_render(*cube_mesh, sp, *cube_mat, model2);
  // render the sphere
  sphere_mat := xMaterial.{sm=xsimple_material_make(*blue_img,*white_img, 8), kind=.SIMPLE};
  sphere_mat.sm.specular_mod = .{0.7,0.7,0.7,1};
  xmesh_render(*sphere_mesh, sp, *sphere_mat, m4_trans(.{3,3,0}));
}


