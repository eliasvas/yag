xGuiID :: u64;
XGUI_INVALID_ID :: 666; // TODO: nil struct for guiBox's ID?

// TODO: produce ID with format string 
xgui_id :: (s : string) -> xGuiID {
	return djb2(s);
}