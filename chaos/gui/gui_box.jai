//////////////////////////////
// GUI boxes

xAxis2 :: enum {
	X;
	Y;
	COUNT;
}

xGuiSizeKind :: enum {
	NULL;	
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
    FLOATING_X       :: (1 << 7);
    FLOATING_Y       :: (1 << 8);
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
	pref_size : [xAxis2.COUNT]xGuiSize;
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

	srnode : *xGuiBox;
}

/*
// our nil struct for g_gui_boxes
g_gui_box : xGuiBox;
#run {
	g_gui_box.srnode = *g_gui_box;
}
*/

xGuiBoxHashSlot :: struct {
	hash_first : *xGuiBox;	
	hash_last : *xGuiBox;	
}