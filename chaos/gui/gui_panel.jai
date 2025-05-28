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

  label : string;
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
      child_dim := v2.{
                ifx axis == .X then parent_dim.x else 0, 
                ifx axis == .Y then parent_dim.y else 0
            } * child.percent_of_parent;
      running_pos = running_pos + child_dim;

      child = child.next;
    }
    r = .{running_pos.x, running_pos.y, parent_dim.x * ifx axis == .X then panel.percent_of_parent else 1.0, parent_dim.y * ifx axis == .Y then panel.percent_of_parent else 1.0 };
  }
  return r;
}

xgui_panel_get_rect :: (panel : *xGuiPanel, root_rect : Rect) -> Rect {
    rect := g_gui_context.root.rect;

    itr := panel;
    while itr != null && itr.parent != null {
      xgui_push_panel_walk_node(.{itr, itr.parent}); 
      itr = itr.parent;
    }

    while !xgui_panel_walk_node_empty() {
        walk_node := xgui_pop_panel_walk_node();
        rect = xgui_panel_get_rect_from_parent_rect(walk_node.child, rect);
    }

    return rect;
}

xGuiPanelWalkNode :: struct {
  child : *xGuiPanel;
  parent : *xGuiPanel;
}
xGuiPanelWalkNodeStack :: struct {
    #as using base : xGuiStack(xGuiPanelWalkNode);
    def_value = .{null, null};
}
xgui_push_panel_walk_node :: (n : xGuiPanelWalkNode) { xgui_stack_push(*g_gui_context.panel_walk_node_stack, n); }
xgui_set_next_panel_walk_node :: (n : xGuiPanelWalkNode) { xgui_stack_push(*g_gui_context.panel_walk_node_stack, n, true); }
xgui_pop_panel_walk_node :: () -> xGuiPanelWalkNode { return xgui_stack_pop(*g_gui_context.panel_walk_node_stack); }
xgui_peek_panel_walk_node :: () -> xGuiPanelWalkNode { return xgui_stack_peek(*g_gui_context.panel_walk_node_stack); }
xgui_panel_walk_node_empty :: () -> bool {return xgui_stack_empty(*g_gui_context.panel_walk_node_stack);}


xgui_panel_do_layouting_for_panels_and_boundaries :: (root_panel : *xGuiPanel, root_rect : Rect) {
    BND_THICK :: 2; //BOUNDARY THICKNESS

    // Build non-leaf panel UI (drag boundaries!!)
    itr := xGuiPanelItr.{root_panel, 0, 0};
    while itr.next != null {
        panel := itr.next;
        // 1. Find panel rect
        r : Rect = xgui_panel_get_rect(panel, root_rect);

        // 2. loop through every child that has a sibling next to it - otherwise no boundary
        child := panel.first;
        while child != null && child.next != null {
          child_rect := xgui_panel_get_rect(child, root_rect);

          // 3. Calculate boundary rect and make a FIXED guiBox
          boundary_rect := child_rect;
          if panel.split_axis == .X {
            boundary_rect.x += child_rect.w - BND_THICK*2;
            boundary_rect.w = BND_THICK*4;
          } else {
            boundary_rect.y += child_rect.h - BND_THICK*2;
            boundary_rect.h = BND_THICK*4;
          }
          xgui_set_next_fixed_x(boundary_rect.x);
          xgui_set_next_fixed_y(boundary_rect.y);
          xgui_set_next_fixed_width(boundary_rect.w);
          xgui_set_next_fixed_height(boundary_rect.h);
          xgui_set_next_child_layout_axis(.Y);
          xgui_set_next_background_color(.{0.1,0.9,0.9,0.9});
          name := tprint("drag_boundary_%", child.label); // this is bad :( :( lewhy

          boundary_button := xgui_button(name);
          boundary_button.box.flags &= ~.DRAW_BORDER;
          boundary_button.box.flags &= ~.DRAW_TEXT;
          boundary_button.box.flags &= ~.TRUNC_TEXT;
          boundary_button.box.rect = boundary_rect;

          // 4. Move boundaries BADLY
          if g_gui_context.active == boundary_button.box.id {

            // very experimental ////
            xwin_set_cursor(*g_engine.win, ifx child.split_axis == .X then xWindowCursorKind.NORTH_SOUTH else xWindowCursorKind.WEST_EAST);
            /////////////////////////

            // ALSO very very experimental!
            delta : v2 = xim_get_mouse_delta();
            delta_split_axis := delta[xx panel.split_axis];
            left_child := child;
            right_child := child.next;

            percent_of_parent_movement := (delta_split_axis) * cast(float)xeng().dt * 0.10;
            left_child.percent_of_parent += percent_of_parent_movement;
            right_child.percent_of_parent -= percent_of_parent_movement;
            /////////////////////////
          }

          child = child.next;
        }

        itr = xgui_panel_traverse_depth_first_pre_order(panel);
    }

    // Build leaf panel UI
    itr = xGuiPanelItr.{root_panel, 0, 0};
    while itr.next != null {
        panel := itr.next;
        // 1. find panel rect
        r : Rect = xgui_panel_get_rect(panel, root_rect);

        // 2. if its a leaf, make a Fixed guiBox!
        if panel.first == null {
            xgui_set_next_fixed_x(r.x + BND_THICK);
            xgui_set_next_fixed_y(r.y + BND_THICK);
            xgui_set_next_fixed_width(r.w - BND_THICK*2);
            xgui_set_next_fixed_height(r.h - BND_THICK*2);
            xgui_set_next_child_layout_axis(.Y);
            xgui_set_next_background_color(.{0.2,0.2,0.2,0.9});
            xgui_set_next_box_roundness(.{2,2,2,2});
            name := tprint("panel_%", panel.label); // this is bad :( :( lewhy
            panel_box := xgui_pane(name);
            panel_box.box.flags |= .DRAW_BORDER;
            //print("panel: % from %\n\n\n", name, panel_box.box.*);
            panel_box.box.rect = r;
        } 
        
        itr = xgui_panel_traverse_depth_first_pre_order(panel);
    }


}
