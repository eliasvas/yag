// TODO: perform timing stuff, calc dt / frame_time etc
xEngine :: struct {
  running : bool = true;
  frame_start_time : float64;
  dt : float64;
  frame_index : u64;

  win : xWindow;
  c : xCam;
   
  proj : m4;
  view : m4;

  dir_light : xLight;
  csm_data : xCSMData;

  persistent_arena : xArena; // no need for initialization I think
  persistent_asset_mgr : xAssetMgr;

  global_data_ub : oglUBlock;
}

g_engine : xEngine;

xeng_get :: () ->*xEngine {
  return *g_engine;
}

xeng :: ()  -> *xEngine {
  return *g_engine;
}

xeng_init :: () {
  using g_engine;
  // 1. we make the base window
  viewport: v4 = .{0,0,1280,720}; // maybe make this configurable?
  assert(xwin_init(*win, "chaos", viewport.width, viewport.height, xWindowFlags.RESIZABLE));
  // 2. ogl init (our graphics wrapper)
  ogl_init();
  ogl_ublock_init(*global_data_ub, size_of(m4)*2);
  // 3. immediate drawing module init
  //ximm_init();
  // 4. base camera init
  c = .{};
  // 5. Init the persistent asset manager (along with some default assets!)
  // (we use the persistent arena allocator for all allocations concerning the persistent asset manager)
  new_context := context;
  new_context.allocator = Allocator.{proc = xarena_allocator_proc, data = *persistent_arena};
  push_context new_context {
    xasset_mgr_init(*persistent_asset_mgr);
    // Add the default white texture
    white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
    white_tag := xasset_mgr_add(*persistent_asset_mgr, xtexture_asset_make(white.data, v2.{1,1}));
    // Add the default font (OS specific sadly)
    dfont_tag, first_time_created := xasset_mgr_add(*persistent_asset_mgr, xfont_asset_make(.{32, 126}));
    assert(first_time_created);
  }
}

// TODO: this should be called frame_begin
xeng_frame_init :: () {
  using g_engine;
  frame_start_time = seconds_since_init();
  // TODO: maybe we should do all the RT clears here too!
  xwin_update_size(*win);
  xcam_update(*c, cast(float32)dt);
  //proj = m4_persp(45.0, xwin_get_fovx(*win), 1, 100);
  proj = m4_persp(45.0, xwin_get_fovx(*win), 0.5, 100);
  view = xcam_get_view_mat(*c);
  // input handling for the frame
  {
    wevents := xwin_capture_events(*win);
    xim_capture_begin();
    xim_consume_events(wevents);
    xim_capture_end();
  }

  // CSM stuff
  xcsm_data_calc(*csm_data);

  // global UBO stuff (this is done only ONCE per-frame)
  pv : [2]m4 = .[m4_transpose(proj), m4_transpose(view)];
  ogl_ublock_set(*global_data_ub, xx pv.data);
  ogl_ublock_bind_to_slot(*xeng().global_data_ub);
}

xeng_frame_end :: () {
  using g_engine;
  //ximm_flush(proj, view);

  xwin_swap(*win);
  frame_end_time := seconds_since_init();
  dt = frame_end_time - frame_start_time;
  frame_index +=1;
  //reset_temporary_storage();
}
