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

xwin_get_dim :: (win : *xWindow) -> v2 {
    using win;
    return dim;
}

xwin_create :: (win : *xWindow) -> bool {
    using win;
    #if true {
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
    #if true {
        SDL_DestroyWindow(impl_state);
    }
    return true;
}

xwin_swap :: (win : *xWindow) {
    using win;
    #if true {
        SDL_GL_SwapWindow(impl_state);
    }
}

xwin_update_size :: (win : *xWindow) {
    using win;
    ww,wh : s32;
    #if true {
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
            case; continue;
        }
        array_add(*wevents, e);
    }
    return wevents;
}