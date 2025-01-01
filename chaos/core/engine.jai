// TODO: perform timing stuff, calc dt / frame_time etc
xEngine :: struct {
  frame_start_time : float64;
  dt : float64;

  win : xWindow;
  c : xCam;
   
  white_img : oglTex;
  proj : m4;
  view : m4;

  dir_light : xLight;
  csm_data : xCSMData;

  global_data_ub : oglUBlock;
}

g_engine : xEngine;

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
  ximm_init();
  // 4. camera init
  c = .{};
  // 5. make some misc stuff
  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
  ogl_tex_init(*white_img, .{1,1}, white.data, oglTexFormat.RGBA8U);
  dir_light = xdir_light_make_basic();
  // 6. we initialize imgui (we will replace this with OUR gui lib soon enough)
  imgui_context := ImGui.CreateContext();
  ImGui_ImplSdl_Init(xx win.impl_state);
  ImGui.StyleColorsClassic();
  io := ImGui.GetIO();

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

  // ImGui bullshit
  io := ImGui.GetIO();
  ImGui_ImplSdl_NewFrame(xx win.impl_state);
  ImGui.NewFrame();
  //ImGui.Text("Hello, world!");
  //show_demo : bool = true;
  //ImGui.ShowDemoWindow(*show_demo);
  ///////////////////////

  // CSM stuff
  xcsm_data_calc(*csm_data);

  // global UBO stuff (this is done only ONCE per-frame)
  pv : [2]m4 = .[m4_transpose(proj), m4_transpose(view)];
  ogl_ublock_set(*global_data_ub, xx pv.data);
  ogl_ublock_bind_to_slot(*xeng().global_data_ub);

  // The other _set API
  //ogl_ublock_load(*xeng().global_data_ub, *bp_sp, 0);
  //pt := m4_transpose(xeng().proj);
  //ogl_ublock_set(*xeng().global_data_ub, "proj", xx *pt);
  //pvv := m4_transpose(xeng().view);
  //ogl_ublock_set(*xeng().global_data_ub, "view", xx *pvv);
  //ogl_ublock_bind(*xeng().global_data_ub);



}

xeng_frame_end :: () {
  using g_engine;
  ximm_flush(proj, view);

  // imgui bullshit
  ImGui.Render();
  io := ImGui.GetIO();
  glViewport(0, 0, xx io.DisplaySize.x, xx io.DisplaySize.y);
  ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());
  ////////////////////////

  xwin_swap(*win);
  frame_end_time := seconds_since_init();
  dt = frame_end_time - frame_start_time;
  reset_temporary_storage();
}
