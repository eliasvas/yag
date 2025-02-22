#import "Basic";
#import "String";
#import "Bucket_Array";

//#load "../core/math.jai";
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

Foo :: struct @entity {
  #as using base : xEntityBase;
  foo : int;
}

Bar :: struct @entity {
  #as using base : xEntityBase;
  bar : string;
}

xentity_calc_global_pos :: (e : *xEntityBase) -> v3 {
  // TODO: implement
  return e.local_pos;
}

#placeholder xEntityStorage;
entity_storage : xEntityStorage;

make_entity :: ($T : Type) -> *T {
  _, slot := bucket_array_add(*entity_storage.array, xEntitySlot.{type=T});

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

  print("NUM_ENTITY_TYPES is %.\n", NUM_ENTITY_TYPES);

  foo1 := make_entity(Foo);
  print_entity(foo1);

  bar1 := make_entity(Bar);
  print_entity(bar1);
}