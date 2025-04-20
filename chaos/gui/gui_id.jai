xGuiID :: u64;
XGUI_INVALID_ID :: 666; // TODO: nil struct for guiBox's ID?

// TODO: produce ID with format string 
xgui_id :: (s : string) -> xGuiID {
	return ifx s.count == 0 then 0 else djb2(s);
}
