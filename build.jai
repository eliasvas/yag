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

      add_build_file("src/game.jai", w); // game source (TODO: should be moved to different workspace)
      add_build_file("src/entity/module.jai", w);

      message_loop();
      compiler_end_intercept(w);
      //print("options %", options);
    }
    set_build_options_dc(.{do_output=false});
  }

has_note :: (header: *Code_Procedure_Header, note: string) -> bool {
    for header.notes  if it.text == note  return true;
    return false;
}

// these will be filled by all 'RunWhenReady' tagged procedures, and will be #run'd
procedures_to_run: [..] *Code_Procedure_Header;

message_loop :: () {
   while true {
      message := compiler_wait_for_message();
      if message.kind == {
         case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked)message;

            for tc: typechecked.procedure_headers {
               header := tc.expression;
               if has_note(header, "RunWhenReady") {
                  array_add(*procedures_to_run, header);
               }
            }
         case .PHASE;
            phase := cast(*Message_Phase)message;
            if phase.phase == .TYPECHECKED_ALL_WE_CAN {
               for procedures_to_run { 
                  s := tprint("#run %();", it.name);
                  add_build_string(s, message.workspace); 
               }

               // Reset the array so we don't emit duplicate runs for these procedures
               // next time we get a TYPECHECKED_ALL_WE_CAN.
               array_reset(*procedures_to_run);
            }
         case .COMPLETE;
            break;
      }
   }
}
