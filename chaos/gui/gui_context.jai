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

    // Stacks
    parent_stack : xGuiParentStack;
    fixed_x_stack : xGuiFixedXStack;
    fixed_y_stack : xGuiFixedYStack;
    fixed_width_stack : xGuiFixedWidthStack;
    fixed_height_stack : xGuiFixedHeightStack;
    pref_width_stack : xGuiPrefWidthStack;
    pref_height_stack : xGuiPrefHeightStack;
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
		while !xgui_box_is_nil(node) {
			// prune unused widgets and insert to the freelist for reuse!
			if node.last_used_frame_index != gctx.frame_index {
				print("will prune because node=[%,%] and context=%\n", node.str, node.last_used_frame_index, gctx.frame_index);
				to_delete := node;
				node = node.hash_next;
				slot.hash_first, slot.hash_last = dll_remove(slot.hash_first, slot.hash_last, to_delete);
				Initialize(to_delete);
			} else {
				//print("srnode=%\n", node.srnode);
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
	while !xgui_box_is_nil(child) {
		xgui_dummy_draw(gctx, child);
		child = child.next;
	}
}

xgui_frame_begin :: () {
	reset(*g_gui_context.frame_arena);
	g_gui_context.rend = xr2d_begin();
	g_gui_context.frame_index = xeng().frame_index;

	g_gui_context.hot = XGUI_INVALID_ID;

    // build a root pane!
    wdim := xwin_get_dim(*xeng().win);
    xgui_set_next_fixed_x(0);
    xgui_set_next_fixed_y(0);
    xgui_set_next_fixed_width(wdim.x);
    xgui_set_next_fixed_height(wdim.y);
    pane_box := xgui_pane("master_pane"); // should be made at frame begin with screendim
    pane_box.box.flags = 0; // cancel all rendering for root pane :(
	g_gui_context.root = pane_box.box; // what the fuck is even this
    xgui_push_parent(pane_box.box);
    //defer xgui_pop_parent();

}

xgui_frame_end :: () {
    // pop the root pane!
    xgui_pop_parent();

	xgui_prune_unused_boxes(*g_gui_context);
	xgui_do_layouting(*g_gui_context);
	xgui_dummy_draw(*g_gui_context, g_gui_context.root);
	xr2d_end(g_gui_context.rend);
}

//////////////////////////////////////////
// GUI styling  (TODO: style stacks for each field!)

// TODO: removethis garbo and make the damn style stacks
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
    for axis : enum_values_as_s64(xAxis2) {
        xgui_layout_calc_constant_sizes(gctx.root, xx axis);
    } 
    xgui_layout_calc_final_rects(gctx.root);
}

xgui_layout_calc_constant_sizes :: (root : *xGuiBox, axis : xAxis2) {
    if root.pref_size[xx axis].kind == .PIXELS {
        root.fixed_size[xx axis] = root.pref_size[xx axis].value;
    } else if root.pref_size[xx axis].kind == .TEXT_CONTENT {
        font := acast(xasset_mgr_find(*xeng().persistent_asset_mgr, "default.ttf"), xFontAsset);
        twidth := xfont_get_text_width(root.str, font, 1.0);
        theight := xfont_get_ymax(root.str, font, 1.0) + xfont_get_ymin(root.str, font, 1.0);
        text_size := v2.{twidth, theight};
        padding := root.pref_size[xx axis].value;
        root.fixed_size[xx axis] = text_size[xx axis] + 2.0 * padding;
    }

	child := root.first;
	while !xgui_box_is_nil(child) {
        xgui_layout_calc_constant_sizes(child, axis);
		child = child.next;
	}
}

xgui_layout_calc_final_rects :: (root : *xGuiBox) {
    root.rect = .{root.fixed_position.x,root.fixed_position.y, root.fixed_size.x, root.fixed_size.y};

	child := root.first;
	while !xgui_box_is_nil(child) {
        xgui_layout_calc_final_rects(child);
		child = child.next;
	}
}

//////////////////////////////
// GUI stacks

xGuiStack :: struct ($T: Type) {
	STACK_MAX_SIZE :: 512;
    // TODO: should be allocated on the persistent gui arena (at startup)
    values : [STACK_MAX_SIZE]T;
    count : u64;
    def_value : T;// = #run Initialize(*T);
    auto_pop : bool = false; // wether to automatically pop (like after set_next);
}

xgui_stack_push :: (using stack : *xGuiStack($T), val : T, autopop : bool = false) {
	assert(count < xGuiStack(T).STACK_MAX_SIZE);
	values[count] = val;
	count+=1;
    auto_pop = autopop;
}
xgui_stack_pop :: (using stack : *xGuiStack($T)) -> T {
	if count == 0 {
		return def_value;
	} else {
		count -=1;
		return values[count];
	}
}
xgui_stack_peek :: (using stack : *xGuiStack($T)) -> T {
	if count == 0 {
		return def_value;
	} else {
		return values[count-1];
	}
}
xgui_stack_empty :: (using stack : *xGuiStack($T)) -> bool {
    return count == 0;
}
xgui_stack_auto_pop :: (using stack : *xGuiStack($T)) {
    if auto_pop {
        xgui_stack_pop(stack);
        auto_pop = false;
    }
}


xGuiParentStack :: struct {
    #as using base : xGuiStack(*xGuiBox);
    def_value = *g_gui_box;
}
xgui_push_parent :: (parent : *xGuiBox) { xgui_stack_push(*g_gui_context.parent_stack, parent); }
xgui_set_next_parent :: (parent : *xGuiBox) { xgui_stack_push(*g_gui_context.parent_stack, parent, true); }
xgui_pop_parent :: () -> *xGuiBox { return xgui_stack_pop(*g_gui_context.parent_stack); }
xgui_peek_parent :: () -> *xGuiBox { return xgui_stack_peek(*g_gui_context.parent_stack); }
xgui_parent_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.parent_stack);}

xGuiFixedXStack :: struct {
    #as using base : xGuiStack(float);
    def_value = 0;
}
xgui_push_fixed_x :: (x : float) { xgui_stack_push(*g_gui_context.fixed_x_stack, x); }
xgui_set_next_fixed_x :: (x : float) { xgui_stack_push(*g_gui_context.fixed_x_stack, x, true); }
xgui_pop_fixed_x :: () -> float { return xgui_stack_pop(*g_gui_context.fixed_x_stack); }
xgui_peek_fixed_x :: () -> float { return xgui_stack_peek(*g_gui_context.fixed_x_stack); }
xgui_fixed_x_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.fixed_x_stack);}

xGuiFixedYStack :: struct {
    #as using base : xGuiStack(float);
    def_value = 0;
}
xgui_push_fixed_y :: (y : float) { xgui_stack_push(*g_gui_context.fixed_y_stack, y); }
xgui_set_next_fixed_y :: (y : float) { xgui_stack_push(*g_gui_context.fixed_y_stack, y, true); }
xgui_pop_fixed_y :: () -> float { return xgui_stack_pop(*g_gui_context.fixed_y_stack); }
xgui_peek_fixed_y :: () -> float { return xgui_stack_peek(*g_gui_context.fixed_y_stack); }
xgui_fixed_y_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.fixed_y_stack);}

xGuiFixedWidthStack :: struct {
    #as using base : xGuiStack(float);
    def_value = 300;
}
xgui_push_fixed_width :: (w : float) { xgui_stack_push(*g_gui_context.fixed_width_stack, w); }
xgui_set_next_fixed_width :: (w : float) { xgui_stack_push(*g_gui_context.fixed_width_stack, w, true); }
xgui_pop_fixed_width :: () -> float { return xgui_stack_pop(*g_gui_context.fixed_width_stack); }
xgui_peek_fixed_width :: () -> float { return xgui_stack_peek(*g_gui_context.fixed_width_stack); }
xgui_fixed_width_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.fixed_width_stack);}

xGuiFixedHeightStack :: struct {
    #as using base : xGuiStack(float);
    def_value = 100;
}
xgui_push_fixed_height :: (h : float) { xgui_stack_push(*g_gui_context.fixed_height_stack, h); }
xgui_set_next_fixed_height :: (h : float) { xgui_stack_push(*g_gui_context.fixed_height_stack, h, true); }
xgui_pop_fixed_height :: () -> float { return xgui_stack_pop(*g_gui_context.fixed_height_stack); }
xgui_peek_fixed_height :: () -> float { return xgui_stack_peek(*g_gui_context.fixed_height_stack); }
xgui_fixed_height_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.fixed_height_stack);}

xGuiPrefWidthStack :: struct {
    #as using base : xGuiStack(xGuiSize);
    def_value = .{.PIXELS, 300.0, 0.0};
}
xgui_push_pref_width :: (w : xGuiSize) { xgui_stack_push(*g_gui_context.pref_width_stack, w); }
xgui_set_next_pref_width :: (w : xGuiSize) { xgui_stack_push(*g_gui_context.pref_width_stack, w, true); }
xgui_pop_pref_width :: () -> xGuiSize { return xgui_stack_pop(*g_gui_context.pref_width_stack); }
xgui_peek_pref_width :: () -> xGuiSize { return xgui_stack_peek(*g_gui_context.pref_width_stack); }
xgui_fixed_pref_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.pref_width_stack);}

xGuiPrefHeightStack :: struct {
    #as using base : xGuiStack(xGuiSize);
    def_value = .{.PIXELS, 100.0, 0.0};
}
xgui_push_pref_height :: (h : xGuiSize) { xgui_stack_push(*g_gui_context.pref_height_stack, h); }
xgui_set_next_pref_height :: (h : xGuiSize) { xgui_stack_push(*g_gui_context.pref_height_stack, h, true); }
xgui_pop_pref_height :: () -> xGuiSize { return xgui_stack_pop(*g_gui_context.pref_height_stack); }
xgui_peek_pref_height :: () -> xGuiSize { return xgui_stack_peek(*g_gui_context.pref_height_stack); }
xgui_fixed_pref_height :: () -> bool {return xgui_stack_empty(*g_gui_context.pref_height_stack);}



xgui_auto_pop_all_stacks :: () {
    xgui_stack_auto_pop(*g_gui_context.parent_stack);
    xgui_stack_auto_pop(*g_gui_context.fixed_x_stack);
    xgui_stack_auto_pop(*g_gui_context.fixed_y_stack);
    xgui_stack_auto_pop(*g_gui_context.fixed_width_stack);
    xgui_stack_auto_pop(*g_gui_context.fixed_height_stack);
}
