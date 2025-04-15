
xGuiComm :: struct {
	box : *xGuiBox;
	pressed : bool;
	released: bool;
	// .....
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
	// insert to hierarchy (TODO)
	// parent := gui_pop_parent();
	g_gui_context.root = box; // what the fuck is even this

	//print("box returned at address: %\n", box);

	// DELETEME
	if xim_mkey_up(.MMB) then box.last_used_frame_index = g_gui_context.frame_index;

	return box;
}

xgui_button :: (label: string) -> xGuiComm {
	box := xgui_box_make(label,
		xGuiBoxFlags.MOUSE_CLICKABLE | 
		xGuiBoxFlags.DRAW_TEXT | 
		xGuiBoxFlags.DRAW_BACKGROUND | 
		xGuiBoxFlags.DRAW_BORDER
	);

	pressed : bool = false;
	if box.flags & xGuiBoxFlags.MOUSE_CLICKABLE {
		pressed = xgui_update_hot_active_for_box(*g_gui_context, box);
	}

	return .{box, pressed, false};
}
