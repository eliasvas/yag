#import "Basic";

// TODO: support other allocators, not only Pools
// NOTE: maybe for_expansion is good here?

alloc_array :: (arena : *xArena, $type : Type, count : u32) -> *type {
  ptr := cast(*type)get(arena, size_of(type)*count);
  memset(ptr, 0, size_of(type)*count);
  return ptr;
}

sll_stack_push :: (f : *$T, n : *T, $next_field_name : string = "next") ->*T {
  #insert -> string { return tprint("n.%=f;\n", next_field_name); } // n.next = f;
  f = n;
  return f;
}

sll_stack_pop :: (f : *$T, $next_field_name : string = "next") ->*T {
  #insert -> string { return tprint("f=f.%;\n", next_field_name); } // f = f.next;
  return f;
}


sll_queue_push :: (f : *$T, l : *T, n : *T, $next_field_name : string = "next") -> *T,*T {
  if l == null {
    f = n;
    l = n;
  } else {
    #insert -> string { return tprint("l.%=n;\n", next_field_name); } // l.next = n;
    #insert -> string { return tprint("n.%=null;\n", next_field_name); } // n.next = null;
    l = n;
  }
  return f,l;
}

sll_queue_push_front :: (f : *$T, l : *T, n : *T, $next_field_name : string = "next") -> *T,*T {
  if l == null {
    f = n;
    l = n;
  } else {
    #insert -> string { return tprint("n.%=f;\n", next_field_name); } // n.next = f;
    f = n;
  }
  return f,l;
}

sll_queue_pop :: (f : *$T, l : *T, n : *T, $next_field_name : string = "next") -> *T,*T {
  if f == l {
    f = null;
    l = null;
  } else {
    #insert -> string { return tprint("f=f.%;\n", next_field_name); } // f = f.next;
  }
  return f,l;
}

// TODO: What about nil structs? maybe add another auto back for that!
dll_insert :: (f : *$T, l : *T, p : *T, n : *T, $next_field_name : string = "next", $prev_field_name : string = "prev") -> *T,*T {
  if f == null { // if list empty

    #insert -> string { 
      sb : String_Builder;
      init_string_builder(*sb);
      print_to_builder(*sb, "n.% = null;", next_field_name); // n.next = null;
      print_to_builder(*sb, "n.% = null;", prev_field_name); // n.prev = null;
      return builder_to_string(*sb);
    }
    f = n;
    l = n;
  } else if p == null { // if we insert to first
    #insert -> string { 
      sb : String_Builder;
      init_string_builder(*sb);
      print_to_builder(*sb, "n.% = f;", next_field_name); // n.next = f;
      print_to_builder(*sb, "n.% = null;", prev_field_name); // n.prev = null;
      print_to_builder(*sb, "f.% = n;", prev_field_name); // f.prev = n;
      return builder_to_string(*sb);
    }
    f = n;
  } else if p == l { // if we insert to last
    #insert -> string { 
      sb : String_Builder;
      init_string_builder(*sb);
      print_to_builder(*sb, "l.% = n;", next_field_name); // l.next = n;
      print_to_builder(*sb, "n.% = l;", prev_field_name); // n.prev = l;
      print_to_builder(*sb, "n.% = null;", next_field_name); // n.next = null;
      return builder_to_string(*sb);
    }
    l = n;
  } 
  else { // default insert
    #insert -> string { 
      sb : String_Builder;
      init_string_builder(*sb);
      print_to_builder(*sb, "p.%.% = n;", next_field_name, prev_field_name); // p.next.prev = n;
      print_to_builder(*sb, "n.% = p.%;", next_field_name, next_field_name); // n.next = p.next;
      print_to_builder(*sb, "p.% = n;", next_field_name); // p.next = n;
      print_to_builder(*sb, "n.% = p;", prev_field_name); // n.prev = p;
      return builder_to_string(*sb);
    }
  }

  return f,l;
}
dll_push_back :: (f : *$T, l : *T, n : *T, $next_field_name : string = "next", $prev_field_name : string = "prev") -> *T,*T {
  f,l := dll_insert(f,l,l,n,next_field_name, prev_field_name);
  return f,l;
}

dll_push_front :: (f : *$T, l : *T, n : *T, $next_field_name : string = "next", $prev_field_name : string = "prev") -> *T,*T {
  l,f := dll_insert(l,f,f,n,prev_field_name, next_field_name);
  return f,l;
}

// TODO: What about nil structs? maybe add another auto bake for that!
dll_remove :: (f : *$T, l : *T, n : *T, $next_field_name : string = "next", $prev_field_name : string = "prev") -> *T,*T {
  if n == f {
    #insert -> string { return tprint("f=n.%;\n", next_field_name); } // f = n.next;
  }
  if n == l {
    #insert -> string { return tprint("l=l.%;\n", prev_field_name); } // l = l.prev;
  }

  #insert -> string { return tprint("if n.% != null then n.%.%=n.%;\n", prev_field_name, prev_field_name, next_field_name, next_field_name); } // if n.prev != null then n.prev.next = n.next;
  #insert -> string { return tprint("if n.% != null then n.%.% = n.%;\n", next_field_name, next_field_name, prev_field_name, prev_field_name); } // if n.next != null then n.next.prev = n.prev;

  return f,l;
}
 


count :: (f : *$T) ->u32 {
  c : u32 = 0;
  while f {
    c+=1;
    f = f.next;
  }
  return c;
}



find :: (f : *$T, $field_name : string = "next", field_val : $K) -> *T {
  found : *T = null;
  while f {
    #insert -> string { return tprint("if f.% == field_val then found = f;\n", field_name); }
    f = f.next;
  }
  return found;
}

////////////////////////////////////////////
// Data Structure for tests
////////////////////////////////////////////
Sentence :: string;

SentenceNode :: struct {
  v : Sentence;

  next   : *SentenceNode;
  prev   : *SentenceNode;
  first  : *SentenceNode;
  last   : *SentenceNode;
  parent : *SentenceNode;

  // hash map
  hash_next : *SentenceNode;
  hash_prev : *SentenceNode;
}
SentenceSlot :: struct {
  // tree
  first  : *SentenceNode;
  last   : *SentenceNode;
}
concat_sentences :: (first : *SentenceNode) -> string {
  builder: String_Builder;
  init_string_builder(*builder);
  iter := first;
  while iter {
    print_to_builder(*builder, "%", iter.v);
    iter = iter.next;
  }
  return builder_to_string(*builder);
}

////////////////////////////////////////////
// Linked-List tests
////////////////////////////////////////////
ll_tests :: (){
  arena: xArena;
  { // singly-linked stack push 
    reset(*arena);
    first : *SentenceNode = null;

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    first = sll_stack_push(first, n1);
    first = sll_stack_push(first, n2);
    first = sll_stack_push(first, n3);
    assert(concat_sentences(first) == "EggWantI");
  }
  { // singly-linked stack pop 
    reset(*arena);
    first : *SentenceNode = null;

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    first = sll_stack_push(first, n1);
    first = sll_stack_push(first, n2);

    popped := first;
    first = sll_stack_pop(first);
    popped.next = null; // we could do the (= null) in _pop but I prefer to return dirty Nodes

    first = sll_stack_push(first, n3);
    assert(concat_sentences(first) == "EggI");
    assert(concat_sentences(popped) == "Want");
  }
  { // singly-linked queue push 
    reset(*arena);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    first,last = sll_queue_push(first, last, n1);
    first,last = sll_queue_push(first, last, n2);
    first,last = sll_queue_push(first, last, n3);
    assert(concat_sentences(first) == "IWantEgg");
  }
  { // singly-linked queue push front 
    reset(*arena);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    first,last = sll_queue_push(first, last, n1);
    first,last = sll_queue_push_front(first, last, n2);
    first,last = sll_queue_push(first, last, n3);
    assert(concat_sentences(first) == "WantIEgg");
  }
  { // singly-linked queue pop
    reset(*arena);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    first,last = sll_queue_push(first, last, n1);
    first,last = sll_queue_push_front(first, last, n2);

    popped := first;
    first,last = sll_queue_pop(first, last, n1);
    popped.next = null;

    first,last = sll_queue_push(first, last, n3);
    assert(concat_sentences(first) == "IEgg");
    assert(concat_sentences(popped) == "Want");
  }
  { // doubly-linked list insert
    reset(*arena);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    first,last = dll_insert(first, last,null, n1);
    first,last = dll_insert(first, last, last, n2);
    first,last = dll_insert(first, last, n1, n3);
    assert(concat_sentences(first) == "IEggWant");
  }
  { // doubly-linked list remove 
    reset(*arena);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    first,last = dll_insert(first, last,null, n1);
    first,last = dll_insert(first, last, last, n2);
    first,last = dll_insert(first, last, n1, n3);
    first,last = dll_remove(first, last, n3);
    assert(concat_sentences(first) == "IWant");
  }
  { // doubly-linked push back/front
    reset(*arena);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    first,last = dll_insert(first, last, null, n1);
    first,last = dll_push_back(first, last, n2);
    first,last = dll_push_front(first, last, n3);
    assert(concat_sentences(first) == "EggIWant");
  }
  { // tree
    reset(*arena);

    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    n1.first,n1.last = dll_push_back(n1.first, n1.last, n2);
    n2.parent = n1;
    n1.first,n1.last = dll_push_back(n1.first, n1.last, n3);
    n3.parent = n1;
    assert(concat_sentences(n2) == "WantEgg");
  }
  // hash table (with Slot array)
  {
    reset(*arena);

    SLOTS_COUNT :: 256;
    slots := alloc_array(*arena, SentenceSlot, SLOTS_COUNT);

    names := string.["I", "Want", "Egg"];
    for n : names {
      node := alloc_array(*arena, SentenceNode, 1); node.v = n;
      slot_num := djb2(node.v) % SLOTS_COUNT;
      slots[slot_num].first, slots[slot_num].last = sll_queue_push(slots[slot_num].first, slots[slot_num].last, node);
    }

    for n : names {
      slot_num := djb2(n) % SLOTS_COUNT;
      assert(slots[slot_num].first.v == n);
    }

    // we re-insert our data so that they become linked lists
    for n : names {
      node := alloc_array(*arena, SentenceNode, 1); node.v = n;
      slot_num := djb2(node.v) % SLOTS_COUNT;
      slots[slot_num].first, slots[slot_num].last = sll_queue_push(slots[slot_num].first, slots[slot_num].last, node);
    }

    for n : names {
      slot_num := djb2(n) % SLOTS_COUNT;
      assert(slots[slot_num].first.next.v == n);
    }
  }

  { // hash table (embedded inside a SentenceNode)
    SLOTS_COUNT :: 256;
    slots := alloc_array(*arena, SentenceNode, SLOTS_COUNT);

    names := string.["I", "Want", "Egg"];
    for n : names {
      node := alloc_array(*arena, SentenceNode, 1); node.v = n;
      slot_num := djb2(node.v) % SLOTS_COUNT;
      slots[slot_num].hash_next, slots[slot_num].hash_prev = dll_push_back(slots[slot_num].hash_next, slots[slot_num].hash_prev, node, "hash_next", "hash_prev");
    }

    for n : names {
      slot_num := djb2(n) % SLOTS_COUNT;
      assert(slots[slot_num].hash_next.v == n);
    }
  }

  { // tree + embedded hash table!
    reset(*arena);

    SLOTS_COUNT :: 256;
    slots := alloc_array(*arena, SentenceNode, SLOTS_COUNT);


    n1 := alloc_array(*arena, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*arena, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*arena, SentenceNode, 1);n3.v = "Egg";
    n1.first,n1.last = dll_push_back(n1.first, n1.last, n2);
    n2.parent = n1;
    n1.first,n1.last = dll_push_back(n1.first, n1.last, n3);
    n3.parent = n1;
    assert(concat_sentences(n2) == "WantEgg");

    slot_num := djb2(n1.v) % SLOTS_COUNT;
    slots[slot_num].hash_next, slots[slot_num].hash_prev = dll_push_back(slots[slot_num].hash_next, slots[slot_num].hash_prev, n1, "hash_next", "hash_prev");
    assert(slots[slot_num].hash_next.v == n1.v);
    slot_num = djb2(n2.v) % SLOTS_COUNT;
    slots[slot_num].hash_next, slots[slot_num].hash_prev = dll_push_back(slots[slot_num].hash_next, slots[slot_num].hash_prev, n2, "hash_next", "hash_prev");
    assert(slots[slot_num].hash_next.v == n2.v);
    slot_num = djb2(n3.v) % SLOTS_COUNT;
    slots[slot_num].hash_next, slots[slot_num].hash_prev = dll_push_back(slots[slot_num].hash_next, slots[slot_num].hash_prev, n3, "hash_next", "hash_prev");
    assert(slots[slot_num].hash_next.v == n3.v);

    n1_dupe := alloc_array(*arena, SentenceNode, 1);n1_dupe.v = "I";
    slot_num = djb2(n1_dupe.v) % SLOTS_COUNT;
    slots[slot_num].hash_next, slots[slot_num].hash_prev = dll_push_back(slots[slot_num].hash_next, slots[slot_num].hash_prev, n1_dupe, "hash_next", "hash_prev");
    assert(n1.hash_next.v == n1_dupe.v);
  }

}

#run ll_tests();







