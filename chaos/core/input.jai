#import "Basic";
/*
Currently xInputManager is a singleton, in the future we could make each xWindow
have one input manager, maybe. Also then, mouse_coords would be window local!

@TODO: No Gamepad support yet!
@TODO: Clean this up. Its not readable
*/

xInputManager :: struct {
  button_state : struct {
    state      : [4]u64;
    prev_state : [4]u64;
  };
  mouse_state : struct {
    state      : u8;
    prev_state : u8;
  };
  mouse_coords : v2;
  mouse_delta  : v2;
  scroll_y     : float32;
};

xKeyState :: enum u8 {
  DOWN     :: 0;
  UP       :: 1;
  PRESSED  :: 2;
  RELEASED :: 3;
};

xMouseKey :: enum u8 {
  LMB :: 0;
  MMB :: 1;
  RMB :: 2;
};

// This is equivalent to SDL_Scancode / USB keyboard spec's scancodes
xKeyScanCode :: enum u8 {
  SC_NONE :: 0;
  SC_A :: 4;
  SC_B :: 5;
  SC_C :: 6;
  SC_D :: 7;
  SC_E :: 8;
  SC_F :: 9;
  SC_G :: 10;
  SC_H :: 11;
  SC_I :: 12;
  SC_J :: 13;
  SC_K :: 14;
  SC_L :: 15;
  SC_M :: 16;
  SC_N :: 17;
  SC_O :: 18;
  SC_P :: 19;
  SC_Q :: 20;
  SC_R :: 21;
  SC_S :: 22;
  SC_T :: 23;
  SC_U :: 24;
  SC_V :: 25;
  SC_W :: 26;
  SC_X :: 27;
  SC_Y :: 28;
  SC_Z :: 29;

  SC_1 :: 30;
  SC_2 :: 31;
  SC_3 :: 32;
  SC_4 :: 33;
  SC_5 :: 34;
  SC_6 :: 35;
  SC_7 :: 36;
  SC_8 :: 37;
  SC_9 :: 38;
  SC_0 :: 39;

  SC_RETURN :: 40;
  SC_ESCAPE :: 41;
  SC_BACKSPACE :: 42;
  SC_TAB :: 43;
  SC_SPACE :: 44;

  SC_MINUS :: 45;
  SC_EQUALS :: 46;
  SC_LEFTBRACKET :: 47;
  SC_RIGHTBRACKET :: 48;
  SC_BACKSLASH :: 49;
  SC_NONUSHASH :: 50;
  SC_SEMICOLON :: 51;
  SC_APOSTROPHE :: 52;
  SC_GRAVE :: 53;
  SC_COMMA :: 54;
  SC_PERIOD :: 55;
  SC_SLASH :: 56;
  SC_CAPSLOCK :: 57;

  SC_F1 :: 58;
  SC_F2 :: 59;
  SC_F3 :: 60;
  SC_F4 :: 61;
  SC_F5 :: 62;
  SC_F6 :: 63;
  SC_F7 :: 64;
  SC_F8 :: 65;
  SC_F9 :: 66;
  SC_F10 :: 67;
  SC_F11 :: 68;
  SC_F12 :: 69;

  SC_PRINTSCREEN :: 70;
  SC_SCROLLLOCK :: 71;
  SC_PAUSE :: 72;
  SC_INSERT :: 73;
  SC_HOME :: 74;
  SC_PAGEUP :: 75;
  SC_DELETE :: 76;
  SC_END :: 77;
  SC_PAGEDOWN :: 78;
  SC_RIGHT :: 79;
  SC_LEFT :: 80;
  SC_DOWN :: 81;
  SC_UP :: 82;
  // TODO: Add More!
  SC_MEDIA_CALC :: 251;
  SC_MAXIMUM; // AFAIK this isn't needed?
};


g_input_manager : xInputManager;

xim_capture_begin :: () {
  using g_input_manager;
  for 0..3 button_state.prev_state[it] = button_state.state[it];
  mouse_state.prev_state = mouse_state.state;
}
xim_capture_end :: () {}

xim_consume_events :: (events : []xWindowEvent) {
  U64_BITS :: size_of(u64) * 8;

  using g_input_manager;
  mp_before_consume := mouse_coords;
  for e : events {
    if e.kind == {
      case .QUIT_EVENT;
        xeng().running = false;
      case .KEYBOARD_EVENT;
        key_index := e.keeb_evt.key / 64;
        button_state.state[key_index] = ifx e.keeb_evt.state then (button_state.state[key_index] | cast(u64)(1 << (e.keeb_evt.key%64))) else (button_state.state[key_index] & xx (~(cast(u64)1 << (e.keeb_evt.key%64))));
      case .MOUSE_EVENT;
        mouse_state.state = cast(u8)ifx e.mouse_evt.state then (mouse_state.state | xx ((1 << e.mouse_evt.key))) else (mouse_state.state & cast(u64)(~(cast(u64)1 << e.mouse_evt.key)));
      case .MOUSE_MOTION_EVENT;
        mouse_coords = .{e.mouse_mot_evt.x, e.mouse_mot_evt.y};
      case .SCROLLWHEEL_EVENT;
        scroll_y = e.scroll_evt.y;
      case;
    }
  }
  mouse_delta = mouse_coords - mp_before_consume;
}

xim_kkey_is_state :: (scancode : xKeyScanCode, state : xKeyState) -> bool {
  using g_input_manager;
  key_index := scancode / 64;
  if state == {
    case .DOWN; return ((button_state.state[key_index]>>(scancode%64))&1)>0;
    case .UP; return (~(button_state.state[key_index]>>(scancode%64))&1)>0;
    case .PRESSED; return ((button_state.state[key_index]>>(scancode%64))&1)>0 && (~(button_state.prev_state[key_index]>>(scancode%64))&1)>0;
    case .RELEASED; return (~(button_state.state[key_index]>>(scancode%64))&1)>0 && ((button_state.prev_state[key_index]>>(scancode%64))&1)>0;
    case;
  }
  return false;
}
xim_kkey_down     :: (scancode : xKeyScanCode)->bool{return xim_kkey_is_state(scancode, .DOWN);}
xim_kkey_up       :: (scancode : xKeyScanCode)->bool{return xim_kkey_is_state(scancode, .UP);}
xim_kkey_pressed  :: (scancode : xKeyScanCode)->bool{return xim_kkey_is_state(scancode, .PRESSED);}
xim_kkey_released :: (scancode : xKeyScanCode)->bool{return xim_kkey_is_state(scancode, .RELEASED);}


xim_mkey_is_state :: (key : xMouseKey, state : xKeyState) -> bool {
using g_input_manager;
  if state == {
    case .DOWN; return ((mouse_state.state>>key)&1)>0;
    case .UP; return (~(mouse_state.state>>key)&1)>0;
    case .PRESSED; return ((mouse_state.state>>key)&1)>0 && (~(mouse_state.prev_state>>key)&1)>0;
    case .RELEASED; return (~(mouse_state.state>>key)&1)>0 && ((mouse_state.prev_state>>key)&1)>0;
    case;
  }
  return false;
}
xim_mkey_down     :: (key : xMouseKey)->bool{return xim_mkey_is_state(key, .DOWN);}
xim_mkey_up       :: (key : xMouseKey)->bool{return xim_mkey_is_state(key, .UP);}
xim_mkey_pressed  :: (key : xMouseKey)->bool{return xim_mkey_is_state(key, .PRESSED);}
xim_mkey_released :: (key : xMouseKey)->bool{return xim_mkey_is_state(key, .RELEASED);}

xim_get_mouse_pos   :: () -> v2 {return g_input_manager.mouse_coords;}
xim_get_mouse_delta :: () -> v2 {return g_input_manager.mouse_delta;}
