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
update :: (using b : *Foo) {
  print("foo update!\n");
}
init :: (using b : *Foo) {
  print("foo init!\n");
}




Bar :: struct @entity {
  #as using base : xEntityBase;
  bar : string;
}
init :: (using b : *Bar) {
  print("bar init!\n");
}
update :: (using b : *Bar) {
  print("bar update!\n");
}

xentity_calc_global_pos :: (e : *xEntityBase) -> v3 {
  // TODO: implement
  return e.local_pos;
}

#placeholder xEntityStorage;
entities : xEntityStorage;

entity_make :: ($T : Type) -> *T {
  _, slot := bucket_array_add(*entities.array, xEntitySlot.{type=T});

  init(ecast(slot,T));

  return cast(*T)slot;
}

ecast :: (e : *xEntityBase, $T : Type) -> *T {
  assert(e.type == T);
  return cast(*T)e;
}

entity_test :: () {
  print("Hello Entity test!\n");

  print("NUM_ENTITY_TYPES is %.\n", NUM_ENTITY_TYPES);

  foo1 := entity_make(Foo);
  bar1 := entity_make(Bar);

  entities_update(*entities); // should be some kind of scene update probably
}
