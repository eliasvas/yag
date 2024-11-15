#import "Basic";
#import "String";
#import "chaos";

my_win : xWindow;
my_sp  : oglSP;
my_vbo : oglBuf;
white_img : oglTex;
offscreen_rt : oglRT;

// goal today is to render a rotating rombus that will bounce VERY funnily via our GREAT easing function
ease_out_bounce :: (x : float64) -> float64 {
  n1 :: 7.5625;
  d1 :: 2.75;

  if (x < 1.0 / d1) {
    return n1 * x * x;
  } else if (x < 2 / d1) {
    x-=1.5/d1;
    return n1 * x * x + 0.75;
  } else if (x < 2.25 / d1) {
    x-=2.25/d1;
    return n1 * x * x + 0.9375;
  } else  {
    x-=2.625/d1;
    return n1 * x * x + 0.984375;
  }
}
ease_in_bounce :: (x : float64) -> float64 {
  return 1.0 - ease_out_bounce(1.0 - x);
}

main :: () {
    c : xCam;

    pm := m4_persp(90.0, 600.0/400.0, 0.1, 100);
    //pm := m4_ortho(0,400,0,600,0.1,10);

    assert(xwin_init(*my_win, "My Great Window", 600, 400, xWindowFlags.RESIZABLE));
    ogl_init();
    ogl_sp_init(*my_sp, SAMPLE_VERT_SHADER, SAMPLE_FRAG_SHADER);
    ogl_sp_add_attrib(*my_sp, ogl_attrib_make(0,oglShaderDataType.VEC2,size_of(v2),0,false));
    white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
    ogl_tex_init(*white_img, .{1,1}, white.data, oglTexFormat.RGBA8U);
    assert(ogl_rt_init(*offscreen_rt, .{256, 256} , oglTexFormat.RGBA32F));

    root_json := xjson_parse_wholefile_string(SAMPLE_JSON);
    node, found := xjson_node_get(root_json, "mesh.tri_count");
    assert(found);
    xjson_print_node(node);

    sample_timer_cb :: (retries : u32, usr_ctx : *void) {print("cb triggered!\n");}
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
        if (xim_kkey_pressed(.SC_ESCAPE)) exit(1); 
        xcam_update(*c, xx 1.0/60.0);
        // render a white quad?
        ogl_rt_clear(null);
        ogl_rt_bind(null);
        ogl_clear_all_state();
        ogl_bind_vertex_buffer(*my_vbo);
        ogl_bind_sp(*my_sp);
        ogl_set_viewport(0,0,600,400);
        color := float32.[1,1,1,1];
        att0 := ogl_rt_get_attachment(*offscreen_rt, 0);
        ogl_sp_set_uniform(*my_sp, "color", oglShaderDataType.VEC4, color.data);

        current_time := cast(float)seconds_since_init();
        //print("current_time in seconds: %\n", current_time);

        //model := m4_scale(.{0.5,xx ease_in_bounce(min(current_time,1)) * 0.3 + 0.2,0.5});
        model := m4_rotate(90.0 * current_time, .{0,1,0});
        mvp := m4_mult(pm, m4_mult(xcam_get_view_mat(*c), model));
        ogl_sp_set_uniform(*my_sp, "MVP", oglShaderDataType.MAT4, mvp.raw.data);
        ogl_bind_tex_to_slot(*white_img, 0);
        ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);

        xwin_swap(*my_win);
    }

}


