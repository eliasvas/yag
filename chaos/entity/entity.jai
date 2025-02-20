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
  using base : xEntityBase;
  foo : int;
}
update_foo :: (using f : *Foo) {
  foo+=1;
}

Bar :: struct {
  using base : xEntityBase;
  bar : string;
}

update_bar :: (using b : *Bar) {
  print("bar update");
}

xEntitySlot :: union  {
  foo : Foo;
  bar : Bar;
}

xentity_calc_global_pos :: (e : *xEntityBase) -> v3 {
  // TODO: implement
  return e.local_pos;
}

MAX_ENTITIES :: 1024;
all_entities : [MAX_ENTITIES]xEntitySlot;

update_all_entities :: () {
  for *e: all_entities {
    if e.type == {
      case Foo; update_foo(*e.foo);
      case Bar; update_bar(*e.bar);
    }
  }
}