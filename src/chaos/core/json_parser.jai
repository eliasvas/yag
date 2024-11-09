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


    Usage: TBA
*/

xjson_parse_wholefile_string :: (wholefile : string){
    tokens := xjson_tokenize(wholefile);
    print("tokens: %\n", tokens);
    root_node := xjson_parse_tokens(tokens);
    print("root node: %\n", root_node.*);
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
  value : string;
  table: Table(string, *xJsonNode, null, null);
};

xjson_node_make :: (kind : xJsonNodeKind, value : string) ->*xJsonNode {
  node : *xJsonNode = alloc(size_of(xJsonNode)); // TODO: we should find some way to pass in an allocator, or something!
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
      assert(0 && "Arrays not supported yet - skipping!\n");
    case .LBRACE;
      return xjson_parse_object(tokens, pos);
    case;
  }

  return xjson_node_make(.NULL, "");
}

xjson_parse_object :: (tokens : []xJsonToken, pos : *s64) -> *xJsonNode {
  node := xjson_node_make(.OBJECT, "");
  node.table;
  // All tables have max size 32??
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

SAMPLE_JSON :: #string END
{
  "scene": 0,
  "lit": false,
  "prop": true,
  "prop2": null,
  "mesh":{
    "tri_count" : 120,
    "detail" : 3 
  }
}
END
