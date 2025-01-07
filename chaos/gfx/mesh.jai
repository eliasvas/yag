// FIXME: currently, vertex definition's vertex buffer instance needs to be allocated on the HEAP?!?!?! please remove this bullshit
xBlinnPhongVertex :: struct {
  pos : v3;
  norm : v3;
  tc : v2;
};

xMesh :: struct {
  primitives : [..]xMeshPrimitive;
  skin : xMeshSkin;
  transform : xGLTF_Transform;
};

xMeshPrimitive :: struct {
  material : xPBR_Material;
  vbos : [..]oglVertexDef;
  ibo : oglBuf;
};


XMESH_INVALID_JOINT_ID :: -1;
xMeshJoint :: struct {
  parent_id : s64 = -1;
  children_ids : []s64;
};

xMeshSkin :: struct {
  ibm : []m4; // transforms joint to origin
  local: []xGLTF_Transform; // local joint transform - this is the animated property
  def_trans: []xGLTF_Transform; // joint's default transform
  global: []m4; // global joint transform - transforms joint from origin to its actual transform
  joint_hierarchy : []xMeshJoint; // the whole joint hierarchy
  joint_count : s64;
};

xmesh_has_skin :: (using mesh : *xMesh) -> bool { return skin.joint_count > 0; }

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
  cube : xMeshPrimitive;
  vertex_def : oglVertexDef;
  vertex_def.vbuf = alloc(size_of(oglBuf));
  ogl_buf_init(vertex_def.vbuf, .VERTEX, cube_verts.data, 36, size_of(float32)*8);
  attribs : [..]oglShaderAttrib;
  array_add(*attribs, .{loc=0,offset=cast(u32)offset_of(xBlinnPhongVertex,#code pos)});
  array_add(*attribs, .{loc=1,offset=cast(u32)offset_of(xBlinnPhongVertex,#code norm)});
  array_add(*attribs,.{loc=2,offset=cast(u32)offset_of(xBlinnPhongVertex,#code tc)});
  vertex_def.attribs = attribs;
  array_add(*cube.vbos,vertex_def);

  mesh : xMesh;
  array_add(*mesh.primitives, cube);

  return mesh;
}


// Mainly for multi-vertex-buffer rendering tests
xmesh_gen_cube_multi_vbos :: () -> xMesh {
  cube : xMeshPrimitive;
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

  mesh : xMesh;
  array_add(*mesh.primitives, cube);
  return mesh;
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
xmesh_gen_sphere_primitive :: (r : float32, stack_count : u32 = 8, sector_count : u32 = 8, negate_normals : bool = false) -> xMeshPrimitive {
  sphere : xMeshPrimitive;

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

xmesh_gen_sphere :: (r : float32, stack_count : u32 = 8, sector_count : u32 = 8, negate_normals : bool = false) -> xMesh {
  prim := xmesh_gen_sphere_primitive(r, stack_count, sector_count, negate_normals);

  mesh : xMesh;
  array_add(*mesh.primitives, prim);
  return mesh;
}

// FIXME: each PRIMITIVE should have a material INSIDE! not this monstrocity!!!
xmesh_render :: (using mesh : *xMesh, sp : *oglSP, model : m4) {
  for mp : primitives {
    assert(mp.vbos.count > 0);
    bindings := oglBindingDesc.{
      index_buf = *mp.ibo,
      vertex_bufs = mp.vbos,
    };

    ogl_sp_apply_bindings(sp, bindings);

    // set boring material stuff to shader
    m := mp.material;
    if m.base_col_tex {
      xpbr_material_set_to_shader(*m, sp);
    }

    if mp.ibo.count {
      ogl_bind_index_buffer(*mp.ibo);
      ogl_draw_indexed(oglPrimitive.TRIANGLES, xx mp.ibo.count, mp.ibo.size / mp.ibo.count);
    } else {
      ogl_draw(oglPrimitive.TRIANGLES, 0, xx mp.vbos[0].vbuf.count);
    }
  }
}

xMeshAnimationInterpolationType :: enum {
  STEP;
  LINEAR;
  QLERP;
};

xMeshAnimationProperty :: enum {
  TRANSLATION;
  ROTATION;
  SCALE;
};

// An animation for given property, e.g position, translation or scale
xMeshPropertyAnimation :: struct {
  interp_type : xMeshAnimationInterpolationType;
  property : xMeshAnimationProperty;
  timestamps : []float;
  anim_data : []float; // cast this to vec3/vec4 depending on animation property

  joint_idx : s64 = -1; // the joint to be animated (if its a joint animation)
};

xMeshAnimation :: struct {
  panim : [..] xMeshPropertyAnimation;
  ref : *xMesh; // the mesh to be animated
};

xmesh_skin_print :: (using skin : *xMeshSkin) {
  for joint,idx : joint_hierarchy {
    print("joint % with parent %\n", idx, joint.parent_id);
  }
}

xmesh_animation_calculate_joint_matrices :: (mesh : *xMesh) ->*m4 {
  joint_mats := cast(*m4)talloc(size_of(m4) * 128);

  for i : 0..127 {
    joint_mats[i] = m4_I;
  }

  for joint,idx : mesh.skin.joint_hierarchy {
    joint_mats[idx] = m4_mult(mesh.skin.global[idx], mesh.skin.ibm[idx]);

    //joint_mats[idx] = mesh.skin.ibm[idx];
    //joint_mats[idx] = m4_mult(mesh.skin.ibm[idx],mesh.skin.global[idx]);
  }

  return joint_mats;
}

xmesh_skin_reset_matrices :: (using skin: *xMeshSkin) {
  // reset local transforms
  def_t : xGLTF_Transform;
  for *lt,idx : local {
    //lt.* = def_trans[idx];
    //lt.* = def_t;
  }
  // reset global transforms
  for *gt : global {
    gt.* = m4_I;
  }
}

// TODO: makybe make a typedef for xMeshJointIndex or something
xmesh_skin_find_root_joint_id :: (using skin : *xMeshSkin) ->s64 {
  for joint,idx : joint_hierarchy {
    if joint.parent_id == XMESH_INVALID_JOINT_ID {
      return idx;
    }
  }
  return 0;
}

// TODO: make this procedural, recursion is generally bad here
xmesh_skin_calc_global_transform :: (using skin : *xMeshSkin, joint_id : s64) {
  current_joint :xMeshJoint= *joint_hierarchy[joint_id];
  parent_joint_transform := m4_I;
  if current_joint.parent_id != XMESH_INVALID_JOINT_ID {
    parent_joint_transform = skin.global[current_joint.parent_id];
  }
  local_joint_transform := xgltf_transform_calc_matrix(*skin.local[joint_id]);
  //inverse_bind_transform := skin.ibm[joint_id];
  //skin.global[joint_id] = m4_mult(local_joint_transform, parent_joint_transform);
  skin.global[joint_id] = m4_mult(parent_joint_transform,local_joint_transform);

  for child_id : joint_hierarchy[joint_id].children_ids {
    xmesh_skin_calc_global_transform(skin, child_id);
  }
}

// TODO: maybe instead of seconds_since_init() we should have an animation begin timestamp??? right???
xmesh_animation_calc_animation_time :: (anim : *xMeshAnimation, looping : bool = true) -> float64 {
  time := seconds_since_init();

  if looping {
    max_time :float= 0.01;
    for panim : anim.panim {
      max_time = max(max_time, panim.timestamps[panim.timestamps.count-1]);
    }
    time = fmod_cycling(time, max_time);
  }

  return time;
}

xmesh_panim_calc_frame_indices :: (panim : *xMeshPropertyAnimation, atime : float64) -> s64,s64 {
  prev_index := 0;
  next_index := 0;
  for i : 0..panim.timestamps.count-1 {
    prev_timestamp := panim.timestamps[i];
    next_timestamp := panim.timestamps[(i+1) % (max(1,panim.timestamps.count-1))];
    if atime > prev_timestamp && atime < next_timestamp {
      prev_index = i;
      next_index = (i+1) % (max(1,panim.timestamps.count-1));
    }
  }

  return prev_index,next_index;
}

xmesh_animation_simulate :: (anim : *xMeshAnimation) {

  time := xmesh_animation_calc_animation_time(anim);

  for *panim,idx : anim.panim {
    // FIXME: why dis guy here ha?
    if panim.joint_idx == -1 {
      print("panim: %, idx %\n", panim.*, idx);
      continue;
    }
    prev_index,next_index := xmesh_panim_calc_frame_indices(panim,time);
    dt := 1.0 - (panim.timestamps[next_index]- time) / (panim.timestamps[next_index] - panim.timestamps[prev_index]);


    if panim.property == {
      case .TRANSLATION;
        anim_prop := cast(*v3)panim.anim_data.data;
        val := anim_prop[prev_index];
        next_val := anim_prop[next_index];
        lerp_val := v3_lerp(val, next_val, xx dt);
        anim.ref.skin.local[panim.joint_idx].trans = lerp_val;
      case .ROTATION;
        anim_prop := cast(*v4)panim.anim_data.data;
        val := anim_prop[prev_index];
        next_val := anim_prop[next_index];
        lerp_val := v4_lerp(v4_norm(val), v4_norm(next_val), xx dt);
        lerp_val = v4_norm(lerp_val);
        anim.ref.skin.local[panim.joint_idx].rot=.{lerp_val.x, lerp_val.y, lerp_val.z, lerp_val.w};
      case .SCALE;
        anim_prop := cast(*v3)panim.anim_data.data;
        val := anim_prop[prev_index];
        next_val := anim_prop[next_index];
        lerp_val := v3_lerp(val, next_val, xx dt);
        anim.ref.skin.local[panim.joint_idx].scale = lerp_val;
      case;
    }
  }
}





