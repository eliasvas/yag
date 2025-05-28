//////////////////////////////////////////
// GUI context

xGuiContext :: struct {
	hot : xGuiID = XGUI_INVALID_ID; 
	active: xGuiID = XGUI_INVALID_ID; 
	frame_index : u64;

	frame_arena : xArena; // maybe we need 2 (if we want frames in flight..)

	SLOT_COUNT :: 512;
	slots : []xGuiBoxHashSlot;
	freelist : *xGuiBox; // TODO: use freelists!

	// transient stuff
	persistent_arena : xArena;
	hierarchy : *xGuiBox;
	rend : *xRend2D;

	root : *xGuiBox;

  // Panel management
  root_panel : *xGuiPanel;
  panel_freelist : *xGuiPanel; // TODO: use freelists!
  panel_walk_node_stack : xGuiPanelWalkNodeStack; // can we remove this?

  // Stacks
  parent_stack : xGuiParentStack;
  fixed_x_stack : xGuiFixedXStack;
  fixed_y_stack : xGuiFixedYStack;
  fixed_width_stack : xGuiFixedWidthStack;
  fixed_height_stack : xGuiFixedHeightStack;
  pref_width_stack : xGuiPrefWidthStack;
  pref_height_stack : xGuiPrefHeightStack;
  child_layout_axis_stack : xGuiChildLayoutAxisStack;
  background_color_stack : xGuiBackgroundColorStack;
  text_alignment_stack : xGuiTextAlignmentStack;
  text_color_stack : xGuiTextColorStack;
  text_size_stack : xGuiTextSizeStack;
  box_roundness_stack : xGuiBoxRoundnessStack;
}

g_gui_context : xGuiContext;

xgui_init :: () {
	// initialize the map for gui boxes, so we can look them up fast!
	a: Allocator; a.proc = xarena_allocator_proc; a.data = *g_gui_context.persistent_arena;
	push_context .{allocator=a} {
	  g_gui_context.slots = NewArray(xGuiContext.SLOT_COUNT, xGuiBoxHashSlot);

      g_gui_context.root_panel = New(xGuiPanel);
      g_gui_context.root_panel.percent_of_parent = 1.0;
      g_gui_context.root_panel.split_axis = .X;
      //g_gui_context.root_panel.split_axis = .Y;

      // DUMMY hierarchy for testing purposes
      child1 := New(xGuiPanel);
      child1.label= "child1";
      child1.percent_of_parent = 0.3;
      child1.split_axis = .Y;
      g_gui_context.root_panel.first, g_gui_context.root_panel.last = dll_push_back(g_gui_context.root_panel.first, g_gui_context.root_panel.last, child1);
      child1.parent = g_gui_context.root_panel;


      child11 := New(xGuiPanel);
      child11.label= "child11";
      child11.percent_of_parent = 0.4;
      child1.first, child1.last = dll_push_back(child1.first, child1.last, child11);
      child11.parent = child1;

      child12 := New(xGuiPanel);
      child12.label= "child12";
      child12.percent_of_parent = 0.6;
      child1.first, child1.last = dll_push_back(child1.first, child1.last, child12);
      child12.parent = child1;


      child2 := New(xGuiPanel);
      child2.label= "child2";
      child2.percent_of_parent = 0.7;
      g_gui_context.root_panel.first, g_gui_context.root_panel.last = dll_push_back(g_gui_context.root_panel.first, g_gui_context.root_panel.last, child2);
      child2.parent = g_gui_context.root_panel;

	}
}

xgui_prune_unused_boxes :: (gctx : *xGuiContext) {
	for *slot,idx : gctx.slots {
		node := slot.hash_first;
		while !xgui_box_is_nil(node) {
			// prune unused widgets and insert to the freelist for reuse!
			if node.last_used_frame_index != gctx.frame_index {
               // print("will prune because node=[%] at % (bucket=%)\n", node.str, node,idx);
				to_delete := node;
				node = node.hash_next;
				slot.hash_first, slot.hash_last = dll_remove(slot.hash_first, slot.hash_last, to_delete, "hash_next", "hash_prev");
				Initialize(to_delete); // default initialize the node
                //to_delete.str = "already_deleted";
                // shouldnt I put his to the freelist?
			} else {
                //print("will not prune because node=[%] at %\n", node.str, node);
				node = node.hash_next;
			}
		}
	}
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

  // very experimental ////
  xwin_set_cursor(*g_engine.win, xWindowCursorKind.ARROW);
  /////////////////////////

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
  //xgui_set_next_child_layout_axis(.Y);
  xgui_set_next_child_layout_axis(.X);
  pane_box := xgui_pane("master_pane"); // should be made at frame begin with screendim
  pane_box.box.flags &= ~.DRAW_BACKGROUND;
  pane_box.box.rect = .{0,0,wdim.x,wdim.y};
  g_gui_context.root = pane_box.box; // what the fuck is even this
  xgui_push_parent(pane_box.box);

  // layout for all the panels / boundaries
  {
    wdim := xwin_get_dim(*xeng().win);
    root_panel := g_gui_context.root_panel;
    root_rect := Rect.{0,0,wdim.x,wdim.y};
    xgui_panel_do_layouting_for_panels_and_boundaries(root_panel, root_rect);
  }
}

xgui_frame_end :: () {
  // pop the root pane!
  xgui_pop_parent();

	xgui_prune_unused_boxes(*g_gui_context);
  xgui_do_layouting(*g_gui_context);
	xgui_dummy_draw(*g_gui_context, g_gui_context.root);
	xr2d_end(g_gui_context.rend);
}


xgui_get_box_color :: (box : *xGuiBox, base_color : v4 = .{0.4,0.4,0.4,1.0}) -> v4 {
    multiplier := 1.0;
    hot_color := base_color * 0.75;
    active_color := base_color * 0.4;
    return v4_lerp(base_color, v4_lerp(hot_color, active_color, box.active_t), box.hot_t);
}

//////////////////////////////
// GUI layouting

xgui_do_layouting :: (gctx : *xGuiContext) {
    for axis : enum_values_as_s64(xAxis2) {
        xgui_layout_calc_constant_sizes(gctx.root, xx axis);
        xgui_layout_calc_parent_dependent_sizes(gctx.root, xx axis);
        xgui_layout_calc_child_dependent_sizes(gctx.root, xx axis);
        xgui_layout_apply_constraints(gctx.root, xx axis);
        // finally calc rects
        xgui_layout_calc_final_rects(gctx.root, xx axis);
    } 
}

xgui_layout_calc_constant_sizes :: (root : *xGuiBox, axis : xAxis2) {
    if root.flags & (xGuiBoxFlags.FIXED_WIDTH<<axis) {
        // do nothing
    } else if root.pref_size[xx axis].kind == .PIXELS {
        root.fixed_size[xx axis] = root.pref_size[xx axis].value;
    } else if root.pref_size[xx axis].kind == .TEXT_CONTENT {
        font := acast(xasset_mgr_find(*xeng().persistent_asset_mgr, "default.ttf"), xFontAsset);
        twidth := xfont_get_text_width(root.str, font, 1.0);
        theight := xfont_get_ymax(root.str, font, 1.0) + xfont_get_ymin(root.str, font, 1.0);
        text_size := v2.{twidth, theight};
        padding := root.pref_size[xx axis].value;
        root.text_padding[xx axis] = padding; // NOTE: should this be filled here? should we move it when the box is created maybe?
        root.fixed_size[xx axis] = text_size[xx axis] + 2.0 * padding;
    }

	child := root.first;
	while !xgui_box_is_nil(child) {
        xgui_layout_calc_constant_sizes(child, axis);
		child = child.next;
	}
}

xgui_layout_calc_parent_dependent_sizes :: (root : *xGuiBox, axis : xAxis2) {
    if root.flags & (xGuiBoxFlags.FIXED_WIDTH<<axis) {
        // do nothing
    } else if root.pref_size[xx axis].kind == .PARENT_PCT {
        // find a fixed parent
        fixed_parent : *xGuiBox = null;
        parent := root.parent;
        while !xgui_box_is_nil(parent) {
            if parent.pref_size[xx axis].kind == .PARENT_PCT || parent.pref_size[xx axis].kind == .PIXELS || parent.pref_size[xx axis].kind == .TEXT_CONTENT {
                fixed_parent = parent;
                break;
            }
            parent = parent.parent;
        }
        if !xgui_box_is_nil(fixed_parent) {
            root.fixed_size[xx axis] = fixed_parent.fixed_size[xx axis] * root.pref_size[xx axis].value;
        }
    }

	child := root.first;
	while !xgui_box_is_nil(child) {
        xgui_layout_calc_parent_dependent_sizes(child, axis);
		child = child.next;
	}
}

xgui_layout_calc_child_dependent_sizes :: (root : *xGuiBox, axis : xAxis2) {
	child := root.first;
	while !xgui_box_is_nil(child) {
        xgui_layout_calc_child_dependent_sizes(child, axis);
		child = child.next;
	}

    if root.flags & (xGuiBoxFlags.FIXED_WIDTH<<axis) {
        // do nothing
    } else if root.pref_size[xx axis].kind == .CHILDREN_SUM{
        total_size := 0.0;
        root_child := root.first;
        while !xgui_box_is_nil(root_child) {
            if axis == root.child_layout_axis {
                total_size += root_child.fixed_size[xx axis];
            } else {
                total_size = max(total_size, root_child.fixed_size[xx axis]);
            }
            root.fixed_size[xx axis] = total_size;
            root_child = root_child.next;
        }
    }
}

xgui_layout_apply_constraints :: (root : *xGuiBox, axis : xAxis2) {
    overflow_allowed := root.flags & (xGuiBoxFlags.ALLOW_OVERFLOW_X<<axis);

    // enforce constraints for non-layout axis (just scale'em to match axis size)
    if root.child_layout_axis != axis && !overflow_allowed {
        child := root.first;
        while !xgui_box_is_nil(child) {
            allowed_size := root.fixed_size[xx axis];
            if !(child.flags & (xGuiBoxFlags.FIXED_X<<axis)) {
                child_size := child.fixed_size[xx axis];
                fixup_needed := (child_size - allowed_size);
                if fixup_needed > 0 {
                    child.fixed_size[xx axis] = child.fixed_size[xx axis] - fixup_needed;
                }
            }
            child = child.next;
        }
    }


    // enforce constraints for actual layout axis

    if root.child_layout_axis == axis && !overflow_allowed {
        total_allowed_size := root.fixed_size[xx axis];
        total_size := 0.0;
        total_weighed_size := 0.0;

        // find total amount of fixup needed
        child := root.first;
        child_count := 0;
        while !xgui_box_is_nil(child) {
            if !(child.flags & (xGuiBoxFlags.FIXED_X<<axis)) {
                total_size += child.fixed_size[xx axis];
                total_weighed_size += child.fixed_size[xx axis] * (1.0 - child.pref_size[xx axis].strictness);
                child_count+=1;
            }
            child = child.next;
        }

        fixup_needed := (total_size - total_allowed_size);
        if fixup_needed > 0.0 {
            child_fixups :*float= talloc(size_of(float)*child_count);
            // calc available fixup for each box
            {
                child := root.first;
                child_idx := 0;
                while !xgui_box_is_nil(child) {
                    if !(child.flags & (xGuiBoxFlags.FIXED_X<<axis)) {
                        available_fixup := child.fixed_size[xx axis] * (1.0 - child.pref_size[xx axis].strictness);
                        child_fixups[child_idx] = max(0.0, available_fixup);
                        child_idx+=1;
                    }
                    child = child.next;
                }
            }
            // take a certain amount off from each box's available fixup
            {
                child := root.first;
                child_idx := 0;
                while !xgui_box_is_nil(child) {
                    if !(child.flags & (xGuiBoxFlags.FIXED_X<<axis)) {
                        fixup_amount := (fixup_needed / total_weighed_size);
                        fixup_amount = min(1.0,max(0.0,fixup_amount));
                        child.fixed_size[xx axis] = child.fixed_size[xx axis] - child_fixups[child_idx]*fixup_amount;
                        child_idx+=1;
                    }
                    child = child.next;
                }
            }
        }

        // if box overflows (no layouting) and it has child parent_pct,
        // and it has been modified as part of layouting, it can result in 
        // parent_pct ratio that is wrong, minor thing, but we can easily fix this
        if root.flags & (xGuiBoxFlags.ALLOW_OVERFLOW_X<<axis) {
            child := root.first;
            while !xgui_box_is_nil(child) {
                child.fixed_size[xx axis] = root.fixed_size[xx axis]*child.pref_size[xx axis].value;
                child = child.next;
            }
        }

    }

    // propagate down the hierarchy
	child := root.first;
	while !xgui_box_is_nil(child) {
        xgui_layout_apply_constraints(child, axis);
		child = child.next;
	}
}




xgui_layout_calc_final_rects :: (root : *xGuiBox, axis : xAxis2) {
    // calculate rects for all childs based on parent layout axis
    layout_pos := 0.0;
	child := root.first;
	while !xgui_box_is_nil(child) {
        
        if !(child.flags & (xGuiBoxFlags.FIXED_X<<axis)) {
            child.fixed_position[xx axis] = layout_pos;
            if axis == root.child_layout_axis {
                layout_pos += child.fixed_size[xx axis];
            }
        }

        if axis == .X {
            //child.rect.x = child.fixed_position.x + root.fixed_position.x;
            child.rect.x = child.fixed_position.x + root.rect.x;
            child.rect.w = child.fixed_size.x;
        } else {
            //child.rect.y = child.fixed_position.y + root.fixed_position.y;
            child.rect.y = child.fixed_position.y + root.rect.y;
            child.rect.h = child.fixed_size.y;
        }

		child = child.next;
    }

	child = root.first;
	while !xgui_box_is_nil(child) {
        xgui_layout_calc_final_rects(child, axis);
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

xGuiChildLayoutAxisStack :: struct {
    #as using base : xGuiStack(xAxis2);
    def_value = xAxis2.X;
}
xgui_push_child_layout_axis :: (a : xAxis2) { xgui_stack_push(*g_gui_context.child_layout_axis_stack, a); }
xgui_set_next_child_layout_axis :: (a : xAxis2) { xgui_stack_push(*g_gui_context.child_layout_axis_stack, a, true); }
xgui_pop_child_layout_axis :: () -> xAxis2 { return xgui_stack_pop(*g_gui_context.child_layout_axis_stack); }
xgui_peek_child_layout_axis :: () -> xAxis2 { return xgui_stack_peek(*g_gui_context.child_layout_axis_stack); }
xgui_child_layout_axis_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.child_layout_axis_stack);}


xGuiBackgroundColorStack :: struct {
    #as using base : xGuiStack(v4);
    def_value = .{0.6,0.6,0.6,1.0};
}
xgui_push_background_color :: (c : v4) { xgui_stack_push(*g_gui_context.background_color_stack, c); }
xgui_set_next_background_color :: (c : v4) { xgui_stack_push(*g_gui_context.background_color_stack, c, true); }
xgui_pop_background_color :: () -> v4 { return xgui_stack_pop(*g_gui_context.background_color_stack); }
xgui_peek_background_color :: () -> v4 { return xgui_stack_peek(*g_gui_context.background_color_stack); }
xgui_background_color_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.background_color_stack);}

xGuiTextAlignmentStack:: struct {
    #as using base : xGuiStack(xGuiTextAlignment);
    def_value = xGuiTextAlignment.MIDDLE;
}
xgui_push_text_alignment :: (a : xGuiTextAlignment) { xgui_stack_push(*g_gui_context.text_alignment_stack, a); }
xgui_set_next_text_alignment :: (a : xGuiTextAlignment) { xgui_stack_push(*g_gui_context.text_alignment_stack, a, true); }
xgui_pop_text_alignment :: () -> xGuiTextAlignment { return xgui_stack_pop(*g_gui_context.text_alignment_stack); }
xgui_peek_text_alignment :: () -> xGuiTextAlignment { return xgui_stack_peek(*g_gui_context.text_alignment_stack); }
xgui_text_alignment_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.text_alignment_stack);}

xGuiTextColorStack :: struct {
    #as using base : xGuiStack(v4);
    def_value = .{0.95,0.95,0.95,1.0};
}
xgui_push_text_color :: (c : v4) { xgui_stack_push(*g_gui_context.text_color_stack , c); }
xgui_set_next_text_color :: (c : v4) { xgui_stack_push(*g_gui_context.text_color_stack , c, true); }
xgui_pop_text_color :: () -> v4 { return xgui_stack_pop(*g_gui_context.text_color_stack); }
xgui_peek_text_color :: () -> v4 { return xgui_stack_peek(*g_gui_context.text_color_stack); }
xgui_text_color_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.text_color_stack);}

xGuiTextSizeStack :: struct {
    #as using base : xGuiStack(v2);
    def_value = .{XFONT_DEFAULT_FONT_SIZE,XFONT_DEFAULT_FONT_SIZE};
}
xgui_push_text_size :: (s : v2) { xgui_stack_push(*g_gui_context.text_size_stack, s); }
xgui_set_next_text_size :: (s : v2) { xgui_stack_push(*g_gui_context.text_size_stack, s, true); }
xgui_pop_text_size :: () -> v2 { return xgui_stack_pop(*g_gui_context.text_size_stack); }
xgui_peek_text_size :: () -> v2 { return xgui_stack_peek(*g_gui_context.text_size_stack); }
xgui_text_size_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.text_size_stack);}

xGuiBoxRoundnessStack:: struct {
    #as using base : xGuiStack(v4);
    def_value = .{5.0,5.0,5.0,5.0};
}
xgui_push_box_roundness :: (r : v4) { xgui_stack_push(*g_gui_context.box_roundness_stack, r); }
xgui_set_next_box_roundness :: (r : v4) { xgui_stack_push(*g_gui_context.box_roundness_stack, r, true); }
xgui_pop_box_roundness :: () -> v4 { return xgui_stack_pop(*g_gui_context.box_roundness_stack); }
xgui_peek_box_roundness :: () -> v4 { return xgui_stack_peek(*g_gui_context.box_roundness_stack); }
xgui_box_roundness_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.box_roundness_stack);}

xgui_auto_pop_all_stacks :: () {
    xgui_stack_auto_pop(*g_gui_context.parent_stack);
    xgui_stack_auto_pop(*g_gui_context.fixed_x_stack);
    xgui_stack_auto_pop(*g_gui_context.fixed_y_stack);
    xgui_stack_auto_pop(*g_gui_context.fixed_width_stack);
    xgui_stack_auto_pop(*g_gui_context.fixed_height_stack);
    xgui_stack_auto_pop(*g_gui_context.pref_width_stack);
    xgui_stack_auto_pop(*g_gui_context.pref_height_stack);
    xgui_stack_auto_pop(*g_gui_context.child_layout_axis_stack);
    xgui_stack_auto_pop(*g_gui_context.background_color_stack);
    xgui_stack_auto_pop(*g_gui_context.text_alignment_stack);
    xgui_stack_auto_pop(*g_gui_context.text_color_stack);
    xgui_stack_auto_pop(*g_gui_context.text_size_stack);
    xgui_stack_auto_pop(*g_gui_context.box_roundness_stack);
}
