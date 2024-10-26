#import "Basic";
#import "String";
#import "chaos";

my_win : nWindow;
my_sp  : oglSP;
my_vbo : oglBuf;

main :: () {
    assert(nwindow_init(*my_win, "My Great Window", 600, 400, nWindowFlags.RESIZABLE));
    ogl_init();
    ogl_sp_init(*my_sp, SAMPLE_VERT_SHADER, SAMPLE_FRAG_SHADER);
    ogl_sp_add_attrib(*my_sp, ogl_attrib_make(0,oglShaderDataType.VEC2,size_of(nVec2),0,false));

    vdata := nVec2.[
        nVec2.{+1.0,-1.0},
        nVec2.{+1.0,+1.0},
        nVec2.{-1.0,+1.0},
        nVec2.{-1.0,-1.0},
    ];
    ogl_buf_init(*my_vbo, oglBufKind.VERTEX, vdata.data, 4, size_of(nVec2));

    while true {
        ogl_rt_clear(null);
        ogl_clear_all_state();
        ogl_bind_vertex_buffer(*my_vbo);
        ogl_bind_sp(*my_sp);
        ogl_set_viewport(0,0,600,400);
        color := float32.[1,0,0,1];
        ogl_sp_set_uniform(*my_sp, "color", oglShaderDataType.VEC4, color.data);
        //ogl_sp_set_dyn_state(*my_sp, oglDynState.CULL);
        ogl_draw(oglPrimitive.TRIANGLE_FAN,0,4);
        //print("New Frame, err=[%]!", glGetError());
        nwindow_swap(*my_win);
    }

}


