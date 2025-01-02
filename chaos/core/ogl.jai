#import "Basic";
#import "String";
#import "GL" (DUMP_GL_ERRORS=true, ENABLE_ALL_EXTENSIONS=true);

// TODO: minimize the code: texture/RT generation could be improved a lot - the less code the better!

/*
Exposition:
  OpenGL SUCKS! Tons of global state, undefined behaviour, horrible anachronistic API and countless other things. It does one thing right though, cross-platform support. Pretty much every OS supports OpenGLES3. ogl is a wrapper that addresses most issues plaguing current-day OpenGL. The interface is modern enough (D3D11 look and feel), which is a sweet spot because you can prototype fast without having to think about synchronization or pipelines or other low level stuff. Its a single-file OpenGL abstraction that is Gud enough.
General usage:
  The basis around this wrapper is the SP (shader program), it ecompasses most of the drawcall. You should initialize your SP with correct attributes from your GLSL shaders. To begin drawing you first bind your Render Target (null for fbo0), then bind the SP then you bind the vertex and index buffer along with any shader bindings (be it texture samplers or uniform blocks) and also any dynamic state you wish to configure (for example enable depth testing with LESS condition) and then you simply draw your specified amount of vertices.
Sample drawcall:
  ogl_bind_rt(*my_rt);
  ogl_bind_sp(*my_sp);
  ogl_set_viewport(0,0,my_rt.dim.x, my_rt.dim.y);
  ogl_set_scissor(0,0,my_rt.dim.x, my_rt.dim.y);
  ogl_bind_vertex_buffer(*my_vbo);
  ogl_bind_index_buffer(*my_ibo);
  ogl_add_binding(0,0, *ublock_0);
  ogl_add_binding(0,1, *tex0);
  ogl_draw(.TRIANGLES, 0, 36);
*/


///////////////////////////////
// ogl Constants
///////////////////////////////
OGL_MAX_ATTRIBS :: 8;
OGL_MAX_TEX_SLOTS :: 8;


///////////////////////////////
// ogl Buffers
///////////////////////////////

oglBufKind :: enum {
  VERTEX;
  INDEX;
  UNIFORM;
};
oglBuf :: struct {
  count      : s64;
  // @CHECK: is this per-element or for all?
  size       : s64; //in bytes
  kind       : oglBufKind;
  impl_state : *void;
};

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
ogl_buf_init :: (using buf : *oglBuf, bkind : oglBufKind, data : *void, data_count : u32, data_size : u32) -> bool {
  kind = bkind;
  count = data_count;
  size = data_size * data_count;
  buffer_kind := ogl_buf_to_gl_buf(kind);
  glGenBuffers(1, xx *impl_state);
  glBindBuffer(buffer_kind, xx buf.impl_state);
  ogl_buf_update(buf, data,data_count,data_size);
  glBindBuffer(buffer_kind, 0);
  return true;
}
// TODO the using's should be in function declaration
ogl_buf_deinit :: (using buf : *oglBuf) -> bool {
  glDeleteBuffers(1, xx impl_state);
  return true;
}
ogl_buf_update :: (using buf : *oglBuf, data : *void, data_count : u32, data_size : u32) {
  count = data_count;
  size = data_size * data_count;
  buffer_kind := ogl_buf_to_gl_buf(kind);
  glBindBuffer(buffer_kind, xx buf.impl_state);
  //if data != null {
  glBufferData(buffer_kind, size, data, GL_STREAM_DRAW);
  //}
}
ogl_buf_sub_update :: (using buf : *oglBuf, offset : s64, data : *void, data_count : u32, data_size : u32) {
  buffer_kind := ogl_buf_to_gl_buf(kind);
  glBindBuffer(buffer_kind, xx buf.impl_state);
  s := data_size * data_count;
  if data != null {
    buffer_kind := ogl_buf_to_gl_buf(kind);
    glBufferSubData(buffer_kind, offset, s, data);
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
///////////////////////////////
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
    glVertexAttribIPointer(loc, cast(GLint)ogl_get_component_num_for_data_type(type), GL_INT, stride, cast(*void)offset);
  } else {
    glVertexAttribPointer(loc, cast(GLint)ogl_get_component_num_for_data_type(type), GL_FLOAT, GL_FALSE, stride, cast(*void)offset);
  }
  glVertexAttribDivisor(loc, cast(GLuint)instanced);
}

ogl_bind_attribs :: (sp : * oglSP, vbo : *oglBuf, attribs : []oglShaderAttrib){
  for i : 0..attribs.count-1 {
    attrib : oglShaderAttrib = attribs[i];
    if attrib.stride == 0 then attrib.stride = cast(u32)vbo.size / cast(u32)vbo.count;
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
///////////////////////////////

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
ogl_draw_indexed :: (prim : oglPrimitive, count : u32, index_size :s64= size_of(u32)) {
  glDrawElements(ogl_prim_to_gl_prim(prim), count, xx ifx index_size == size_of(u32) then GL_UNSIGNED_INT else GL_UNSIGNED_SHORT, null);
}
///////////////////////////////
// ogl Textures
///////////////////////////////

oglTexFormat :: enum {
  R8U;
  RGBA8U;
  RGB8U;

  RGBA32F;
  R32F;
  D32F; // will create array texture FBO for layered rendering
};
oglTex :: struct {
  dim : v2;
  format : oglTexFormat;
  impl_state : *void;
};

ogl_tex_init :: (using tex : *oglTex, dimensions : v2, data : *u8, data_format : oglTexFormat) -> bool {
  dim = dimensions;
  format = data_format;

  tex_format : GLuint = 0;
  if #complete format == {
    case oglTexFormat.RGBA8U; #through;
    case oglTexFormat.RGB8U; {
      tex_format = xx (ifx format == oglTexFormat.RGBA8U then GL_RGBA else GL_RGB);
      glGenTextures(1, xx *impl_state);
      glBindTexture(GL_TEXTURE_2D, cast(GLuint)impl_state);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, xx dim.x, xx dim.y, 0, tex_format, GL_UNSIGNED_BYTE, data);
      glGenerateMipmap(GL_TEXTURE_2D);
    };
    case oglTexFormat.R8U; {
      glGenTextures(1, xx *impl_state);
      glBindTexture(GL_TEXTURE_2D, cast(GLuint)impl_state);
      glPixelStorei(GL_UNPACK_ALIGNMENT, 1); // NOTE: is this really needed? its used only for font rendering random access
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, xx dim.x, xx dim.y, 0, GL_RED, GL_UNSIGNED_BYTE, data);
    };
    case oglTexFormat.RGBA32F; #through;
    case oglTexFormat.R32F; #through;
    case oglTexFormat.D32F; #through;
    case; print("invalid texture format=[%]", format);
  }
  return (impl_state != null);
}
ogl_tex_deinit :: (tex : *oglTex) {
  using tex;
  glDeleteTextures(1,xx *impl_state);
}

ogl_bind_tex_to_slot :: (using tex : *oglTex, slot : u32) {
  glActiveTexture(GL_TEXTURE0 + slot);
  glBindTexture(xx ifx tex.format == .D32F then GL_TEXTURE_2D_ARRAY else GL_TEXTURE_2D, cast(GLuint)impl_state);
}

// TODO: maybe instead of sampler_name provide (binding=1) ?
ogl_sp_bind_sampler_to_slot :: (using sp : *oglSP, sampler_name : string, tex : * oglTex, slot : u32) {
  ogl_bind_tex_to_slot(tex, slot);
  ogl_sp_set_uniform(sp, sampler_name, oglShaderDataType.INT , *slot);
}
///////////////////////////////
// ogl RTs
///////////////////////////////

oglRTAttachment :: enum { A0; A1; A2; A3; DS; };
oglRT :: struct {
  dim : v2;
  format : oglTexFormat; // for color attachments
  impl_state : *void;
};
ogl_rt_init :: (using rt : *oglRT, rt_dim : v2, rt_img_format : oglTexFormat) -> bool {
  dim = rt_dim;
  format = rt_img_format;
  tex_format : GLuint;
  attachments : [4]GLuint;

  if #complete format == {
    case oglTexFormat.D32F;
      glGenFramebuffers(1, xx *impl_state);
      cascade_count :: 4; // FIXME: we should have a MAX_COUNT - maybe use/set the one from frustum.jai
      g_light_depth_maps : GLuint;
      glGenTextures(1, *g_light_depth_maps);
      glBindTexture(GL_TEXTURE_2D_ARRAY, g_light_depth_maps);
      glTexImage3D( GL_TEXTURE_2D_ARRAY, 0, GL_DEPTH_COMPONENT32F, xx dim.x, xx dim.y,cascade_count+1,0, GL_DEPTH_COMPONENT, GL_FLOAT, xx 0);
      glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
      glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
      border_color := float32.[1,1,1,1];
      glTexParameterfv(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_BORDER_COLOR, border_color.data);
      glBindFramebuffer(GL_FRAMEBUFFER, xx impl_state);
      glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, g_light_depth_maps, 0);
      glDrawBuffer(GL_NONE);
      glReadBuffer(GL_NONE);
      assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
      glBindFramebuffer(GL_FRAMEBUFFER, xx 0);
    case oglTexFormat.R32F; #through;
    case oglTexFormat.RGBA32F; {
      tex_format = xx (ifx format == oglTexFormat.RGBA32F then GL_RGBA32F else GL_R32F);
      internal_format :GLuint = xx (ifx format == oglTexFormat.RGBA32F then GL_RGBA else GL_RED);
      glGenFramebuffers(1, xx *impl_state);
      glBindFramebuffer(GL_FRAMEBUFFER, xx impl_state);
      // - position color buffer
      glGenTextures(1, *attachments[0]);
      glBindTexture(GL_TEXTURE_2D, attachments[0]);
      glTexImage2D(GL_TEXTURE_2D, 0, xx tex_format, xx dim.x, xx dim.y, 0, internal_format, GL_FLOAT, null);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, attachments[0], 0);
      // - normal color buffer
      glGenTextures(1, *attachments[1]);
      glBindTexture(GL_TEXTURE_2D, attachments[1]);
      glTexImage2D(GL_TEXTURE_2D, 0, xx tex_format, xx dim.x, xx dim.y, 0, internal_format, GL_FLOAT, null);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, attachments[1], 0);
      // - color + specular color buffer
      glGenTextures(1, *attachments[2]);
      glBindTexture(GL_TEXTURE_2D, attachments[2]);
      glTexImage2D(GL_TEXTURE_2D, 0, xx tex_format, xx dim.x, xx dim.y, 0, internal_format, GL_FLOAT, null);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, attachments[2], 0);
      attachments_gl := u32.[ GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2 ];
      glDrawBuffers(3, *attachments_gl[0]);
      ds_tex : GLuint;
      glGenTextures(1, *ds_tex);
      glBindTexture(GL_TEXTURE_2D, ds_tex);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, xx dim.x, xx dim.y, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
      border_col := float32.[1.0, 1.0, 1.0, 1.0];
      glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, border_col.data);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, ds_tex, 0);

      assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
    };
    case oglTexFormat.RGBA8U; #through;
    case oglTexFormat.RGB8U; #through;
    case oglTexFormat.R8U; #through;
    case; print("invalid RT texture format=[%]", format);
  }
  return (impl_state != null);
}
ogl_rt_bind :: (using rt : *oglRT) {
  glBindFramebuffer(GL_FRAMEBUFFER, xx (ifx rt != null then impl_state else null));
}
ogl_rt_clear :: (using rt : *oglRT) {
  ogl_rt_bind(rt);

  glClearColor(0.0, 0.0, 0.0, 0.0);
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
///////////////////////////////

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
  ogl_buf_update(*uniform_buf, buf, 1, xx uniform_buf.size);
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
///////////////////////////////

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
    if vbo.vbuf.size == 0 then continue;
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
///////////////////////////////

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
///////////////////////////////

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
