// NOTE: should we make some font abstraction in asset_mgr as opposed to here? I think so
// NOTE: maybe scale should be vert_px like in font assets! or something..

xfont_get_text_width :: (text : string, font : *xFontAsset, scale : float = 1.0) -> float {
  _, width := xfont_get_substring_to_fit_dim(text,font, scale, .{FLOAT32_MAX, FLOAT32_MAX});
  return width;
}

// TODO: Maybe we need to provide alignment too I THINK;
xfont_get_substring_to_fit_dim :: (text : string, font : *xFontAsset, scale : float = 1.0, dim : v2) -> string, float {
  substr := text;

  // Early return, if the height does not fit, truncate EVERYTHING :)
  height := xfont_get_ymax(text, font, 1.0) + xfont_get_ymin(text, font, 1.0);
  if height > dim.y then return "",0;


  // If its ok, fit as many characters as possible
  total_width : float = 0.0;
  total_chars : u32 = 0;
  for c : text {
    glyph_info, found := xfont_asset_lookup_glyph_info(font, cast(u32)c);
    if found {
      if scale * (total_width + glyph_info.metrics.hadvance) < dim.x {
        total_width += glyph_info.metrics.hadvance;
        total_chars +=1;
      } else {
        break;
      }
    }
  }
  substr.count = total_chars;
  return substr, total_width*scale;
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
      ymin = min(ymin, cast(float)glyph_info.metrics.hbearing_y);
    }
  }
  return ymin*scale;
}