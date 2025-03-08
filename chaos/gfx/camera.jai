///////////////////////////////
// Camera 3D
///////////////////////////////

xCamMode :: enum {
  DYNAMIC;
  STATIC;
  //@TODO: Should we make a RotateAroundOrigin mode? for the viewer..
}

xCam :: struct {
  mode : xCamMode = .DYNAMIC;
  pos      : v3 = .{0,0,0};
  front    : v3 = .{0,0,-1};
  up       : v3;
  right    : v3;
  world_up : v3 = .{0,1,0};
  yaw : float = -90.0;
  pitch : float;
  speed : float = 20.0; 
  mouse_sens : float = 0.15;
}

xcam_get_view_mat :: (cam : *xCam) -> m4 {
  return m4_look_at(cam.pos, cam.pos + cam.front, cam.up);
}

xcam_update :: (cam : *xCam, dt : float) {
  using cam;
  // Update all camera vectors
  front.x = cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch));
  front.y = sin(deg_to_rad(pitch));
  front.z = sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch));
  right = v3_norm(v3_cross(front, world_up));
  up = v3_norm(v3_cross(right, front));
  // Move the camera around
  if mode == {
    case .DYNAMIC;
      if xim_kkey_down(.SC_W) then pos += front * speed * dt;
      if xim_kkey_down(.SC_A) then pos -= v3_norm(v3_cross(front, up)) * speed * dt;
      if xim_kkey_down(.SC_S) then pos -= front * speed * dt;
      if xim_kkey_down(.SC_D) then pos += v3_norm(v3_cross(front, up)) * speed * dt;
    case .STATIC;
    case;
  }
  // Misc camera controls
  if xim_mkey_down(.RMB) && xim_mkey_down(.LMB) {
    mouse_delta := xim_get_mouse_delta();
    pos += right * mouse_delta.x * speed * dt;
    pos += up * -mouse_delta.y * speed * dt;
  }else if xim_mkey_down(.RMB) {
    mouse_delta := xim_get_mouse_delta();
    yaw += mouse_sens * mouse_delta.x;
    pitch += mouse_sens * mouse_delta.y;
    if (pitch > 89.0) then pitch = 89.0;
    if (pitch < -89.0) then pitch = -89.0;
  }
}



///////////////////////////////
// Camera 2D
///////////////////////////////

xCamera2D :: struct {
  target : v2;    // point the camera is following
  offset : v2;    // where tha camera is centered (e.g middle of screen)
  rot    : float; // rotation in degrees
  zoom   : float; // zoom
}
/*
  This is a simple CPU-based camera, we provide functions to transform to the various spaces, namely:
  - World-Space: the world coordinates of the sprites, could be anywhere depending on game/world representation
  - Screen-Space: the actual coordinates in the screen that world coordinates map to
  - NDC-Space: same as screen coords only stretched to fit Normalized Device Coordinates for ogl, can easily be modified for any graphics API / layer 

  The concept is you can transform sprite's 2D world coordinated to actual NDC coordinates so there are no matrix calculations GPU side,
  theoretically an API as simple as this can drive both UI and regular sprite rendering by placing the camera correctly.
*/

world_to_screen :: (wcoords : v2, c : *xCamera2D) ->v2 {
  coords := wcoords;
  // translation
  coords -= v2.{c.target.x, c.target.y};
  // rotation
  coords = v2_rotate(coords, c.rot);
  // scale
  coords *= c.zoom;
  // offset
  coords += v2.{c.offset.x, c.offset.y};
  return coords;
}

screen_to_world :: (scoords : v2, c : *xCamera2D) ->v2 {
  coords := scoords;
  // revert offset
  coords -= v2.{c.offset.x, c.offset.y};
  // revert scale 
  assert(c.zoom != 0.0);
  coords /= c.zoom;
  // revert rotation
  coords = v2_rotate(coords, -c.rot);
  // revert translation 
  coords += v2.{c.target.x, c.target.y};

  return coords;
}

// NOTE: for clipping we should probably use ogl.. or something
// NOTE: to use this for arbitrary 'viewports' we should provide start_x's start_y's
screen_to_ndc :: (scoords : v2, windim : v2) -> v2 {
  coords := ((scoords / windim) - 0.5)*2.0;
  coords.y *= -1.0; // because origin is the top left corner
  return coords;
}

ndc_to_screen :: (ncoords : v2, windim : v2) -> v2 {
  coords := (v2.{ncoords.x, -ncoords.y} / 2.0) + 0.5;
  coords *= windim;
  return coords;
}

apply_camera_transform :: world_to_screen;
apply_projection_transform :: screen_to_ndc;

// TODO: add some more tests..
#run {
  almost_equal :: (f0: float, f1: float, epsilon := 0.1) -> bool { return abs(f0-f1) <= epsilon; }
  almost_equal :: (f0: v2, f1: v2, epsilon := 0.1) -> bool { return almost_equal(f0.x, f1.x, epsilon) && almost_equal(f0.y, f1.y, epsilon); }

  {
    cam := xCamera2D.{
      target = v2.{20,0},
      rot = 0,
      zoom = 1.2,
      offset = v2.{400,400},
    };
    sample_screen_pos := v2.{100,100};
    world := screen_to_world(sample_screen_pos, *cam);
    //print("screen [%] -> world [%]\n", sample_screen_pos, world);
    screen := world_to_screen(world, *cam);
    //print("world [%] -> screen [%]\n", world, screen);
    assert(almost_equal(sample_screen_pos, screen));
  }

  {
    cam := xCamera2D.{
      target = v2.{23,123},
      rot = 88.0,
      zoom = 0.4,
      offset = v2.{100,400},
    };
    windim := v2.{400,400};
    sample_screen_pos := v2.{100,100};
    ndc := screen_to_ndc(sample_screen_pos, windim);
    //print("screen [%] -> ndc [%]\n", sample_screen_pos, ndc);
    screen := ndc_to_screen(ndc, windim);
    //print("ndc [%] -> screen [%]\n", ndc, screen);
    assert(almost_equal(sample_screen_pos, screen));
  }
}

/*
// This is the old way of doing stuff with matrices, we decided not to because of computational complexity

// projection matrix transforms from screen space to NDC (e.g [-1,1] for XYZ)
get_projection_matrix :: (using c : *xCamera2D, windim : v2) -> m4 {
  return m4_ortho(0,windim.x, windim.y, 0, -1, 1);
}
 
// camera matrix transforms from world to screen (e.g {0,0,800,600})
get_camera_matrix :: (using c : *xCamera2D) -> m4 {
  camera_matrix : m4 = m4_I;

  translation_mat := m4_trans(v3.{-target.x, -target.y,0});
  rotation_mat := m4_rotate(rot, v3.{0,0,1});
  scale_mat := m4_scale(v3.{zoom,zoom,1});
  offset_mat := m4_trans(v3.{offset.x, offset.y,0});

  return m4_mult(offset_mat,m4_mult(scale_mat,m4_mult(rotation_mat,translation_mat)));
}
screen_to_world :: (using c : *xCamera2D, screen_pos : v2) -> v2 {
  world_pos := m4_multv(m4_inverse(get_camera_matrix(c)), v4.{screen_pos.x, screen_pos.y, 0, 1});
  return v2.{world_pos.x, world_pos.y};
}

world_to_screen :: (using c : *xCamera2D, world_pos : v2) -> v2 {
  screen_pos := m4_multv(get_camera_matrix(c), v4.{world_pos.x, world_pos.y, 0, 1});
  return v2.{screen_pos.x, screen_pos.y};
}
*/