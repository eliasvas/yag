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

rend : xRend3D;

main :: () {
  xeng_init();

  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
  ogl_tex_init(*white_img, .{1,1}, white.data, oglTexFormat.RGBA8U);

  blue := u8.[ 0x00,0x00,0xFF,0xFF ];
  ogl_tex_init(*blue_img, .{1,1}, blue.data, oglTexFormat.RGBA8U);

  trans_red := u8.[ 0xFF,0x00,0x00,0x7F ];
  ogl_tex_init(*trans_red_img, .{1,1}, trans_red.data, oglTexFormat.RGBA8U);



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


  xr3d_init(*rend);


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
    ImGui.Checkbox("Shadows enabled", *xeng().csm_data.enabled);
    ImGui.Checkbox("CSM debug draw", *xeng().csm_data.debug_draw);
    ImGui.Checkbox("CSM debug frustum", *xeng().csm_data.debug_frustum);
    fps := 1.0/(xeng().dt);
    frame_str := tprint("fps: %", fps);
    ImGui.TextUnformatted(frame_str.data);
    ImGui.End();

    big_cube_mat := xMaterial.{sm=xsimple_material_make(*trans_red_img,*white_img, 8), kind=.SIMPLE};
    big_model := m4_mult(m4_trans(.{0,-2,0}),m4_scale(.{100,1,100}));
    xr3d_push_bundle(*rend, cube_mesh, big_cube_mat, big_model);

    spin_model := m4_mult(m4_trans(.{0,2,0}),m4_rotate(90.0 * cast(float)seconds_since_init()/40.0, .{0,1,0}));
    spin_cube_mat := xMaterial.{sm=xsimple_material_make(*diff_img, *spec_img, 8), kind=.SIMPLE};
    xr3d_push_bundle(*rend, cube_mesh, spin_cube_mat, spin_model);


    light_pos := v3.{3,2,3};
    light_source_model := m4_mult(m4_trans(light_pos), m4_scale(.{0.5,0.5,0.5}));
    light_mat := xMaterial.{sm=xsimple_material_make(*white_img,*white_img, 8), kind=.SIMPLE};
    light_mat.sm.diffuse_mod = .{1000.0,1000.0,1000.0,1000.0};
    xr3d_push_bundle(*rend, cube_mesh, light_mat, light_source_model);

    sphere_mat := xMaterial.{sm=xsimple_material_make(*blue_img,*white_img, 8), kind=.SIMPLE};
    sphere_mat.sm.specular_mod = .{0.7,0.7,0.7,1};
    xr3d_push_bundle(*rend, sphere_mesh, sphere_mat, m4_trans(.{3,3,0}));




    if xeng().csm_data.enabled {
      xr3d_do_shadow_pass(*rend);
    }else {
      ogl_rt_clear(*rend.shadow_rt);
    }
    //xr3d_do_main_pass(*rend);
    xr3d_do_g_pass(*rend);
    xr3d_do_def_pass(*rend); 
    ogl_copy_depth_buffer_to_default_depth(*rend.g_buffer);

    // do 'transparent' pass
    xr3d_clear_bundles(*rend);

    //FIXME: we must do the depth=MAX technique, because our RT is already full!
    //xskydome_render(*skydome);

    xeng_frame_end();
  }

}

