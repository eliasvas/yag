#import "Basic";
#import "String";
#import "SDL";

xWindowFlags :: enum_flags {
  RESIZABLE  :: 0x1;
  BORDERLESS :: 0x2;
};

xWindow :: struct {
  dim : v2;
  name : string;
  flags : xWindowFlags;

  cursor_store : xWindowCursorStore;

  impl_state : *void; // this holds SDL_Window
};



xWindowEvent :: struct {
  xWindowEventKind :: enum {
    NONE;
    KEYBOARD_EVENT;
    MOUSE_EVENT;
    MOUSE_MOTION_EVENT;
    SCROLLWHEEL_EVENT;
    QUIT_EVENT;
  };
  kind : xWindowEventKind;

  union {
    keeb_evt : struct {
      key : u32;
      state : bool;
    };
    mouse_evt : struct {
      key : u32; // 0 = LMB, 1 = MMB, 2 = RMB
      state : bool;
    };
    mouse_mot_evt : struct {
      x : float32;
      y : float32;
    };
    scroll_evt : struct {
      y : float32; // scroll amount
    };
    //gamepad_event(s) ...
  };
}

xwin_get_viewport :: (win : *xWindow) ->v4 {
  return .{0,0,win.dim.x,win.dim.y};
}

xwin_get_fovx :: (win : *xWindow) ->float32 {
  return win.dim.x / win.dim.y;
}

xwin_get_dim :: (win : *xWindow) -> v2 {
  using win;
  return dim;
}

xwin_create :: (win : *xWindow) -> bool {
  using win;
  #if SDL_IMPL {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER)) { return false; }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    // TODO: set this ONLY in debug builds
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, xx SDL_GL_CONTEXT_DEBUG_FLAG);
    //SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, xx SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);

    sdl_flags : SDL_WindowFlags = SDL_WINDOW_OPENGL;
    if (flags & xWindowFlags.RESIZABLE) { sdl_flags |= SDL_WINDOW_RESIZABLE; }
    if (flags & xWindowFlags.BORDERLESS) { sdl_flags |= SDL_WINDOW_BORDERLESS; }
    window : *SDL_Window = SDL_CreateWindow(name.data,SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, cast(s32)dim.x, cast(s32)dim.y, xx sdl_flags);
    impl_state = window;
    assert(window != null);

    glcontext :SDL_GLContext = SDL_GL_CreateContext(window);
    if (!glcontext) {
      // TODO: maybe get the SDL_Error() and print it too??
      print("Error creating GL context!\n");
      return false;
    }
    SDL_GL_MakeCurrent(window,glcontext);
    gl_load(*gl, SDL_GL_GetProcAddress);
    //gl_enable_debug_output(true);
    using gl;
    DumpGLErrors("context");
    assert(glGetError() == GL_NO_ERROR);
    {
      majorv, minorv, profilem : s32;
      SDL_GL_GetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, *majorv);
      SDL_GL_GetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, *minorv);
      SDL_GL_GetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, *profilem);
      print("OpenGL %.% (ES=%)\n", majorv, minorv, ifx (SDL_GL_CONTEXT_PROFILE_ES == xx profilem) then "true" else "compatibility");
    }

    //SDL_ShowWindow(window);
    {
      width, height : s32;
      SDL_GetWindowSize(window, *width, *height);
      print("Window size: %x%\n", width, height);
    }
    print("SDL window [%] created succesfully!\n", name);
  }

  init(*win.cursor_store);

  // set the cursor (by default) to arrow
  xwin_set_cursor(win, xWindowCursorKind.ARROW);

  return true;
}


xwin_init :: (win : *xWindow, wname : string, ww : float32, wh : float32, wflags : xWindowFlags) -> bool {
  using win;
  dim = v2.{ww,wh};
  flags = wflags;
  name = wname;

  return xwin_create(win);
}

xwin_deinit :: (win : *xWindow) -> bool {
  using win;
  deinit(*win.cursor_store);
  #if SDL_IMPL {
    SDL_DestroyWindow(impl_state);
  }
  return true;
}

xwin_swap :: (win : *xWindow) {
  using win;
  #if SDL_IMPL {
    SDL_GL_SwapWindow(impl_state);
  }
}

xwin_update_size :: (win : *xWindow) {
  using win;
  ww,wh : s32;
  #if SDL_IMPL {
    SDL_GetWindowSize(impl_state, *ww, *wh);
    win.dim = v2.{xx ww,xx wh};
  }
}

xwin_capture_events :: (win : *xWindow) -> []xWindowEvent {
  wevents : [..] xWindowEvent;
  // here we use a temporary allocator because these are frame specific data!
  wevents.allocator = temp;
  event : SDL_Event;
  while SDL_PollEvent(*event) {
    e : xWindowEvent;
    if event.type == {
      case .SDL_QUIT;
        e.kind = .QUIT_EVENT;
      case .SDL_KEYUP;
        e.kind = .KEYBOARD_EVENT;
        e.keeb_evt.state = false;
        e.keeb_evt.key = xx event.key.keysym.scancode;
      case .SDL_KEYDOWN;
        e.kind = .KEYBOARD_EVENT;
        e.keeb_evt.state = true;
        e.keeb_evt.key = xx event.key.keysym.scancode;
      case .SDL_MOUSEBUTTONDOWN;
        e.kind = .MOUSE_EVENT;
        e.mouse_evt.key = event.button.button - SDL_BUTTON_LEFT;
        e.mouse_evt.state = true;
      case .SDL_MOUSEBUTTONUP;
        e.kind = .MOUSE_EVENT;
        e.mouse_evt.key = event.button.button - SDL_BUTTON_LEFT;
        e.mouse_evt.state = false;
      case .SDL_MOUSEMOTION;
        e.kind = .MOUSE_MOTION_EVENT;
        e.mouse_mot_evt.x = xx event.motion.x;
        e.mouse_mot_evt.y = xx event.motion.y;
      case .SDL_MOUSEWHEEL;
        e.kind = .SCROLLWHEEL_EVENT;
        e.scroll_evt.y = xx event.wheel.y;
      case .SDL_WINDOWEVENT;
          w, h : s32;
          SDL_GetWindowSize(xx win.impl_state,*w,*h);
          win.dim.x = xx w;
          win.dim.y = xx h;
      case; continue;
    }
    array_add(*wevents, e);
  }
  return wevents;
}

xWindowCursorKind :: enum {
  ARROW;
  WEST_EAST;
  NORTH_SOUTH;
  CROSSHAIR;
}
xWindowCursor :: struct {
  kind : xWindowCursorKind;
  impl_state : *void; // this holds the SDL_Cursor
}


xWindowCursorStore :: struct {
  CURSOR_LOW, CURSOR_HIGH:: #run enum_range(xWindowCursorKind);
  cursors : [CURSOR_HIGH-CURSOR_LOW+1] xWindowCursor;
  active_cursor : xWindowCursorKind;
}

release_cursor :: (store : *xWindowCursorStore, dest : *xWindowCursor) {
  #if SDL_IMPL {
    SDL_FreeCursor(xx dest.impl_state);
  }
}

load_cursor :: (store : *xWindowCursorStore, dest : *xWindowCursor) {
  #if SDL_IMPL {
    to_sdl_cursor_type :: (kind : xWindowCursorKind) -> SDL_SystemCursor {
      if kind == {
        case .ARROW;
          return SDL_SystemCursor.ARROW;
        case .WEST_EAST;
          return SDL_SystemCursor.SIZEWE;
        case .NORTH_SOUTH;
          return SDL_SystemCursor.SIZENS;
        case .CROSSHAIR;
          return SDL_SystemCursor.CROSSHAIR;
        case;
          return SDL_SystemCursor.ARROW;
      }
    }

    cursor := SDL_CreateSystemCursor(to_sdl_cursor_type(dest.kind));
    dest.impl_state = cursor;
  }
}

// create all cursors
init :: (store : *xWindowCursorStore) {
  for cursor : enum_values_as_s64(xWindowCursorKind) {
    cursor_idx := get_cursor_idx_in_store(xx cursor);
    store.cursors[cursor_idx].kind = xx cursor;
    load_cursor(store, *store.cursors[cursor_idx]); 
  }
}
// release all cursors
deinit :: (store : *xWindowCursorStore) {
  for cursor : enum_values_as_s64(xWindowCursorKind) {
    cursor_idx := get_cursor_idx_in_store(xx cursor);
    store.cursors[cursor_idx].kind = xx cursor;
    release_cursor(store, *store.cursors[cursor_idx]); 
  }
}

get_cursor_idx_in_store :: (kind : xWindowCursorKind) -> s64 {
  low, high := enum_range(xWindowCursorKind); 
  cursor_idx := (cast(s64)kind-low);
  return cursor_idx;
}

// set current cursor
xwin_set_cursor :: (win : *xWindow, kind : xWindowCursorKind) {
  cursor_idx := get_cursor_idx_in_store(kind);
  cursor := win.cursor_store.cursors[cursor_idx].impl_state;
  if (xwin_get_active_cursor(win) != kind) {
    win.cursor_store.active_cursor = kind;
    SDL_SetCursor(xx cursor);
  }
}

xwin_get_active_cursor :: (win : *xWindow) -> xWindowCursorKind {
  return win.cursor_store.active_cursor;
}

