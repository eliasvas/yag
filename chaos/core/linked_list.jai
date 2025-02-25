#import "Basic";
#import "Flat_Pool";

// TODO: support other allocators, not only Pools

alloc_array :: (pool : *Flat_Pool, type : $T, count : u32) -> *T {
  ptr := cast(*T)get(pool, size_of(T)*count);
  memset(ptr, 0, size_of(T)*count);
  return ptr;
}

sll_stack_push :: (f : *$T, n : *T) ->*T {
  n.next = f;
  f = n;
  return f;
}

sll_stack_pop :: (f : *$T) -> *T {
  f = f.next;
  return f;
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

    n1 := alloc_array(*pool, SentenceNode.{}, 1);n1.v = "Egg";
    n2 := alloc_array(*pool, SentenceNode.{}, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode.{}, 1);n3.v = "I";
    first = sll_stack_push(first, n1);
    first = sll_stack_push(first, n2);
    first = sll_stack_push(first, n3);
    assert(concat_sentences(first) == "IWantEgg");
  }
  { // singly-linked stack pop 
    reset(*pool);
    first : *SentenceNode = null;

    n1 := alloc_array(*pool, SentenceNode.{}, 1);n1.v = "Egg";
    n2 := alloc_array(*pool, SentenceNode.{}, 1);n2.v = "Want";
    n3 := alloc_array(*pool, SentenceNode.{}, 1);n3.v = "I";
    first = sll_stack_push(first, n1);
    first = sll_stack_push(first, n2);

    popped := first;
    first = sll_stack_pop(first);
    popped.next = null; // we could do the (= null) in _pop but I prefer to return dirty Nodes

    first = sll_stack_push(first, n3);
    assert(concat_sentences(first) == "IEgg");
    assert(concat_sentences(popped) == "Want");
  }
}

//#run tests();







