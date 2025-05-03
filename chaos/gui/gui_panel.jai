// A window managed panel
xGuiPanel :: struct {
	// tree links
	first : *xGuiPanel;
	last : *xGuiPanel;
	next : *xGuiPanel;
	prev : *xGuiPanel;
	parent : *xGuiPanel;

	percent_of_parent : float;
	split_axis : xAxis2;
};

xGuiPanelItr :: struct {
	next : *xGuiPanel;
	push_count : s32;
	pop_count : s32;
}

xgui_panel_traverse_depth_first_pre_order :: (panel : *xGuiPanel) -> xGuiPanelItr {
	itr := xGuiPanelItr.{};

	// we go 'down' the hierarchy by 1
	if panel.first != null {
		itr.next = panel.first;
		itr.push_count = 1;
	} else { // we go 'up' the hierarchy
		p := panel;
		while p != null {
			if p.next != null {
				//itr.next = p.next;
				itr.next = p.next;
				break;
			}
			itr.pop_count+=1;
			p = p.parent;
		}
	}
	return itr;
}

xgui_panel_get_rect_from_parent_rect :: (panel : *xGuiPanel, parent_rect : Rect) -> Rect {
	r : Rect = parent_rect;
	parent := panel.parent;
	if parent != null {
		parent_dim := v2.{parent_rect.w, parent_rect.h};
		axis := parent.split_axis;

		child := parent.first;
		running_pos := v2.{r.x,r.y};
		while child != null && child != panel {
			child_dim := v2.{ifx axis == .X then parent_dim.x else 0, ifx axis == .Y then parent_dim.y else 0} * child.percent_of_parent;
			running_pos = running_pos + child_dim;

			child = child.next;
		}
		r = .{running_pos.x, running_pos.y, parent_dim.x * ifx axis == .X then panel.percent_of_parent else 1.0, parent_dim.y * ifx axis == .Y then panel.percent_of_parent else 1.0 };
	}
	return r;
}

xGuiPanelRectNode :: struct {
	panel : *xGuiPanel;
	r : Rect;
}
xGuiPanelRectNodeStack :: struct {
    #as using base : xGuiStack(xGuiPanelRectNode);
    def_value = .{null, .{0,0,600,400}};
}
xgui_push_panel_rect_node :: (n : xGuiPanelRectNode) { xgui_stack_push(*g_gui_context.panel_rect_node_stack, n); }
xgui_set_next_panel_rect_node :: (n : xGuiPanelRectNode) { xgui_stack_push(*g_gui_context.panel_rect_node_stack, n, true); }
xgui_pop_panel_rect_node :: () -> xGuiPanelRectNode { return xgui_stack_pop(*g_gui_context.panel_rect_node_stack); }
xgui_peek_panel_rect_node :: () -> xGuiPanelRectNode { return xgui_stack_peek(*g_gui_context.panel_rect_node_stack); }
xgui_panel_rect_node_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.panel_rect_node_stack);}

