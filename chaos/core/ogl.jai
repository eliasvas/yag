#import "Basic";
#import "String";
#import "GL" (DUMP_GL_ERRORS=true, ENABLE_ALL_EXTENSIONS=true);
#load "def_shaders.jai";

// for debugging
//assert(glGetError() == GL_NO_ERROR);

/*
    ogl: this is a simple abstraction over OpenGLES3 that makes the API much more sane, no more global state.
    The library contains some primitive types for rendering. Namely:

    oglSP - shader program - you pass fragment+vertex shaders to create a shader program
    oglShaderAttrib - shader attrib description - describe whats inside your vertex buffer
    oglBuf - gpu buffer - your index/vertex/uniform buffer
    oglTex - regular texture - you provide a data pointer + dimensions + internal format
    oglRT - render target - contains textures as attachments (4xCOL + 1xDS)
    oglPrimitive - rendering primitive - the primitive you wanna use to draw your draw-call
*/

///////////////////////////////
// ogl Constants
///////////////////////////////
OGL_MAX_ATTRIBS :: 16;
OGL_MAX_TEX_SLOTS :: 4;


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
    size       : s64; //in bytes
    kind       : oglBufKind;
    impl_state : *void;
};

// TODO: Currently only vertex/index buffers are supported, do uniform buffers as well
ogl_buf_init :: (buf : *oglBuf, bkind : oglBufKind, data : *void, data_count : u32, data_size : u32) -> bool {
    using buf;
    kind = bkind;
    count = data_count;
    size = data_size * data_count;

    buffer_kind : GLuint = xx (ifx kind == oglBufKind.VERTEX then GL_ARRAY_BUFFER else GL_ELEMENT_ARRAY_BUFFER);

    glGenBuffers(1, xx *impl_state);
    glBindBuffer(buffer_kind, xx buf.impl_state);
    ogl_buf_update(buf, data,data_count,data_size);
    glBindBuffer(buffer_kind, 0);
    //ogl_check_error();
    return true;
}
ogl_buf_deinit :: (buf : *oglBuf) -> bool {
    using buf;
    glDeleteBuffers(1, xx impl_state);
    return true;
}
ogl_buf_update :: (buf : *oglBuf, data : *void, data_count : u32, data_size : u32) {
    using buf;
    ogl_bind_vertex_buffer(buf);
    count = data_count;
    size = data_size * data_count;
    buffer_kind : GLuint = xx (ifx kind == oglBufKind.VERTEX then GL_ARRAY_BUFFER else GL_ELEMENT_ARRAY_BUFFER);
    if data != null {
        glBufferData(buffer_kind, size, data, GL_STREAM_DRAW);
    }
}
ogl_bind_index_buffer :: (buf : *oglBuf) {
    using buf;
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, xx impl_state);
}
ogl_bind_vertex_buffer :: (buf : *oglBuf) {
    using buf;
    glBindBuffer(GL_ARRAY_BUFFER, xx impl_state);
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

oglShaderAttrib :: struct {
    vbo_idx   : u32;
    stride    : u32;
    offset    : u32;
    type      : oglShaderDataType;
    instanced : bool; // whether the attribute is instanced
};
oglSP :: struct {
    attribs      : [OGL_MAX_ATTRIBS]oglShaderAttrib;
    attrib_count : s64;
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
gl_make_sp :: (vs_source : string, fs_source : string) -> GLuint {
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

    sp = glCreateProgram();
    glAttachShader(sp, vs);
    glAttachShader(sp, fs);
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
ogl_attrib_make :: (vbo_idx : u32, type : oglShaderDataType, stride : u32, offset : u32, instanced : bool) -> oglShaderAttrib {
    return oglShaderAttrib.{ vbo_idx, stride, offset, type, instanced };
}
ogl_sp_init :: (shader : *oglSP, vs_source : string, fs_source : string) -> bool {
    using shader;
    impl_state = cast(*void)gl_make_sp(vs_source, fs_source);
    attrib_count = 0;
    //ogl_check_error();
    return (cast(s64)impl_state !=0);
}
ogl_sp_deinit :: (shader : *oglSP) -> bool {
    using shader;
    glDeleteProgram(cast(GLuint)impl_state);
    return true;
}
ogl_sp_add_attrib :: (shader : *oglSP, attrib : oglShaderAttrib) {
    using shader;
    attribs[attrib_count] = attrib;
    attrib_count += 1;
    // TODO: This probably should be like a dynamic array [..]
    assert(attrib_count < OGL_MAX_ATTRIBS);
}
ogl_bind_attrib :: (attrib : *oglShaderAttrib) {
    using attrib;
    glEnableVertexAttribArray(vbo_idx);
    if type == oglShaderDataType.INT {
        glVertexAttribIPointer(vbo_idx, cast(GLint)ogl_get_component_num_for_data_type(type), GL_FLOAT, stride, cast(*void)offset);
    } else {
        glVertexAttribPointer(vbo_idx, cast(GLint)ogl_get_component_num_for_data_type(type), GL_FLOAT, GL_FALSE, stride, cast(*void)offset);
        //assert(glGetError() == GL_NO_ERROR);
    }
    glVertexAttribDivisor(vbo_idx, cast(GLuint)instanced);
}
ogl_sp_bind_attribs :: (shader : *oglSP){
    using shader;
    for i : 0..max(0,attrib_count-1) {
        ogl_bind_attrib(*attribs[i]);
    }
}
ogl_bind_sp :: (shader : *oglSP){
    using shader;
    glUseProgram(cast(GLuint)impl_state);
    ogl_sp_bind_attribs(shader);
}
ogl_sp_set_uniform :: (shader : *oglSP, uniform_name : string, type : oglShaderDataType, val : *void){
    using shader;
    if #complete type == {
	case .FLOAT; glUniform1fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
	case .VEC2; glUniform2fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
	case .VEC3; glUniform3fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
	case .VEC4; glUniform4fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, cast(*float32)val);
	case .MAT4; glUniformMatrix4fv(glGetUniformLocation(cast(GLuint)impl_state, uniform_name.data), 1, GL_TRUE, cast(*float32)val);
	case .INT; #through;
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
};


ogl_prim_to_gl_prim :: (prim : oglPrimitive) -> GLuint {
    gl_prim : GLuint = 0;
    if #complete prim == {
	case .TRIANGLES; gl_prim = GL_TRIANGLES;
	case .TRIANGLE_STRIP; gl_prim = GL_TRIANGLE_STRIP;
	case .TRIANGLE_FAN; gl_prim = GL_TRIANGLE_FAN;
	case .LINES; gl_prim = GL_LINES;
	case .LINE_STRIP; gl_prim = GL_LINE_STRIP;
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
};

ogl_dyn_state_to_gl_state :: (state : oglDynState) -> GLuint {
    gl_state : GLuint = 0;
    if #complete state == {
	case .DEPTH; gl_state = GL_DEPTH_TEST;
	case .CULL; gl_state = GL_CULL_FACE;
	case .STENCIL; gl_state = GL_STENCIL_TEST;
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
};
oglTex :: struct {
    dim : v2;
    format : oglTexFormat;
    impl_state : *void;
};

ogl_tex_init :: (tex : *oglTex, dimensions : v2, data : *u8, data_format : oglTexFormat) -> bool {
    using tex;
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
	case; print("invalid texture format=[%]", format);
    }
    return (impl_state != null);
}
ogl_tex_deinit :: (tex : *oglTex) {
    using tex;
    glDeleteTextures(1,xx *impl_state);
}
ogl_bind_tex_to_slot :: (tex : *oglTex, slot : u32) {
    using tex;
    glActiveTexture(GL_TEXTURE0 + slot);
    glBindTexture(GL_TEXTURE_2D, cast(GLuint)impl_state);
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
ogl_rt_init :: (rt : *oglRT, rt_dim : v2, rt_img_format : oglTexFormat) -> bool {
    using rt;
    dim = rt_dim;
    format = rt_img_format;
    tex_format : GLuint;
    attachments : [4]GLuint;

    if #complete format == {
	case oglTexFormat.RGBA32F; {
            glGenFramebuffers(1, xx *impl_state);
            glBindFramebuffer(GL_FRAMEBUFFER, xx impl_state);
            // - position color buffer
            glGenTextures(1, *attachments[0]);
            glBindTexture(GL_TEXTURE_2D, attachments[0]);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, xx dim.x, xx dim.y, 0, GL_RGBA, GL_FLOAT, null);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, attachments[0], 0);
            // - normal color buffer
            glGenTextures(1, *attachments[1]);
            glBindTexture(GL_TEXTURE_2D, attachments[1]);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, xx dim.x, xx dim.y, 0, GL_RGBA, GL_FLOAT, null);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, attachments[1], 0);
            // - color + specular color buffer
            glGenTextures(1, *attachments[2]);
            glBindTexture(GL_TEXTURE_2D, attachments[2]);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, xx dim.x, xx dim.y, 0, GL_RGBA, GL_FLOAT, null);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, attachments[2], 0);
	    attachments_gl := u32.[ GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2 ];
            glDrawBuffers(3, *attachments_gl[0]);
	    rbo : GLuint;
            glGenRenderbuffers(1, *rbo);
            glBindRenderbuffer(GL_RENDERBUFFER, rbo);
            glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, xx dim.x, xx dim.y);
            glBindRenderbuffer(GL_RENDERBUFFER, 0);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo);
            assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
	};
	case oglTexFormat.RGBA8U; #through;
	case oglTexFormat.RGB8U; #through; 
	case oglTexFormat.R8U; #through; 
	case; print("invalid RT texture format=[%]", format);
    }
    return (impl_state != null);
}
ogl_rt_bind :: (rt : *oglRT) {
    using rt;
    glBindFramebuffer(GL_FRAMEBUFFER, xx (ifx rt != null then impl_state else null));
}
ogl_rt_clear :: (rt : *oglRT) {
    using rt;
    ogl_rt_bind(rt);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); // stencil?
    ogl_rt_bind(null);
}
ogl_rt_get_attachment :: (rt : *oglRT, attachment : oglRTAttachment) -> oglTex {
    using rt;
    tex : oglTex;
    tex.dim = dim;
    tex.format = format;

    prev_fbo : GLuint;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, xx *prev_fbo);
    ogl_rt_bind(rt);
    glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, xx (GL_COLOR_ATTACHMENT0 + attachment), GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, xx *tex.impl_state);
    // TODO: -- clean this up
    glBindFramebuffer(GL_FRAMEBUFFER, prev_fbo);
    // ---------------------
    return tex;
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
    print("ogl is FINE!\n");
}
ogl_deinit :: () {
    glDeleteVertexArrays(1, *global_context.vao);
}
ogl_set_viewport :: (x : float32 , y : float32, w : float32, h : float32) {
    glViewport(xx x,xx y,xx w,xx h);
}
ogl_set_scissor :: (x : float32 , y : float32, w : float32, h : float32) {
    glScissor(xx x,xx y,xx w,xx h);
}
ogl_clear_all_state :: () {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindVertexArray(xx global_context.vao);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    for i : 0..OGL_MAX_ATTRIBS-1 {
        glDisableVertexAttribArray(xx i);
    }
    for i : 0..OGL_MAX_TEX_SLOTS-1 {
        glActiveTexture(xx (GL_TEXTURE0 + i));
        glBindTexture(GL_TEXTURE_2D, 0);
    }
    glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
    glBindVertexArray(global_context.vao);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_STENCIL_TEST);
    glDisable(GL_CULL_FACE);
    glDisable(GL_BLEND);
    glLineWidth(4);
}
