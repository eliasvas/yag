// TODO: Think about allocations, what we want to be temporary, want we want to group etc.
// FIXME: This module leaks a LOT, we should put everything for a glTF scene in a single allocator, to be able to hassle-free deallocate
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
  nodes : [..] xGLTF_Node;

  meshes : [..] xGLTF_Mesh;

  buffers : [..]xGLTF_Buffer;
  buffer_views : [..]xGLTF_BufferView;
  accessors : [..]xGLTF_Accessor;

  images : [..]xGLTF_Image;
  samplers : [..]xGLTF_Sampler;
  textures : [..]xGLTF_Texture;

  materials : [..]xGLTF_Material;
};

xGLTF_Node :: struct {
  camera_id : s64 = XGLTF_INVALID_ID;
  skin_id   : s64 = XGLTF_INVALID_ID;
  mesh_id   : s64 = XGLTF_INVALID_ID;
  transform : xGLTF_Transform;
  children  : [..] s64;
};


///////////////////////////////
// glTF buffers
///////////////////////////////

// FIXME: why only floats? we need some kind of xGLTF_BufferKind!
// vertex ids for example are ints!
xGLTF_Buffer :: struct {
  buf : []float;
};

xGLTF_BufferView :: struct {
  buffer : s64;
  byte_offset : s64;
  byte_length : s64;
  byte_stride : s64;
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
  base_color_factor : v4;

  metallic_tex_id : s64 = XGLTF_INVALID_ID;
  metallic_factor : float;

  roughness_tex_id : s64 = XGLTF_INVALID_ID;
  roughness_factor : float;
};

///////////////////////////////
// glTF animations
///////////////////////////////
xGLTF_Transform :: struct {
  trans : v3 = v3.{0,0,0};
  scale : v3 = v3.{1,1,1};
  rot   : Quat = quat_I;
};

xgltf_transform_calc_matrix :: (t : *xGLTF_Transform) -> m4 {
  translation := m4_trans(t.trans);
  // FIXME: here we should put the Quaternion Magic
  rotation := m4_rotate(t.rot.w, .{t.rot.x,t.rot.y,r.rot.z});
  /////////////////////////////////////////////////
  scale := m4_scale(t.scale);
  m := m4_mult(translation,m4_mult(rotation, scale));
  return m;
}

xgltf_convert_matrix_to_transfor :: (m : m4) -> xGLTF_Transform {
  t : xGLTF_Transform;
  // TBA
  return t;
}


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
    buffer_id := xjson_get_int(bufferv_node, "buffer", XGLTF_INVALID_ID);
    byte_offset := xjson_get_int(bufferv_node, "byteOffset", XGLTF_INVALID_ID);
    byte_length := xjson_get_int(bufferv_node, "byteLength", XGLTF_INVALID_ID);
    byte_stride := xjson_get_int(bufferv_node, "byteStride", XGLTF_INVALID_ID);
    target := xjson_get_int(bufferv_node, "target", XGLTF_INVALID_ID);
    bufferv : xGLTF_BufferView = .{buffer_id, byte_offset, byte_length, byte_stride, target};

    array_add(*scene.buffer_views, bufferv);
  }

  // parse accessors
  for accessor_node : xjson_get_array(root_json, "accessors") {
    buffer_view := xjson_get_int(accessor_node, "bufferView", XGLTF_INVALID_ID);
    buffer_offset := xjson_get_int(accessor_node, "bufferOffset", XGLTF_INVALID_ID);
    byte_offset := xjson_get_int(accessor_node, "byteOffset", XGLTF_INVALID_ID);
    component_type := xjson_get_int(accessor_node, "componentType", XGLTF_INVALID_ID);
    count := xjson_get_int(accessor_node, "count", XGLTF_INVALID_ID);
    type := xjson_get_string(accessor_node, "type");
    // TODO: also parse min (we have to infer actual type from count/type/component_type combo)
    // TODO: also parse max
    accessor : xGLTF_Accessor = .{buffer_view, byte_offset, component_type, count, type};

    array_add(*scene.accessors, accessor);
  }


  // parse images (raw texture data) 
  for image_node : xjson_get_array(root_json, "images") {
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
  for sampler_node : xjson_get_array(root_json, "samplers") {
    // TODO:default value here should be 0 or something?
    mag_filter := xjson_get_int(sampler_node, "magFilter", XGLTF_INVALID_ID);
    min_filter := xjson_get_int(sampler_node, "minFilter", XGLTF_INVALID_ID);
    wrap_s := xjson_get_int(sampler_node, "wrapS", XGLTF_INVALID_ID);
    wrap_t := xjson_get_int(sampler_node, "wrapT", XGLTF_INVALID_ID);

    sampler : xGLTF_Sampler = .{mag_filter, min_filter, wrap_s, wrap_t};
    array_add(*scene.samplers, sampler);
  }

  // parse textures
  for texture_node : xjson_get_array(root_json, "textures") {
    sampler_id := xjson_get_int(texture_node, "sampler", XGLTF_INVALID_ID);
    source_id := xjson_get_int(texture_node, "source", XGLTF_INVALID_ID);

    texture : xGLTF_Texture = .{sampler_id, source_id};
    array_add(*scene.textures, texture);
  }

  // parse material (BETA) 
  for material_node : xjson_get_array(root_json, "materials") {
    mr_node := xjson_node_get(material_node, "pbrMetallicRoughness");
    // TODO: incomplete!
    base_color_tex_id :s64 = XGLTF_INVALID_ID;
    base_color_factor : v4;
    bct, bctfound := xjson_node_get(mr_node, "baseColorTexture.index");
    if bctfound {
      base_color_tex_id = xjson_string_to_int(bct.value);
    }else {
      bcf := xjson_node_get(mr_node, "baseColorFactor");
      // FIXME: hacky AF
      base_color_factor = v4.{xjson_string_to_float(bcf.values[0].value),xjson_string_to_float(bcf.values[1].value),xjson_string_to_float(bcf.values[2].value),xjson_string_to_float(bcf.values[3].value)};
    }
    //white_img:oglTex; white := u8.[ 0xFF,0xFF,0xFF,0xFF ]; ogl_tex_init(*white_img, .{1,1}, white.data, oglTexFormat.RGBA8U);
    material : xGLTF_Material;
    material.base_color_tex_id = base_color_tex_id;
    material.base_color_factor = base_color_factor;
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
      return 3;
  }
}

///////////////////////////////
// non-glTF code! (this is not part of the parser)
///////////////////////////////

xgltf_parse_mesh :: (json_wholefile : string) -> xMesh{
  scene := xgltf_scene_load(json_wholefile);
  mesh : xMesh;

  for gltf_mesh : scene.meshes {
    for primitive : gltf_mesh.primitives {
      m: xMeshPrimitive;
      // Shitty material handling to load a shitty image
      tex : *oglTex = alloc(size_of(oglTex));
      // FIXME: it can also be other image formats.. we should encode this somewhere in GLTF structure
      if primitive.material_id != XGLTF_INVALID_ID {
        gltf_mat := scene.materials[primitive.material_id];
        if gltf_mat.base_color_tex_id != XGLTF_INVALID_ID {
          png_data := scene.images[scene.textures[scene.materials[primitive.material_id].base_color_tex_id].image_id].buf;
          tex_w, tex_h, channels : s32;
          stbi_set_flip_vertically_on_load(1);
          raw_image_data := stbi_load_from_memory(png_data.data, cast(s32)png_data.count, *tex_w, *tex_h, *channels, 4);
          ogl_tex_init(tex, .{cast(float)tex_w,cast(float)tex_h}, xx raw_image_data, oglTexFormat.RGBA8U);
          m.material.base_col_tex = tex;
        } else {
          color := gltf_mat.base_color_factor;
          c :[]u8= .[cast(u8)(color.x * 255.0),cast(u8)(color.y * 255.0),cast(u8)(color.z * 255.0),cast(u8)(color.w * 255.0)];
          // TODO make c the actual color, we gotta go float -> byte
          img:oglTex; ogl_tex_init(*img, .{1,1}, c.data, oglTexFormat.RGBA8U);
          ogl_tex_init(tex, .{1,1}, xx c.data, oglTexFormat.RGBA8U);
          m.material.base_col_tex = tex;
        }
      }
      
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
      array_add(*mesh.primitives, m);
    }
  }

  return mesh;
}
