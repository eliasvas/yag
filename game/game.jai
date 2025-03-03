#import "Basic";
#import "String";
#import "Bucket_Array";
//#import "chaos";
#import "File";


// TODO: get a good bitmap font, like in microui, and BAKE it in font rendering code path
// TODO: instead of xeng(), do just xeng
// TODO: FIRE RENDERING!!!!! (lights will also be emmitted?!??!?!)

skydome : xSkydome;
grid : xGrid;

rend : xRend3D;

main2 :: () {
  xeng_init();
  grid = xgrid_make();

  xr3d_init(*rend);

  // gltf loading tests
  //gltf_path := "../assets/glTF-Sample-Models/2.0/CesiumMan/glTF-Embedded/CesiumMan.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/NormalTangentTest/glTF/NormalTangentTest.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/NormalTangentMirrorTest/glTF/NormalTangentMirrorTest.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/WaterBottle/glTF/WaterBottle.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/DamagedHelmet/glTF/DamagedHelmet.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/SciFiHelmet/glTF/SciFiHelmet.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/BoomBox/glTF/BoomBox.gltf";
  gltf_path := "../assets/glTF-Sample-Models/2.0/MetalRoughSpheres/glTF/MetalRoughSpheres.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/OrientationTest/glTF/OrientationTest.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/BrainStem/glTF-Embedded/BrainStem.gltf";
  sample_gltf_meshes := xgltf_parse_meshes(gltf_path);
  sample_gltf_animations := xgltf_parse_animations(gltf_path, sample_gltf_meshes.data);

  cube_mesh := xmesh_gen_cube();
  sphere_mesh := xmesh_gen_sphere(1.0, 64,64);

  while true {
    xeng_frame_init();
    if (xim_kkey_pressed(.SC_ESCAPE)) exit(1);


    for *sample_gltf_mesh : sample_gltf_meshes {
      xmesh_skin_reset_matrices(*sample_gltf_mesh.skin);
    }
    for *anim : sample_gltf_animations {
      xmesh_animation_simulate(anim);
    }
    for *mesh : sample_gltf_meshes {
      if xmesh_has_skin(mesh) {
        xmesh_skin_calc_global_transform(*mesh.skin, xmesh_skin_find_root_joint_id(*mesh.skin));
      }
    }

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
    frame_str := tprint("fps: %\0", fps);
    ImGui.TextUnformatted(frame_str.data);
    ImGui.End();


    // render the json mesh!!
    for sample_gltf_mesh : sample_gltf_meshes {
      model := xgltf_transform_calc_matrix(*sample_gltf_mesh.transform);
      //xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_trans(.{0,2,-10}), model));
      //xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_scale(.{20,20,20}), model));
      //xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_rotate(xx seconds_since_init(), .{0,1,0}),m4_mult(m4_rotate(-3.14/2.0, .{1,0,0}), model)));
      xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_rotate(0, .{0,1,0}),m4_mult(m4_rotate(3.14/2.0, .{1,0,0}), model)));
      //xr3d_push_bundle(*rend, *sample_gltf_mesh, model);
    }

    if xeng().csm_data.enabled {
      xr3d_do_shadow_pass(*rend);
    }else {
      ogl_rt_clear(*rend.shadow_rt);
    }
    xr3d_do_g_pass(*rend);
    xr3d_do_def_pass(*rend); 
    xr3d_do_copy_depth_from_g_buf_to_d0(*rend);
    xr3d_clear_bundles(*rend);
    // do 'transparent' pass
    //xgrid_render(*grid);
    xhdr_skybox_render(*rend.hdr_skybox);


    xeng_frame_end();
  }

}

xim_print_state :: () {
  using g_input_manager;
  ImGui.SetNextWindowSizeConstraints(.{100.0, 100.0}, .{400, 200});
  ImGui.Begin("KeyScanCodes");
  for enum_values_as_s64(xKeyScanCode) {
    key_index := it / 64;
    s := tprint("% -> [%,%]\0", cast(xKeyScanCode) it, (button_state.state[key_index] >> (it%64))&1, (button_state.prev_state[key_index] >> (it%64))&1);
    ImGui.TextUnformatted(s.data);
  }
  ImGui.End();
}
 
main :: () {
  xeng_init();


  // load the 2d texture
  tex : oglTex;
  {
    png_data := read_entire_file("../assets/DungeonTiles/DungeonTiles.png");
    tex_w, tex_h, channels : s32;
    //stbi_set_flip_vertically_on_load(1);
    raw_image_data := stbi_load_from_memory(png_data.data, cast(s32)png_data.count, *tex_w, *tex_h, *channels, 4);
    ogl_tex_init(*tex, .{cast(float)tex_w,cast(float)tex_h}, xx raw_image_data, oglTexFormat.RGBA8U);
  }

  // load its accompanying json to get metadata
  root_node := xjson_parse_wholefile_string(read_entire_file("../assets/DungeonTiles/DungeonTiles.json"));
  parsed_tc,found := xjson_get_float_array(root_node, "flask_big_yellow", 4);
  assert(found);
  tex_dim := tex.dim;
  flask_tc := v4.{parsed_tc[0] / tex_dim.x, parsed_tc[1] / tex_dim.y, parsed_tc[2] / tex_dim.x, parsed_tc[3] / tex_dim.y};

  rend : xRend2D;

  cam := xCamera2D.{
    target = v2.{0,0},
    rot = 0,
    zoom = 1,
    offset = v2.{0,0},
  };
  quad_pos := v4.{0,0,200,200};

  while xeng().running {
    // set camera offset to middle of screen
    wdim := xwin_get_dim(*xeng().win);
    cam.offset =  v2.{wdim.x/2.0, wdim.y/2.0};

    // sample quad movement
    if (xim_kkey_down(.SC_UP)) quad_pos.y -= 1;
    if (xim_kkey_down(.SC_DOWN)) quad_pos.y += 1;
    if (xim_kkey_down(.SC_LEFT)) quad_pos.x -= 1;
    if (xim_kkey_down(.SC_RIGHT)) quad_pos.x += 1;

    xeng_frame_init();
    if (xim_kkey_pressed(.SC_ESCAPE)) xeng().running = false;
    ogl_rt_clear(null);

    // render a sample quad
    xr2d_quad_render(*rend, quad_pos, flask_tc, .{0.8,0.8,0.8,1.0}, *cam);
    //xr2d_quad_render(*rend, .{0,0,0.4,0.3}, flask_tc, .{0.8,0.8,0.8,1.0});

    xeng_frame_end();
  }
}


