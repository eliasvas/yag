xgui_render_box :: (gctx : *xGuiContext, box : *xGuiBox) {
	r := gctx.rend;

	id := box.id;
	rect := box.rect;
	text := box.str;

	white_tex := acast(xasset_mgr_find(*xeng().persistent_asset_mgr, "white.png"), xTextureAsset);
	assert(white_tex != null);

	if box.flags & xGuiBoxFlags.DRAW_BACKGROUND {
        // 0. Draw The button background
		xr2d_push_quad(r,v2.{rect.x,rect.y},v2.{rect.x + rect.w,rect.y + rect.h}, v2.{0,0}, v2.{0,0}, box.color, 10.0);
	}

	if box.flags & xGuiBoxFlags.DRAW_TEXT {
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
	      xr2d_push_quad(r,v2.{rpos.x,rpos.y},v2.{rpos.x + cast(float)glyph_info.metrics.width, rpos.y + cast(float)glyph_info.metrics.height}, v2.{glyph_info.tex_coord.x,glyph_info.tex_coord.y}, v2.{glyph_info.tex_coord.x+glyph_info.tex_coord.z,glyph_info.tex_coord.y + glyph_info.tex_coord.w}, .{0.95, 0.95,0.95,1.0}, 0.0, "default.ttf");
	      rpos -= v2.{cast(float)glyph_info.metrics.hbearing_x, - cast(float)glyph_info.metrics.hbearing_y};
	      rpos.x += glyph_info.metrics.hadvance;
	    }
	  }
	}
}
