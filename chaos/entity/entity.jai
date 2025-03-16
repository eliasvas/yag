XENTITY_MAX_ENTITIES :: 1024;

xEntityID :: u64;

xEntityBase :: struct { 
  id : xEntityID;
  local_pos : v3; // TODO: should be transform
  type : Type;

  // to put inside a hash map
  hash_prev : *xEntityBase;
  hash_next : *xEntityBase;

  // embedded linked list for hierarchy
  parent : *xEntityBase;
  first  : *xEntityBase;
  last   : *xEntityBase;
  prev   : *xEntityBase;
  next   : *xEntityBase;

  // misc properties
  marked_for_destruction : bool;
}

xEntityHashSlot :: struct {
  first : *xEntityBase;
  last : *xEntityBase;
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
deinit :: (using b : *Foo) {
  print("foo deinit!\n");
}





Bar :: struct @entity {
  #as using base : xEntityBase;
  bar : string;
}
init :: (using b : *Bar) {
  print("bar init!\n");
}
deinit :: (using b : *Bar) {
  print("bar init!\n");
}
update :: (using b : *Bar) {
  if (xim_kkey_pressed(.SC_UP)) xentity_lazy_delete(b.id);
  print("bar update!\n");
}

// TODO: this should be a whole transform not just position in the future
// we accumulate transforms from the parent to each node
xentity_calc_global_pos :: (e : *xEntityBase) -> v3 {
  itr := e.parent;
  gpos := e.local_pos;
  while itr {
    gpos += itr.local_pos;
    itr = itr.parent;
  }
  return gpos;
}

#placeholder xEntityStorage;
entities : xEntityStorage;

xentity_make :: ($T : Type) -> *T {
  entity_node : *xEntityBase;

  // try to get an already used node, if there aren't any create a new one (TODO: every scene should have an arena for storage)
  if entities.freelist_head {
    entity_node = entities.freelist_head;
    entities.freelist_head = sll_stack_pop(entities.freelist_head);
    entity_node.type = T;
  } else {
    entity_node = cast(*xEntityBase)alloc_array(*xeng().persistent_arena, xEntitySlot, 1);
    entity_node.type = T;
  }


  // find the new entity's ID and associated storage slot
  id := entities.next_idx;
  entities.next_idx+=1;
  entity_node.id = id;
  slot := id % XENTITY_MAX_ENTITIES;
  slot_node := *entities.slots[slot];

  // add the entity to its slot's doubly-linked list
  entities.slots[slot].first, entities.slots[slot].last = dll_push_back(entities.slots[slot].first, entities.slots[slot].last, entity_node, "hash_next", "hash_prev");

  init(ecast(entity_node,T));

  return ecast(entity_node, T);
}

xentity_find :: (id : xEntityID) ->*xEntitySlot {
  ret : *xEntitySlot;
  // TODO: we shouldn't name both entity megasumtype AND the has indices SLOTS, its confusing
  slot := id % XENTITY_MAX_ENTITIES; 
  e := entities.slots[slot].first;
  while e {
    if e.id == id { ret = cast(*xEntitySlot)e; break;}
    e = e.hash_next;
  }
  return ret;
}

xentity_lazy_delete :: (id : xEntityID) -> bool {
  e := xentity_find(id);
  if e {
    e.marked_for_destruction = true;
    return true;
  }
  return false;
}

xentity_delete :: (e : *xEntitySlot) {
  if e == null return;
  entity_deinit(e);

  child := e.first;
  while child {
    xentity_delete(cast(*xEntitySlot)child);
    child = child.next;
  }

  slot := e.id % XENTITY_MAX_ENTITIES;
  entities.slots[slot].first, entities.slots[slot].last = dll_remove(entities.slots[slot].first, entities.slots[slot].last, e);

  node_for_freelist := e;
  memset(node_for_freelist, 0, size_of(xEntitySlot));
  entities.freelist_head = sll_stack_push(entities.freelist_head, node_for_freelist);
}

xentity_attach :: (parent : xEntityID, child : xEntityID) {
  // find parent Entity
  pn := xentity_find(parent);
  assert(pn != null); // should be early return

  // find child Entity
  cn := xentity_find(child);
  assert(cn != null); // should be early return

  // attach via linked lists!
  cn.parent = pn;
  pn.first, pn.last = dll_push_back(pn.first, pn.last, cn);
}

ecast :: (e : *xEntityBase, $T : Type) -> *T {
  assert(e.type == T);
  return cast(*T)e;
}

entity_test :: () {
  print("Hello Entity test!\n");

  print("NUM_ENTITY_TYPES is %.\n", NUM_ENTITY_TYPES);

  foo1 := xentity_make(Foo);
  bar1 := xentity_make(Bar);

  entities_cleanup(*entities);
  entities_update(*entities); // should be some kind of scene update probably

  e := xentity_find(foo1.id);
  assert(e && e.id == foo1.id);
}

#run entity_test();