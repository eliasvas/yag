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

// we provide an alloc strategy via pushing allocator (xArena) and return the asset

xasset_alloc :: ($type : Type) -> *type { return alloc(size_of(type)); }


xFontMetaData :: struct { } // TODO

xFontAsset :: struct @asset {
  #as using base : xAssetBase;
  tex : oglTex;
  metadata : xFontMetaData;
}

xTextureAsset :: struct @asset {
  #as using base : xAssetBase;
  tex : oglTex;
  details : *xJsonNode;
}

xSceneAsset :: struct @asset {
  #as using base : xAssetBase;
  root : *xJsonNode;
}