// NOTE: should we make some font abstraction in asset_mgr as opposed to here? I think so

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