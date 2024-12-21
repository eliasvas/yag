
xBlinnPhongVertex :: struct {
  pos : v3;
  norm : v3;
  tc : v2;
};

xMesh :: struct {
  vbo : oglBuf;
  ibo : oglBuf;
  has_ibo : bool = false;

  // resource handle; (?) + some uuid maybe
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
  ogl_buf_init(*cube.vbo, .VERTEX, cube_verts.data, 36, size_of(float32)*8);

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
  ogl_buf_init(*sphere.vbo, .VERTEX, vertices, xx vertex_count, size_of(xBlinnPhongVertex));

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
  sphere.has_ibo = true;

  return sphere;
}

xmesh_render :: (mesh : *xMesh, sp : *oglSP, m : *xMaterial = null, model : m4) {
  using mesh;


  bp_attribs := oglShaderAttrib.[
    ogl_attrib_make(0,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code pos),false),
    ogl_attrib_make(1,oglShaderDataType.VEC3,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code norm),false),
    ogl_attrib_make(2,oglShaderDataType.VEC2,size_of(xBlinnPhongVertex),xx offset_of(xBlinnPhongVertex, #code tc),false)
  ];

  bindings := oglBindingDesc.{
    *mesh.ibo,
    .[*mesh.vbo],
    .[bp_attribs],
  };

 
  //ogl_bind_sp(sp);
  ogl_sp_apply_bindings(sp, bindings);
  if m {
    xmaterial_set_to_shader(m, sp);
  }
  ogl_sp_set_uniform(sp, "model", oglShaderDataType.MAT4, model.raw.data);
  ogl_sp_set_dyn_state(sp, .BLEND);
  if has_ibo {
    ogl_bind_index_buffer(*mesh.ibo);
    ogl_draw_indexed(oglPrimitive.TRIANGLES, xx ibo.count);
  } else {
    ogl_draw(oglPrimitive.TRIANGLES, 0, xx vbo.count);
  }
}
