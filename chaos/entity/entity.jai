#import "Basic";
#import "String";
//#load "math.jai";

// TODO: type/scene serialization
// what about Game_Scene?

// This entity system is a rather simple attempt at achieving composition. There are only entities, linked to each other.
// a big inspiration was this article on ECS https://joshuamanton.substack.com/p/why-i-removed-components-from-my
// also the 'Building a Data-Oriented Entity System' series in the bitsquid blog https://bitsquid.blogspot.com/2014/08/building-data-oriented-entity-system.html

xEntityBase :: struct { 
  local_pos : v3; // TODO: should be transform
  type : Type;

  /*
  // embedded linked list for hierarchy
  parent : *xEntityBase;
  first  : *xEntityBase;
  last   : *xEntityBase;
  prev   : *xEntityBase;
  next   : *xEntityBase;
  */
}

// TODO: this should be done via metaprogramming, like @entity tag on each struct
Foo :: struct {
  #as using base : xEntityBase;
  foo : int;
} @entity

Bar :: struct {
  #as using base : xEntityBase;
  bar : string;
} @entity

xEntitySlot :: union {
  #as using base : xEntityBase;
  // This will be a union of all @entity structs!
  #insert -> string {
    sb: String_Builder;
    init_string_builder(*sb);

    for entity_type : entity_type_names {
      print_to_builder(*sb, "_%1 : %1;\n",entity_type);
      print("------------_%1 : %1;\n",entity_type);
    } 
    return builder_to_string(*sb);
  }
}

xentity_calc_global_pos :: (e : *xEntityBase) -> v3 {
  // TODO: implement
  return e.local_pos;
}

entity_type_names: [..] string;

MAX_ENTITIES :: 1024;
all_entities : [MAX_ENTITIES]xEntitySlot;
entity_index : u64;

make_entity :: ($T : Type) -> *T {
  slot : *xEntitySlot = *all_entities[entity_index];
  slot.type = T;

  entity_index+=1;
  assert(entity_index < MAX_ENTITIES);

  /*
  // we can have specific initialization for each type
  if T == {
    case Foo; init_foo(*e.foo);
    case Bar; init_bar(*e.bar);
  }
  */
  return cast(*T)slot;
}

print_entity:: (using e : *xEntityBase) {
  if type == {
    case Foo; print("we got a foo here!\n"); 
    case Bar; print("we got a bar here!\n");
  }
}


entity_test :: () {
  print("Hello Entity test!\n");

  foo1 := make_entity(Foo);
  print_entity(foo1);

  bar1 := make_entity(Bar);
  print_entity(bar1);
}


// TODO: maybe entities should be a different metaprogram?!
/*
#placeholder NUM_ENTITY_TYPES;  // The total number of entity types.
#placeholder entity_types;      // The array of entity types.
#placeholder Entity_Storage;    // Bucket_Arrays that store the various entity types.
entity_storage: Entity_Storage;
*/