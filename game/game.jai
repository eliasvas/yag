//#import "chaos";

// TODO: get a good bitmap font, like in microui, and BAKE it in font rendering code path
// TODO: instead of xeng(), do just xeng
// TODO: FIRE RENDERING!!!!! (lights will also be emmitted?!??!?!)

// these guys need to Go Go
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

texture_load :: (path : string) -> oglTex {
  tex : oglTex;
  png_data := read_entire_file(path);
  assert(png_data.count > 0);
  tex_w, tex_h, channels : s32;
  //stbi_set_flip_vertically_on_load(1);
  raw_image_data := stbi_load_from_memory(png_data.data, cast(s32)png_data.count, *tex_w, *tex_h, *channels, 4);
  ogl_tex_init(*tex, .{cast(float)tex_w,cast(float)tex_h}, xx raw_image_data, oglTexFormat.RGBA8U);
  assert(tex.dim.x > 0);
  assert(tex.dim.y > 0);
  return tex;
}
 

// global asset manager, maybe should be inside xeng

example_rows := 0;

main :: () {
  xeng_init();
  xgui_init();

  rend : xRend2D;
  cam := xCamera2D.{
    target = v2.{0,0},
    rot = 0,
    zoom = 1, offset = v2.{0,0},
  };

  ////////////////////
  // Game's Asset Manager initialization
  ////////////////////
  mgr : xAssetMgr;
  xasset_mgr_init(*mgr);
  dungeon_tileset := xasset_mgr_load(*mgr, "../assets/DungeonTiles");
  assert(xasset_mgr_find(*mgr, dungeon_tileset) != null);
  sprite1 := xentity_make(Sprite);
  sprite_init(sprite1, acast(xasset_mgr_find(*mgr, dungeon_tileset), xTextureAsset), "big_demon_run_anim", 8);
  // make a sprite with a texture from another tileset
  particle_tileset := xasset_mgr_load(*mgr, "../assets/SmokeParticles");
  assert(xasset_mgr_find(*mgr, particle_tileset) != null);
  sprite2 := xentity_make(Sprite);
  sprite_init(sprite2, acast(xasset_mgr_find(*mgr, particle_tileset), xTextureAsset), "smoke_fx_6", 24);



  player1 := xentity_make(Player).id;
  xentity_attach(player1, sprite1.id);

  while xeng().running {
    if (xim_kkey_pressed(.SC_Z)) then xentity_make(Player);

    //print("freelist size: %\n", count(entities.freelist_head));
    entities_cleanup(*entities);
    entities_update(*entities); // should be some kind of scene update probably

    // set camera offset to middle of screen
    wdim := xwin_get_dim(*xeng().win);
    cam.offset = v2.{wdim.x/2.0, wdim.y/2.0};

    gpos := xentity_calc_global_pos(xentity_find(player1));
    cam.target = v2.{gpos.x, gpos.y};

    if (xim_kkey_down(.SC_Q)) cam.rot += 0.001;
    if (xim_kkey_down(.SC_E)) cam.rot -= 0.001;

    if (xim_kkey_down(.SC_1)) cam.zoom = 1;
    if (xim_kkey_down(.SC_2)) cam.zoom = 2;
    if (xim_kkey_down(.SC_3)) cam.zoom = 3;
    if (xim_kkey_down(.SC_4)) cam.zoom = 4;

    xeng_frame_init();
    if (xim_kkey_pressed(.SC_ESCAPE)) xeng().running = false;
    ogl_rt_clear(null,.{0.7,0.3,0.2,1.0});

    if sprite1.id then render(sprite1, *rend, *cam, ecast(xentity_find(player1),Player).flip_x);
    if sprite2.id then render(sprite2, *rend, *cam, false);

    xgui_frame_begin();
    if 0 {
      // push master panel as panel
      xgui_push_parent(g_gui_context.root);

      xgui_set_next_pref_width(.{.TEXT_CONTENT, 5.0, 1.0});
      xgui_set_next_pref_height(.{.TEXT_CONTENT, 5.0, 1.0});
      xgui_set_next_box_roundness(.{3,3,3,3});
      xgui_set_next_background_color(.{0.32,0.22,0.455,1.0});
      xgui_set_next_text_color(.{0.86,0.49,0.4,0.7});
      if xgui_button("Hello There!").pressed {
          print("Hello There pressed!\n");
      }


      xgui_pop_parent();

      // add a button!
    }

    if 0 {
        xgui_set_next_pref_width(.{.PARENT_PCT, 1.0, 1.0});
        xgui_set_next_pref_height(.{.PIXELS, 60.0, 1.0});
        xgui_set_next_background_color(.{0.8,0.8,0.8,1.0});
        xgui_set_next_child_layout_axis(.X);
        hpane := xgui_pane("header_pane");
        xgui_push_parent(hpane.box);

        xgui_spacer(.{.PARENT_PCT, 1.0, 0.0});


        if (xim_kkey_pressed(.SC_U)) example_rows = min(10, example_rows+1);

        xgui_set_next_pref_width(.{.TEXT_CONTENT, 5.0, 1.0});
        xgui_set_next_pref_height(.{.PIXELS, 60.0, 1.0});
        xgui_set_next_box_roundness(.{0,0,10,10});
        xgui_set_next_background_color(.{0.32,0.22,0.455,1.0});
        xgui_set_next_text_color(.{0.86,0.49,0.4,0.7});
        if xgui_button("More!").pressed {
            print("More button pressed!\n");
            example_rows = min(30, example_rows+1);
        }

        xgui_set_next_pref_width(.{.TEXT_CONTENT, 5.0, 1.0});
        xgui_set_next_pref_height(.{.PIXELS, 60.0, 1.0});
        xgui_set_next_box_roundness(.{10,10,0,0});
        xgui_set_next_text_color(.{0.32,0.22,0.455,0.7});
        xgui_set_next_background_color(.{0.86,0.49,0.4,1.0});
        if xgui_button("Less!").pressed {
            print("Less button pressed!\n");
            example_rows = max(0, example_rows-1);
        }

        xgui_spacer(.{.PARENT_PCT, 1.0, 0.0});

        xgui_pop_parent(); // header-pane


        xgui_set_next_pref_width(.{.PARENT_PCT, 1.0, 1.0});
        xgui_set_next_pref_height(.{.PARENT_PCT, 1.0, 0.0});
        xgui_set_next_background_color(.{0.9,0.1,0.1,1.0});
        xgui_set_next_child_layout_axis(.Y);
        bpane := xgui_pane("button_pane");
        xgui_push_parent(bpane.box);
        
        dummy_colors := v4.[ v4.{0.18, 0.80, 0.44, 1.0}, v4.{0.20, 0.60, 0.86, 1.0}, v4.{0.61, 0.35, 0.71, 1.0}, v4.{0.35, 0.77, 0.06, 1.0}, v4.{0.20, 0.29, 0.37, 1.0}, v4.{0.90, 0.49, 0.13, 1.0}, v4.{0.36, 0.73, 0.89, 1.0}, v4.{0.55, 0.76, 0.29, 1.0}, v4.{0.95, 0.42, 0.61, 1.0}, v4.{0.34, 0.46, 0.60, 1.0}, v4.{0.98, 0.81, 0.69, 1.0}, v4.{0.60, 0.59, 0.85, 1.0}, v4.{0.43, 0.89, 0.71, 1.0}, v4.{0.99, 0.56, 0.23, 1.0}, v4.{0.73, 0.84, 0.27, 1.0}, v4.{0.38, 0.18, 0.60, 1.0}, v4.{0.15, 0.68, 0.38, 1.0}, v4.{0.91, 0.26, 0.54, 1.0}, v4.{0.30, 0.75, 0.93, 1.0}, v4.{0.98, 0.78, 0.27, 1.0}, v4.{0.52, 0.35, 0.27, 1.0}, ];

        for idx1 : 0..example_rows {
            xgui_set_next_pref_width(.{.PARENT_PCT, 1.0, 1.0});
            xgui_set_next_pref_height(.{.PARENT_PCT, 1.0, 0.0});
            xgui_set_next_background_color(.{0.6,0.8,0.9,1.0});
            xgui_set_next_child_layout_axis(.X);
            ibpane_name := tprint("button_pane%", idx1);
            ibpane := xgui_pane(ibpane_name);
            xgui_push_parent(ibpane.box);

            for idx2 : 0..3 {
                //name := tprint("button%-%", idx1, idx2);
                name := tprint("button%-%", idx1, idx2);
                xgui_set_next_pref_width(.{.PARENT_PCT, 1.0, 0.0});
                xgui_set_next_pref_height(.{.PARENT_PCT, 1.0, 0.0});
                if idx2 == 0 then xgui_set_next_text_alignment(.LEFT);
                if idx2 == 3 then xgui_set_next_text_alignment(.RIGHT);
                col := dummy_colors[(idx1+1)*(idx2+1)%dummy_colors.count];
                xgui_set_next_background_color(col);
                btn := xgui_button(name);
                if btn.pressed {
                    print("% pressed!\n", name);
                }
            }

            xgui_pop_parent(); // internal button-pane

        }

        xgui_pop_parent(); // button-pane

        assert(hpane.box.next == bpane.box); // :)
    }

    xgui_frame_end();
    xeng_frame_end();
  }
}

