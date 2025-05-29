#import "chaos";

#import "File";
#import "File_Utilities";
#import "stb_image";

// these guys need to Go Go
skydome : xSkydome;
grid : xGrid;
rend : xRend3D;

main :: () {
  xeng_init();
  grid = xgrid_make();
  xr3d_init(*rend);

  // gltf loading tests
  //gltf_path := "../assets/glTF-Sample-Models/2.0/CesiumMan/glTF-Embedded/CesiumMan.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/NormalTangentTest/glTF/NormalTangentTest.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/NormalTangentMirrorTest/glTF/NormalTangentMirrorTest.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/WaterBottle/glTF/WaterBottle.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/DamagedHelmet/glTF/DamagedHelmet.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/SciFiHelmet/glTF/SciFiHelmet.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/BoomBox/glTF/BoomBox.gltf";
  gltf_path := "../assets/glTF-Sample-Models/2.0/MetalRoughSpheres/glTF/MetalRoughSpheres.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/OrientationTest/glTF/OrientationTest.gltf";
  //gltf_path := "../assets/glTF-Sample-Models/2.0/BrainStem/glTF-Embedded/BrainStem.gltf";
  sample_gltf_meshes := xgltf_parse_meshes(gltf_path);
  sample_gltf_animations := xgltf_parse_animations(gltf_path, sample_gltf_meshes.data);

  cube_mesh := xmesh_gen_cube();
  sphere_mesh := xmesh_gen_sphere(1.0, 64,64);

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
      if xmesh_has_skin(mesh) {
        xmesh_skin_calc_global_transform(*mesh.skin, xmesh_skin_find_root_joint_id(*mesh.skin));
      }
    }

    /*
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
    */


    // render the json mesh!!
    for sample_gltf_mesh : sample_gltf_meshes {
      model := xgltf_transform_calc_matrix(*sample_gltf_mesh.transform);
      //xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_trans(.{0,2,-10}), model));
      //xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_scale(.{20,20,20}), model));
      //xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_rotate(xx seconds_since_init(), .{0,1,0}),m4_mult(m4_rotate(-3.14/2.0, .{1,0,0}), model)));
      xr3d_push_bundle(*rend, *sample_gltf_mesh, m4_mult(m4_rotate(0, .{0,1,0}),m4_mult(m4_rotate(3.14/2.0, .{1,0,0}), model)));
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
    //xgrid_render(*grid);
    xhdr_skybox_render(*rend.hdr_skybox);


    xeng_frame_end();
  }

}

texture_load :: (path : string) -> oglTex {
  tex : oglTex;
  png_data := read_entire_file(path);
  assert(png_data.count > 0);
  tex_w, tex_h, channels : s32;
  //stbi_set_flip_vertically_on_load(1);
  raw_image_data := stbi_load_from_memory(png_data.data, cast(s32)png_data.count, *tex_w, *tex_h, *channels, 4);
  ogl_tex_init(*tex, .{cast(float)tex_w,cast(float)tex_h}, xx raw_image_data, oglTexFormat.RGBA8U);
  assert(tex.dim.x > 0);
  assert(tex.dim.y > 0);
  return tex;
}
