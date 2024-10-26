
#run build();

build :: () {
   {
      w2 := get_current_workspace();
      print("the current workspace is %\n", w2);
   }

   {
      w := compiler_create_workspace();
      options := get_build_options();
      options.output_type = .EXECUTABLE;
      options.output_executable_name = "game";
      options.output_path = "../.build";

      import_path: [..] string;
      array_add(*import_path, ..options.import_path);
      array_add(*import_path, ".");
      options.import_path = import_path;

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
      add_build_file("game.jai", w);
      //print("options %", options);
   }
   set_build_options_dc(.{do_output=false});
}

#import "Basic";
#import "Compiler";

