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
      add_build_file("game/game.jai", w);
      message_loop();
      compiler_end_intercept(w);

      //print("options %", options);
   }
   set_build_options_dc(.{do_output=false});
}

generated_code : bool = false;
message_loop :: () {
   while true {
      message := compiler_wait_for_message();
      if message.kind == {
         case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked)message;
            for typechecked.structs note_struct(it.expression);
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
note_struct :: (code_struct: *Code_Struct) {

   /*
   if has_note(header, "entity") {
      array_add(*procedures_to_run, header);
   }
   */

   if is_subclass_of(code_struct.defined_type, "xEntityBase") && code_struct.defined_type.name != "xEntitySlot" {
      name := code_struct.defined_type.name;

      added := array_add_if_unique(*entity_type_names, name);
      if added print("Detected entity '%'.\n", name);
   }
}

generate_entity_code :: (w : Workspace) {
   quick_sort(entity_type_names, compare_strings);
   type_names := join(..entity_type_names, ", ");

   entity_storage_string : string;
   {
      builder : String_Builder;
      for entity_type_names {
         items_per_bucket :: 20;
         print_to_builder(*builder, "    _%1: Bucket_Array(%1, %2, true);\n", it, items_per_bucket);
      }
      entity_storage_string = builder_to_string(*builder);
      //print("entity_storage_string: %\n", entity_storage_string);
      build_string := sprint(ENTITY_INSERTION_STRING, entity_type_names.count, type_names, entity_storage_string);
      add_build_string(build_string, w);
      print("Adding build string:\n%\n", build_string);
   }
}

ENTITY_INSERTION_STRING :: #string DONE
NUM_ENTITY_TYPES :: %1;
entity_types : [%1] Type : .[ %2 ];
Entity_Storage :: struct {
%3
}
DONE


