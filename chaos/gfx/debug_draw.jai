// TODO: Add textures and other primitives
// TODO: Make the color per-instance

imm_sp : oglSP;
g_imm_tri_data : [..] xDebugVertex;

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
  // create Immediate World Space Shader
  ogl_sp_init(*imm_sp, WS_VERT_SHADER, WS_FRAG_SHADER);

  // FIXME: why is there a bug without this reserve?? what are we doing wrong with dynamic arrays?!
  array_reserve(*g_imm_tri_data, 1000);
}

ximm_triangle :: (tri : xImmPrimitiveTriangle, color : v4) {
  array_add(*g_imm_tri_data, .{tri.v0, color});
  array_add(*g_imm_tri_data, .{tri.v1, color});
  array_add(*g_imm_tri_data, .{tri.v2, color});
}

ximm_flush :: (proj : m4, view : m4) {
  //defer array_reset(*g_imm_tri_data);
  defer g_imm_tri_data.count = 0;
  tri_buf : oglBuf;
  ogl_buf_init(*tri_buf, .VERTEX,g_imm_tri_data.data,xx g_imm_tri_data.count,size_of(xDebugVertex));
  ogl_rt_bind(null);

  bindings : oglBindingDesc;
  bindings.vertex_bufs = oglVertexDef.[
    .{*tri_buf, oglShaderAttrib.[
      .{loc=0,offset=cast(u32)offset_of(xDebugVertex,#code wpos)},
      .{loc=1,offset=cast(u32)offset_of(xDebugVertex,#code color)},
    ]}
  ];

  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    flags = .BLEND | .DEPTH
  };

  ogl_bind_sp(*imm_sp);
  ogl_sp_apply_bindings(*imm_sp, bindings);
  ogl_sp_apply_dyn_state(*imm_sp, dyn_state);
  ogl_draw(oglPrimitive.TRIANGLES, 0, xx g_imm_tri_data.count);
}
