Sprite :: struct {
  #as using base : xEntityBase;

  tex : *oglTex;
  tc : v4;
  base_tc : v4;
  halfdim : v2;
  frame_count : u32;
  fps : u32;
  type = Sprite;
}

sprite_fill_spritesheet_from_json :: (root : *xJsonNode, path : string, tex : *oglTex, dest : *Sprite) {
  node,found := xjson_node_get(root, path);
  assert(found);

  if node.values.count > 0 { // is an array (many textures)
    dest.frame_count = cast(u32)node.values.count; 
    node = node.values[0];
  } else {
  	dest.frame_count = 1;
  }

	tc : v4;
	tc.x = xjson_string_to_float(node.values[0].value);
	tc.y = xjson_string_to_float(node.values[1].value);
	tc.z = xjson_string_to_float(node.values[2].value);
	tc.w = xjson_string_to_float(node.values[3].value);
  tex_dim := tex.dim;
  tc = v4.{tc[0] / tex_dim.x, tc[1] / tex_dim.y, tc[2] / tex_dim.x, tc[3] / tex_dim.y};

  dest.base_tc = tc;
}

sprite_init :: (sprite : *Sprite, tex_asset : *xTextureAsset, sprite_name : string, fps : u32) {
  sprite_fill_spritesheet_from_json(tex_asset.details, sprite_name, *tex_asset.tex, sprite);
  sprite.tex = *tex_asset.tex;
  sprite.halfdim = v2.{sprite.base_tc.z*tex_asset.tex.dim.x*2, sprite.base_tc.w*tex_asset.tex.dim.y*2};
  sprite.fps = fps;
}


init :: (using s : *Sprite) {
  //print("Sprite init!\n");
}

deinit :: (using s : *Sprite) {
  //print("Sprite deinit!\n");
}

update :: (using s : *Sprite) {
  //print("Sprite update!\n");
  tc = base_tc;
  tc.x += (cast(u32)(seconds_since_init() * cast(float)fps) % frame_count) * base_tc.z;
  //tc.y += (cast(u32)(seconds_since_init() * cast(float)fps) % frame_count) * base_tc.w;
}

render :: (using s : *Sprite, rend : *xRend2D, cam : *xCamera2D, flip_x : bool) {
	gpos := xentity_calc_global_pos(s);
  actual_tc := tc;
  if flip_x {
    actual_tc.x = actual_tc.x + actual_tc.z;
    actual_tc.z = -actual_tc.z;
  }
  xr2d_imm_render_quad(rend, v4.{gpos.x-halfdim.x,gpos.y-halfdim.y,halfdim.x*2,halfdim.y*2}, actual_tc, .{1,1,1,1}, cam, tex);
}


Player :: struct {
  #as using base : xEntityBase;

  flip_x : bool;
  type = Player;
}

init :: (using p : *Player) {
	//print("Player init!\n");
}

deinit :: (using p : *Player) {
	//print("Player deinit!\n");
}


update :: (using p : *Player) {
	//print("Player update! %\n", local_pos);
	if (xim_kkey_down(.SC_UP)) local_pos.y -= 1;
	if (xim_kkey_down(.SC_DOWN)) local_pos.y += 1;
	if (xim_kkey_down(.SC_LEFT)) local_pos.x -= 1;
	if (xim_kkey_down(.SC_RIGHT)) local_pos.x += 1;

  if (xim_kkey_pressed(.SC_LEFT)) flip_x = true;
  if (xim_kkey_pressed(.SC_RIGHT)) flip_x = false;

	// for testing
	if (xim_kkey_down(.SC_X))marked_for_destruction = true; 
}
