#import "Basic";
#import "String";
#import "chaos";
// TODO: A nice debug drawing API for points/lines/triangles, no textures only wire/solid!

my_win : xWindow;
bp_sp : oglSP;
light_sp : oglSP;
white_img : oglTex;

main :: () {
    c : xCam;
    viewport: v4 = .{0,0,1280,720};

    assert(xwin_init(*my_win, "chaos", viewport.width, viewport.height, xWindowFlags.RESIZABLE));
    ogl_init();

    white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
    ogl_tex_init(*white_img, .{1,1}, white.data, oglTexFormat.RGBA8U);

    cutoff := 50;
    // generate diffuse and specular textures
    diff_img : oglTex;
    diffuse_tex := cast(*u32)alloc(400*400*size_of(u32)); 
    defer free(diffuse_tex);
    for y : 0..400-1 {
      for x : 0..400-1 {
        c1 := u8.[ 0xFF,0x3F,0x3F,0xFF ];
        c2 := u8.[ 0x3F,0x3F,0x3F,0xFF ];
        col : *u32 = *diffuse_tex[x + y * 400];
        if x < cutoff || y < cutoff || x + cutoff > 400 || y + cutoff > 400 {
          col.* = (cast(*u32)c1.data).*;
        } else {
          col.* = (cast(*u32)c2.data).*;
        }
      }
    }
    ogl_tex_init(*diff_img, .{400,400}, xx diffuse_tex, oglTexFormat.RGBA8U);
    // generate specular texture
    spec_img : oglTex;
    spec_tex := cast(*u32)alloc(400*400*size_of(u32)); 
    defer free(spec_tex);
    for y : 0..400-1 {
      for x : 0..400-1 {
        white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
        grey := u8.[ 0x00,0x00,0x00,0x00 ];
        col : *u32 = *spec_tex[x + y * 400];
        if x < cutoff || y < cutoff || x + cutoff > 400 || y + cutoff > 400 {
          col.* = (cast(*u32)white.data).*;
        } else {
          col.* = (cast(*u32)grey.data).*;
        }
      }
    }
    ogl_tex_init(*spec_img, .{400,400}, xx spec_tex, oglTexFormat.RGBA8U);





    // create Blinn-Phong Shader
    ogl_sp_init(*bp_sp, BP_VERT_SHADER, BP_FRAG_SHADER);
    ogl_sp_add_attrib(*bp_sp, ogl_attrib_make(0,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code pos),false));
    ogl_sp_add_attrib(*bp_sp, ogl_attrib_make(1,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code norm),false));
    ogl_sp_add_attrib(*bp_sp, ogl_attrib_make(2,oglShaderDataType.VEC2,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code tc),false));

    // create Light Shader (all-white)
    ogl_sp_init(*light_sp, BP_VERT_SHADER, LIGHT_FRAG_SHADER);
    ogl_sp_add_attrib(*light_sp, ogl_attrib_make(0,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code pos),false));
    ogl_sp_add_attrib(*light_sp, ogl_attrib_make(1,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code norm),false));
    ogl_sp_add_attrib(*light_sp, ogl_attrib_make(2,oglShaderDataType.VEC2,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code tc),false));


    // json tests
    root_json := xjson_parse_wholefile_string(SAMPLE_JSON);
    node, found := xjson_node_get(root_json, "mesh.tri_count");
    assert(found);
    xjson_print_node(node);

    sample_timer_cb :: (retries : u32, usr_ctx : *void) {print("cb triggered!\n");}
    t := xtimer_make(100, 5, sample_timer_cb, null);

    skybox := xskybox_make();
    cube_mesh := xmesh_gen_cube();

    while true {
        // input stuff
        {
            wevents := xwin_capture_events(*my_win);
            xim_capture_begin();
            xim_consume_events(wevents);
            xim_capture_end();
        }
        if (xim_kkey_pressed(.SC_ESCAPE)) exit(1); 
        xcam_update(*c, xx 1.0/60.0);
        ogl_set_viewport(0,0,1280,720);
        // render a white quad?
        ogl_rt_clear(null);
        ogl_rt_bind(null);
        ogl_clear_all_state();
        ogl_bind_sp(*bp_sp);
        // render OUR cube
        ogl_sp_set_uniform(*bp_sp, "view_pos", oglShaderDataType.VEC3, *c.pos);
        model := m4_rotate(90.0 * cast(float)seconds_since_init()/40.0, .{0,1,0});
        ogl_sp_set_uniform(*bp_sp, "model", oglShaderDataType.MAT4, model.raw.data);
        view := xcam_get_view_mat(*c);
        ogl_sp_set_uniform(*bp_sp, "view", oglShaderDataType.MAT4, view.raw.data);
        proj := m4_persp(90.0, viewport.width/viewport.height, 0.1, 10000);
        ogl_sp_set_uniform(*bp_sp, "proj", oglShaderDataType.MAT4, proj.raw.data);

        // Directional Light
        dir_light := xdir_light_make_basic();
        xlight_set_to_shader(*dir_light, *bp_sp);

        // Point Light
        light_pos := v3.{3,2,3};
        point_light := xpoint_light_make_basic(light_pos);
        xlight_set_to_shader(*point_light, *bp_sp);

        // bind diffuse/specular textures
        //cube_mat := xsimple_material_make(.{1,0,0.5,1});
        cube_mat := xsimple_material_make(*diff_img, *spec_img, 8);
        xsimple_material_set_to_shader(*cube_mat, *bp_sp);


        xmesh_render(*cube_mesh, *bp_sp, model);

        // render light source cube
        ogl_bind_sp(*light_sp);
        light_source_model := m4_mult(m4_trans(light_pos), m4_scale(.{0.5,0.5,0.5}));
        ogl_sp_set_uniform(*light_sp, "model", oglShaderDataType.MAT4, light_source_model.raw.data);
        ogl_sp_set_uniform(*light_sp, "view", oglShaderDataType.MAT4, view.raw.data);
        ogl_sp_set_uniform(*light_sp, "proj", oglShaderDataType.MAT4, proj.raw.data);
        ogl_sp_set_dyn_state(*light_sp, .BLEND);
        ogl_sp_set_dyn_state(*light_sp, .DEPTH);
        ogl_draw(oglPrimitive.TRIANGLES,0,36);



        xskybox_render(*skybox, viewport, *c, proj);

        xwin_swap(*my_win);
    }

}


