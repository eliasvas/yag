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
  speed : float = 1.0; 
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
