// TODO: Think about allocations, what we want to be temporary, want we want to group etc.
#import "Base64"; // in modules/Base64.jai

/*
Quick rundown of different glTF nodes:
  scene - entry point for description of the scene.
  node - a node in the scene graph hierarchy.
  camera - view configuration for rendering the scene.
  mesh - a geometric object that appears in the scene, it also has _accessors_ for vertex data and _materials_ to define its appearance.
  skin - defines parameters used for vertex skinning which allows deformation of a mesh, its values are provided through _accessors_.
  animation - describes how transformations (translations/rotations) change over time.
  accessor - a source of arbitrary data. Used by meshes skins and animations. Refers to a _bufferView_ which is part of a buffer.
  material - contains parameters that define the appearance of an object. Usually refers to _texture_ objects that are applied to geometry.
  texture - is defined by a _sampler_ and an _image_. The _sampler_ defines how the texture _image_ should be placed on an object.
*/

/*
  Generally, we first parse file.json, and then go on to parse all files reference in "buffers" and "images" in Json's top-level, like:
  "buffers" : [
    {
      "uri" : "buffer1.bin",
      "bufferLength" : 66
    }
  ]
  "images" : [
    {
      "uri" : "image01.png"
    }
  ]
  we will read all buffers and images, bufferViews and samplers will refer to these binary files.
*/

XGLTF_INVALID_ID :: -1;

///////////////////////////////
// glTF Meshes
///////////////////////////////


xGLTF_Attribute :: struct {
  name : string;
  accessor_id : s64 = XGLTF_INVALID_ID;
};

xGLTF_Indices :: struct {
  accessor_id : s64 = XGLTF_INVALID_ID;
};

xGLTF_Primitive :: struct {
    attributes : [..]xGLTF_Attribute;
    indices : xGLTF_Indices;
};

xGLTF_Mesh :: struct {
  primitives : [..]xGLTF_Primitive;
};

xGLTF_Scene :: struct {
  meshes : [..] xGLTF_Mesh;

  buffers : [..]xGLTF_Buffer;
  buffer_views : [..]xGLTF_BufferView;
  accessors : [..]xGLTF_Accessor;
};


///////////////////////////////
// glTF buffers
///////////////////////////////
// FIXME: why only floats? we need some kind of xGLTF_BufferKind!
xGLTF_Buffer :: struct {
  buf : []float;
};

xGLTF_BufferView :: struct {
  buffer : s64;
  byte_offset : s64;
  byte_length : s64;
  target : s64;
};

xGLTF_Accessor :: struct {
  buffer_view : s64;
  byte_offset : s64;
  component_type : s64;
  count : s64;
  type : string;
  //min
  //max
};

// TODO: can we simplify this with an ifx
xgltf_accessor_calc_data_type_size :: (using accessor : *xGLTF_Accessor) -> u32 {
  bytes :u32;
  if component_type == {
    case 5120; //s8
    case 5121; //u8
      bytes = 1;
    case 5122; //s16
    case 5123; //u16
      bytes = 2;
    case 5125; //u32
    case 5126; //f32
      bytes = 4;
    case;
  }
  mult :u32;
  if type == {
    case "SCALAR";
      mult = 1;
    case "VEC2";
      mult = 2;
    case "VEC3";
      mult = 3;
    case "VEC4";#through;
    case "MAT2";
      mult = 4;
    case "MAT3";
      mult = 9;
    case "MAT4";
      mult = 16;
    case;
  }
  return bytes*mult;
}

xgltf_scene_load_from_file :: (gltf_path: string) ->xGLTF_Scene, bool {
  scene : xGLTF_Scene;
  success := true;
  if contains(gltf_path, ".gltf") {
    file_content, succ := read_entire_file(gltf_path);
    if succ then scene = xgltf_scene_load(file_content);
    else print("file % not found!\n", gltf_path);
  } else if contains(gltf_path, ".glb") {
    assert(0, ".glb not supported yet!");
  } else {
    print("file % is not a valid .gltf file!", gltf_path);
  }

  return scene, success;
}
xgltf_scene_load :: (json_wholefile : string) ->xGLTF_Scene {
  scene : xGLTF_Scene;

  //file_content, success := read_entire_file(filename);
  root_json := xjson_parse_wholefile_string(json_wholefile);

  // parse meshes
  for mesh_node : xjson_node_get(root_json, "meshes").values {
    mesh : xGLTF_Mesh;
    prim_arr_node, pfound := xjson_node_get(mesh_node, "primitives");
    assert(pfound);
    for prim_node : prim_arr_node.values {
      prim : xGLTF_Primitive;
      attribs_node, afound := xjson_node_get(prim_node, "attributes");
      if afound {
        for val, key: attribs_node.table {
          attrib : xGLTF_Attribute = .{key, xjson_string_to_int(val.value)};
          array_add(*prim.attributes, attrib);
        }
        indices_node,ifound := xjson_node_get(prim_node, "indices");
        if ifound then prim.indices = .{xjson_string_to_int(indices_node.value)};
        array_add(*mesh.primitives, prim);
      }
    }
    array_add(*scene.meshes, mesh);
  }

  // parse buffers
  for buffer_node : xjson_node_get(root_json, "buffers").values {
    uri_node, ufound := xjson_node_get(buffer_node, "uri");
    assert(ufound);
    byte_len_node, bfound := xjson_node_get(buffer_node, "byteLength");
    if bfound { // if we got a byteLength, the buffer is embedded
      found,l,r := split_from_left(uri_node.value, "base64,");
      binary_text := base64_decode(r);
      bin_f :[]float = .{xjson_string_to_int(byte_len_node.value) / size_of(float), cast(*float)binary_text.data};
      array_add(*scene.buffers, .{bin_f});
    } else { // else we should read from 'file.bin' (stored in URI)
      assert(0 && "glTF external buffer reads not supported yet!");
    }
  }

  // parse bufferViews
  for bufferv_node : xjson_node_get(root_json, "bufferViews").values {
    // FIXME: are we absolutely certain ALL these properties are gonna be there? maybe an ifx would help here
    buffer_id  := xjson_string_to_int(xjson_node_get(bufferv_node, "buffer").value);
    byte_offset := xjson_string_to_int(xjson_node_get(bufferv_node, "byteOffset").value);
    byte_length := xjson_string_to_int(xjson_node_get(bufferv_node, "byteLength").value);
    target     := xjson_string_to_int(xjson_node_get(bufferv_node, "target").value);
    bufferv : xGLTF_BufferView = .{buffer_id, byte_offset, byte_length, target};

    array_add(*scene.buffer_views, bufferv);
  }

  // parse accessors
  for accessor_node : xjson_node_get(root_json, "accessors").values {
    // FIXME: are we absolutely certain ALL these properties are gonna be there? maybe an ifx would help here
    buffer_view    := xjson_string_to_int(xjson_node_get(accessor_node, "bufferView").value);
    byte_offset    := xjson_string_to_int(xjson_node_get(accessor_node, "byteOffset").value);
    component_type := xjson_string_to_int(xjson_node_get(accessor_node, "componentType").value);
    count          := xjson_string_to_int(xjson_node_get(accessor_node, "count").value);
    type           := xjson_node_get(accessor_node, "type").value;
    // TODO: also parse min (we have to infer actual type from count/type/component_type combo)
    // TODO: also parse max
    accessor : xGLTF_Accessor = .{buffer_view, byte_offset, component_type, count, type};

    array_add(*scene.accessors, accessor);
  }

  /*
  // parse textures
  for buffer_node : xjson_node_get(root_json, "buffers").values {
    uri_node, ufound := xjson_node_get(buffer_node, "uri");
    assert(ufound);
    byte_len_node, bfound := xjson_node_get(buffer_node, "byteLength");
    if bfound { // if we got a byteLength, the buffer is embedded
      found,l,r := split_from_left(uri_node.value, "base64,");
      binary_text := base64_decode(r);
      bin_f :[]float = .{xjson_string_to_int(byte_len_node.value) / size_of(float), cast(*float)binary_text.data};
      array_add(*scene.buffers, .{bin_f});
    } else { // else we should read from 'file.bin' (stored in URI)
      assert(0 && "glTF external buffer reads not supported yet!");
    }
  }
  */



  print("glTF scene: %\n", scene);
  return scene;
}

xgltf_parse_mesh :: (json_wholefile : string) -> xMesh {
  m: xMesh;
  scene := xgltf_scene_load(json_wholefile);

  for mesh : scene.meshes {
    for primitive : mesh.primitives {
      index_buf_accessor_id := primitive.indices.accessor_id;
      if index_buf_accessor_id != XGLTF_INVALID_ID {
        accessor := scene.accessors[index_buf_accessor_id];
        buffer_view := scene.buffer_views[accessor.buffer_view];
        buffer := scene.buffers[buffer_view.buffer];
        ptr := cast(*u8)buffer.buf.data + accessor.byte_offset + buffer_view.byte_offset;

        data_type_size: = xgltf_accessor_calc_data_type_size(*accessor);
        ogl_buf_init(*m.ibo, .INDEX, xx ptr, xx accessor.count, data_type_size); // how do we get the actual type?? some type_id stuff?
      }

      for attr : primitive.attributes {
        vertex_buf_accessor_id := attr.accessor_id;
        attrib_loc :u32 = ifx attr.name == "POSITION" then cast(u32)0 else cast(u32)1; // we should make a switch statment for this
        if vertex_buf_accessor_id != XGLTF_INVALID_ID {
          accessor := scene.accessors[vertex_buf_accessor_id];
          buffer_view := scene.buffer_views[accessor.buffer_view];
          buffer := scene.buffers[buffer_view.buffer];
          ptr := cast(*u8)buffer.buf.data + accessor.byte_offset + buffer_view.byte_offset;
          vertex_buf := alloc(size_of(oglBuf));

          data_type_size: = xgltf_accessor_calc_data_type_size(*accessor);
          ogl_buf_init(vertex_buf, .VERTEX, xx ptr, xx accessor.count, data_type_size);

          vertex_def : oglVertexDef;
          vertex_def.vbuf = vertex_buf;
          attribs : [..]oglShaderAttrib;
          array_add(*attribs, .{loc=attrib_loc});
          vertex_def.attribs = attribs;
          array_add(*m.vbos,vertex_def);
        }
      }
    }
  }

  return m;
}
