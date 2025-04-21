
xgui_update_hot_active_for_box :: (gctx : *xGuiContext, box : *xGuiBox) -> bool {
	box_pressed : bool = false;

	id := box.id;
	mp := xim_get_mouse_pos();
	lmb_pressed := xim_mkey_pressed(.LMB);
	lmb_released := xim_mkey_released(.LMB);

    anim_dt := cast(float)xeng().dt;
    fast_rate := 1.0 - pow(2, -50.0 * anim_dt);

    if box.flags & .FOCUS_HOT {
        if rect_isect(box.rect, mp) then gctx.hot = id;
        is_hot := g_gui_context.hot == box.id;
        box.hot_t += fast_rate * ((cast(float)is_hot) - box.hot_t);
    }
    if box.flags & .FOCUS_ACTIVE {
        if gctx.hot == id && lmb_pressed then gctx.active = id;
        is_active := g_gui_context.active == box.id;
        box.active_t += fast_rate * (cast(float)is_active - box.active_t);
    }

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

xGuiComm :: struct {
	box : *xGuiBox;
	pressed : bool;
	released: bool;
	// .....
}
xgui_button :: (label: string) -> xGuiComm {
	box := xgui_box_make(label,
		xGuiBoxFlags.MOUSE_CLICKABLE | 
		xGuiBoxFlags.FOCUS_HOT | 
		xGuiBoxFlags.FOCUS_ACTIVE | 
		xGuiBoxFlags.DRAW_TEXT | 
		xGuiBoxFlags.DRAW_BACKGROUND | 
		xGuiBoxFlags.DRAW_BORDER
	);

	pressed : bool = false;
	if box.flags & xGuiBoxFlags.MOUSE_CLICKABLE {
        pressed = xgui_update_hot_active_for_box(*g_gui_context, box);
        box.color = xgui_get_box_color(box, box.color);
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
