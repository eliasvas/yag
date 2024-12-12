// TODO: Add textures and other primitives
// TODO: Make the color per-instance

imm_sp : oglSP;

imm_tri_data : [..] xDebugVertex;

xImmPrimitiveTriangle :: struct {
  v0 : v3;
  v1 : v3;
  v2 : v3;
}

xImmPrimitiveKind :: enum {
  TRIANGLE;
  LINE;
  POINT;
}

xImmPrimitive :: struct {
  kind : xImmPrimitiveKind;
  union {
    tri   : xImmPrimitiveTriangle;
    //line  : xImmPrimitiveLine;
    //point : xImmPrimitivePoint;
  }
  color : v4;
}

xDebugVertex :: struct {
  wpos : v3;
  color : v4;
}

ximm_init :: () {
    // create Immediate Shader
    ogl_sp_init(*imm_sp, WS_VERT_SHADER, WS_FRAG_SHADER, WS_NORM_VIS_GEOM_SHADER);
    //ogl_sp_init(*imm_sp, WS_VERT_SHADER, WS_FRAG_SHADER);
    ogl_sp_add_attrib(*imm_sp, ogl_attrib_make(0,oglShaderDataType.VEC3,size_of(xDebugVertex),xx offset_of(xDebugVertex, #code wpos),false));
    ogl_sp_add_attrib(*imm_sp, ogl_attrib_make(1,oglShaderDataType.VEC4,size_of(xDebugVertex),xx offset_of(xDebugVertex, #code color),false));

}

ximm_triangle :: (tri : xImmPrimitiveTriangle, color : v4) {
  array_add(*imm_tri_data, .{tri.v0, color});
  array_add(*imm_tri_data, .{tri.v1, color});
  array_add(*imm_tri_data, .{tri.v2, color});
}

ximm_flush :: (proj : m4, view : m4) {
  defer imm_tri_data.count = 0;
  tri_buf : oglBuf;
  ogl_buf_init(*tri_buf, .VERTEX,imm_tri_data.data,xx imm_tri_data.count,size_of(xDebugVertex));
  ogl_clear_all_state();
  ogl_rt_bind(null);
  ogl_bind_vertex_buffer(*tri_buf);
  ogl_bind_sp(*imm_sp);
  ogl_set_viewport(0,0,1280,720);
  ogl_sp_set_uniform(*imm_sp, "proj", oglShaderDataType.MAT4, proj.raw.data);
  ogl_sp_set_uniform(*imm_sp, "view", oglShaderDataType.MAT4, view.raw.data);
  ogl_sp_set_dyn_state(*imm_sp, .BLEND);
  ogl_sp_set_dyn_state(*imm_sp, .DEPTH);
  ogl_draw(oglPrimitive.TRIANGLES, 0, xx imm_tri_data.count);
}
