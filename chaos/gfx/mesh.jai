// FIXME: currently, vertex definition's vertex buffer instance needs to be allocated on the HEAP?!?!?! please remove this bullshit
xBlinnPhongVertex :: struct {
  pos : v3;
  norm : v3;
  tc : v2;
};

xMesh :: struct {
  vbos : [..]oglVertexDef;
  ibo : oglBuf;
};

// pos norm tc
cube_verts : [36 * 8] float32 = .[
    -1.0, -1.0, -1.0,  0.0,  0.0, -1.0,  0.0,  0.0,
     1.0, -1.0, -1.0,  0.0,  0.0, -1.0,  1.0,  0.0,
     1.0,  1.0, -1.0,  0.0,  0.0, -1.0,  1.0,  1.0,
     1.0,  1.0, -1.0,  0.0,  0.0, -1.0,  1.0,  1.0,
    -1.0,  1.0, -1.0,  0.0,  0.0, -1.0,  0.0,  1.0,
    -1.0, -1.0, -1.0,  0.0,  0.0, -1.0,  0.0,  0.0,

    -1.0, -1.0,  1.0,  0.0,  0.0,  1.0,  0.0,  0.0,
     1.0, -1.0,  1.0,  0.0,  0.0,  1.0,  1.0,  0.0,
     1.0,  1.0,  1.0,  0.0,  0.0,  1.0,  1.0,  1.0,
     1.0,  1.0,  1.0,  0.0,  0.0,  1.0,  1.0,  1.0,
    -1.0,  1.0,  1.0,  0.0,  0.0,  1.0,  0.0,  1.0,
    -1.0, -1.0,  1.0,  0.0,  0.0,  1.0,  0.0,  0.0,

    -1.0,  1.0,  1.0, -1.0,  0.0,  0.0,  1.0,  0.0,
    -1.0,  1.0, -1.0, -1.0,  0.0,  0.0,  1.0,  1.0,
    -1.0, -1.0, -1.0, -1.0,  0.0,  0.0,  0.0,  1.0,
    -1.0, -1.0, -1.0, -1.0,  0.0,  0.0,  0.0,  1.0,
    -1.0, -1.0,  1.0, -1.0,  0.0,  0.0,  0.0,  0.0,
    -1.0,  1.0,  1.0, -1.0,  0.0,  0.0,  1.0,  0.0,

     1.0,  1.0,  1.0,  1.0,  0.0,  0.0,  1.0,  0.0,
     1.0,  1.0, -1.0,  1.0,  0.0,  0.0,  1.0,  1.0,
     1.0, -1.0, -1.0,  1.0,  0.0,  0.0,  0.0,  1.0,
     1.0, -1.0, -1.0,  1.0,  0.0,  0.0,  0.0,  1.0,
     1.0, -1.0,  1.0,  1.0,  0.0,  0.0,  0.0,  0.0,
     1.0,  1.0,  1.0,  1.0,  0.0,  0.0,  1.0,  0.0,

    -1.0, -1.0, -1.0,  0.0, -1.0,  0.0,  0.0,  1.0,
     1.0, -1.0, -1.0,  0.0, -1.0,  0.0,  1.0,  1.0,
     1.0, -1.0,  1.0,  0.0, -1.0,  0.0,  1.0,  0.0,
     1.0, -1.0,  1.0,  0.0, -1.0,  0.0,  1.0,  0.0,
    -1.0, -1.0,  1.0,  0.0, -1.0,  0.0,  0.0,  0.0,
    -1.0, -1.0, -1.0,  0.0, -1.0,  0.0,  0.0,  1.0,

    -1.0,  1.0, -1.0,  0.0,  1.0,  0.0,  0.0,  1.0,
     1.0,  1.0, -1.0,  0.0,  1.0,  0.0,  1.0,  1.0,
     1.0,  1.0,  1.0,  0.0,  1.0,  0.0,  1.0,  0.0,
     1.0,  1.0,  1.0,  0.0,  1.0,  0.0,  1.0,  0.0,
    -1.0,  1.0,  1.0,  0.0,  1.0,  0.0,  0.0,  0.0,
    -1.0,  1.0, -1.0,  0.0,  1.0,  0.0,  0.0,  1.0
];

xmesh_gen_cube :: () -> xMesh {
  cube : xMesh;

  vertex_def : oglVertexDef;
  vertex_def.vbuf = alloc(size_of(oglBuf));
  ogl_buf_init(vertex_def.vbuf, .VERTEX, cube_verts.data, 36, size_of(float32)*8);
  attribs : [..]oglShaderAttrib;
  array_add(*attribs, .{loc=0,offset=cast(u32)offset_of(xBlinnPhongVertex,#code pos)});
  array_add(*attribs, .{loc=1,offset=cast(u32)offset_of(xBlinnPhongVertex,#code norm)});
  array_add(*attribs,.{loc=2,offset=cast(u32)offset_of(xBlinnPhongVertex,#code tc)});
  vertex_def.attribs = attribs;

  array_add(*cube.vbos,vertex_def);



  return cube;
}


// Mainly for multi-vertex-buffer rendering tests
xmesh_gen_cube_multi_vbos :: () -> xMesh {
  cube : xMesh;

  vertex_def_pos : oglVertexDef;
  vertex_def_pos.vbuf = alloc(size_of(oglBuf));
  ogl_buf_init(vertex_def_pos.vbuf, .VERTEX, cube_verts.data, 36, size_of(float32)*8);
  attribs_pos : [..]oglShaderAttrib;
  array_add(*attribs_pos, .{loc=0,offset=cast(u32)offset_of(xBlinnPhongVertex,#code pos)});
  vertex_def_pos.attribs = attribs_pos;
  array_add(*cube.vbos,vertex_def_pos);

  vertex_def_norm : oglVertexDef;
  vertex_def_norm.vbuf = alloc(size_of(oglBuf));
  ogl_buf_init(vertex_def_norm.vbuf, .VERTEX, cube_verts.data, 36, size_of(float32)*8);
  attribs_norm : [..]oglShaderAttrib;
  array_add(*attribs_norm, .{loc=1,offset=cast(u32)offset_of(xBlinnPhongVertex,#code norm)});
  vertex_def_norm.attribs = attribs_norm;
  array_add(*cube.vbos,vertex_def_norm);

  vertex_def_tc : oglVertexDef;
  vertex_def_tc.vbuf = alloc(size_of(oglBuf));
  ogl_buf_init(vertex_def_tc.vbuf, .VERTEX, cube_verts.data, 36, size_of(float32)*8);
  attribs_tc : [..]oglShaderAttrib;
  array_add(*attribs_tc, .{loc=2,offset=cast(u32)offset_of(xBlinnPhongVertex,#code tc)});
  vertex_def_tc.attribs = attribs_tc;
  array_add(*cube.vbos,vertex_def_tc);

  return cube;
}

/*
  Each sphere has sectors ( horizontal w/ theta = [0-2pi] ) and stacks (vertical w/ phi = [-pi/2 - pi/2])
  For each vertex (x,y,z), it must hold true that:
    x = r * cos(phi) * cos(theta)
    y = r * cos(phi) * sin(theta)
    z = r * sin(phi)
    (prove it on paper, its very simple!)
  So we will generate those vertices with positions as described above, normals as normalized
  positions and tex_coords ranging from [0-1] depending on theta and phi.
  Then we will connect and index the mesh accoringly.
*/
xmesh_gen_sphere :: (r : float32, stack_count : u32 = 8, sector_count : u32 = 8, negate_normals : bool = false) -> xMesh {
  sphere : xMesh;

  assert(stack_count > 0);
  assert(sector_count > 0);

  // allocate vertices and indices needed
  vertices : *xBlinnPhongVertex = alloc(size_of(xBlinnPhongVertex) * stack_count * sector_count);
  defer free(vertices);
  vertex_count := 0;

  indices : *u32 = alloc(size_of(u32) * stack_count * sector_count * 6);
  defer free(indices);
  index_count :u32= 0;

  // generate the vertices
  for stack_index : 0..stack_count {
    stack_angle := PI/2.0 - PI * stack_index/stack_count;
    for sector_index : 0..sector_count {
      sector_angle := 2 * PI * sector_index/sector_count;

      new_vert : xBlinnPhongVertex;
      new_vert.pos = .{r*cos(stack_angle)*cos(sector_angle), r*cos(stack_angle)*sin(sector_angle),r*sin(stack_angle)};
      // sidenote: we swap y and z so our sphere will be upright in OpenGL screen-space
      {
        tmpz:=new_vert.pos.z;
        new_vert.pos.z = new_vert.pos.y;
        new_vert.pos.y = tmpz;
      }
      new_vert.norm = v3_norm(new_vert.pos) * ifx negate_normals then (-1.0) else (1.0);
      new_vert.tc = .{cast(float)sector_index/sector_count, 1.0 - cast(float)stack_index/stack_count};
      vertices[vertex_count] = new_vert;
      vertex_count+=1;
    }
  }

  vertex_def : oglVertexDef;
  vertex_def.vbuf = alloc(size_of(oglBuf));
  ogl_buf_init(vertex_def.vbuf, .VERTEX, vertices, xx vertex_count, size_of(xBlinnPhongVertex));
  attribs : [..]oglShaderAttrib;
  array_add(*attribs, .{loc=0,offset=cast(u32)offset_of(xBlinnPhongVertex,#code pos)});
  array_add(*attribs, .{loc=1,offset=cast(u32)offset_of(xBlinnPhongVertex,#code norm)});
  array_add(*attribs,.{loc=2,offset=cast(u32)offset_of(xBlinnPhongVertex,#code tc)});
  vertex_def.attribs = attribs;

  array_add(*sphere.vbos,vertex_def);



  // generate the indices (triangles i0-i1-i0+1 and i0+1-i1-i1+1)
  for stack_index : 0..stack_count-1 {
    i0 := stack_index * (sector_count+1);
    i1 := i0 + (sector_count+1);
    for sector_index : 0..sector_count-1 {
      if stack_index != 0 {
        indices[index_count] = i0;
        indices[index_count+1] = i1;
        indices[index_count+2] = i0+1;
        index_count+=3;
      }
      if stack_index != stack_count-1 {
        indices[index_count] = i0+1;
        indices[index_count+1] = i1;
        indices[index_count+2] = i1+1;
        index_count+=3;
      }
      i0+=1;
      i1+=1;
    }
  }
  ogl_buf_init(*sphere.ibo, .INDEX, indices, xx index_count, size_of(u32));

  return sphere;
}

xmesh_render :: (using mesh : *xMesh, sp : *oglSP, m : *xMaterial = null, model : m4) {
  assert(mesh.vbos.count > 0);
  bindings := oglBindingDesc.{
    index_buf = *mesh.ibo,
    vertex_bufs = mesh.vbos,
  };

  ogl_sp_apply_bindings(sp, bindings);
  if m {
    xmaterial_set_to_shader(m, sp);
  }

  if ibo.count {
    ogl_bind_index_buffer(*mesh.ibo);
    ogl_draw_indexed(oglPrimitive.TRIANGLES, xx ibo.count, ibo.size / ibo.count);
  } else {
    ogl_draw(oglPrimitive.TRIANGLES, 0, xx vbos[0].vbuf.count);
  }
}
