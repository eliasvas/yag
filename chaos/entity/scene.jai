xResourceManager :: struct {
  // TODO
  res_type : int;
}

xGameScene :: struct {
  name : string;
  entities : xEntityStorage;
  resources : xResourceManager;
  pool : Flat_Pool; // ALL our memory will come from here, at scene deinit we dealloc the whole pool!
}

xgame_scene_init_from_file :: (filename : string) -> *xGameScene {
  return New(xGameScene);
}