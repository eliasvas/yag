#import "Basic";
#import "Hash";
#import "Random";
#import "Hash_Table";
// TODO: make it so a SINGLE allocator is used for this ting
/*
    This is a simple Json Parser, which we will use for configuration files
    as well as the base for our glTF 2.0 loading, which will be the main
    3D file format for the engine.

    BEWARE: Currently, only correct(TM) Json files can be parsed!

    Usage: TBA
*/
xJsonParser :: struct {
    foo : u32;
};

xjson_parser_parse_wholefile_string :: (wholefile : string){
    tokens := xjson_tokenize(wholefile);
    print("tokens: %\n", tokens);
}

// xjson_parser_parse_wholefile_string :: (wholefile : string){
//     table_size := 32*1024;
//     fnv1a_hash_string :: (s: string) -> u32 { return cast,trunc(u32) inline fnv1a_hash(s.data, s.count); };
//     generator_function :: (idx: int) -> string {key := sprint("%", formatInt(idx, base = 16));return key;}
//     table: Table(string, int, fnv1a_hash_string, null);
//     init(*table, table_size);
//     defer deinit(*table);
//     for 0..15 {
//         key := generator_function(it);
//         inline table_add(*table, key, xx it);
//         //inline table_remove(*table, key);
//     }
//     value, found := table_find(*table, key="1");
//     assert(found);
//     assert(value == 1);

//     table2: Table(string, string, fnv1a_hash_string, null);
//     init(*table2, table_size);
//     defer deinit(*table2);
//     for 0..15 {
//         key := generator_function(it);
//         val := generator_function(it+1);
//         inline table_add(*table2, key, val);
//         //inline table_remove(*table, key);
//     }
//     value2, found2 := table_find(*table2, key="1");
//     assert(found2);
//     assert(value2 == "2");
// }

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

SAMPLE_JSON :: #string END
{
  "scene": 0,
  "lit": false,
  "prop": true,
  "prop2": null,
  "nodes" : [
    {
      "mesh" : 120
    }
  ]
}
END