//////////////////////////////
// GUI boxes

xAxis2 :: enum {
	X;
	Y;
}

xGuiSizeKind :: enum {
	//NULL;	 // maybe we should justuse the pref size even in fixed size widgets like root
	PIXELS;
	TEXT_CONTENT;
	PARENT_PCT;
	CHILDREN_SUM;
}
xGuiSize :: struct {
	kind : xGuiSizeKind;
	value : float;
	strictness : float;
}

xGuiBoxFlags :: enum_flags u32{
	// input
    MOUSE_CLICKABLE  :: (1 << 0);
    FOCUS_HOT        :: (1 << 1);
    FOCUS_ACTIVE     :: (1 << 2);
    SCROLL           :: (1 << 3);
    DISABLED         :: (1 << 4);
    // drawing / animation
    FIXED_WIDTH      :: (1 << 5);
    FIXED_HEIGHT     :: (1 << 6);
    FIXED_X          :: (1 << 7);
    FIXED_Y          :: (1 << 8);
    ALLOW_OVERFLOW_X :: (1 << 9);
    ALLOW_OVERFLOW_Y :: (1 << 10);
    // layout
    DRAW_BACKGROUND  :: (1 << 11);
    DRAW_BORDER      :: (1 << 12);
    DRAW_TEXT        :: (1 << 13);
    CLIP             :: (1 << 14);
}

xGuiBox :: struct {
	// tree links
	first : *xGuiBox;
	last : *xGuiBox;
	next : *xGuiBox;
	prev : *xGuiBox;
	parent : *xGuiBox;

	// hash links
	hash_next : *xGuiBox;
	hash_prev : *xGuiBox;

	// keying stuff
	id : xGuiID;
	str : string;

	// position stuff
	fixed_position : v2;
	fixed_size : v2;
	pref_size : [2]xGuiSize;
	child_layout_axis : xAxis2;
	rect : Rect;

	// persistent stuff 
	hot_t : float;
	active_t : float;

	// other data
	flags : xGuiBoxFlags;
	text_padding : float;
	font_size : float;
	transparency : float;
	last_used_frame_index : u64;
    color : v4;
}

// our nil struct for g_gui_boxes
g_gui_box : xGuiBox;
#run {
    g_gui_box.first = *g_gui_box;
    g_gui_box.last = *g_gui_box;
    g_gui_box.next = *g_gui_box;
    g_gui_box.prev = *g_gui_box;
    g_gui_box.parent = *g_gui_box;
}

xGuiBoxHashSlot :: struct {
	hash_first : *xGuiBox;	
	hash_last : *xGuiBox;	
}

xgui_box_is_nil :: (box : *xGuiBox) -> bool {
    return (box == null || box == *g_gui_box);
}

// TODO: maybe here we should use the nil struct, not sure I even wanna use it altogether tbh
xgui_box_clear_treelinks :: (box : *xGuiBox) {
    box.first  = null;
    box.last   = null;
    box.next   = null;
    box.prev   = null;
    box.parent = null;
}


xgui_box_make :: (label : string, flags : xGuiBoxFlags) -> *xGuiBox {
	id := xgui_id(label);
	box : *xGuiBox = null;
	// search for a box with the same id on the map, if found, we just use this one!
	for slot : g_gui_context.slots {
		node := slot.hash_first;
		while node != null {
			if node.id == id {
				box = node;
				break;
			}
			node = node.hash_next;
		}
	}
	// if not found make the node (either alloc or from freelist) and insert to map
	if box == null {
	    popped := g_gui_context.freelist;
	    if popped != null {
			g_gui_context.freelist = sll_stack_pop(g_gui_context.freelist);
			box = popped;
	    } else {
			a: Allocator; a.proc = xarena_allocator_proc; a.data = *g_gui_context.persistent_arena;
			box = New(xGuiBox,, a);
	    }
	    box.id = id;
	    box.str = label;
	    box.flags = flags;
	    slot_to_insert := id % xGuiContext.SLOT_COUNT;
	    // insert to map
		g_gui_context.slots[slot_to_insert].hash_first,g_gui_context.slots[slot_to_insert].hash_last = dll_push_back(g_gui_context.slots[slot_to_insert].hash_first,g_gui_context.slots[slot_to_insert].hash_last, box);
	}
    xgui_box_clear_treelinks(box); // this should probably happen at cleanup/prune step? maaaaaaybe
    box.child_layout_axis = xgui_peek_child_layout_axis();
    box.parent = xgui_peek_parent();
    box.color = xgui_peek_background_color();

    // insert the box to the parent hierarchy
    box.parent.first, box.parent.last = dll_push_back(box.parent.first, box.parent.last, box);
	
    // assign fixed/preferred widths heights and maybe fixed positions (for pinned stuff)
    if !xgui_fixed_x_empty() {
        box.fixed_position[xx xAxis2.X] = xgui_peek_fixed_x();
        box.flags |= .FIXED_X;
    }
    if !xgui_fixed_y_empty() {
        box.fixed_position[xx xAxis2.Y] = xgui_peek_fixed_y();
        box.flags |= .FIXED_Y;
    }
    if !xgui_fixed_width_empty() {
        box.fixed_size[xx xAxis2.X] = xgui_peek_fixed_width();
        box.flags |= .FIXED_WIDTH;
    } else {
        box.pref_size[xx xAxis2.X] = xgui_peek_pref_width();
    } 
    if !xgui_fixed_height_empty() {
        box.fixed_size[xx xAxis2.Y] = xgui_peek_fixed_height();
        box.flags |= .FIXED_HEIGHT;
    } else {
        box.pref_size[xx xAxis2.Y] = xgui_peek_pref_height();
    } 



	//print("box returned at address: %\n", box);
	box.last_used_frame_index = g_gui_context.frame_index;

    xgui_auto_pop_all_stacks();
	return box;
}


