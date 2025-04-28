xgui_render_box :: (gctx : *xGuiContext, box : *xGuiBox) {
	// ATTENTION!
	// TODO: should we clip here? I think so!

	r := gctx.rend;

	id := box.id;
	rect := box.rect;
	text := box.str;

	white_tex := acast(xasset_mgr_find(*xeng().persistent_asset_mgr, "white.png"), xTextureAsset);
	assert(white_tex != null);

	if box.flags & xGuiBoxFlags.DRAW_BACKGROUND {
		xr2d_push_quad(r,v2.{rect.x,rect.y},v2.{rect.x + rect.w,rect.y + rect.h}, v2.{0,0}, v2.{0,0}, box.color, ifx box.flags & xGuiBoxFlags.MOUSE_CLICKABLE then v4.{0.5,0.5,0.5,1.0} else v4.{}, box.roundness, 1.0, ifx box.flags & xGuiBoxFlags.MOUSE_CLICKABLE then 2.0 else 0.0, 1.0);
	}

	if box.flags & xGuiBoxFlags.DRAW_TEXT {
		font := acast(xasset_mgr_find(*xeng().persistent_asset_mgr, "default.ttf"), xFontAsset);

	    trunc_text := ifx box.flags & .TRUNC_TEXT then xgui_box_truncate_text_to_fit_in_box(box, font) else box.str;
		rpos := xgui_box_calc_text_position(box, trunc_text);

		for codepoint : trunc_text {
			glyph_info, found := xfont_asset_lookup_glyph_info(font, cast(u32)codepoint);
			if found {
				rpos += v2.{cast(float)glyph_info.metrics.hbearing_x, - cast(float)glyph_info.metrics.hbearing_y};
				xr2d_push_quad(r,v2.{rpos.x,rpos.y},v2.{rpos.x + cast(float)glyph_info.metrics.width, rpos.y + cast(float)glyph_info.metrics.height}, v2.{glyph_info.tex_coord.x,glyph_info.tex_coord.y}, v2.{glyph_info.tex_coord.x+glyph_info.tex_coord.z,glyph_info.tex_coord.y + glyph_info.tex_coord.w}, box.text_color, v4.{0,0,0,0}, v4.{0,0,0,0}, 0.0, 0.0, 0.0, "default.ttf");
				rpos -= v2.{cast(float)glyph_info.metrics.hbearing_x, - cast(float)glyph_info.metrics.hbearing_y};
				rpos.x += glyph_info.metrics.hadvance;
			}
		}
	}
}
