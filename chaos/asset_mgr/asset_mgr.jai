// make this a polymorphic struct ? or no idk
xAssetMgr :: struct {
	slots : *xAssetHashSlot;
}
xAssetTag :: string;
XASSET_MGR_MAX_ASSETS :: 64;


xAssetHashSlot :: struct {
	first : *xAssetBase;
	last  : *xAssetBase;
}

xasset_mgr_init :: (using mgr : *xAssetMgr) {
	slots = alloc(size_of(xAssetHashSlot) * XASSET_MGR_MAX_ASSETS);
}

xasset_mgr_load :: (mgr : *xAssetMgr, base_path : string) -> xAssetTag {
	tag : xAssetTag;

	// find the type of asset (currently Textures and Fonts)
	asset_type : Type;
  is_dir := is_directory(base_path);
  if is_dir {
  	success := visit_files(base_path, false, *asset_type, (info: *File_Visit_Info, user_data: *Type) { 
  		if contains(info.short_name, ".png") {
  			user_data.* = xTextureAsset;
  		} else if contains(info.short_name, ".ttf") {
  			user_data.* = xFontAsset;
  		}
  	}, visit_files = true, visit_directories = false, visit_symlinks = false, follow_directory_symlinks = false);
		//print("XASSET - Parsed Asset of type: [%]", asset_type);


		// make the actual asset and fill the tag
		if asset_type == {
			case xTextureAsset;
				// maybe this should be a function on the asset type
				found,asset_path,texture_name := split_from_right(base_path, #char "/");
				png_path := tprint("%/%.png\0", base_path, texture_name);
				json_path := tprint("%/%.json\0", base_path, texture_name);

				asset : *xTextureAsset = alloc(size_of(xTextureAsset));
				asset.details = xjson_parse_wholefile_string(read_entire_file(json_path));
			  asset.tex = texture_load(png_path);
			  asset.tag = texture_name;
			  asset.ref_count = 1;
			  asset.base_path = base_path;
			  asset.type = asset_type;

			  slot := djb2(asset.tag) % XASSET_MGR_MAX_ASSETS;
		    mgr.slots[slot].first, mgr.slots[slot].last = dll_push_back(mgr.slots[slot].first, mgr.slots[slot].last, asset);

		    tag = asset.tag;

			case xFontAsset;
			case;
		}

  } else {
  	print("XASSET: Loading asset dir=[%] failed", base_path);
  }
  return tag;
}

xasset_find :: (mgr : *xAssetMgr, tag : xAssetTag) -> *xAssetBase {
  slot := djb2(tag) % XASSET_MGR_MAX_ASSETS;
  asset_itr := mgr.slots[slot].first;

  while asset_itr {
  	if asset_itr.tag == tag then return asset_itr;
  	asset_itr = asset_itr.next;
  }
  return null;
}

acast :: (a : *xAssetBase, $T : Type) -> *T {
  assert(a.type == T);
  return cast(*T)a;
}
