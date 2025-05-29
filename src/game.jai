#import "chaos";

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
  ///////////////////



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

    xgui_push_parent(xgui_box_lookup(xgui_id("panel_child11")));
    {
      xgui_set_next_pref_width(.{.TEXT_CONTENT, 5.0, 1.0});
      xgui_set_next_pref_height(.{.TEXT_CONTENT, 5.0, 1.0});
      xgui_set_next_box_roundness(.{3,3,3,3});
      xgui_set_next_background_color(.{0.32,0.22,0.455,1.0});
      xgui_set_next_text_color(.{0.86,0.49,0.4,1.0});
      if xgui_button("These Buttons").pressed {
          print("These Buttons pressed!\n");
      }

      xgui_set_next_pref_width(.{.TEXT_CONTENT, 5.0, 1.0});
      xgui_set_next_pref_height(.{.TEXT_CONTENT, 5.0, 1.0});
      xgui_set_next_box_roundness(.{3,3,3,3});
      xgui_set_next_background_color(.{0.88,0.22,0.255,1.0});
      xgui_set_next_text_color(.{0.9,0.9,0.9,1.0});
      if xgui_button("Are Fixed!").pressed {
          print("Are Fixed pressed!\n");
      }
    }
    xgui_pop_parent();

    xgui_push_parent(xgui_box_lookup(xgui_id("panel_child12")));
    {
      xgui_set_next_pref_width(.{.PARENT_PCT, 1.0, 1.0});
      xgui_set_next_pref_height(.{.TEXT_CONTENT, 5.0, 1.0});
      xgui_set_next_box_roundness(.{3,3,3,3});
      xgui_set_next_background_color(.{0.32,0.22,0.455,1.0});
      xgui_set_next_text_color(.{0.86,0.49,0.4,1.0});
      if xgui_button("These Ones").pressed {
          print("These Ones pressed!\n");
      }

      xgui_set_next_pref_width(.{.PARENT_PCT, 1.0, 1.0});
      xgui_set_next_pref_height(.{.TEXT_CONTENT, 5.0, 1.0});
      xgui_set_next_box_roundness(.{3,3,3,3});
      xgui_set_next_background_color(.{0.88,0.22,0.255,1.0});
      xgui_set_next_text_color(.{0.9,0.9,0.9,1.0});
      if xgui_button("Streeeeeeetch!").pressed {
          print("Streeeeeeeech pressed!\n");
      }
    }
    xgui_pop_parent();

    xgui_push_parent(xgui_box_lookup(xgui_id("panel_child2")));
    {
      xgui_set_next_pref_width(.{.PIXELS, 200.0, 1.0});
      xgui_set_next_pref_height(.{.PIXELS, 150.0, 1.0});
      xgui_set_next_box_roundness(.{3,3,3,3});
      xgui_set_next_background_color(.{0.2,0.6,0.2,1.0});
      xgui_set_next_text_color(.{0.9,0.9,0.9,1.0});
      if xgui_button("Fat Guy").pressed {
          print("Fat Guy pressed!\n");
      }
    }
    xgui_pop_parent();

   
    xgui_frame_end();
    xeng_frame_end();
  }
}

