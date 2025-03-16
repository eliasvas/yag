Sprite :: struct @entity {
  #as using base : xEntityBase;

  tex : *oglTex;
  tc : v4;
  base_tc : v4;
  frame_count : u32;
  fps : u32;
}

init :: (using s : *Sprite) {
  print("Sprite init!\n");
}

deinit :: (using s : *Sprite) {
  print("Sprite deinit!\n");
}

update :: (using s : *Sprite) {
  print("Sprite update!\n");
  tc = base_tc;
  tc.x += (cast(u32)(seconds_since_init() * cast(float)fps) % frame_count) * base_tc.z;
  //tc.y += (cast(u32)(seconds_since_init() * cast(float)fps) % frame_count) * base_tc.w;
}

render :: (using s : *Sprite, rend : *xRend2D, cam : *xCamera2D) {
	gpos := xentity_calc_global_pos(s);
	print("gpos: %\n", gpos);
    xr2d_quad_render(rend, v4.{gpos.x,gpos.y,100,100}, tc, .{1,1,1,1}, cam, tex);
}


Player :: struct @entity {
  #as using base : xEntityBase;
}

init :: (using p : *Player) {
	print("Player init!\n");
}

deinit :: (using p : *Player) {
	print("Player deinit!\n");
}


update :: (using p : *Player) {
	print("Player update! %\n", local_pos);
	if (xim_kkey_down(.SC_UP)) local_pos.y -= 1;
	if (xim_kkey_down(.SC_DOWN)) local_pos.y += 1;
	if (xim_kkey_down(.SC_LEFT)) local_pos.x -= 1;
	if (xim_kkey_down(.SC_RIGHT)) local_pos.x += 1;

	// for testing
	if (xim_kkey_down(.SC_X))marked_for_destruction = true; 
}
