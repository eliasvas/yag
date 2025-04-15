#import "Basic";
#import "String";
#import "GL" (DUMP_GL_ERRORS=true, ENABLE_ALL_EXTENSIONS=true);

// TODO: minimize the code: texture/RT generation could be improved a lot - the less code the better!

/* This is a simple example on how to use the major features of ogl - like VBOS/IBOS ublocks/textures and stuff
main :: () {
  xeng_init();
  VERT_SHADER :: #string DONE
  #version 430 core
  layout (location = 0) in vec3 in_pos;
  layout (location = 1) in vec3 in_color;

  out VS_OUT {
    vec3 color;
    vec2 tc;
  } vs_out;

  void main() {
    gl_Position = vec4(in_pos.xyz, 1.0);
    vs_out.tc = in_pos.xy;
    vs_out.color = in_color;
  }
  DONE
  FRAG_SHADER :: #string DONE
  #version 430 core
  in VS_OUT {
    vec3 color;
    vec2 tc;
  } fs_in;

  layout(std140, binding = 1) uniform SimpleData {
    float time;
  };

  uniform sampler2D tex;

  void main() {
    gl_FragColor = vec4(time*fs_in.color * texture(tex, fs_in.tc).xyz, 1.0);
  }
  DONE

  // Creating a texture for use in the shader
  white_tex:oglTex;
  white := u8.[ 0xFF,0xFF,0xFF,0xFF ];
  ogl_tex_init(*white_tex, .{1,1}, white.data, oglTexFormat.RGBA8U);

  // Creating the shader program
  simple_sp : oglSP;
  ogl_sp_init(*simple_sp, VERT_SHADER, FRAG_SHADER);

  // Creating the uniform block associated with this shader
  simple_ub : oglUBlock;
  ogl_ublock_load(*simple_ub, *simple_sp, 1);
 
  // Creating the vertex Definition for the VBO (can be omitted if all locations are in a single buffer, we figure it out!)
  MyVertex :: struct {pos : v3; color: v3;};
  vertex_def : oglVertexDef; // the definition for the vertex drawn
  vertex_def.vbuf = alloc(size_of(oglBuf));
  attribs : [..]oglShaderAttrib;
  array_add(*attribs, .{loc=0,offset=cast(u32)offset_of(MyVertex,#code pos)});
  array_add(*attribs, .{loc=1,offset=cast(u32)offset_of(MyVertex,#code color)});
  vertex_def.attribs = attribs;

  // Creating the vertex buffer holding our data for the drawcall
  triangle_data : []float32 = .[ -1.0,-1.0,0.0,1,0,0, +1.0,-1.0,0.0,0,1,0, +0.0,+1.0,0.0,0,0,1, ];
  ogl_buf_init(vertex_def.vbuf, .VERTEX, triangle_data.data, cast(u32)triangle_data.count, size_of(MyVertex));

  // Creating the index buffer for our data
  indices := u32.[0,1,2];
  ibo : oglBuf;
  ogl_buf_init(*ibo, .INDEX, indices.data, cast(u32)indices.count, size_of(u32));

  while true {
    xeng_frame_init();
    ogl_rt_clear(null);
    if (xim_kkey_pressed(.SC_ESCAPE)) exit(1);

    ogl_sp_bind_sampler_to_slot(*simple_sp, "tex", *white_tex, 0);

    ogl_bind_sp(*simple_sp);

    time := cast(float32)seconds_since_init();
    ogl_ublock_set(*simple_ub, "time", xx *time);

    bindings := oglBindingDesc.{
      index_buf = *ibo,
      vertex_bufs = []oglVertexDef.{1, *vertex_def},
    };
    ogl_sp_apply_bindings(*simple_sp, bindings);

    dyn_state := oglDynState.{
      viewport = .{0,0,xeng().win.dim.x, xeng().win.dim.y},
      scissor = .{},
      flags = .BLEND
    };
    ogl_sp_apply_dyn_state(*simple_sp, dyn_state);
    ogl_ublock_bind_to_slot(*simple_ub);

    ogl_draw_indexed(oglPrimitive.TRIANGLES, cast(u32)ibo.count, ibo.bytes_per_element);

    xeng_frame_end();
  }
}
*/

///////////////////////////////
// ogl Constants

OGL_MAX_ATTRIBS           :: 8;
OGL_MAX_TEX_SLOTS         :: 8;
OGL_MAX_COLOR_ATTACHMENTS :: 8;

///////////////////////////////
// ogl Buffers

oglBufKind :: enum { VERTEX; INDEX; UNIFORM; };
oglBuf :: struct {
  bytes_per_element : s64; // how much space each element takes
  count             : s64; // how many elements (e.g 2 x vec4)
  kind              : oglBufKind; // kind of buffer (index/vertex/uniform)
  impl_state        : *void; // OpenGL id
};

ogl_buf_get_total_byte_count :: (using buf: *oglBuf) -> s64 { return count * bytes_per_element; }

ogl_buf_to_gl_buf :: (kind : oglBufKind) ->GLuint {
  gl_buf_kind : GLuint = 0;
  if kind == {
    case .VERTEX;
      gl_buf_kind = GL_ARRAY_BUFFER;
    case .INDEX;
      gl_buf_kind = GL_ELEMENT_ARRAY_BUFFER;
    case .UNIFORM;
      gl_buf_kind = GL_UNIFORM_BUFFER;
    case;
      assert(0 && "unimplemented buffer kind - implement this!");
  }
  return gl_buf_kind;
}
ogl_buf_init :: (using buf : *oglBuf, bkind : oglBufKind, data : *void, data_count : u32, bytes_per_elem : u32) -> bool {
  kind = bkind;
  count = data_count;
  bytes_per_element = bytes_per_elem;
  buffer_kind := ogl_buf_to_gl_buf(kind);
  glGenBuffers(1, xx *impl_state);
  glBindBuffer(buffer_kind, xx buf.impl_state);
  ogl_buf_update(buf, data,xx count,xx bytes_per_element);
  glBindBuffer(buffer_kind, 0);
  return true;
}
// TODO the using's should be in function declaration
ogl_buf_deinit :: (using buf : *oglBuf) -> bool {
  if buf != null && impl_state != null {
    glDeleteBuffers(1, xx *impl_state);
    return true;
  } else {
    return false;
  }
}
ogl_buf_update :: (using buf : *oglBuf, data : *void, data_count : u32, bytes_per_elem: u32) {
  count = data_count;
  bytes_per_element = bytes_per_elem;
  buffer_kind := ogl_buf_to_gl_buf(kind);
  glBindBuffer(buffer_kind, xx buf.impl_state);
  //if data != null {
  glBufferData(buffer_kind, ogl_buf_get_total_byte_count(buf), data, GL_STREAM_DRAW);
  //}
}
ogl_buf_sub_update :: (using buf : *oglBuf, offset : s64, data : *void, data_count : u32, bytes_per_elem : u32) {
  buffer_kind := ogl_buf_to_gl_buf(kind);
  glBindBuffer(buffer_kind, xx buf.impl_state);
  size := data_count * bytes_per_elem;
  if data != null {
    buffer_kind := ogl_buf_to_gl_buf(kind);
    glBufferSubData(buffer_kind, offset, size, data);
  }
}

ogl_bind_index_buffer :: (using buf : *oglBuf) {
  if buf {
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, xx impl_state);
  } else {
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
  }
}

ogl_bind_vertex_buffer :: (using buf : *oglBuf, attribs : []oglShaderAttrib = .[]) {
  if buf {
    glBindBuffer(GL_ARRAY_BUFFER, xx impl_state);
  } else {
    glBindBuffer(GL_ARRAY_BUFFER, 0);
  }
}
ogl_bind_uniform_buffer :: (using buf : *oglBuf) {
  if buf {
    glBindBuffer(GL_UNIFORM_BUFFER, xx impl_state);
  } else {
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
  }
}


///////////////////////////////
// ogl Shaders

oglShaderDataType :: enum {
  FLOAT;
  INT;
  IVEC2;
  IVEC3;
  IVEC4;
  VEC2;
  VEC3;
  VEC4;
  MAT4;
};

gl_data_type_to_ogl_data_type :: (gl_data_type : s64) -> oglShaderDataType {
  type := oglShaderDataType.FLOAT;
  if gl_data_type == {
    case GL_FLOAT;
      type = .FLOAT;
    case GL_INT;
      type = .INT;
    case GL_INT_VEC2;
      type = .IVEC2;
    case GL_INT_VEC3;
      type = .IVEC3;
    case GL_INT_VEC4;
      type = .IVEC4;
    case GL_FLOAT_VEC2;
      type = .VEC2;
    case GL_FLOAT_VEC3;
      type = .VEC3;
    case GL_FLOAT_VEC4;
      type = .VEC4;
    case GL_FLOAT_MAT4;
      type = .MAT4;
    case;
  };
  return type;
}

oglShaderAttrib :: struct {
  loc       : u32;
  offset    : u32;
  stride    : u32;
  type      : oglShaderDataType;
  instanced : bool;
};
oglSP :: struct {
  impl_state   : *void;
  attribs :[OGL_MAX_ATTRIBS]oglAttribDesc;
};

gl_check_shader_compile_errors :: (sp_handle : GLuint) -> bool {
  success : s32;
  glGetShaderiv(sp_handle, GL_COMPILE_STATUS, *success);
  if (!success) {
  info_data : [512]u8;
  glGetShaderInfoLog (sp_handle,512,null,info_data.data);
  print("Shader compilation error: [%]\n", to_string(info_data.data));
}
return (success == 0);
}
gl_check_shader_link_errors :: (sp_handle : GLuint) -> bool {
  success : s32;
  glGetProgramiv(sp_handle, GL_LINK_STATUS, *success);
  if (!success) {
    info_data : [512]u8;
    glGetProgramInfoLog (sp_handle,512,null,info_data.data);
    print("Shader link error: [%]\n", to_string(info_data.data));
  }
  return (success == 0);
}
gl_make_sp :: (vs_source : string, fs_source : string, gs_source : string = "") -> GLuint {
  sp : GLuint = 0;

  vs : GLuint = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vs, 1, *vs_source.data, xx 0);
  glCompileShader(vs);
  assert(vs != 0);
  assert(!gl_check_shader_compile_errors(vs));

  fs : GLuint = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fs, 1, *fs_source.data, xx 0);
  glCompileShader(fs);
  assert(fs != 0);
  assert(!gl_check_shader_compile_errors(fs));

  gs : GLuint;
  if gs_source.count {
    gs = glCreateShader(GL_GEOMETRY_SHADER);
    glShaderSource(gs, 1, *gs_source.data, xx 0);
    glCompileShader(gs);
    assert(gs != 0);
    assert(!gl_check_shader_compile_errors(gs));
  }

  sp = glCreateProgram();
  glAttachShader(sp, vs);
  glAttachShader(sp, fs);
  if gs_source.count then glAttachShader(sp, gs);
  glLinkProgram(sp);
  assert(!gl_check_shader_link_errors(sp));

  glDeleteShader(vs);
  glDeleteShader(fs);

  return sp;
}
ogl_get_component_num_for_data_type :: (type : oglShaderDataType) -> u32 {
  comp_count : u32 = 0;
  if #complete type == {
    case .FLOAT; comp_count = 1;
    case .INT;   comp_count = 1;
    case .IVEC2; comp_count = 2;
    case .VEC2;  comp_count = 2;
    case .VEC3;  comp_count = 3;
    case .IVEC3; comp_count = 3;
    case .VEC4;  comp_count = 4;
    case .IVEC4; comp_count = 4;
    case .MAT4;  comp_count = 16;
    case; print("invalid shader type=[%]", type);
  }
  return comp_count;
}

// TODO: first offset then stride in function def
ogl_attrib_make :: (loc : u32, type : oglShaderDataType, stride : u32, offset : u32, instanced : bool) -> oglShaderAttrib {
  return oglShaderAttrib.{ loc, offset,stride, type, instanced };
}

ogl_attrib_is_integral :: (using attrib : *oglShaderAttrib) -> bool {
  return type == .INT || type == .IVEC2 || type == .IVEC3 || type == .IVEC4;
}

oglAttribDesc :: struct {
  loc  : u32;
  type : oglShaderDataType;
  available : bool;
};

ogl_sp_detect_attribs :: (using sp : *oglSP) {
  name_buf : [256]u8;
  attrib_count : s32;
  glGetProgramiv(xx impl_state, GL_ACTIVE_ATTRIBUTES, *attrib_count);
  for i : 0..attrib_count-1 {
    desc : oglAttribDesc;
    type : GLenum;
    size : GLint;
    length : GLsizei;
    glGetActiveAttrib(xx impl_state, xx i, 256, *length, *size, *type, name_buf.data);
    name_str : string = .{length, name_buf.data};
    loc := xx glGetAttribLocation(xx impl_state, name_buf.data);
    if loc == -1 then continue; // we skip built-in vertex attribs like gl_VertexID
    desc.loc = xx loc;
    desc.available = true;
    desc.type = gl_data_type_to_ogl_data_type(type);
    attribs[loc] = desc;
  }
}
ogl_sp_init :: (using sp: *oglSP, vs_source : string, fs_source : string) -> bool { return ogl_sp_init(sp, vs_source, "", fs_source); }
ogl_sp_init :: (using sp: *oglSP, vs_source : string, gs_source : string, fs_source : string) -> bool {
  impl_state = cast(*void)gl_make_sp(vs_source, fs_source, gs_source);
  ogl_sp_detect_attribs(sp);
  return (cast(s64)impl_state !=0);
}
ogl_sp_deinit :: (using sp : *oglSP) -> bool {
  glDeleteProgram(cast(GLuint)impl_state);
  return true;
}
ogl_bind_attrib :: (attrib : *oglShaderAttrib) {
  using attrib;
  glEnableVertexAttribArray(loc);
  if ogl_attrib_is_integral(attrib) {
    // FIXME: here, prim_kind should be calculated, whether its GL_SHORT or GL_INT
    prim_kind :u32= GL_SHORT;
    glVertexAttribIPointer(loc, cast(GLint)ogl_get_component_num_for_data_type(type), prim_kind, stride, cast(*void)offset);
  } else {
    glVertexAttribPointer(loc, cast(GLint)ogl_get_component_num_for_data_type(type), GL_FLOAT, GL_FALSE, stride, cast(*void)offset);
  }
  glVertexAttribDivisor(loc, cast(GLuint)instanced);
}

ogl_bind_attribs :: (sp : * oglSP, vbo : *oglBuf, attribs : []oglShaderAttrib){
  for i : 0..attribs.count-1 {
    attrib : oglShaderAttrib = attribs[i];
    if attrib.stride == 0 then attrib.stride = cast(u32)vbo.bytes_per_element;
    attrib.type = sp.attribs[attrib.loc].type;
    ogl_bind_attrib(*attrib);
  }
}
ogl_bind_sp :: (using sp : *oglSP){
  glUseProgram(cast(GLuint)impl_state);
}
ogl_sp_set_uniform :: (using sp : *oglSP, uniform_name : string, type : oglShaderDataType, val : *void){
  if #complete type == {
    case .FLOAT; glUniform1fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
    case .VEC2; glUniform2fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
    case .IVEC2; glUniform2iv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*s32)val);
    case .VEC3; glUniform3fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
    case .IVEC3; glUniform3iv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*s32)val);
    case .VEC4; glUniform4fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
    case .IVEC4; glUniform4iv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*s32)val);
    case .MAT4; glUniformMatrix4fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, GL_TRUE, cast(*float32)val);
    case .INT;
    glUniform1iv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*s32)val);
    case; print("invalid shader set for uniform of type=[%]", type);
  }
}

///////////////////////////////
// ogl Draw API

oglPrimitive :: enum{
  TRIANGLES;
  TRIANGLE_STRIP;
  TRIANGLE_FAN;
  LINES;
  LINE_STRIP;
  POINTS;
};


ogl_prim_to_gl_prim :: (prim : oglPrimitive) -> GLuint {
  gl_prim : GLuint = 0;
  if #complete prim == {
    case .TRIANGLES; gl_prim = GL_TRIANGLES;
    case .TRIANGLE_STRIP; gl_prim = GL_TRIANGLE_STRIP;
    case .TRIANGLE_FAN; gl_prim = GL_TRIANGLE_FAN;
    case .LINES; gl_prim = GL_LINES;
    case .LINE_STRIP; gl_prim = GL_LINE_STRIP;
    case .POINTS; gl_prim = GL_POINTS;
    case; print("invalid primitive =[%]", prim);
  }
  return gl_prim;
}

ogl_draw :: (prim : oglPrimitive, first : u32, count : u32) {
  glDrawArrays(ogl_prim_to_gl_prim(prim), xx first, xx count);
}
ogl_draw_instanced :: (prim : oglPrimitive, first : u32, count : u32, instance_count : u32) {
  glDrawArraysInstanced(ogl_prim_to_gl_prim(prim), xx first, xx count, instance_count);
}
ogl_draw_indexed :: (prim : oglPrimitive, count : u32, index_size :s64 = size_of(u32)) {
  glDrawElements(ogl_prim_to_gl_prim(prim), count, xx ifx index_size == size_of(u32) then GL_UNSIGNED_INT else GL_UNSIGNED_SHORT, null);
}

///////////////////////////////
// ogl Textures

oglTexFilter :: enum {
  NEAREST;
  LINEAR;
  LINEAR_MIPMAP_LINEAR;
}
ogl_tex_filter_to_gl_tex_filter :: (tf : oglTexFilter) -> u32 {
  if tf == {
    case .NEAREST; return GL_NEAREST;
    case .LINEAR; return GL_LINEAR;
    case .LINEAR_MIPMAP_LINEAR; return GL_LINEAR_MIPMAP_LINEAR;
    case; return GL_LINEAR;
  }
}

oglTexWrapMethod :: enum {
  REPEAT;
  MIRRORED_REPEAT;
  CLAMP_TO_EDGE;
  CLAMP_TO_BORDER;
}
ogl_tex_wrap_method_to_gl_tex_wrap_method :: (wrap : oglTexWrapMethod) -> u32 {
  if wrap == {
    case .REPEAT; return GL_REPEAT;
    case .MIRRORED_REPEAT; return GL_MIRRORED_REPEAT;
    case .CLAMP_TO_EDGE; return GL_CLAMP_TO_EDGE;
    case .CLAMP_TO_BORDER; return GL_CLAMP_TO_BORDER;
    case; return GL_REPEAT;
  }
}

oglTexParams :: struct {
  min_filter    : oglTexFilter;
  mag_filter    : oglTexFilter;
  wrap_s        : oglTexWrapMethod;
  wrap_t        : oglTexWrapMethod;
  wrap_r        : oglTexWrapMethod;
  generate_mips : bool;
}

ogl_apply_tex_parameters_for_gl_tex_target :: (target : u32, params : oglTexParams) {
  //if params.generate_mips then glGenerateMipmap(GL_TEXTURE_2D);
  glTexParameteri(target, GL_TEXTURE_MIN_FILTER, xx ogl_tex_filter_to_gl_tex_filter(params.min_filter));
  glTexParameteri(target, GL_TEXTURE_MAG_FILTER, xx ogl_tex_filter_to_gl_tex_filter(params.mag_filter));
  glTexParameteri(target, GL_TEXTURE_WRAP_S, xx ogl_tex_wrap_method_to_gl_tex_wrap_method(params.wrap_s));
  border_color := float32.[1,1,1,1];
  if params.wrap_s == .CLAMP_TO_BORDER then glTexParameterfv(target, GL_TEXTURE_BORDER_COLOR, border_color.data);
  glTexParameteri(target, GL_TEXTURE_WRAP_T, xx ogl_tex_wrap_method_to_gl_tex_wrap_method(params.wrap_t));
  if params.wrap_t == .CLAMP_TO_BORDER then glTexParameterfv(target, GL_TEXTURE_BORDER_COLOR, border_color.data);
  glTexParameteri(target, GL_TEXTURE_WRAP_R, xx ogl_tex_wrap_method_to_gl_tex_wrap_method(params.wrap_r));
  if params.wrap_r == .CLAMP_TO_BORDER then glTexParameterfv(target, GL_TEXTURE_BORDER_COLOR, border_color.data);
}

oglTexFormat :: enum {
  R8U;
  RGBA8U;
  RGBA16F;
  RGBA32F;
  R32F;
  D32F; // will create array texture FBO for layered rendering
};
oglTex :: struct {
  dim : v2;
  format : oglTexFormat;
  is_cube : bool;
  impl_state : *void;
};

// FIXME: hacky AF
ogl_tex_convert_rt_to_cubemap :: (using rt : *oglRT, mips : bool = false) -> oglTex {
  cubemap : oglTex;
  cubemap.dim = rt.dim;
  cubemap.is_cube = true;
  cubemap.format = oglTexFormat.RGBA16F;
  glGenTextures(1, xx *cubemap.impl_state);
  glBindTexture(GL_TEXTURE_CUBE_MAP, cast(GLuint)cubemap.impl_state);

  for i : 0..5 { glTexImage2D(xx (GL_TEXTURE_CUBE_MAP_POSITIVE_X + i), 0, GL_RGBA16F, xx dim.x, xx dim.y, 0, GL_RGBA, GL_HALF_FLOAT, xx 0); }

  ogl_rt_bind(rt);
  for i : 0..5{
    glReadBuffer(xx(GL_COLOR_ATTACHMENT0 + i)); // Select the correct color attachment
    glBindTexture(GL_TEXTURE_CUBE_MAP, xx cubemap.impl_state);
    glCopyTexSubImage2D(xx(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i), 0, 0, 0, 0, 0, xx dim.x, xx dim.y);
  }

  glBindTexture(GL_TEXTURE_CUBE_MAP, xx cubemap.impl_state);
  params := oglTexParams.{
    min_filter = ifx mips then .LINEAR_MIPMAP_LINEAR else .LINEAR,
    //min_filter = .LINEAR,
    mag_filter = .LINEAR,
    wrap_s = .CLAMP_TO_EDGE,
    wrap_t = .CLAMP_TO_EDGE,
    wrap_r = .CLAMP_TO_EDGE,
  };
  ogl_apply_tex_parameters_for_gl_tex_target(GL_TEXTURE_CUBE_MAP, params);


  if mips {
    glBindTexture(GL_TEXTURE_CUBE_MAP, xx cubemap.impl_state);
    glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);
    glGenerateMipmap(GL_TEXTURE_CUBE_MAP);
  }

  return cubemap;
}

ogl_tex_init :: (using tex : *oglTex, dimensions : v2, data : *u8, data_format : oglTexFormat, params : oglTexParams = .{}) -> bool {
  dim = dimensions;
  format = data_format;

  pixel_type := ifx ogl_tex_format_is_integral(format) then GL_UNSIGNED_BYTE else GL_FLOAT;
  glGenTextures(1, xx *impl_state);
  glBindTexture(GL_TEXTURE_2D, cast(GLuint)impl_state);
  ogl_apply_tex_parameters_for_gl_tex_target(GL_TEXTURE_2D, params);
  glTexImage2D(GL_TEXTURE_2D, 0, xx ogl_tex_format_to_gl_internal_format(format), xx dim.x, xx dim.y, 0, xx ogl_tex_format_to_gl_pixel_format(format), xx pixel_type, data);
  if params.generate_mips then glGenerateMipmap(GL_TEXTURE_2D);

  return (impl_state != null);
}
ogl_tex_format_is_integral :: (format : oglTexFormat) -> bool { return format == .RGBA8U || format == .R8U; }
ogl_tex_format_to_gl_pixel_format :: (format : oglTexFormat) -> s32 {
  comp_num := ogl_tex_format_get_component_num(format);
  if comp_num == {
    case 1; return GL_RED;
    case 4; return GL_RGBA;
    case; return GL_RGBA;
  }
}
ogl_tex_format_to_gl_internal_format :: (format : oglTexFormat) -> s32 {
  comp_num := ogl_tex_format_get_component_num(format);
  if comp_num == {
    case 1; return ifx ogl_tex_format_is_integral(format) then cast(s32)GL_RED else cast(s32)GL_R32F;
    case 4; return ifx ogl_tex_format_is_integral(format) then cast(s32)GL_RGBA else cast(s32)GL_RGBA32F;
    case; return GL_RGBA;
  }
}
ogl_tex_format_get_component_num :: (format : oglTexFormat) -> s32{
  num : s32;
  if #complete format == {
    case oglTexFormat.RGBA8U; #through;
    case oglTexFormat.RGBA16F; #through;
    case oglTexFormat.RGBA32F;
      num = 4;
    case oglTexFormat.R8U; #through;
    case oglTexFormat.R32F; #through;
    case oglTexFormat.D32F;
      num = 1;
    case;
      num = 0;
  }
  return num;
}

ogl_tex_deinit :: (using tex : *oglTex) {
  glDeleteTextures(1,xx *impl_state);
}

// @FIXME: this is hacky as FUCK
ogl_get_tex_target_from_tex :: (using tex : *oglTex) ->u32 {
  tformat : u32 = xx GL_TEXTURE_2D;
  if tex.format == .D32F then tformat = xx GL_TEXTURE_2D_ARRAY;
  if tex.is_cube then tformat = xx GL_TEXTURE_CUBE_MAP;
  return tformat;
}

ogl_bind_tex_to_slot :: (using tex : *oglTex, slot : u32) {
  glActiveTexture(GL_TEXTURE0 + slot);
  glBindTexture(ogl_get_tex_target_from_tex(tex), cast(GLuint)impl_state);
}

// TODO: maybe instead of sampler_name provide (binding=1) ? YES PLEASE PLEASE PLEASE
ogl_sp_bind_sampler_to_slot :: (using sp : *oglSP, sampler_name : string, tex : * oglTex, slot : u32) {
  ogl_bind_tex_to_slot(tex, slot);
  ogl_sp_set_uniform(sp, sampler_name, oglShaderDataType.INT , *slot);
}
///////////////////////////////
// ogl RTs

oglRTAttachment :: enum { A0; A1; A2; A3; DS; };
oglRT :: struct {
  dim : v2;
  format : oglTexFormat; // for color attachments
  impl_state : *void;
};
ogl_rt_init :: (using rt : *oglRT, rt_dim : v2, rt_img_format : oglTexFormat, attachment_count : u32 = 4) -> bool {
  dim = rt_dim;
  format = rt_img_format;
  tex_format : GLuint;
  attachments : [OGL_MAX_TEX_SLOTS]GLuint;

  if #complete format == {
    case oglTexFormat.D32F;
      glGenFramebuffers(1, xx *impl_state);
      cascade_count := attachment_count;
      g_light_depth_maps : GLuint;
      glGenTextures(1, *g_light_depth_maps);
      glBindTexture(GL_TEXTURE_2D_ARRAY, g_light_depth_maps);
      glTexImage3D( GL_TEXTURE_2D_ARRAY, 0, GL_DEPTH_COMPONENT32F, xx dim.x, xx dim.y,cascade_count+1,0, GL_DEPTH_COMPONENT, GL_FLOAT, xx 0);
      params := oglTexParams.{
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        wrap_s = .CLAMP_TO_BORDER,
        wrap_t = .CLAMP_TO_BORDER,
        wrap_r = .CLAMP_TO_BORDER,
      };
      ogl_apply_tex_parameters_for_gl_tex_target(GL_TEXTURE_2D_ARRAY, params);
      glBindFramebuffer(GL_FRAMEBUFFER, xx impl_state);
      glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, g_light_depth_maps, 0);
      glDrawBuffer(GL_NONE);
      glReadBuffer(GL_NONE);
      assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
      glBindFramebuffer(GL_FRAMEBUFFER, xx 0);
    case oglTexFormat.R32F; #through;
    case oglTexFormat.RGBA32F; #through;
    case oglTexFormat.RGBA8U; #through;
    case oglTexFormat.R8U; #through;
    case oglTexFormat.RGBA16F; {
      glGenFramebuffers(1, xx *impl_state);
      glBindFramebuffer(GL_FRAMEBUFFER, xx impl_state);

      for i : 0..attachment_count-1 {
        pixel_type := ifx ogl_tex_format_is_integral(format) then GL_UNSIGNED_BYTE else GL_FLOAT;
        glGenTextures(1, xx *attachments[i]);
        glBindTexture(GL_TEXTURE_2D, attachments[i]);
        glTexImage2D(GL_TEXTURE_2D, 0, xx ogl_tex_format_to_gl_internal_format(format), xx dim.x, xx dim.y, 0, xx ogl_tex_format_to_gl_pixel_format(format), xx pixel_type, null);
        params := oglTexParams.{
          min_filter = .NEAREST,
          mag_filter = .NEAREST,
          wrap_s = .CLAMP_TO_EDGE,
          wrap_t = .CLAMP_TO_EDGE,
        };
        ogl_apply_tex_parameters_for_gl_tex_target(GL_TEXTURE_2D, params);
        glFramebufferTexture2D(GL_FRAMEBUFFER, xx (GL_COLOR_ATTACHMENT0 + i), GL_TEXTURE_2D, attachments[i], 0);
      }

      attachments_gl : [..] u32;
      attachments_gl.allocator = temp;
      for i : 0..attachment_count-1 { array_add(*attachments_gl, xx(GL_COLOR_ATTACHMENT0+i)); }
      glDrawBuffers(attachment_count, attachments_gl.data);

      ds_tex : GLuint;
      glGenTextures(1, *ds_tex);
      glBindTexture(GL_TEXTURE_2D, ds_tex);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, xx dim.x, xx dim.y, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
      params := oglTexParams.{
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        wrap_s = .CLAMP_TO_BORDER,
        wrap_t = .CLAMP_TO_BORDER,
      };
      ogl_apply_tex_parameters_for_gl_tex_target(GL_TEXTURE_2D, params);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, ds_tex, 0);

      assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
    };
    case; print("invalid RT texture format=[%]", format);
  }
  return (impl_state != null);
}
ogl_rt_bind :: (using rt : *oglRT, attachment_indices : []oglRTAttachment = .{}) {
  if attachment_indices.count == 0 {
    glBindFramebuffer(GL_FRAMEBUFFER, xx (ifx rt != null then impl_state else null));
  }else {
    // here we can bind only specific attachments, instead of the whole RT
    attachments_gl : [..] u32;
    attachments_gl.allocator = temp;
    for idx : attachment_indices { array_add(*attachments_gl, xx(GL_COLOR_ATTACHMENT0+idx)); }
    glDrawBuffers(xx attachments_gl.count, attachments_gl.data);
    glBindFramebuffer(GL_FRAMEBUFFER, xx (ifx rt != null then impl_state else null));
  }
}
ogl_rt_clear :: (using rt : *oglRT, color : v4 = .{0,0,0,0}) {
  ogl_rt_bind(rt);

  glClearColor(color.x,color.y,color.z,color.w);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT); // stencil?
  ogl_rt_bind(null);
}

ogl_rt_get_attachment :: (using rt : *oglRT, attachment : oglRTAttachment) -> oglTex {
  tex : oglTex;
  tex.dim = dim;
  tex.format = format;

  prev_fbo : GLuint;
  glGetIntegerv(GL_FRAMEBUFFER_BINDING, xx *prev_fbo);
  ogl_rt_bind(rt);
  if attachment == .DS {
    glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, xx GL_DEPTH_ATTACHMENT, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, xx *tex.impl_state);
  }else {
    glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, xx (GL_COLOR_ATTACHMENT0 + attachment), GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, xx *tex.impl_state);
  }
  // TODO: -- clean this up
  glBindFramebuffer(GL_FRAMEBUFFER, prev_fbo);
  // ---------------------
  return tex;
}

///////////////////////////////
// ogl Uniform Blocks

// FIXME: currently, arrays are not supported inside other arrays, i think @check
// FIXME: in GENERAL, uniform blocks do a lot of string stuff, they NEED to be faster!!
// TODO: Can we make this dynamic for ogl_ublock_load maybe?

OGL_MAX_VARS_PER_UB :: 32;

oglUBOVarInfo :: struct {
  //name : string;
  offset : s64;
  type : oglShaderDataType;
  count  : s64; // for array types, how many we got
}
oglUBOMetaData :: struct {
  table : Table(string, oglUBOVarInfo, null, null);
}
oglUBlock :: struct {
  uniform_buf : oglBuf;
  md : oglUBOMetaData;
  index : u32;
  name : string;
}
ogl_ublock_load :: (using ub : *oglUBlock, sp : *oglSP, block_index : u32 = 0) {
  init(*md.table, OGL_MAX_VARS_PER_UB);
  index = block_index;
  ublock_count : GLint;
  glGetProgramiv(xx sp.impl_state, GL_ACTIVE_UNIFORM_BLOCKS, *ublock_count);
  for i : 0..ublock_count-1 {
    binding : GLint;
    glGetActiveUniformBlockiv(xx sp.impl_state, xx i, GL_UNIFORM_BLOCK_BINDING, *binding);
    if cast(u32)binding == index {
      block_size : GLint;
      glGetActiveUniformBlockiv(xx sp.impl_state, xx i, GL_UNIFORM_BLOCK_DATA_SIZE, *block_size);
      ogl_buf_init(*uniform_buf, .UNIFORM, null, 1, xx block_size);
      var_count : GLint;
      glGetActiveUniformBlockiv(xx sp.impl_state, xx i, GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS, *var_count);
      var_indices : [OGL_MAX_VARS_PER_UB]GLuint;
      glGetActiveUniformBlockiv(xx sp.impl_state, xx i, GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES, xx var_indices.data);
      var_offsets: [OGL_MAX_VARS_PER_UB]GLint;
      glGetActiveUniformsiv(xx sp.impl_state, xx var_count, var_indices.data, GL_UNIFORM_OFFSET, xx var_offsets.data);

      for i : 0..var_count-1 {
        name : [256]u8;
        name_len : u32;
        array_count : s32;
        type : GLenum;
        glGetActiveUniform(xx sp.impl_state, var_indices[i], 256, *name_len, *array_count, *type, name.data);
        str_name : string = .{name_len, name.data};
        _, str_name = split_from_left(str_name, "["); // this way, str_name will have only name, not the [0] for arrays
        data_type := gl_data_type_to_ogl_data_type(xx type);
        var_info := oglUBOVarInfo.{var_offsets[i], data_type, array_count};
        vn := alloc_string(str_name.count);
        memcpy(vn.data, name.data, str_name.count);
        inline table_add(*md.table, vn, var_info);
        // optional - just for clarity
        _, found := table_find(*md.table, vn);
        assert(found);
      }
    }
  }
}

ogl_ublock_init :: (using ub : *oglUBlock, size : s64, block_index : u32 = 0) {
  init(*md.table, OGL_MAX_VARS_PER_UB);
  ogl_buf_init(*uniform_buf, .UNIFORM, null, 1, xx size);
  index = block_index;
}

ogl_ublock_deinit :: (using ub : *oglUBlock) {
  for val, key: md.table {
    free(key.data);
  }
  deinit(*md.table);
}

// binds Uniform Block in correct slot
ogl_ublock_bind_to_slot :: (using ub : *oglUBlock) {
  glBindBufferBase(GL_UNIFORM_BUFFER, xx index, xx uniform_buf.impl_state);
}

ogl_ublock_set :: (using ub : *oglUBlock, buf : *u8) {
  ogl_buf_update(*uniform_buf, buf, 1, xx ogl_buf_get_total_byte_count(*uniform_buf));
}

ogl_ublock_calc_array_offset :: (var_name : string) ->u32 {
  offset : u32 = 0;
  found,str := contains(var_name, #char "[");
  if found && str[str.count-1] == #char "]" {
    str.count -=1;
    for c,index : str {
      offset += xx ((c - #char "0") * pow(10.0, xx(str.count-index-1)));
    }
  }
  return offset;
}

ogl_ublock_set :: (using ub : *oglUBlock, var_name : string, data : *u8) -> bool {
  is_array,base_name,r := split_from_left(var_name, #char "[");
  var_info, found := table_find(*md.table, base_name);
  if found {
    array_offset := ifx is_array then ogl_ublock_calc_array_offset(var_name) else 0;
    data_size := ogl_get_component_num_for_data_type(var_info.type) * size_of(float32);
    data_size_aligned := ogl_get_component_num_for_data_type(.VEC4) * size_of(float32);
    // this max(..) is done to align with vec4's
    ogl_buf_sub_update(*uniform_buf, var_info.offset + ifx is_array max(data_size,data_size_aligned) * array_offset, data, 1, data_size);
    return true;
  }else {
    print("var % not found\n", var_name);
  }
  return false;
}

ogl_shader_data_type_match :: (type : string) -> bool {
  if type == {
    case "int";#through;
    case "float32";#through;
    case "float";#through;
    case "v2";#through;
    case "v3";#through;
    case "v4";#through;
    case "m4";
      return true;
    case;
      return false;
  }
}

// This will set each member from a struct to a shader uniform block - the less code the better! :D
// FIXME: i should think this better, maybe alignas(16) is all i need for structs? i need to work on introspection tbh
ogl_ublock_set_uniformable_struct :: (using ub : *oglUBlock, uni_struct : *$T, prefix : string) {
  ti_us := type_info(T);
  info_struct := cast(*Type_Info_Struct) ti_us;
  //print("%\n", info_struct.*);
  for m : info_struct.members {
    var_name := tprint("%.%", prefix, m.name);
    if m.type.type == {
      case .ARRAY;
        array_info := cast(*Type_Info_Array)m.type;
        //print("array_info: %\n", array_info.element_type.type);
        //for index : array_info.count {
        //  var_name := tprint("%[%]", var_name, index);
        //}
      case .STRUCT;
        struct_info := cast(*Type_Info_Struct)m.type;
        if ogl_shader_data_type_match(struct_info.name) {
          ogl_ublock_set(ub, var_name,  cast(*u8)uni_struct + m.offset_in_bytes);
        } else {
            ogl_ublock_set_uniformable_struct(ub, cast(*u8)uni_struct + m.offset_in_bytes, var_name);
        }
      case .POINTER;
      case .STRING;
      case .ENUM;
      case;
    }
  }
}
// A good hacky plan!!!! get via introspection the struct's first field so you have struct.field and set it via glBufferSubData,
// assuming the buffer is correctly aligned to be set to a shader! (std140 maybe)

///////////////////////////////
// ogl Bindings

oglVertexDef :: struct {
  vbuf : *oglBuf;
  attribs : []oglShaderAttrib;
};

oglBindingDesc :: struct {
  index_buf : *oglBuf;
  vertex_bufs : []oglVertexDef;
}


ogl_sp_apply_bindings :: (using sp : *oglSP, bindings : oglBindingDesc) {
  if bindings.index_buf {
    ogl_bind_index_buffer(bindings.index_buf);
  }
  enabled_locs : [OGL_MAX_ATTRIBS]bool;
  for *vbo, idx : bindings.vertex_bufs {
    if ogl_buf_get_total_byte_count(vbo.vbuf) == 0 then continue;
    ogl_bind_vertex_buffer(vbo.vbuf, vbo.attribs);
    ogl_bind_attribs(sp, vbo.vbuf, vbo.attribs);
    for attr : vbo.attribs {
      // check that the attribute is available in shader/attr_desc
      if sp.attribs[attr.loc].available {
        enabled_locs[attr.loc] = true;
      }
    }
  }
  for idx : 0..OGL_MAX_ATTRIBS-1 {
    if !enabled_locs[idx] {
      glDisableVertexAttribArray(xx idx);
    }
  }
}

///////////////////////////////
// ogl Dynamic state 

// TODO: needs a LOT of work, current customizability is very minimal

oglDynState :: struct {
  viewport : v4;
  scissor : v4;
  flags : oglDynStateFlags;
  extra_flags : s64;
}

oglDynStateFlags :: enum_flags u16 {
  NONE    :: 0x0;
  DEPTH   :: 0x1;
  CULL    :: 0x2;
  STENCIL :: 0x4;
  BLEND   :: 0x8;
}

ogl_dyn_state_to_gl_state :: (state : oglDynStateFlags) -> GLuint {
  gl_state : GLuint = 0;
  if state == {
    case .DEPTH; gl_state = GL_DEPTH_TEST;
    case .CULL; gl_state = GL_CULL_FACE;
    case .STENCIL; gl_state = GL_STENCIL_TEST;
    case .BLEND; gl_state = GL_BLEND;
    case .NONE; gl_state = 0;
    case; print("invalid state=[%]", state);
  }
  return gl_state;
}

ogl_sp_unset_dyn_state :: (state : oglDynStateFlags) {
  gl_state : GLuint = ogl_dyn_state_to_gl_state(state);
  glDisable(gl_state);
}
ogl_sp_set_dyn_state :: (state : oglDynStateFlags, extra_flags : s64) {
  gl_state : GLuint = ogl_dyn_state_to_gl_state(state);
  glEnable(gl_state);
  if state == {
    case .DEPTH; ifx extra_flags glDepthFunc(GL_ALWAYS) else glDepthFunc(GL_LEQUAL);
    case .CULL; glCullFace(GL_BACK);
    case .STENCIL; glStencilFunc(GL_EQUAL, 1, 0xFF);
    case .BLEND; glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    case; print("invalid set on state=[%]", state);
  }
}

ogl_sp_apply_dyn_state :: (sp : *oglSP, dyn_state : oglDynState) {
  ogl_set_viewport(dyn_state.viewport);
  ogl_set_scissor(dyn_state.scissor);
  for state : enum_values_as_s64(oglDynStateFlags) {
    if state & cast(s64)dyn_state.flags > 0 {
      ogl_sp_set_dyn_state(cast(oglDynStateFlags)state, dyn_state.extra_flags);
    } else {
      ogl_sp_unset_dyn_state(cast(oglDynStateFlags)state);
    }
  }
}


///////////////////////////////
// ogl Context

oglContext :: struct {
vao : GLuint;
initialized : bool;
};
global_context : oglContext;

ogl_init :: () {
  assert(glGenVertexArrays != null);
  glGenVertexArrays(1, *global_context.vao);
  glBindVertexArray(global_context.vao);
  print("ogl is FINE!\n");
}
ogl_deinit :: () {
  glDeleteVertexArrays(1, *global_context.vao);
}
ogl_set_viewport :: (x : float32 , y : float32, w : float32, h : float32) {
  glViewport(xx x,xx y,xx w,xx h);
}
ogl_set_viewport :: (vp : v4) {
  glViewport(xx vp.x,xx vp.y,xx vp.z,xx vp.w);
}
ogl_set_scissor :: (x : float32 , y : float32, w : float32, h : float32) {
  glScissor(xx x,xx y,xx w,xx h);
}
ogl_set_scissor :: (sc : v4) {
  glScissor(xx sc.x,xx sc.y,xx sc.z,xx sc.w);
}
ogl_clear_all_state :: () {
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  ogl_bind_vertex_buffer(null);
  ogl_bind_index_buffer(null);
  ogl_bind_uniform_buffer(null);
  for i : 0..OGL_MAX_ATTRIBS-1 {
    glDisableVertexAttribArray(xx i);
  }
  for i : 0..OGL_MAX_TEX_SLOTS-1 {
    glActiveTexture(xx (GL_TEXTURE0 + i));
    glBindTexture(GL_TEXTURE_2D, 0);
  }
  glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_STENCIL_TEST);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);
  glBindVertexArray(global_context.vao);
}
