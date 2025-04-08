#import "ImGui";
#load "imgui_sdl_gl.jai";

// This whole gui lib is mainly based on the excellent UI series of articles by Ryan Fleury, some useful links below.
// https://www.rfleury.com/p/ui-series-table-of-contents 
// https://www.rfleury.com/p/codebase-walkthrough-multi-window
// https://github.com/EpicGamesExt/raddebugger/tree/master/src/ui
// https://iquilezles.org/articles/distfunctions2d/
// https://github.com/eliasvas/motfk/tree/main/gui 

// NOTE: These xfont stuff should go to a different file (gui_font?)
xfont_get_text_width :: (text : string, font : *xFontAsset, scale : float = 1.0) -> float {
  total_width : float = 0.0;
  for c : text {
    glyph_info, found := xfont_asset_lookup_glyph_info(font, cast(u32)c);
    if found {
      total_width += glyph_info.metrics.hadvance;
    }
  }
  return total_width*scale;
}

xfont_get_ymax :: (text : string, font : *xFontAsset, scale : float = 1.0) -> float {
  ymax : float = 0.0;
  for c : text {
    glyph_info, found := xfont_asset_lookup_glyph_info(font, cast(u32)c);
    if found {
      ymax = max(ymax, cast(float)glyph_info.metrics.hbearing_y);
    }
  }
  return ymax*scale;
}

xfont_get_ymin :: (text : string, font : *xFontAsset, scale : float = 1.0) -> float {
  ymin : float = 0.0;
  for c : text {
    glyph_info, found := xfont_asset_lookup_glyph_info(font, cast(u32)c);
    if found {
      //ymin = max(ymin, cast(float)(glyph_info.metrics.height - glyph_info.metrics.hbearing_y));
      ymin = min(ymin, cast(float)glyph_info.metrics.hbearing_y);
    }
  }
  return ymin*scale;
}

xGuiStyle :: struct {
	panel_color             : v4 = v4.{0.2,0.2,0.2,1.0};
  default_widget_color    : v4 = v4.{0.3,0.3,0.3,1.0};
	hot_widget_color        : v4 = v4.{0.4,0.4,0.4,1.0};
	active_widget_color     : v4 = v4.{0.5,0.5,0.5,1.0};
	text_color0             : v4 = v4.{0.9,0.9,0.9,1.0};
}

XGUI_ID :: u64;
XGUI_INVALID :: 666;

xGuiContext :: struct {
	style : xGuiStyle;
	hot : XGUI_ID = XGUI_INVALID; 
	active: XGUI_ID = XGUI_INVALID; 
}

g_gui_context : xGuiContext;

xgui_frame_begin:: () {
	g_gui_context.hot = XGUI_INVALID;

}
xgui_frame_end :: () { }


xgui_button :: (rend : *xRend2D, text : string, r : Rect) -> bool {
  ret : bool = false;
	id := djb2(text);
	mp := xim_get_mouse_pos();
	lmb_pressed := xim_mkey_pressed(.LMB);
  lmb_released := xim_mkey_released(.LMB);
	if rect_isect(r, mp) then g_gui_context.hot = id;
	if g_gui_context.hot == id && lmb_pressed then g_gui_context.active = id;
  if g_gui_context.active == id && g_gui_context.hot == id && lmb_released {
    g_gui_context.active = XGUI_INVALID;
    ret = true;
  }
  if g_gui_context.active == id && g_gui_context.hot != id && lmb_released {
    g_gui_context.active = XGUI_INVALID;
    ret = false;
  }

  xgui_render_button(rend, text, r);

	return ret;
}

xgui_get_widget_color :: (id : XGUI_ID) -> v4 {
  if g_gui_context.active == id then return g_gui_context.style.active_widget_color;
  if g_gui_context.hot == id then return g_gui_context.style.hot_widget_color;
  return g_gui_context.style.default_widget_color;
}

xgui_render_button :: (rend : *xRend2D, text : string, rect : Rect) {
  r := xr2d_begin();
  //defer xr2d_end(r);

  id := djb2(text);
  white_tex := acast(xasset_mgr_find(*xeng().persistent_asset_mgr, "white.png"), xTextureAsset);
  assert(white_tex != null);

  cam := xCamera2D.{ target = v2.{0,0}, rot = 0, zoom = 1, offset = v2.{0,0}, };

  // 0. Draw The button border
  //xr2d_imm_render_quad(rend, .{rect.x,rect.y, cast(float)rect.w, cast(float)rect.h}, .{0,0,0,0}, xgui_get_widget_color(id), *cam, *white_tex.tex);
  xr2d_push_quad(r,v2.{rect.x,rect.y},v2.{rect.w,rect.h},xgui_get_widget_color(id));
  xr2d_end(r);

  // 1. Calc text-boxes final metrics
  font := acast(xasset_mgr_find(*xeng().persistent_asset_mgr, "default.ttf"), xFontAsset);
  width := xfont_get_text_width(text, font, 1.0);
  height := xfont_get_ymax(text, font, 1.0) + xfont_get_ymin(text, font, 1.0);

  // 2. here we can change the text layouting (also what about clipping)
  rpos := v2.{rect.x - (width-rect.w)/2.0,rect.y + rect.h/2.0 + height/2.0};

  // 3. Draw the text
  for codepoint : text {
    glyph_info, found := xfont_asset_lookup_glyph_info(font, cast(u32)codepoint);
    if found {
      rpos += v2.{cast(float)glyph_info.metrics.hbearing_x, - cast(float)glyph_info.metrics.hbearing_y};
      xr2d_imm_render_quad(rend, .{rpos.x,rpos.y, cast(float)glyph_info.metrics.width, cast(float)glyph_info.metrics.height}, glyph_info.tex_coord, g_gui_context.style.text_color0, *cam, *font.atlas);
      rpos -= v2.{cast(float)glyph_info.metrics.hbearing_x, - cast(float)glyph_info.metrics.hbearing_y};
      rpos.x += glyph_info.metrics.hadvance;
    }
  }
}