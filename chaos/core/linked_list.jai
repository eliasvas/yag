#import "Basic";
#import "Flat_Pool";

// TODO: support other allocators, not only Pools
// NOTE: maybe for_expansion is good here?

alloc_array :: (pool : *Flat_Pool, $type : Type, count : u32) -> *type {
  ptr := cast(*type)get(pool, size_of(type)*count);
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

// TODO: What about nil structs? maybe add another auto back for that!
dll_remove :: (f : *$T, l : *T, n : *T, $next_field_name : string = "next", $prev_field_name : string = "prev") -> *T,*T {
  if n == f {
    #insert -> string { return tprint("f=n.%;\n", next_field_name); } // f = n.next;
  }
  if n == l {
    #insert -> string { return tprint("l=l.%;\n", prev_field_name); } // l = l.prev;
  }
  if n.prev != null {
    #insert -> string { return tprint("n.%.% = n.%;\n", prev_field_name, next_field_name, next_field_name); } // n.prev.next = n.next;
  }
  if n.next != null {
    #insert -> string { return tprint("n.%.% = n.%;\n", next_field_name, prev_field_name, prev_field_name); } // n.next.prev = n.prev;
  }

  return f,l;
}
 


////////////////////////////////////////////
// Data Structure for tests
////////////////////////////////////////////
Sentence :: string;

SentenceNode :: struct {
  v : Sentence;
  next : *SentenceNode;
  prev : *SentenceNode;
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
//#run {
ll_tests :: (){
  pool: Flat_Pool;
  { // singly-linked stack push 
    reset(*pool);
    first : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*pool, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode, 1);n3.v = "Egg";
    first = sll_stack_push(first, n1);
    first = sll_stack_push(first, n2);
    first = sll_stack_push(first, n3);
    assert(concat_sentences(first) == "EggWantI");
  }
  { // singly-linked stack pop 
    reset(*pool);
    first : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*pool, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode, 1);n3.v = "Egg";
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
    reset(*pool);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*pool, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode, 1);n3.v = "Egg";
    first,last = sll_queue_push(first, last, n1);
    first,last = sll_queue_push(first, last, n2);
    first,last = sll_queue_push(first, last, n3);
    assert(concat_sentences(first) == "IWantEgg");
  }
  { // singly-linked queue push front 
    reset(*pool);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*pool, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode, 1);n3.v = "Egg";
    first,last = sll_queue_push(first, last, n1);
    first,last = sll_queue_push_front(first, last, n2);
    first,last = sll_queue_push(first, last, n3);
    assert(concat_sentences(first) == "WantIEgg");
  }
  { // singly-linked queue pop
    reset(*pool);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*pool, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode, 1);n3.v = "Egg";
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
    reset(*pool);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*pool, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode, 1);n3.v = "Egg";
    first,last = dll_insert(first, last,null, n1);
    first,last = dll_insert(first, last, last, n2);
    first,last = dll_insert(first, last, n1, n3);
    assert(concat_sentences(first) == "IEggWant");
  }
  { // doubly-linked list remove 
    reset(*pool);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*pool, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode, 1);n3.v = "Egg";
    first,last = dll_insert(first, last,null, n1);
    first,last = dll_insert(first, last, last, n2);
    first,last = dll_insert(first, last, n1, n3);
    first,last = dll_remove(first, last, n3);
    assert(concat_sentences(first) == "IWant");
  }
  { // doubly-linked push back/front
    reset(*pool);
    first : *SentenceNode = null;
    last  : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode, 1);n1.v = "I";
    n2 := alloc_array(*pool, SentenceNode, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode, 1);n3.v = "Egg";
    first,last = dll_insert(first, last, null, n1);
    first,last = dll_push_back(first, last, n2);
    first,last = dll_push_front(first, last, n3);
    assert(concat_sentences(first) == "EggIWant");
  }
}

//#run tests();







