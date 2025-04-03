
QuadVertex :: struct {
  pos : v2;
  color: v4;
  tc : v2;
}

xRend2D :: struct {
  sp : oglSP;
  sp_ub1 : oglUBlock;
  vertex_def : oglVertexDef;
  initialized : bool;
}

xr2d_init :: (using rend : *xRend2D) {
  ogl_sp_init(*sp, QUAD_VERT_SHADER, QUAD_FRAG_SHADER);
  ogl_ublock_load(*sp_ub1, *sp, 1);

  vertex_def.vbuf = alloc(size_of(oglBuf)); // NOTE: I hate this, what can be done
  memset(vertex_def.vbuf, 0, size_of(oglBuf));
  attribs :: #run oglShaderAttrib.[.{loc=0,offset=cast(u32)offset_of(QuadVertex,#code pos)},.{loc=1,offset=cast(u32)offset_of(QuadVertex,#code color)},.{loc=2,offset=cast(u32)offset_of(QuadVertex,#code tc)}];
  vertex_def.attribs = attribs;

  initialized = true;
}

xr2d_quad_render :: (using rend : *xRend2D, r : v4, texcoords : v4, col : v4, cam : *xCamera2D, tex : *oglTex = null) {
  if !initialized then xr2d_init(rend);
  rect := v4.{r.x, r.y, r.x+r.z, r.y+r.w};

  ogl_rt_bind(null);
  ogl_bind_sp(*sp);

  ogl_buf_deinit(vertex_def.vbuf);
  vertices : [4]QuadVertex;

  vertices[0] = .{pos = .{rect.x, rect.y}, color = col, tc = .{texcoords.x, texcoords.y}};
  vertices[0].pos = apply_camera_transform(vertices[0].pos, cam);
  vertices[0].pos = apply_projection_transform(vertices[0].pos, xwin_get_dim(*xeng().win));

  vertices[1] = .{pos = .{rect.z, rect.y}, color = col, tc = .{texcoords.x + texcoords.z, texcoords.y}};
  vertices[1].pos = apply_camera_transform(vertices[1].pos, cam);
  vertices[1].pos = apply_projection_transform(vertices[1].pos, xwin_get_dim(*xeng().win));

  vertices[2] = .{pos = .{rect.x, rect.w}, color = col, tc = .{texcoords.x, texcoords.y + texcoords.w}};
  vertices[2].pos = apply_camera_transform(vertices[2].pos, cam);
  vertices[2].pos = apply_projection_transform(vertices[2].pos, xwin_get_dim(*xeng().win));

  vertices[3] = .{pos = .{rect.z, rect.w}, color = col, tc = .{texcoords.x + texcoords.z, texcoords.y + texcoords.w}};
  vertices[3].pos = apply_camera_transform(vertices[3].pos, cam);
  vertices[3].pos = apply_projection_transform(vertices[3].pos, xwin_get_dim(*xeng().win));


  ogl_buf_init(vertex_def.vbuf, .VERTEX, vertices.data, cast(u32)vertices.count, size_of(QuadVertex));
  bindings := oglBindingDesc.{
    index_buf = null,
    vertex_bufs = []oglVertexDef.{1, *vertex_def},
  };
  ogl_sp_apply_bindings(*sp, bindings);

  if tex {
    ogl_sp_bind_sampler_to_slot(*sp, "tex", tex, 0);
  }

  ogl_ublock_set(*sp_ub1, "color", xx *col);
  ogl_ublock_bind_to_slot(*sp_ub1);

  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    flags = .BLEND
  };
  ogl_sp_apply_dyn_state(*sp, dyn_state);

  ogl_draw(oglPrimitive.TRIANGLE_STRIP,0,4);
}

QUAD_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec2 in_pos;
layout (location = 1) in vec4 in_color;
layout (location = 2) in vec2 in_tc;


vec2 quad[4] = vec2[](
  vec2(+1.0,-1.0),
  vec2(+1.0,+1.0),
  vec2(-1.0,+1.0),
  vec2(-1.0,-1.0)
);

layout(std140, binding = 0) uniform GlobalData {
  mat4 proj;
  mat4 view;
};

layout(std140, binding = 1) uniform QuadData {
  mat4 final_matrix;
  vec4 color;
};


out VS_OUT {
  vec2 tc;
} vs_out;

void main() {
  //vec4 p = vec4(quad[gl_VertexID].xy,0.0, 1.0);
  //vec4 pr = final_matrix * vec4(in_pos,0.0, 1.0);
  vec4 pr = vec4(in_pos,0.0, 1.0);
  gl_Position = pr;
  vs_out.tc = in_tc;

}
DONE

QUAD_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

in VS_OUT {
  vec2 tc;
} fs_in;

layout(std140, binding = 0) uniform GlobalData {
  mat4 proj;
  mat4 view;
};

layout(std140, binding = 1) uniform QuadData {
  mat4 final_matrix;
  vec4 color;
};

uniform sampler2D tex;

void main() {
  FragColor = color;
  FragColor = color * texture(tex, fs_in.tc);
}

DONE
