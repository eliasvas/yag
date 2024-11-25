
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

// TODO: should the cube be indexed?
xmesh_gen_cube :: () -> xMesh {
  cube : xMesh;
  ogl_buf_init(*cube.vbo, .VERTEX, cube_verts.data, 36, size_of(float32)*8);

  return cube;
}

xmesh_render :: (mesh : *xMesh, sp : *oglSP, model : m4) {
  using mesh;
  // TODO: we SHOULD clear_all_state, but for this to work we must bind lights/materials/matrices here!
  //ogl_clear_all_state();
  ogl_bind_vertex_buffer(*mesh.vbo);
  ogl_bind_sp(sp);
  ogl_sp_set_uniform(sp, "model", oglShaderDataType.MAT4, model.raw.data);
  ogl_sp_set_dyn_state(sp, .BLEND);
  ogl_sp_set_dyn_state(sp, .DEPTH);
  if has_ibo {
    ogl_bind_index_buffer(*mesh.ibo);
    ogl_draw(oglPrimitive.TRIANGLES,0,xx ibo.count);
  } else {
    ogl_draw(oglPrimitive.TRIANGLES,0,xx vbo.count);
  }
}


