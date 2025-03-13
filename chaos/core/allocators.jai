#import "Basic";
#import "Flat_Pool";

// NOTE: for now we use jai's Flat_Pool as an arena, in the future we should implement
// our own because Flat_Pool doesn't scale with linked-list fashion

xArena :: Flat_Pool;
xarena_allocator_proc :: flat_pool_allocator_proc;

#run {
  // Declare an xArena as so:
  arena : xArena;

  memory := cast(*u8) get(*arena, 100);
  for 0..99 memory[it] = xx it;
  for 0..99 { assert(memory[it] == it); }

  Thing :: struct { name := "A Thing"; value := 42.0; }

  // We can also use arena's allocator proc:
  a: Allocator;
  a.proc = xarena_allocator_proc;
  a.data = *arena;
  thing := New(Thing,, a);
  assert(thing.name == "A Thing");

  // reset will put the 'base' pointer to 0
  reset(*arena);
  // FYI: to ensure there is no use after free we can overwrite_memory to poison it I think (using this reset will crash)
  //reset(*arena, overwrite_memory=true);

  assert(thing.name == "A Thing");

  // to actually release everything you can
  fini(*arena);
}