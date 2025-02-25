#import "Basic";
#import "String";
#import "Bucket_Array";

// Note: Flat_Pool doesn't grow past initial alloc, at some point we should make our own allocator for this (a growing arena)
#import "Flat_Pool";

#load "entity.jai";
#load "scene.jai";
