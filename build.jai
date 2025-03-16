#import "Basic";
#import "Compiler";
#import "String";
#import "Bucket_Array";
#import "Sort";

#run build();

build :: () {
   {
      w := compiler_create_workspace();
      options := get_build_options();
      options.output_type = .EXECUTABLE;
      options.output_executable_name = "game";
      options.output_path = ".build";

      import_paths: [..]string;
      array_add(*import_paths, tprint("%", #filepath));
      for options.import_path array_add(*import_paths, it);
      options.import_path = import_paths;

      // TODO: differentiate on DEBUG/RELEASE builds
      {
          options.stack_trace = true;
          options.backtrace_on_crash = .OFF;
          options.array_bounds_check = .ON;
          options.cast_bounds_check  = .FATAL; 
          options.null_pointer_check = .ON;
          options.enable_bytecode_inliner = true; 
          //options.runtime_storageless_type_info = true;
          //options.dead_code_elimination = .NONE;
      }

      //set_optimization(*options, .VERY_OPTIMIZED);
      set_optimization(*options, .DEBUG);
      set_build_options(options, w);

      // build the entity placeholders (in entity.jai)
      compiler_begin_intercept(w);
      add_build_file("chaos/module.jai", w); // engine source
      add_build_file("game/game.jai", w); // game source (TODO: should be moved to different workspace)
      add_build_file("game/sprite.jai", w); // game source (TODO: should be moved to different workspace)
      message_loop();
      compiler_end_intercept(w);

      //print("options %", options);
   }
   set_build_options_dc(.{do_output=false});
}

generated_code : bool = false;

has_note :: (header: *Code_Procedure_Header, note: string) -> bool {
    for header.notes  if it.text == note  return true;
    return false;
}

message_loop :: () {
   while true {
      message := compiler_wait_for_message();
      if message.kind == {
         case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked)message;
            for typechecked.structs try_add_entity_subclasses(it.expression);
         case .PHASE;
            phase := cast(*Message_Phase)message;
            if phase.phase == .TYPECHECKED_ALL_WE_CAN {
               if !generated_code {
                  generate_entity_code(message.workspace);
                  generated_code = true;
               }
            }
         case .COMPLETE;
            break;
      }

   }
}
entity_type_names: [..] string;
try_add_entity_subclasses :: (code_struct: *Code_Struct) {
   for note : code_struct.notes {
      if note.text == "entity" {
         name := code_struct.defined_type.name;
         added := array_add_if_unique(*entity_type_names, name);
         break;
      }
   }
}

generate_entity_code :: (w : Workspace) {
   quick_sort(entity_type_names, compare_strings);
   type_names := join(..entity_type_names, ", ");

   entity_storage_string : string;
   {
      builder : String_Builder;
      for entity_type_names {
         print_to_builder(*builder, "_%1: %1;\n", it);
      }
      slot_string := builder_to_string(*builder);
      storage_string : string= "slots : [XENTITY_MAX_ENTITIES]xEntityHashSlot;\n freelist_head : *xEntityBase;\n next_idx : u32 = 1;";

      ubuilder : String_Builder;
      for entity_type_names {
         print_to_builder(*ubuilder, "case %1;\n update(ecast(itr,%1));\n", it);
      }
      update_string := builder_to_string(*ubuilder);

      dbuilder : String_Builder;
      for entity_type_names {
         print_to_builder(*ubuilder, "case %1;\n deinit(ecast(e,%1));\n", it);
      }
      deinit_string := builder_to_string(*ubuilder);




      build_string := sprint(ENTITY_INSERTION_STRING, entity_type_names.count, type_names, slot_string, storage_string, update_string, deinit_string);
      add_build_string(build_string, w);
      //print("Adding build string:\n%\n", build_string);
   }
}

ENTITY_INSERTION_STRING :: #string DONE
NUM_ENTITY_TYPES :: %1;
entity_types : [%1] Type : .[ %2 ];
xEntitySlot :: union {
  #as using base : xEntityBase;
%3 
}
xEntityStorage :: struct {
%4
}
entities_update :: (entities : *xEntityStorage) {
   for slot : 0..XENTITY_MAX_ENTITIES-1 {
      e := *entities.slots[slot];
      itr := e.first;
      while itr {
         if itr.type == {
            %5
            case;
         }
         itr=itr.hash_next;
      }
   }

}

entity_deinit :: (e : *xEntitySlot) {
   if e.type == {
      %6
      case;
   }
}

entities_cleanup :: (entities : *xEntityStorage) {
   for slot : 0..XENTITY_MAX_ENTITIES-1 {
      e := *entities.slots[slot];
      itr := e.first;
      while itr {
         // we get the node, memzero it, remove from hashmap and insert it to the freelist
         if itr.marked_for_destruction {
            xentity_delete(cast(*xEntitySlot)itr);
         }
         itr = itr.next;
      }
   }

}
DONE


