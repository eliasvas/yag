
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

  quad_instances : [..]PackedQuadVertex;
  quad_instances_tex_tags : [..]xAssetTag; // texture asset per quad instance
}

xr2d_init :: (using rend : *xRend2D) {
  ogl_sp_init(*sp, QUAD_VERT_SHADER, QUAD_FRAG_SHADER);
  ogl_ublock_load(*sp_ub1, *sp, 1);

  vertex_def.vbuf = New(oglBuf);
  attribs :: #run oglShaderAttrib.[.{loc=0,offset=cast(u32)offset_of(QuadVertex,#code pos)},.{loc=1,offset=cast(u32)offset_of(QuadVertex,#code color)},.{loc=2,offset=cast(u32)offset_of(QuadVertex,#code tc)}];
  vertex_def.attribs = attribs;

  initialized = true;
}

xr2d_deinit :: (using rend : *xRend2D) {
  ogl_sp_deinit(*sp);
  //ogl_ublock_deinit(*sp_ub1, *sp, 1);
  ogl_buf_deinit(vertex_def.vbuf);
  free(vertex_def.vbuf);
  array_reset(*quad_instances);
  array_reset(*quad_instances_tex_tags);
  initialized = false;
}

xr2d_imm_render_quad :: (using rend : *xRend2D, r : v4, texcoords : v4, col : v4, cam : *xCamera2D, tex : *oglTex = null) {
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

PackedQuadVertex :: struct {
  p0    : v2;
  p1    : v2;
  t0    : v2;
  t1    : v2;
  color : v4;
  roundness : float;
  sampler_id : u32; // this will be filled by the renderer
}

// This is so retarded I cant even..
xr2d_begin :: () -> *xRend2D {
  push_context .{allocator=temp} {
    using rend : *xRend2D = New(xRend2D);
    ogl_sp_init(*sp, PACKED_QUAD_VERT_SHADER, PACKED_QUAD_FRAG_SHADER);
    ogl_ublock_load(*sp_ub1, *sp, 1);

    vertex_def.vbuf = New(oglBuf);
    attribs :: #run oglShaderAttrib.[
      .{loc=0,offset=cast(u32)offset_of(PackedQuadVertex,#code p0), instanced=true},
      .{loc=1,offset=cast(u32)offset_of(PackedQuadVertex,#code p1), instanced=true},
      .{loc=2,offset=cast(u32)offset_of(PackedQuadVertex,#code t0), instanced=true},
      .{loc=3,offset=cast(u32)offset_of(PackedQuadVertex,#code t1), instanced=true},
      .{loc=4,offset=cast(u32)offset_of(PackedQuadVertex,#code color), instanced=true},
      .{loc=5,offset=cast(u32)offset_of(PackedQuadVertex,#code roundness), instanced=true},
      .{loc=6,offset=cast(u32)offset_of(PackedQuadVertex,#code sampler_id), instanced=true},
    ];
    vertex_def.attribs = attribs;

    quad_instances.allocator = temp;
    quad_instances_tex_tags.allocator = temp;

    initialized = true;
    return rend;
  }
}

xr2d_push_quad :: (using rend : *xRend2D, p0 : v2, p1 : v2, t0 : v2, t1 : v2, color : v4, roundness : float, atex : xAssetTag = "white.png") {
  // add quad to the quad_instances [..]
  wdim : v2 = xwin_get_dim(*xeng().win);
  //array_add(*quad_instances, PackedQuadVertex.{screen_to_ndc(p0,wdim), screen_to_ndc(p1,wdim), t0, t1, color, 0});
  array_add(*quad_instances, .{p0, p1, t0, t1, color, roundness, 0});
  array_add(*quad_instances_tex_tags, atex);
}

xr2d_end :: (using rend : *xRend2D) {
  // render quad_instances [..]
  ogl_rt_bind(null);
  ogl_bind_sp(*sp);
  wdim : v2 = xwin_get_dim(*xeng().win);
  ogl_ublock_set(*sp_ub1, "res", xx *wdim);
  ogl_ublock_bind_to_slot(*sp_ub1);

  dyn_state := oglDynState.{
    viewport = xwin_get_viewport(*xeng().win),
    scissor = .{},
    flags = .BLEND
  };
  ogl_sp_apply_dyn_state(*sp, dyn_state);

  MAX_TEX_BINDINGS_PER_DRAWCALL :: 8;
  // find all textures for each asset + calc the correct sampler_id for each batch
  tex_per_instance : [..]*oglTex;
  {
    texture_slots : [..]*oglTex;
    texture_slots.allocator = temp;
    current_idx := 0;
    while current_idx < quad_instances.count {
      array_reset(*texture_slots);
      start_idx := current_idx;
      while texture_slots.count < MAX_TEX_BINDINGS_PER_DRAWCALL && current_idx < quad_instances.count {
        asset := xasset_mgr_find(*xeng().persistent_asset_mgr, quad_instances_tex_tags[current_idx]);
        tex : *oglTex = ifx asset then ifx asset.type == xTextureAsset then *acast(asset, xTextureAsset).tex else *acast(asset, xFontAsset).atlas;
        if tex {
          tex_already_loaded, tex_idx := array_find(texture_slots, tex);
          if !tex_already_loaded {
            tex_idx = texture_slots.count;
            array_add(*texture_slots, tex);
            ogl_sp_bind_sampler_to_slot(*sp, tprint("textures[%]", tex_idx), tex, xx tex_idx);
          }
          quad_instances[current_idx].sampler_id = xx tex_idx;
          array_add(*tex_per_instance, tex);
        } else {
          quad_instances[current_idx].sampler_id = 0;
          array_add(*tex_per_instance, null);
        }
        current_idx += 1;
      }
    }
  }
  // make the vertex buffer
  ogl_buf_init(vertex_def.vbuf, .VERTEX, quad_instances.data, cast(u32)quad_instances.count, size_of(PackedQuadVertex));
  bindings := oglBindingDesc.{
    index_buf = null,
    vertex_bufs = []oglVertexDef.{1, *vertex_def},
  };
  ogl_sp_apply_bindings(*sp, bindings);
  // draw all batches
  {
    texture_slots : [..]*oglTex;
    texture_slots.allocator = temp;
    current_idx := 0;
    while current_idx < quad_instances.count {
      array_reset(*texture_slots);
      start_idx := current_idx;
      while texture_slots.count < MAX_TEX_BINDINGS_PER_DRAWCALL && current_idx < quad_instances.count {
        tex := tex_per_instance[current_idx];
        if tex {
          tex_already_loaded, tex_idx := array_find(texture_slots, tex);
          if !tex_already_loaded {
            tex_idx = texture_slots.count;
            array_add(*texture_slots, tex);
            ogl_sp_bind_sampler_to_slot(*sp, tprint("textures[%]", tex_idx), tex, xx tex_idx);
          }
        }
        current_idx += 1;
      }
      ogl_draw_instanced(oglPrimitive.TRIANGLE_STRIP, 0, 4, xx (current_idx - start_idx));
    }
  }
  // release the resources, I love temporary storage heck yeah!
  xr2d_deinit(rend);
}

PACKED_QUAD_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec2 in_p0;
layout (location = 1) in vec2 in_p1;
layout (location = 2) in vec2 in_t0;
layout (location = 3) in vec2 in_t1;
layout (location = 4) in vec4 in_color;
layout (location = 5) in float in_roundness;
layout (location = 6) in int in_sampler_id;


vec2 quad[4] = vec2[](
  vec2(-1.0,-1.0),
  vec2(+1.0,-1.0),
  vec2(-1.0,+1.0),
  vec2(+1.0,+1.0)
);

//vec2 quad[4] = vec2[]( vec2(+1.0,-1.0), vec2(+1.0,+1.0), vec2(-1.0,+1.0), vec2(-1.0,-1.0) );

layout(std140, binding = 0) uniform GlobalData {
  mat4 proj;
  mat4 view;
};

layout(std140, binding = 1) uniform ResolutionData {
  vec2 res;
};

out VS_OUT {
  vec4 color;
  vec2 tc;
  vec2 p;
  vec2 p_center;
  vec2 p_hs;
  flat int sampler_id;
  float roundness;
} vs_out;

vec2 to_ndc (vec2 p) {
  vec2 v = 2 * (p/res)- 1.0;
  v.y *= -1.0;
  return v;
}

void main() {
  // calculate position
  vec2 p_hs = (in_p1 - in_p0)/2.0; 
  vec2 p_center = (in_p0 + in_p1)/2.0; 
  vec4 p = vec4(p_center + p_hs * quad[gl_VertexID],0.0,1.0);
  gl_Position = vec4(to_ndc(p.xy),0,1);
  // calculate texcoord 
  vec2 t_hs = (in_t1 - in_t0)/2.0; 
  vec2 t_center = (in_t0 + in_t1)/2.0; 
  vec2 t = t_center + t_hs * quad[gl_VertexID];
  vs_out.tc = t;
  // pass-through the color and sampler id
  vs_out.color = in_color;
  vs_out.sampler_id = in_sampler_id;
  vs_out.p = p.xy;
  vs_out.p_center = p_center;
  vs_out.p_hs = p_hs;
  vs_out.roundness = in_roundness;
}
DONE

PACKED_QUAD_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

in VS_OUT {
  vec4 color;
  vec2 tc;
  vec2 p;
  vec2 p_center;
  vec2 p_hs;
  flat int sampler_id;
  float roundness;
} fs_in;

layout(std140, binding = 0) uniform GlobalData {
  mat4 proj;
  mat4 view;
};

layout(std140, binding = 1) uniform ResolutionData {
  vec2 res;
};


uniform sampler2D textures[8];

/*
float sdf_rounded_box(vec2 p, vec2 b, vec4 r) {
  r.xy = (p.x>0.0) ? r.xy : r.zw;
  r.x  = (p.y>0.0) ? r.x  : r.y;
  vec2 q = abs(p)-b+r.x;
  return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}
*/

float sdf_rounded_box(vec2 p, vec2 b, float r) {
  vec2 q = abs(p)-b+r;
  return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r;
}


void main() {
  float dist = sdf_rounded_box(fs_in.p - fs_in.p_center, fs_in.p_hs, fs_in.roundness);
  float sdf_factor = float((dist < 0.0));

  FragColor = texture(textures[fs_in.sampler_id], fs_in.tc) * fs_in.color * sdf_factor;
  //FragColor = vec4(vec3(sdf_factor), 1.0); // visualize the distance
}
DONE