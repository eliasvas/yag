#import "freetype-2.12.1";

// This is a great into for anything FreeType https://freetype.org/freetype2/docs/tutorial/index.html
// This is the reference https://freetype.sourceforge.net/freetype2/docs/reference/ft2-base_interface.html
// This guy is cracked https://www.youtube.com/watch?v=PyTPhG9eA0Y

// TODO:
// - Font Mip-Mapping (making a font atlas with multiple resolutions and interpolating)
// - SDF fonts
// - kerning
// - investigate OpenGL texture coordinates
// - subpixel rendering

xFontAsset :: struct @asset {
  #as using base : xAssetBase;
  atlas : oglTex;
  glyphs : xFontGlyphCache;
}

xFontGlyphCache :: struct {
  map : *xFontGlyphInfoSlot;
  //count : u32; // how many glyphs/codepoints
}

xFontGlyphInfoSlot :: struct {
  first : *xFontGlyphInfo;
  last : *xFontGlyphInfo;
}

xFontGlyphInfo :: struct {
  next : *xFontGlyphInfo;
  prev : *xFontGlyphInfo;

  codepoint : u32;
  metrics : xFontGlyphMetrics;
  tex_coord : v4; // NOTE: this should maybe be a Rect?
}

xFontGlyphMetrics :: struct {
  width : s32; // glyph width (in pixels)
  height : s32; // glyph height (in pixels)
  hbearing_x : s32; // pixels to glyphs leftmost border
  hbearing_y : s32; // pixels to glyphs topmost border (offset from baseline)
  hadvance : s32; // how many pixels to advance to account for glyph
}


g_font_tex : oglTex;
g_metrics : xFontGlyphMetrics;

FT_RGBA_Pixel :: struct { r,g,b,a : u8; }
freetype_extract_font_bitmap_and_metrics :: (face : FT_Face, codepoint : u32, vert_size_px : u32 = 64) -> *FT_RGBA_Pixel, xFontGlyphMetrics {
  error := FT_Set_Pixel_Sizes(face, 0, vert_size_px); 
  assert(!error);

  glyph_index := FT_Get_Char_Index(face, codepoint);
  assert(glyph_index != 0); // 0 means missing glyph

  error = FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
  assert(!error);
  error = FT_Render_Glyph(face.glyph, .FT_RENDER_MODE_NORMAL);

  g_metrics = xFontGlyphMetrics.{
    width = xx (face.glyph.metrics.width >> 6),
    height = xx (face.glyph.metrics.height >> 6),
    hbearing_x = xx (face.glyph.metrics.horiBearingX >> 6),
    hbearing_y = xx (face.glyph.metrics.horiBearingY >> 6),
    hadvance = xx (face.glyph.metrics.horiAdvance >> 6),
  };

  bitmap_px_count := cast(u32)face.glyph.bitmap.width * face.glyph.bitmap.rows;
  rgba_tex :*FT_RGBA_Pixel= talloc(bitmap_px_count * size_of(FT_RGBA_Pixel));
  for i : 0..bitmap_px_count-1 {
    c : u8 = xx (cast(*u8)face.glyph.bitmap.buffer)[i];
    rgba_tex[i] = .{c,c,c,c};
    //rgba_tex[i] = .{c,c,c,255};
  }

  return rgba_tex, g_metrics;
}

freetype_pack_all_ascii_to_texture :: (face : FT_Face) -> oglTex {
  atlas_width :: 512;
  atlas_height :: 512;
  atlas_pixels :*FT_RGBA_Pixel= talloc(atlas_width * atlas_height * size_of(FT_RGBA_Pixel));

  iv2 :: struct { x,y : s32;}
  // hrect is internal, used for the packing, it will do the 'layouting'
  copy :: (src : *FT_RGBA_Pixel, src_dim : iv2, dst : *FT_RGBA_Pixel, dst_dim : iv2, hrect : *iRect) {
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
  for i : 33..126 {
    pixels, metrics := freetype_extract_font_bitmap_and_metrics(face,cast(u32)i);
    copy(pixels, iv2.{metrics.width, metrics.height}, atlas_pixels, iv2.{atlas_width, atlas_height}, *hrect);
  }

  atlas : oglTex;
  ogl_tex_init(*atlas, v2.{atlas_width, atlas_height}, cast(*u8)atlas_pixels, oglTexFormat.RGBA8U);

  return atlas;
}

xfont_get_default_font_path :: () -> string {
  #if OS == .WINDOWS {
    XDEFAULT_FONT_PATH :: "C:/Windows/Fonts";
    XDEFAULT_FONT_FILE :: "georgia.ttf";
  } else #if OS == .LINUX {
    XDEFAULT_FONT_PATH :: "/usr/share/fonts";
    XDEFAULT_FONT_FILE :: "open-sans/OpenSans-Bold.ttf";
  }
  font_path := tprint("%/%\0", XDEFAULT_FONT_PATH, XDEFAULT_FONT_FILE);

  return font_path;
}

// xfont_load_asset(..., font_range : []u32);

ft_test :: () {
  library : FT_Library;
  error := FT_Init_FreeType(*library);
  defer FT_Done_FreeType(library);
  assert(!error);

  font_path := xfont_get_default_font_path();

  face : FT_Face;
  error = FT_New_Face(library, font_path.data, 0, *face);
  defer FT_Done_Face(face);

  assert(!error);
  glyph_bitmap, metrics := freetype_extract_font_bitmap_and_metrics(face, #char "a");
  print("extracted metrics : %\n", metrics);
  //ogl_tex_init(*g_font_tex, v2.{cast(float)face.glyph.bitmap.width, cast(float)face.glyph.bitmap.rows}, cast(*u8)glyph_bitmap, oglTexFormat.RGBA8U);

  g_font_tex = freetype_pack_all_ascii_to_texture(face);
}
