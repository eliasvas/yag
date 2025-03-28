#import "freetype-2.12.1";

// This is a great into for anything FreeType https://freetype.org/freetype2/docs/tutorial/index.html
// This is the reference https://freetype.sourceforge.net/freetype2/docs/reference/ft2-base_interface.html
// This guy is cracked https://www.youtube.com/watch?v=PyTPhG9eA0Y

// TODO:
// - Font Mip-Mapping (making a font atlas with multiple resolutions and interpolating)
// - SDF fonts
// - investigate OpenGL texture coordinates

/*
// When we integrate to chaos, definition should look like this!
xFontMetaData :: struct { } // TODO

xFontAsset :: struct @asset {
  #as using base : xAssetBase;
  atlas : oglTex;
  metadata : xFontMetaData;
}
*/ 


g_font_tex : oglTex;

ft_lingo :: () {
  // 1. create an FT library
  library : FT_Library;
  error := FT_Init_FreeType(*library);
  //defer FT_Done_FreeType(library);
  assert(!error);

  #if OS == .WINDOWS {
    XDEFAULT_FONT_PATH :: "C:/Windows/Fonts";
  } else #if OS == .LINUX {
    XDEFAULT_FONT_PATH :: "/usr/share/fonts";
  }
  XDEFAULT_FONT_FILE :: "georgia.ttf";
  font_path := tprint("%/%\0", XDEFAULT_FONT_PATH, XDEFAULT_FONT_FILE);

  // 2. create an FT face
  face : FT_Face;
  error = FT_New_Face(library, font_path.data, 0, *face);
  //defer FT_Done_Face(face);
  assert(!error);

  print("Loaded font : %\n", XDEFAULT_FONT_FILE);
  print("-> num_glyphs : %\n", face.num_glyphs);
  print("-> scalable : %\n", face.face_flags & FT_FACE_FLAG_SCALABLE);
  print("-> units_per_EM : %\n", face.units_per_EM);
  print("-> available_size_num: %\n", face.available_sizes);

  // 2. set the puixel sizes for the glyphs
  error = FT_Set_Pixel_Sizes(face, 0, 32); // sizex sizey (in pixels)
  assert(!error);

  // 3. get glyph index of a unicode character
  glyph_index := FT_Get_Char_Index(face, #char "F");
  assert(glyph_index != 0); // 0 means missing glyph

  // 4. render the glyph
  error = FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
  assert(!error);
  error = FT_Render_Glyph(face.glyph, .FT_RENDER_MODE_NORMAL);

  print("bitmap: %\n", face.glyph.bitmap);
  print("left: %\n", face.glyph.bitmap_left);
  print("top: %\n", face.glyph.bitmap_top);

  bitmap_px_count := cast(u32)face.glyph.bitmap.width * face.glyph.bitmap.rows;
  rgba_tex :*v4=  alloc(bitmap_px_count * size_of(v4));
  for i : 0..bitmap_px_count-1 {
    c : u8 = xx (cast(*u8)face.glyph.bitmap.buffer)[i];
    rgba_tex[i] = v4.{xx c,xx c,xx c,255};
  }

  ogl_tex_init(*g_font_tex, v2.{cast(float)face.glyph.bitmap.width, cast(float)face.glyph.bitmap.rows}, cast(*u8)rgba_tex, oglTexFormat.RGBA32F);

}
