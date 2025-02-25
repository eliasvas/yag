
// TODO: Instead of this monstrocity, we should probably have some RUNTIME check for backends + load the functions ourselves
SDL_IMPL :: true;

offset_of :: ($T: Type, ident: Code) -> s64 #expand { t: T = ---; return cast(*void) (*t.#insert ident) - cast(*void) *t; }

#load "math.jai";
#load "ogl.jai";
#load "window.jai";
#load "input.jai";
#load "json_parser.jai";
#load "linked_list.jai";
#load "engine.jai";
