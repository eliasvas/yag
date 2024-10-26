#import "Basic";
#import "String";
#import "SDL";

nWindowFlags :: enum_flags {
    RESIZABLE  :: 0x1;
    BORDERLESS :: 0x2;
};

nWindow :: struct {
    dim : nVec2;
    name : string;
    flags : nWindowFlags;

    impl_state : *void; // this holds SDL_Window
};

nWindowEventKind :: enum {
    NONE;
    KEYBOARD_EVENT;
    MOUSE_EVENT;
    MOUSE_MOTION_EVENT;
    SCROLLWHEEL_EVENT;
};

nWindowKeyboardEvent :: struct {
    key : u32;
    state : bool;
};

nWindowMouseEvent :: struct {
    key : u32; // 0 = LMB, 1 = MMB, 2 = RMB
    state : u32;
};

nWindowMouseMotionEvent :: struct {
    x : float32;
    y : float32;
};

// TODO: Maybe we can enhance this
nWindowScrollWheelEvent :: struct {
    y : float32; // scroll amount
};

nwindow_get_dim :: (win : *nWindow) -> nVec2 {
    using win;
    return dim;
}

nwindow_create :: (win : *nWindow) -> bool {
    using win;
    #if true {
        if (SDL_Init(SDL_INIT_VIDEO)) { return false; }

        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
        // TODO: set this ONLY in debug builds
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, xx SDL_GL_CONTEXT_DEBUG_FLAG);
        //SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, xx SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);

        sdl_flags : SDL_WindowFlags = SDL_WINDOW_OPENGL;
        if (flags & nWindowFlags.RESIZABLE) { sdl_flags |= SDL_WINDOW_RESIZABLE; }
        if (flags & nWindowFlags.BORDERLESS) { sdl_flags |= SDL_WINDOW_BORDERLESS; }
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
        gl_enable_debug_output(true);
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

nwindow_init :: (win : *nWindow, wname : string, ww : float32, wh : float32, wflags : nWindowFlags) -> bool {
    using win;
    dim = nVec2.{ww,wh};
    flags = wflags;
    name = wname;
    return nwindow_create(win);
}

nwindow_deinit :: (win : *nWindow) -> bool {
    using win;
    #if true {
        SDL_DestroyWindow(impl_state);
    }
    return true;
}

nwindow_swap :: (win : *nWindow) {
    using win;
    #if true {
        SDL_GL_SwapWindow(impl_state);
    }
}

nwindow_update_size :: (win : *nWindow) {
    using win;
    ww,wh : s32;
    #if true {
        SDL_GetWindowSize(impl_state, *ww, *wh);
        win.dim = nVec2.{xx ww,xx wh};
    }
}

// nWindowEventNode* nwindow_impl_capture_events(nWindow *win) {
//     nWindowEventNode *first = NULL;
//     nWindowEventNode *last = NULL;
//     SDL_Event event;
//     s32 scroll_y;
//     while (SDL_PollEvent(&event)) {
//         nWindowEventNode *node = push_array(get_frame_arena(), nWindowEventNode, 1);
//         switch (event.type) {
//             case SDL_QUIT:
//                 exit(1);
//             case SDL_KEYUP:
//                 node->kind = N_WINDOW_EVENT_KIND_KEYBOARD_EVENT;
//                 node->ke.key = event.key.keysym.scancode;
//                 node->ke.state = 0;
//                 sll_queue_push(first, last, node);
//                 break;
//             case SDL_KEYDOWN:
//                 node->kind = N_WINDOW_EVENT_KIND_KEYBOARD_EVENT;
//                 node->ke.key = event.key.keysym.scancode;
//                 node->ke.state = 1;
//                 sll_queue_push(first, last, node);
//                 break;
//             case SDL_MOUSEMOTION:
//                 node->kind = N_WINDOW_EVENT_KIND_MOUSE_MOTION_EVENT;
//                 node->mme.x = event.motion.x;
//                 node->mme.y = event.motion.y;
//                 sll_queue_push(first, last, node);
//                 break;
//             case SDL_MOUSEBUTTONDOWN:
//                 node->kind = N_WINDOW_EVENT_KIND_MOUSE_EVENT;
//                 node->me.key = event.button.button - SDL_BUTTON_LEFT;
//                 node->ke.state = 1;
//                 sll_queue_push(first, last, node);
//                 break;
//             case SDL_MOUSEBUTTONUP:
//                 node->kind = N_WINDOW_EVENT_KIND_MOUSE_EVENT;
//                 node->me.key = event.button.button - SDL_BUTTON_LEFT;
//                 node->ke.state = 0;
//                 sll_queue_push(first, last, node);
//                 break;
//             case SDL_MOUSEWHEEL:
//                 node->kind = N_WINDOW_EVENT_KIND_SCROLLWHEEL_EVENT;
//                 scroll_y = event.wheel.y;
//                 node->swe.y = scroll_y;
//                 sll_queue_push(first, last, node);
//             default:
//                 break;
//         }
//     }
//     nwindow_impl_update_size(win);

//     return first;
// }
