#import "Basic";
#import "Hash";
#import "Random";
#import "Hash_Table";

// TODO: make it so a SINGLE allocator is used for this ting
// TODO: Currently, only correct(TM) files are parsed. Make some error value (second return value maybe), no debug info needed.

/*
  This is a simple Json Parser, which we will use for configuration files
  as well as the base for our glTF 2.0 loading, which will be the main
  3D file format for the engine.

  In Json there exist 3 types :
    - values (String, Bool, Number, Null)
    - objects (string : JsonNode pairs)
    - arrays (multiples of JsonNode)

  Usage: TBA
*/

xjson_parse_wholefile_string :: (wholefile : string) -> *xJsonNode {
  //print("Json:\n %\n------\n", SAMPLE_JSON);
  tokens := xjson_tokenize(wholefile);
  //print("tokens: %\n", tokens);
  root_node := xjson_parse_tokens(tokens);
  //xjson_print_node(root_node, 0);
  return root_node;
}

xJsonTokenKind :: enum u8 {
  LBRACE;
  RBRACE;
  LBRACKET;
  RBRACKET;
  COLON;
  COMMA;
  STRING;
  NUMBER;
  TRUE;
  FALSE;
  NULL;
};

xJsonToken :: struct {
  kind : xJsonTokenKind;
  value : string;
};

xjson_tokenize :: (wholefile : string) -> [] xJsonToken {
  tokens : [..] xJsonToken;
  pos := 0;
  while pos != wholefile.count {
    c : u8 = wholefile[pos];
    if c == {
      case #char "{";
        array_add(*tokens, .{kind=.LBRACE});
        pos +=1;
      case #char "}";
        array_add(*tokens, .{kind=.RBRACE});
        pos +=1;
      case #char "[";
        array_add(*tokens, .{kind=.LBRACKET});
        pos +=1;
      case #char "]";
        array_add(*tokens, .{kind=.RBRACKET});
        pos +=1;
      case #char ":";
        array_add(*tokens, .{kind=.COLON});
        pos +=1;
      case #char ",";
        array_add(*tokens, .{kind=.COMMA});
        pos +=1;
      case #char "\"";
        pos+=1;
        s : string = .{data=*wholefile[pos],count=0};
        c = wholefile[pos];
        while c != #char "\"" {
          s.count+=1;
          c = wholefile[pos+s.count];
        }
        pos+=s.count+1;
        array_add(*tokens, .{kind=.STRING,value=s});
      case;
        if to_string(*wholefile[pos], 4) == "true" {
          pos+=4;
          array_add(*tokens, .{kind=.TRUE});
        } else if to_string(*wholefile[pos], 4) == "null" {
          pos+=4;
          array_add(*tokens, .{kind=.NULL});
        } else if to_string(*wholefile[pos], 5) == "false" {
          pos+=5;
          array_add(*tokens, .{kind=.FALSE});
        } else if is_digit(c) || c==#char"-" || c==#char"." {
          s : string = .{data=*wholefile[pos], count=0};
          while is_digit(c) || c==#char"-" || c==#char"." {
            s.count+=1;
            c = wholefile[pos+s.count];
          }
          pos+=s.count;
          array_add(*tokens, .{kind=.NUMBER, value=s});
        }else {
          pos+=1;
        }
      }
  }
  return tokens;
}

// TODO: should this number be different for ints/floats?
xJsonNodeKind :: enum {
  STRING;
  NUMBER;
  OBJECT;
  ARRAY;
  BOOL;
  NULL;
};

// TODO: shouldn't the value be of 'value' type?
xJsonNode :: struct {
  kind : xJsonNodeKind;
  union {
    value : string;
    table : Table(string, *xJsonNode, null, null);
    values : [..] *xJsonNode;
  };
};

// FIXME: WHY?!?! do we allocate this on the fucking heap? am i stupid
xjson_node_make :: (kind : xJsonNodeKind, value : string) ->*xJsonNode {
  node : *xJsonNode = alloc(size_of(xJsonNode));
  memset(node, 0, size_of(xJsonNode));
  node.kind = kind;
  node.value = value;
  return node;
}

xjson_parse_tokens :: (tokens : []xJsonToken) -> *xJsonNode {
  pos := 0;
  return xjson_parse_value(tokens, *pos);
}

xjson_parse_value :: (tokens : []xJsonToken, pos : *s64) -> *xJsonNode {
  token := tokens[pos.*];
  if token.kind == {
    case .NULL;
      return xjson_node_make(.NULL, "null");
    case .TRUE;
      return xjson_node_make(.BOOL, "true");
    case .FALSE;
      return xjson_node_make(.BOOL, "false");
    case .STRING;
      return xjson_node_make(.STRING, token.value);
    case .NUMBER;
      return xjson_node_make(.NUMBER, token.value);
    case .LBRACKET;
      return xjson_parse_array(tokens, pos);
    case .LBRACE;
      return xjson_parse_object(tokens, pos);
    case;
  }

  return xjson_node_make(.NULL, "");
}

xjson_parse_object :: (tokens : []xJsonToken, pos : *s64) -> *xJsonNode {
  node := xjson_node_make(.OBJECT, "");
  node.table;
  // All tables have max size 32?? (or buckets??)
  init(*node.table, 32);
  // eat '{'
  pos.*+=1;
  // start parsing 'key' : 'value' pairs
  while tokens[pos.*].kind != .RBRACE {
    key_token := tokens[pos.*];
    pos.*+=1;
    colon_token := tokens[pos.*];
    pos.*+=1;
    value := xjson_parse_value(tokens, pos);
    pos.*+=1;
    // insert key value pair to map
    inline table_add(*node.table, key_token.value, value); 
    // eat ','
    if tokens[pos.*].kind == .COMMA then pos.*+=1;
  }
  return node;
}

xjson_parse_array :: (tokens : []xJsonToken, pos : *s64) -> *xJsonNode {
  node := xjson_node_make(.ARRAY, "");
  // eat '['
  pos.*+=1;
  // start parsing 'value's 
  while tokens[pos.*].kind != .RBRACKET {
    value := xjson_parse_value(tokens, pos);
    pos.*+=1;
    // insert value to array
    array_add(*node.values, value);
    // eat ','
    if tokens[pos.*].kind == .COMMA then pos.*+=1;
  }
  return node;
}

// TODO: printing is not yet Gud, newline/tab stuff need a refactor for sure
xjson_print_node :: (node : *xJsonNode, level : s64 = 0) {
  if node.kind == {
    case .ARRAY;
      print("[");
      for value : node.values { xjson_print_node(value, level+1); print(" ");}
      print("]");
    case .OBJECT;
      for val, key: node.table {
        print("\n");
        for 0..level-1 { print("\t");}
        print("% : ", key);
        xjson_print_node(val,level+1);
      }
    case;
      print("%", node.value);
  }
}

xjson_node_get :: (root_node : *xJsonNode, path : string) -> *xJsonNode, bool {
  ret : *xJsonNode;
  found : bool = false;
  if contains(path, #char ".") {
    found = false;
    f, left_path, right_path := split_from_left(path, #char ".");
    subnode, node_found := table_find(*root_node.table, left_path);
    if node_found {
      ret,found = xjson_node_get(subnode, right_path);
    }
  }else {
    ret, found = table_find(*root_node.table, path);
  }
  return ret, found;
}

// TODO: we can do better than string_to_float!
xjson_string_to_float :: (s : string) -> float {
  return string_to_float(s);
}
xjson_string_to_int :: (s : string) -> int {
  sum := 0;
  for c,index : s {
    sum += xx ((c - #char "0") * pow(10.0, xx(s.count-index-1)));
  }
  return sum;
}

xjson_get_string :: (node : *xJsonNode, path : string, default:string="") -> string, bool {
    local_node, found := xjson_node_get(node, path);
    if found {
      return local_node.value, true;
    }else {
      return default,false;
    }
}

xjson_get_float_array :: (node : *xJsonNode, path : string, $count : u32, default:float=0.0) -> [count]float, bool {
  arr : [count]float;
  array_node, found := xjson_node_get(node, path);

  if found {
    for idx : 0..count-1 {
      arr[idx] = xjson_string_to_float(array_node.values[idx].value);
    }
  }
  return arr, found;
}

xjson_get_float :: (node : *xJsonNode, path : string, default:float=0.0) -> float, bool {
    local_node, found := xjson_node_get(node, path);
    if found {
      return xjson_string_to_float(local_node.value), true;
    }else {
      return default,false;
    }
}

xjson_get_int :: (node : *xJsonNode, path : string, default:int=-1) -> int, bool {
    local_node, found := xjson_node_get(node, path);
    if found {
      return xjson_string_to_int(local_node.value), true;
    }else {
      return default,false;
    }
}

xjson_get_array :: (node : *xJsonNode, path : string) -> []*xJsonNode {
    local_node, found := xjson_node_get(node, path);
    if found {
      return local_node.values;
    }else {
      return .[];
    }
}

SAMPLE_JSON :: #string END
{
  "scene": 0,
  "scenes" : [
    {
      "nodes" : [ 0 ]
    }
  ],

  "nodes" : [
    {
      "mesh" : 0
    }
  ],

  "meshes" : [
    {
      "primitives" : [ {
        "attributes" : {
          "POSITION" : 1
        },
        "indices" : 0
      } ]
    }
  ],

  "buffers" : [
    {
      "uri" : "data:application/octet-stream;base64,AAABAAIAAAAAAAAAAAAAAAAAAAAAAIA/AAAAAAAAAAAAAAAAAACAPwAAAAA=",
      "byteLength" : 44
    }
  ],
  "bufferViews" : [
    {
      "buffer" : 0,
      "byteOffset" : 0,
      "byteLength" : 6,
      "target" : 34963
    },
    {
      "buffer" : 0,
      "byteOffset" : 8,
      "byteLength" : 36,
      "target" : 34962
    }
  ],
  "accessors" : [
    {
      "bufferView" : 0,
      "byteOffset" : 0,
      "componentType" : 5123,
      "count" : 3,
      "type" : "SCALAR",
      "max" : [ 2 ],
      "min" : [ 0 ]
    },
    {
      "bufferView" : 1,
      "byteOffset" : 0,
      "componentType" : 5126,
      "count" : 3,
      "type" : "VEC3",
      "max" : [ 1.0, 1.0, 0.0 ],
      "min" : [ 0.0, 0.0, 0.0 ]
    }
  ],
  
  "asset" : {
    "version" : "2.0"
  }
}
END
