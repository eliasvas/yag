#import "Basic";
#import "String";
#import "chaos";

my_win : xWindow;
my_sp  : oglSP;
my_vbo : oglBuf;
white_img : oglTex;
offscreen_rt : oglRT;

main :: () {
    assert(xwin_init(*my_win, "My Great Window", 600, 400, xWindowFlags.RESIZABLE));
    ogl_init();
    ogl_sp_init(*my_sp, SAMPLE_VERT_SHADER, SAMPLE_FRAG_SHADER);
    ogl_sp_add_attrib(*my_sp, ogl_attrib_make(0,oglShaderDataType.VEC2,size_of(v2),0,false));
    white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
    ogl_tex_init(*white_img, .{1,1}, white.data, oglTexFormat.RGBA8U);
    assert(ogl_rt_init(*offscreen_rt, .{256, 256} , oglTexFormat.RGBA32F));

    print("Json:\n %\n------\n", SAMPLE_JSON);
    xjson_parser_parse_wholefile_string(SAMPLE_JSON);

    sample_timer_cb :: (retries : u32, usr_ctx : *void) -> u32 #c_call {write_string("cb triggered!\n");return 0;}
    t := xtimer_make(100, 5, sample_timer_cb, null);

    vdata := v2.[
        v2.{+1.0,-1.0},
        v2.{+1.0,+1.0},
        v2.{-1.0,+1.0},
        v2.{-1.0,-1.0},
    ];
    ogl_buf_init(*my_vbo, oglBufKind.VERTEX, vdata.data, 4, size_of(v2));

    while true {
        // input stuff
        {
            wevents := xwin_capture_events(*my_win);
            xim_capture_begin();
            xim_consume_events(wevents);
            xim_capture_end();
        }
        if (xim_kkey_pressed(.SC_A)) print("A\n");
        if (xim_kkey_pressed(.SC_DELETE)) print("DELETE\n");
        // 1. bind offscreen RT and draw red in half the screen
        ogl_clear_all_state();
        ogl_rt_clear(*offscreen_rt);
        ogl_rt_bind(*offscreen_rt);
        ogl_bind_vertex_buffer(*my_vbo);
        ogl_bind_sp(*my_sp);
        ogl_set_viewport(0,0,128,256);
        color_off := float32.[0.5,0.5,0.5,1];
        ogl_sp_set_uniform(*my_sp, "color", oglShaderDataType.VEC4, color_off.data);
        ogl_bind_tex_to_slot(*white_img, 0);
        ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);
        // 2. bind def RT and draw contents of RT with modifier (color=0.5) so it will be dimmer and visible only in left half
        ogl_rt_clear(null);
        ogl_rt_bind(null);
        ogl_clear_all_state();
        ogl_bind_vertex_buffer(*my_vbo);
        ogl_bind_sp(*my_sp);
        ogl_set_viewport(0,0,600,400);
        color := float32.[1,0,0,1];
        att0 := ogl_rt_get_attachment(*offscreen_rt, 0);
        ogl_sp_set_uniform(*my_sp, "color", oglShaderDataType.VEC4, color.data);
        ogl_bind_tex_to_slot(*att0, 0);
        ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);
        // 3. swap buffers
        xwin_swap(*my_win);
    }

}


