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
        c2 := u8.[ 0x3F,0x6F,0x3F,0xFF ];
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
        // render a white quad?
        ogl_rt_clear(null);
        ogl_rt_bind(null);
        ogl_clear_all_state();
        ogl_bind_vertex_buffer(*cube_mesh.vbo);
        ogl_bind_sp(*bp_sp);
        ogl_set_viewport(0,0,1280,720);
        // render OUR cube
        ogl_sp_set_uniform(*bp_sp, "view_pos", oglShaderDataType.VEC3, *c.pos);
        color := float32.[0.7,0.3,0.2,1];
        ogl_sp_set_uniform(*bp_sp, "color", oglShaderDataType.VEC4, color.data);
        model := m4_rotate(90.0 * cast(float)seconds_since_init()/40.0, .{0,1,0});
        ogl_sp_set_uniform(*bp_sp, "model", oglShaderDataType.MAT4, model.raw.data);
        view := xcam_get_view_mat(*c);
        ogl_sp_set_uniform(*bp_sp, "view", oglShaderDataType.MAT4, view.raw.data);
        proj := m4_persp(90.0, viewport.width/viewport.height, 0.1, 10000);
        ogl_sp_set_uniform(*bp_sp, "proj", oglShaderDataType.MAT4, proj.raw.data);
        chrome_shininess : float32 = 8;
        ogl_sp_set_uniform(*bp_sp, "material.shininess", oglShaderDataType.FLOAT, *chrome_shininess);
        light_amb := float32.[0.2,0.2,0.2];
        ogl_sp_set_uniform(*bp_sp, "light.ambient", oglShaderDataType.VEC3, light_amb.data);
        light_diff := float32.[0.5,0.5,0.5];
        ogl_sp_set_uniform(*bp_sp, "light.diffuse", oglShaderDataType.VEC3, light_diff.data);
        light_spec := float32.[1,1,1];
        ogl_sp_set_uniform(*bp_sp, "light.specular", oglShaderDataType.VEC3, light_spec.data);
        light_pos := v3.{4,2,4};
        ogl_sp_set_uniform(*bp_sp, "light.pos", oglShaderDataType.VEC3, *light_pos);
        // bind diffuse/specular textures
        diff_slot :s32= 0;
        ogl_bind_tex_to_slot(*diff_img, xx diff_slot);
        ogl_sp_set_uniform(*bp_sp, "material.diffuse", oglShaderDataType.INT, *diff_slot);
        spec_slot :s32 = 1;
        ogl_bind_tex_to_slot(*spec_img, xx spec_slot);
        ogl_sp_set_uniform(*bp_sp, "material.specular", oglShaderDataType.INT, *spec_slot);
        ogl_sp_set_dyn_state(*bp_sp, .BLEND);
        ogl_sp_set_dyn_state(*bp_sp, .DEPTH);
        ogl_draw(oglPrimitive.TRIANGLES,0,36);

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


