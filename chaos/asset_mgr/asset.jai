// TODO: serialization/deserialization

xAssetBase :: struct {
	base_path : string;
	tag : string;
	ref_count : u32;

  // hash maps links
  next : *xAssetBase;
  prev : *xAssetBase;

  type : Type;
}

acast :: (a : *xAssetBase, $T : Type) -> *T {
  assert(a.type == T);
  return cast(*T)a;
}

// we provide an alloc strategy via pushing allocator (xArena) and return the asset

//xasset_alloc :: ($type : Type) -> *type { return alloc(size_of(type)); }

xTextureAsset :: struct {
  #as using base : xAssetBase;
  tex : oglTex;
  details : *xJsonNode;
  type = xTextureAsset;
}

// TODO: here we need a texture desc probably
xtexture_asset_make :: (data : *u8, dim : v2) -> *xTextureAsset {
  name : string = "white.png";
  asset : *xTextureAsset = New(xTextureAsset);
  asset.ref_count = 1;
  asset.type = xTextureAsset;
  asset.tag = name;
  asset.base_path = XDEFAULT_FONT_PATH;

  ogl_tex_init(*asset.tex, dim, cast(*u8)data, oglTexFormat.RGBA8U);

  return asset;
}

xSceneAsset :: struct {
  #as using base : xAssetBase;
  root : *xJsonNode;
  type = xSceneAsset;
}