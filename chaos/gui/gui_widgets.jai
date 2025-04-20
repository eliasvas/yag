
xGuiComm :: struct {
	box : *xGuiBox;
	pressed : bool;
	released: bool;
	// .....
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
        box.color = xgui_get_widget_color(box.id, box.color);
	}

	return .{box, pressed, false};
}

xgui_pane :: (label: string) -> xGuiComm {
	box := xgui_box_make(label,
		xGuiBoxFlags.DRAW_BACKGROUND | 
		xGuiBoxFlags.DRAW_BORDER
	);

	return .{box, false, false};
}

xgui_spacer :: (size : xGuiSize) -> xGuiComm {
    parent := xgui_peek_parent();

    if parent.child_layout_axis == .X {
        xgui_set_next_pref_width(size);
    } else {
        xgui_set_next_pref_height(size);
    }

	box := xgui_box_make("",0);

	return .{box, false, false};
}
