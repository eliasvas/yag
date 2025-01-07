#import "Basic";
#import "String";
#import "chaos";
#import "File";

// TODO: get a good bitmap font, like in microui, and BAKE it in font rendering code path
// TODO: instead of xeng(), do just xeng
// TODO: FIRE RENDERING!!!!! (lights will also be emmitted?!??!?!)

cube_mesh : xMesh;
sphere_mesh : xMesh;
skydome : xSkydome;

rend : xRend3D;

make_weird_tex :: ( col0 : []u8, col1 : []u8, dim : s64, cutoff : s64) -> oglTex {
  tex : oglTex;
  t := cast(*u32)alloc(dim*dim*size_of(u32));
  defer free(t);
  for y : 0..400-1 {
    for x : 0..400-1 {
      col : *u32 = *t[x + y * dim];
      if x < cutoff || y < cutoff || x + cutoff > dim || y + cutoff > dim {
        col.* = (cast(*u32)col0.data).*;
      } else {
        col.* = (cast(*u32)col1.data).*;
      }
    }
  }
  ogl_tex_init(*tex, .{cast(float)dim,cast(float)dim}, xx t, oglTexFormat.RGBA8U);
  return tex;
}

main :: () {
  xeng_init();

  white_img:oglTex; white := u8.[ 0xFF,0xFF,0xFF,0xFF ]; ogl_tex_init(*white_img, .{1,1}, white.data, oglTexFormat.RGBA8U);

  blue_img:oglTex; blue := u8.[ 0x00,0x00,0xFF,0xFF ]; ogl_tex_init(*blue_img, .{1,1}, blue.data, oglTexFormat.RGBA8U);
  green_img:oglTex; green := u8.[ 0x00,0xFF,0x00,0xFF ]; ogl_tex_init(*green_img, .{1,1}, green.data, oglTexFormat.RGBA8U);

  trans_red_img : oglTex; trans_red := u8.[ 0xFF,0x00,0x00,0x7F ]; ogl_tex_init(*trans_red_img, .{1,1}, trans_red.data, oglTexFormat.RGBA8U);

  diff_img := make_weird_tex(u8.[ 0xFF,0x3F,0x3F,0xFF ],u8.[ 0x3F,0x3F,0x3F,0xFF ], 400, 50);
  spec_img := make_weird_tex(u8.[ 0xFF,0xFF,0xFF,0xFF ],u8.[ 0x00,0x00,0x00,0x00 ], 400, 50);


  xr3d_init(*rend);

  // gltf loading tests
  //sample_gltf_mesh := xgltf_parse_mesh(SAMPLE_JSON);
  //gltf_path := "../assets/glTF-Sample-Models/2.0/BoxAnimated/glTF-Embedded/BoxAnimated.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/CesiumMan/glTF-Embedded/CesiumMan.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/RiggedFigure/glTF-Embedded/RiggedFigure.gltf";
  gltf_path := "../assets/glTF-Sample-Models/2.0/BrainStem/glTF-Embedded/BrainStem.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/RiggedSimple/glTF-Embedded/RiggedSimple.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/BoxTextured/glTF-Embedded/BoxTextured.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/Box/glTF-Embedded/Box.gltf";
  file_content, succ := read_entire_file(gltf_path);
  assert(succ);
  normalize_line_endings(*file_content);

  sample_gltf_meshes := xgltf_parse_meshes(file_content);

  sample_gltf_animations := xgltf_parse_animations(file_content, sample_gltf_meshes.data);


  // FIXME: Context has been DEPRECATED! we should find a new way to do this, the new Jai way I guess
  //sample_timer_cb :: (retries : u32, usr_ctx : *void) {print("cb triggered!\n");}
  //t := xtimer_make(100, 5, sample_timer_cb, null);

  skydome = xskydome_make();
  cube_mesh = xmesh_gen_cube();
  sphere_mesh = xmesh_gen_sphere(1.0, 64,64);

  while true {
    xeng_frame_init();
    if (xim_kkey_pressed(.SC_ESCAPE)) exit(1);


    for *sample_gltf_mesh : sample_gltf_meshes {
      xmesh_skin_reset_matrices(*sample_gltf_mesh.skin);
    }
    for *anim : sample_gltf_animations {
      xmesh_animation_simulate(anim);
    }
    for *mesh : sample_gltf_meshes {
      xmesh_skin_calc_global_transform(*mesh.skin, xmesh_skin_find_root_joint_id(*mesh.skin));
    }

    // Do the CSM ImGui menu
    ImGui.Begin("CSM");
    ImGui.SliderFloat3("light dir", xx *xeng().dir_light.dl.dir, -1.0, 1.0);
    xeng().dir_light.dl.dir = v3_norm(xeng().dir_light.dl.dir);
    ImGui.SliderInt("cascade count",xx *xeng().csm_data.cascade_count, 1, 4);
    ImGui.SliderFloat("zMult factor", xx *xeng().csm_data.z_mult, 1.0, 10.0);
    ImGui.Checkbox("Shadows enabled", *xeng().csm_data.enabled);
    ImGui.Checkbox("CSM debug draw", *xeng().csm_data.debug_draw);
    ImGui.Checkbox("CSM debug frustum", *xeng().csm_data.debug_frustum);
    fps := 1.0/(xeng().dt);
    frame_str := tprint("fps: %\0", fps);
    ImGui.TextUnformatted(frame_str.data);
    ImGui.End();

    big_cube_mat := xPBR_Material.{*green_img,*white_img, null, null, null, null};
    big_model := m4_mult(m4_trans(.{0,-2,0}),m4_scale(.{100,1,100}));
    cube_mesh.primitives[0].material = big_cube_mat;
    xr3d_push_bundle(*rend, cube_mesh, big_model);

    sphere_mat := xPBR_Material.{*blue_img,*white_img, null, null, null, null};
    sphere_mesh.primitives[0].material = sphere_mat;
    //xr3d_push_bundle(*rend, sphere_mesh, m4_trans(.{3,3,0}));


    // render the json mesh!!
    for sample_gltf_mesh : sample_gltf_meshes {
      model := xgltf_transform_calc_matrix(*sample_gltf_mesh.transform);
      xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_trans(.{0,0,-10}), model));
      //xr3d_push_bundle(*rend, *sample_gltf_mesh, model);
    }


    if xeng().csm_data.enabled {
      xr3d_do_shadow_pass(*rend);
    }else {
      ogl_rt_clear(*rend.shadow_rt);
    }
    xr3d_do_g_pass(*rend);
    xr3d_do_def_pass(*rend); 
    xr3d_do_copy_depth_from_g_buf_to_d0(*rend);
    xr3d_clear_bundles(*rend);
    // do 'transparent' pass
    xskydome_render(*skydome);

    xeng_frame_end();
  }

}
