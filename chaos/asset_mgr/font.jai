#import "freetype-2.12.1";

XFONT_DEFAULT_FONT_SIZE :: 32;

// This is a great into for anything FreeType https://freetype.org/freetype2/docs/tutorial/index.html
// This is the reference https://freetype.sourceforge.net/freetype2/docs/reference/ft2-base_interface.html
// This guy is cracked https://www.youtube.com/watch?v=PyTPhG9eA0Y

// TODO:
// - Font Mip-Mapping (making a font atlas with multiple resolutions and interpolating)
// - SDF fonts
// - kerning
// - investigate OpenGL texture coordinates
// - subpixel rendering
// - support multiple codepoint ranges per font asset
// - hint resolution for given font.. small/medium/large maybe?

#if OS == .WINDOWS {
  XDEFAULT_FONT_PATH :: "C:/Windows/Fonts";
  XDEFAULT_FONT_FILE :: "georgia.ttf";
} else #if OS == .LINUX {
  XDEFAULT_FONT_PATH :: "/usr/share/fonts/open-sans";
  XDEFAULT_FONT_FILE :: "OpenSans-Bold.ttf";
}
xfont_get_default_font_path :: () -> string { return tprint("%/%\0", XDEFAULT_FONT_PATH, XDEFAULT_FONT_FILE); }

//////////////////////////////////
// xFont Asset
//////////////////////////////////

xFontAsset :: struct {
  #as using base : xAssetBase;
  atlas : oglTex;
  glyphs : xFontGlyphCache;
  type = xFontAsset;
}

xFontGlyphCache :: struct {
  base_codepoint : u32;
  glyphs : []xFontGlyphInfo;
}

xFontGlyphInfo :: struct {
  codepoint : u32;
  metrics : xFontGlyphMetrics;
  tex_coord : v4; // NOTE: this should maybe be a Rect?
}

// more info https://freetype.org/freetype2/docs/glyphs/glyphs-3.html
xFontGlyphMetrics :: struct {
  width : s32; // glyph width (in pixels)
  height : s32; // glyph height (in pixels)
  hbearing_x : s32; // pixels to glyphs leftmost border
  hbearing_y : s32; // pixels to glyphs topmost border (offset from baseline)
  hadvance : s32; // how many pixels to advance to account for glyph
}

xfont_asset_make :: (codepoint_range : iv2) -> *xFontAsset {
  name : string = "default.ttf";
  asset : *xFontAsset = New(xFontAsset);
  font_path := xfont_get_default_font_path();
  // TODO: actual reference counting
  asset.ref_count = 1;
  asset.type = xFontAsset;
  asset.tag = name;
  asset.base_path = XDEFAULT_FONT_PATH;

  library, face := freetype_helper_load_font(font_path);
  defer FT_Done_FreeType(library);
  defer FT_Done_Face(face);


  font_atlas_pixels, glyph_infos := freetype_helper_pack_codepoint_range(face, codepoint_range);
  ogl_tex_init(*asset.atlas, v2.{512,512}, cast(*u8)font_atlas_pixels, oglTexFormat.RGBA8U);

  asset.glyphs.base_codepoint = cast(u32)codepoint_range.x;
  asset.glyphs.glyphs = .{codepoint_range.y - codepoint_range.x, glyph_infos};

  return asset;
}

xfont_asset_lookup_glyph_info :: (using fasset : *xFontAsset, codepoint : u32) -> *xFontGlyphInfo, bool {
  if codepoint < fasset.glyphs.base_codepoint || codepoint > fasset.glyphs.base_codepoint + fasset.glyphs.glyphs.count {
    return null, false;
  }
  return *fasset.glyphs.glyphs[codepoint - fasset.glyphs.base_codepoint], true;
}

//////////////////////////////////
// FreeType helper functions
//////////////////////////////////

freetype_helper_load_font :: (fullpath : string) -> FT_Library, FT_Face {
  library : FT_Library;
  error := FT_Init_FreeType(*library);
  //defer FT_Done_FreeType(library);
  assert(!error);

  face : FT_Face;
  error = FT_New_Face(library, fullpath.data, 0, *face);
  //defer FT_Done_Face(face);

  return library, face;
}


FT_RGBA_Pixel :: struct { r,g,b,a : u8; }
freetype_helper_extract_font_bitmap_and_metrics :: (face : FT_Face, codepoint : u32, vert_size_px : u32 = XFONT_DEFAULT_FONT_SIZE) -> *FT_RGBA_Pixel, xFontGlyphMetrics {
  error := FT_Set_Pixel_Sizes(face, 0, vert_size_px); 
  assert(!error);

  glyph_index := FT_Get_Char_Index(face, codepoint);
  assert(glyph_index != 0); // 0 means missing glyph

  error = FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
  assert(!error);
  error = FT_Render_Glyph(face.glyph, .FT_RENDER_MODE_NORMAL);

  metrics := xFontGlyphMetrics.{
    width = xx (face.glyph.metrics.width >> 6),
    height = xx (face.glyph.metrics.height >> 6),
    hbearing_x = xx (face.glyph.metrics.horiBearingX >> 6),
    hbearing_y = xx (face.glyph.metrics.horiBearingY >> 6),
    hadvance = xx (face.glyph.metrics.horiAdvance >> 6),
  };

  bitmap_px_count := cast(u32)face.glyph.bitmap.width * face.glyph.bitmap.rows;
  if bitmap_px_count == 0 { // Space (32)
    return null, metrics;
  } else {
    rgba_tex :*FT_RGBA_Pixel = talloc(bitmap_px_count * size_of(FT_RGBA_Pixel));
    for i : 0..bitmap_px_count-1 {
      c : u8 = xx (cast(*u8)face.glyph.bitmap.buffer)[i];
      rgba_tex[i] = .{c,c,c,c};
      //rgba_tex[i] = .{c,c,c,255};
    }
    return rgba_tex, metrics;
  }
}

freetype_helper_pack_codepoint_range :: (face : FT_Face, range : iv2) -> *FT_RGBA_Pixel, *xFontGlyphInfo {
  atlas_width :: 512;
  atlas_height :: 512;
  atlas_pixels :*FT_RGBA_Pixel = talloc(atlas_width * atlas_height * size_of(FT_RGBA_Pixel));
  glyphs : *xFontGlyphInfo = alloc(size_of(xFontGlyphInfo) * (range.y - range.x));

  // hrect is internal, used for the packing, it will do the 'layouting'
  copy :: (src : *FT_RGBA_Pixel, src_dim : iv2, dst : *FT_RGBA_Pixel, dst_dim : iv2, hrect : *iRect) {
    if src == null return;
    assert(src_dim.x <= dst_dim.x);
    assert(src_dim.y <= dst_dim.y);

    // if codepoint goes over image boundary, change line
    if hrect.x + hrect.w + src_dim.x > dst_dim.x {
      hrect.w = 0;
      hrect.y = (hrect.y + hrect.h) % dst_dim.y; // tex will warp through
      hrect.h = 0;
    }
    // if codepoint extends beyond end of image, warp to beginning
    if hrect.y + src_dim.y > dst_dim.x {
      hrect.y = 0;
    }
    hrect.h = max(hrect.h, src_dim.y);

    for x : 0..src_dim.x-1 {
      for y : 0..src_dim.y-1 {
        xcoord := hrect.x + hrect.w + x;
        ycoord := hrect.y + y;
        dst[xcoord + ycoord * dst_dim.x] = src[x + y * src_dim.x];
      }
    }
    hrect.w += src_dim.x;
  }

  current_w := 0;
  current_h := 0;
  // 32 is space.. do we need it?
  hrect : iRect;
  for i : range.x..range.y {
    pixels, metrics_codepoint := freetype_helper_extract_font_bitmap_and_metrics(face,cast(u32)i);
    copy(pixels, iv2.{metrics_codepoint.width, metrics_codepoint.height}, atlas_pixels, iv2.{atlas_width, atlas_height}, *hrect);

    glyphs[i - range.x] = xFontGlyphInfo.{
      codepoint = cast(u32)i,
      metrics = metrics_codepoint,
      tex_coord = .{(hrect.x + hrect.w - metrics_codepoint.width) / cast(float)atlas_width , (hrect.y) / cast(float)atlas_height,(metrics_codepoint.width) / cast(float)atlas_width,(metrics_codepoint.height) / cast(float)atlas_height},
    };
  }

  return atlas_pixels, glyphs;
}

