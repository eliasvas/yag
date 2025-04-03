
//////////////////////////////////
// xAssetMgr
//////////////////////////////////
// TODO: currently im not sure init/deinit stuff work... @check
// TODO: look into allocation / deallocation (freelist)
// FIXME: WHY are AssetTags strings? WHERE are they allocated? AM I RETARDED?

xAssetMgr :: struct {
	slots : *xAssetHashSlot;

	freelist_first : *xAssetBase; // contains unused xAssetBase's
	freelist_last : *xAssetBase; // contains unused xAssetBase's
}
xAssetTag :: string;
XASSET_MGR_MAX_ASSET_BUCKETS :: 64;


xAssetHashSlot :: struct {
	first : *xAssetBase;
	last  : *xAssetBase;
}

xasset_mgr_init :: (using mgr : *xAssetMgr) {
	slots = alloc(size_of(xAssetHashSlot) * XASSET_MGR_MAX_ASSET_BUCKETS);
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

				asset : *xTextureAsset = New(xTextureAsset);
			  asset.tag = texture_name;
				_, first_time_created := xasset_mgr_add(mgr, asset); // this is triggered here so no allocations happen before its tried to be created
				if first_time_created {
					asset.details = xjson_parse_wholefile_string(read_entire_file(json_path));
				  asset.tex = texture_load(png_path);
				  asset.ref_count = 1;
				  asset.base_path = base_path;
				  asset.type = asset_type;
				} else {
					asset.ref_count +=1;
				}
		    tag = asset.tag;

			case xFontAsset;
			case;
		}

  } else {
  	print("XASSET: Loading asset dir=[%] failed", base_path);
  }
  return tag;
}


xasset_mgr_add :: (mgr : *xAssetMgr, asset: *xAssetBase) -> xAssetTag, bool {
  slot := djb2(asset.tag) % XASSET_MGR_MAX_ASSET_BUCKETS;

	//asset_tag_already_created := find(mgr.slots[slot].first, "tag", asset.tag);
  asset_tag_already_created := xasset_mgr_find(mgr, asset.tag);

	if asset_tag_already_created != null {
		asset_tag_already_created.ref_count += 1;
	}else {
		asset.ref_count = 1;
	  mgr.slots[slot].first, mgr.slots[slot].last = dll_push_back(mgr.slots[slot].first, mgr.slots[slot].last, asset);
	}

	// @FIXME asset.tag could be deallocated? we want the one on the xAssetMgr's map!
  return asset.tag, asset_tag_already_created == null;
}

xasset_mgr_remove :: (mgr : *xAssetMgr, tag : xAssetTag) -> bool {
	asset := xasset_mgr_find(mgr, tag);

	if asset != null {
		if asset.ref_count == 1 {
		  slot := djb2(tag) % XASSET_MGR_MAX_ASSET_BUCKETS;
		  mgr.slots[slot].first, mgr.slots[slot].last = dll_remove(mgr.slots[slot].first, mgr.slots[slot].last, asset);
		  // TODO: add to the freelist?
		  //mgr.freelist_first, mgr.freelist_last = dll_push_back(mgr.freelist_first, mgr.freelist_last, asset);
			asset.ref_count = 0;
		} else {
			asset.ref_count -=1;
		}
	}

	return (asset != null) && asset.ref_count == 0;
}


xasset_mgr_find :: (mgr : *xAssetMgr, tag : xAssetTag) -> *xAssetBase {
  slot := djb2(tag) % XASSET_MGR_MAX_ASSET_BUCKETS;
  asset_itr := mgr.slots[slot].first;

  while asset_itr {
  	if asset_itr.tag == tag then return asset_itr;
  	asset_itr = asset_itr.next;
  }
  return null;
}




//////////////////////////////////
// xAssetMgr Tests
//////////////////////////////////

asset_mgr_tests :: () {
  mgr : xAssetMgr;
  xasset_mgr_init(*mgr);
  dummy_font1 := New(xFontAsset);
  dummy_font1.tag = "DummyFont";

  dummy_font2 := New(xFontAsset);
  dummy_font2.tag = "DummyFont";

  other_font := New(xFontAsset);
  other_font.tag = "OtherFont";


  {
	  my_tag, first_time_created := xasset_mgr_add(*mgr, dummy_font1);
	  assert(first_time_created);
	  assert(xasset_mgr_find(*mgr, my_tag).ref_count == 1);
	  assert(xasset_mgr_remove(*mgr, my_tag));
	  assert(dummy_font1.ref_count == 0);
	  assert(xasset_mgr_find(*mgr, my_tag) == null);
  }

  {
	  my_tag, first_time_created := xasset_mgr_add(*mgr, dummy_font1);
	  assert(first_time_created);
	  assert(xasset_mgr_find(*mgr, my_tag).ref_count == 1);
	  xasset_mgr_add(*mgr, dummy_font2);
	  assert(xasset_mgr_find(*mgr, my_tag).ref_count == 2);
	  assert(xasset_mgr_remove(*mgr, my_tag) == false);
	  assert(xasset_mgr_find(*mgr, my_tag).ref_count == 1);
	  assert(xasset_mgr_remove(*mgr, my_tag));
	  assert(xasset_mgr_find(*mgr, my_tag) == null);
  }

  {
	  my_tag, first_time_created := xasset_mgr_add(*mgr, dummy_font1);
	  assert(first_time_created);
	  assert(xasset_mgr_find(*mgr, my_tag).ref_count == 1);
	  other_tag, _ := xasset_mgr_add(*mgr, other_font);
	  assert(xasset_mgr_find(*mgr, my_tag).ref_count == 1);
	  assert(xasset_mgr_find(*mgr, other_tag).ref_count == 1);
	  assert(xasset_mgr_remove(*mgr, my_tag));
	  assert(xasset_mgr_find(*mgr, my_tag) == null);
	  assert(xasset_mgr_remove(*mgr, other_tag));
	  assert(xasset_mgr_find(*mgr, other_tag) == null);
  }


}

//#run asset_mgr_tests();
