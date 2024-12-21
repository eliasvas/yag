#import "Basic";
#import "String";
#import "GL" (DUMP_GL_ERRORS=true, ENABLE_ALL_EXTENSIONS=true);
#load "def_shaders.jai";

// FIXME: currently state management is done via ogl_state_clear_all(), this is not fine,
// we'll have to think of a better way sadly, maybe i need to re-study the sokol architecture..
// maybe some sort of cache should be implemented inside our oglContext
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
  count = data_count;
  size = data_size * data_count;
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

  //bp_attribs := oglShaderAttrib.[
  //  ogl_attrib_make(0,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code pos),false),
  //  ogl_attrib_make(1,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code norm),false),
  //  ogl_attrib_make(2,oglShaderDataType.VEC2,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code tc),false)
  //];
ogl_bind_vertex_buffer :: (using buf : *oglBuf, attribs : []oglShaderAttrib = .[]) {
  if buf {
    glBindBuffer(GL_ARRAY_BUFFER, xx impl_state);
  } else {
    glBindBuffer(GL_ARRAY_BUFFER, 0);
  }
  ogl_bind_attribs(attribs);
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
  attribs      : []oglShaderAttrib;
  impl_state   : *void;
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
    case .VEC2;  comp_count = 2;
    case .VEC3;  comp_count = 3;
    case .VEC4;  comp_count = 4;
    case .MAT4;  comp_count = 16;
    case; print("invalid shader type=[%]", type);
  }
  return comp_count;
}

// TODO: first offset then stride in function def
ogl_attrib_make :: (loc : u32, type : oglShaderDataType, stride : u32, offset : u32, instanced : bool) -> oglShaderAttrib {
  return oglShaderAttrib.{ loc, offset,stride, type, instanced };
}

ogl_sp_init :: (using sp: *oglSP, vs_source : string, fs_source : string) -> bool { return ogl_sp_init(sp, vs_source, "", fs_source); }
ogl_sp_init :: (using sp: *oglSP, vs_source : string, gs_source : string, fs_source : string) -> bool {
  impl_state = cast(*void)gl_make_sp(vs_source, fs_source, gs_source);
  //ogl_check_error();
  return (cast(s64)impl_state !=0);
}
ogl_sp_deinit :: (using sp : *oglSP) -> bool {
  glDeleteProgram(cast(GLuint)impl_state);
  return true;
}
ogl_bind_attrib :: (attrib : *oglShaderAttrib) {
  using attrib;
  glEnableVertexAttribArray(loc); 
  if type == oglShaderDataType.INT {
    glVertexAttribIPointer(loc, cast(GLint)ogl_get_component_num_for_data_type(type), GL_FLOAT, stride, cast(*void)offset);
  } else {
    glVertexAttribPointer(loc, cast(GLint)ogl_get_component_num_for_data_type(type), GL_FLOAT, GL_FALSE, stride, cast(*void)offset);
  }
  glVertexAttribDivisor(loc, cast(GLuint)instanced);
}
ogl_bind_attribs :: (attribs : []oglShaderAttrib){
  for i : 0..attribs.count-1 {
    ogl_bind_attrib(*attribs[i]);
  }
}
ogl_bind_sp :: (using sp : *oglSP){
  //ogl_clear_all_state();
  glUseProgram(cast(GLuint)impl_state);
}
ogl_sp_set_uniform :: (using sp : *oglSP, uniform_name : string, type : oglShaderDataType, val : *void){
  if #complete type == {
    case .FLOAT; glUniform1fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
    case .VEC2; glUniform2fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
    case .VEC3; glUniform3fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
    case .VEC4; glUniform4fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
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
ogl_draw_indexed :: (prim : oglPrimitive, count : u32) {
  glDrawElements(ogl_prim_to_gl_prim(prim), count, GL_UNSIGNED_INT, null);
}

///////////////////////////////
// ogl Dynamic State
///////////////////////////////
// TODO: needs a LOT of work, current customizability is very minimal

oglDynState :: enum {
  DEPTH;
  CULL;
  STENCIL;
  BLEND;
  BLEND2;
};

ogl_dyn_state_to_gl_state :: (state : oglDynState) -> GLuint {
  gl_state : GLuint = 0;
  if #complete state == {
    case .DEPTH; gl_state = GL_DEPTH_TEST;
    case .CULL; gl_state = GL_CULL_FACE;
    case .STENCIL; gl_state = GL_STENCIL_TEST;
    case .BLEND2; #through;
    case .BLEND; gl_state = GL_BLEND;
    case; print("invalid state=[%]", state);
  }
  return gl_state;
}
ogl_sp_set_dyn_state :: (shader : *oglSP, state : oglDynState) {
  gl_state : GLuint = ogl_dyn_state_to_gl_state(state);
  glEnable(gl_state);
  if #complete state == {
    case .DEPTH; glDepthFunc(GL_LESS);
    case .CULL; glCullFace(GL_BACK);
    case .STENCIL; glStencilFunc(GL_EQUAL, 1, 0xFF);
    case .BLEND; glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);glBlendEquationSeparate(GL_FUNC_ADD, GL_FUNC_ADD);glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    case .BLEND2;glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    case; print("invalid set on state=[%]", state);
  }
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

// TODO: make a SANE texture slot API, currently we bind_to_slot + set_uni(.INT, tex_slot)
ogl_bind_tex_to_slot :: (using tex : *oglTex, slot : u32) {
  glActiveTexture(GL_TEXTURE0 + slot);
  glBindTexture(xx ifx tex.format == .D32F then GL_TEXTURE_2D_ARRAY else GL_TEXTURE_2D, cast(GLuint)impl_state);
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

// TODO: Can we make this dynamic for ogl_ublock_load maybe?
OGL_MAX_VARS_PER_UB :: 32;

// TODO: maybe we shouldn't call them just 'vars'
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
        str_name : string;
        str_name.data = name.data;
        str_name.count = name_len;
        data_type := gl_data_type_to_ogl_data_type(xx type);
        var_info := oglUBOVarInfo.{var_offsets[i], data_type, array_count};
        //print("var % = %\n", str_name, var_info);
        vn := alloc_string(name_len);
        memcpy(vn.data, name.data, name_len);
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

ogl_ublock_set :: (using ub : *oglUBlock, var_name : string, data : *u8) -> bool {
  var_info, found := table_find(*md.table, var_name);
  if found {
    data_size := ogl_get_component_num_for_data_type(var_info.type) * size_of(float32);
    ogl_buf_sub_update(*uniform_buf, var_info.offset, data, xx var_info.count, data_size);
    return true;
  }else {
    print("var % not found\n", var_name);
  }
  return false;
}

///////////////////////////////
// ogl Bindings 
///////////////////////////////

oglBindingDesc :: struct {
  index_buf : *oglBuf;
  vertex_bufs : []oglBuf;
  attribs : [][]oglShaderAttrib; // for each vertex buf, its attribs
}

ogl_sp_apply_bindings :: (using sp : *oglSP, bindings : oglBindingDesc) {
  if bindings.index_buf {
    ogl_bind_index_buffer(bindings.index_buf);
  }
  for *vbo, idx : bindings.vertex_bufs {
    ogl_bind_vertex_buffer(vbo, bindings.attribs[idx]);
  } 

  // disable unused locs by default
  enabled_locs : [OGL_MAX_ATTRIBS]bool;
  for attrib_arr, idx : bindings.attribs {
    for attr_idx : bindings.attribs[idx] {
      enabled_locs[attr_idx.loc] = true;
    }
  }
  for idx : 0..OGL_MAX_ATTRIBS {
    if !enabled_locs {
      glDisableVertexAttribArray(xx idx);
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
ogl_clear_all_state :: () {
  //glBindFramebuffer(GL_FRAMEBUFFER, 0);
  //glBindVertexArray(global_context.vao);
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
  // strictly for debugging purposes
  glLineWidth(4);
  glEnable(GL_PROGRAM_POINT_SIZE);
  glPointSize(10);
}
