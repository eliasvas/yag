// TODO: Think about allocations, what we want to be temporary, want we want to group etc.
#import "Base64"; // in modules/Base64.jai
#import "stb_image";

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
  material_id : s64 = XGLTF_INVALID_ID;
};

xGLTF_Mesh :: struct {
  primitives : [..]xGLTF_Primitive;
};

xGLTF_Scene :: struct {
  meshes : [..] xGLTF_Mesh;

  buffers : [..]xGLTF_Buffer;
  buffer_views : [..]xGLTF_BufferView;
  accessors : [..]xGLTF_Accessor;

  images : [..]xGLTF_Image;
  samplers : [..]xGLTF_Sampler;
  textures : [..]xGLTF_Texture;

  materials : [..]xGLTF_Material;
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

///////////////////////////////
// glTF textures
///////////////////////////////

xGLTF_Image :: struct {
  buf : []u8;
};

xGLTF_Sampler :: struct {
  mag_filter : s64;
  min_filter : s64;
  wrap_s     : s64;
  wrap_t     : s64;
};

xGLTF_Texture :: struct {
  sampler_id : s64 = XGLTF_INVALID_ID;
  image_id : s64 = XGLTF_INVALID_ID;
};


///////////////////////////////
// glTF materials 
///////////////////////////////

// Currently just a roughtness-metallic material description
xGLTF_Material :: struct {
  base_color_tex_id : s64 = XGLTF_INVALID_ID;
  base_color_factor : v3;

  metallic_tex_id : s64 = XGLTF_INVALID_ID;
  metallic_factor : float;

  roughness_tex_id : s64 = XGLTF_INVALID_ID;
  roughness_factor : float;
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

        material_node,mfound := xjson_node_get(prim_node, "material");
        if mfound then prim.material_id = xjson_string_to_int(material_node.value);

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
      //bin_f :[]float = .{xjson_string_to_int(byte_len_node.value) / size_of(float), cast(*float)binary_text.data};
      bin_f :[]float = .{binary_text.count / size_of(float), cast(*float)binary_text.data};
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


  // parse images (raw texture data) 
  for image_node : xjson_node_get(root_json, "images").values {
    uri_node, ufound := xjson_node_get(image_node, "uri");
    assert(ufound);
    // FIXME: only handling embedded-textures
    found,l,r := split_from_left(uri_node.value, "base64,");
    binary_text := base64_decode(r);
    bin_f :[]u8 = .{binary_text.count, binary_text.data};
    array_add(*scene.images, .{bin_f});
  }
  // parse samplers
  // FIXME: currently sampler values aren't used in final texture creation, we need to enhance ogl a bit
  for sampler_node : xjson_node_get(root_json, "samplers").values {
    // FIXME: are we absolutely certain ALL these properties are gonna be there? maybe an ifx would help here
    mag_filter := xjson_string_to_int(xjson_node_get(sampler_node, "magFilter").value);
    min_filter := xjson_string_to_int(xjson_node_get(sampler_node, "minFilter").value);
    wrap_s := xjson_string_to_int(xjson_node_get(sampler_node, "wrapS").value);
    wrap_t := xjson_string_to_int(xjson_node_get(sampler_node, "wrapT").value);

    sampler : xGLTF_Sampler = .{mag_filter, min_filter, wrap_s, wrap_t};
    array_add(*scene.samplers, sampler);
  }
  // parse textures
  for texture_node : xjson_node_get(root_json, "textures").values {
    // FIXME: are we absolutely certain ALL these properties are gonna be there? maybe an ifx would help here
    sampler_id := xjson_string_to_int(xjson_node_get(texture_node, "sampler").value);
    source_id := xjson_string_to_int(xjson_node_get(texture_node, "source").value);

    texture : xGLTF_Texture = .{sampler_id, source_id};
    array_add(*scene.textures, texture);
  }

  // parse material (BETA) 
  for material_node : xjson_node_get(root_json, "materials").values {
    mr_node := xjson_node_get(material_node, "pbrMetallicRoughness");
    // TODO: incomplete!
    base_color_tex_id := xjson_string_to_int(xjson_node_get(mr_node, "baseColorTexture.index").value);
    material : xGLTF_Material;
    material.base_color_tex_id = base_color_tex_id;
    array_add(*scene.materials, material);
  }



  print("glTF scene: %\n", scene);
  return scene;
}

// TODO: find a cleaner way to do this
xgltf_calc_attrib_loc_from_name :: (attrib_name : string) -> u32 {
  if attrib_name == {
    case "POSITION";
      return 0;
    case "NORMAL";
      return 1;
    case "TEXCOORD_0";
      return 2;
    case;
      return 0;
  }
}

xgltf_parse_mesh :: (json_wholefile : string) -> xMesh, xPBR_Material {
  m: xMesh;
  material : xPBR_Material;
  scene := xgltf_scene_load(json_wholefile);

  for mesh : scene.meshes {
    for primitive : mesh.primitives {
      // Shitty material handling to load a shitty image
      tex : *oglTex = alloc(size_of(oglTex));
      // FIXME: it can also be other image formats.. we should encode this somewhere in GLTF structure
      png_data := scene.images[scene.textures[scene.materials[primitive.material_id].base_color_tex_id].image_id].buf;
      tex_w, tex_h, channels : s32;
      raw_image_data := stbi_load_from_memory(png_data.data, cast(s32)png_data.count, *tex_w, *tex_h, *channels, 4);
      ogl_tex_init(tex, .{cast(float)tex_w,cast(float)tex_h}, xx raw_image_data, oglTexFormat.RGBA8U);
      material.base_col_tex = tex;
      //////////////////////////////////////////////////
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
        attrib_loc := xgltf_calc_attrib_loc_from_name(attr.name);
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

  return m, material;
}
