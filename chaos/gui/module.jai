#import "ImGui";
#load "imgui_sdl_gl.jai";
#load "gui_box.jai";
#load "gui_context.jai";
#load "gui_font.jai";
#load "gui_render.jai";
#load "gui_widgets.jai";
#load "gui_id.jai";

// This whole gui lib is mainly based on the excellent UI series of articles by Ryan Fleury, some useful links below.
// https://www.rfleury.com/p/ui-series-table-of-contents 
// https://www.rfleury.com/p/codebase-walkthrough-multi-window
// https://github.com/EpicGamesExt/raddebugger/tree/master/src/ui
// https://iquilezles.org/articles/distfunctions2d/
// https://github.com/eliasvas/motfk/tree/main/gui 

// TODO: maybe make an input abstraction (not needed currently though)
// NOTE: maybe we could pull the Rect rendering code from rend2d since its only used here? and wont be used anythere else, I think.. right?