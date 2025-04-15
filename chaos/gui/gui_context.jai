//////////////////////////////////////////
// GUI context

xGuiContext :: struct {
	style : xGuiStyle;
	hot : xGuiID = XGUI_INVALID_ID; 
	active: xGuiID = XGUI_INVALID_ID; 
	frame_index : u64;

	frame_arena : xArena; // maybe we need 2

	SLOT_COUNT :: 512;
	slots : []xGuiBoxHashSlot;
	freelist : *xGuiBox;

	// transient stuff
	persistent_arena : xArena;
	hierarchy : *xGuiBox;
	rend : *xRend2D;

	root : *xGuiBox;

}

g_gui_context : xGuiContext;

xgui_init :: () {
	// 0. initialize the map for gui boxes, so we can look them up fast!
	a: Allocator; a.proc = xarena_allocator_proc; a.data = *g_gui_context.persistent_arena;
	push_context .{allocator=a} {
	  g_gui_context.slots = NewArray(xGuiContext.SLOT_COUNT, xGuiBoxHashSlot);
	}
}

xgui_prune_unused_boxes :: (gctx : *xGuiContext) {
	for *slot : gctx.slots {
		node := slot.hash_first;
		while node != null {
			// prune unused widgets and insert to the freelist for reuse!
			if node.last_used_frame_index != gctx.frame_index {
				print("will prune because node=[%,%] and context=%\n", node.str, node.last_used_frame_index, gctx.frame_index);
				to_delete := node;
				node = node.hash_next;
				slot.hash_first, slot.hash_last = dll_remove(slot.hash_first, slot.hash_last, to_delete);
				Initialize(to_delete);
			} else {
				print("srnode=%\n", node.srnode);
				node = node.hash_next;
			}
		}
	}
}

xgui_update_hot_active_for_box :: (gctx : *xGuiContext, box : *xGuiBox) -> bool {
	box_pressed : bool = false;

	id := box.id;
	mp := xim_get_mouse_pos();
	lmb_pressed := xim_mkey_pressed(.LMB);
	lmb_released := xim_mkey_released(.LMB);
	if rect_isect(box.rect, mp) then gctx.hot = id;
	if gctx.hot == id && lmb_pressed then gctx.active = id;
	if gctx.active == id && gctx.hot == id && lmb_released {
		gctx.active = XGUI_INVALID_ID;
	    box_pressed = true;
	}
	if gctx.active == id && gctx.hot != id && lmb_released {
		gctx.active = XGUI_INVALID_ID;
		box_pressed= false;
	}
	return box_pressed;
}

xgui_dummy_draw :: (gctx : *xGuiContext, root : *xGuiBox) {
	// render the current box
	xgui_render_box(gctx, root);

	// render all its children
	child := root.first;
	while child != null {
		xgui_dummy_draw(gctx, child);
		child = child.next;
	}
}




xgui_frame_begin :: () {
	reset(*g_gui_context.frame_arena);
	g_gui_context.rend = xr2d_begin();
	g_gui_context.frame_index = xeng().frame_index;

	g_gui_context.hot = XGUI_INVALID_ID;
}

xgui_frame_end :: () {
	xgui_prune_unused_boxes(*g_gui_context);
	xgui_do_layouting(*g_gui_context);
	xgui_dummy_draw(*g_gui_context, g_gui_context.root);
	xr2d_end(g_gui_context.rend);
}

//////////////////////////////////////////
// GUI styling  (TODO: style stacks for each field!)

xGuiStyle :: struct {
	panel_color              : v4 = v4.{0.2,0.2,0.2,1.0};
	default_widget_color     : v4 = v4.{0.45,0.45,0.45,1.0};
	hot_widget_color         : v4 = v4.{0.4,0.4,0.4,1.0};
	active_widget_color      : v4 = v4.{0.3,0.3,0.3,1.0};
	text_color0              : v4 = v4.{0.9,0.9,0.9,1.0};
}

xgui_get_widget_color :: (id : xGuiID) -> v4 {
  if g_gui_context.active == id then return g_gui_context.style.active_widget_color;
  if g_gui_context.hot == id then return g_gui_context.style.hot_widget_color;
  return g_gui_context.style.default_widget_color;
}

//////////////////////////////
// GUI layouting

xgui_do_layouting :: (gctx : *xGuiContext) {
	// FixedPosition = ..;
	gctx.root.rect = .{100,100,300,100};
}
