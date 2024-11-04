#import "Basic";
#import "String";
#import "SDL";
/*
    Currently this is a thin wrapper around SDL's Timer module.
    you can xtimer_make to create a timer, return value on your callback will
    be millis before next timeout, when 0, we stop!

    TODO: currently our callback is #c_call, can we change this? or mitigate somehow?
*/

SDL_TimerCallback :: #type (interval : u32, param : *void) -> u32 #c_call;
SDL_AddTimer :: (interval : u32, callback : SDL_TimerCallback, userdata : *void) -> s32 #foreign SDL2;
SDL_callback_wrapper :: (interval : u32, param : *void) -> u32 #c_call {
    timer_ctx : *xTimerCtx = xx param;
    if timer_ctx.retries {
        timer_ctx.usr_cb(timer_ctx.retries, timer_ctx.usr_ctx);
        timer_ctx.retries-=1;
        return timer_ctx.interval;
    } else {
        return 0;
    }
}

xTimerCallback :: #type (retries : u32, usr_ctx : *void) -> u32 #c_call;


xTimerCtx :: struct {
    usr_ctx : *void;
    usr_cb : xTimerCallback;
    interval : u32;
    retries : u32;
};

xTimer :: struct {
    ctx : *xTimerCtx;
    impl_state : *void;
};


// optionally here provide allocator or something
xtimer_make :: (interval : u32, retry_count : u32 = 0, cb: xTimerCallback, user_ctx : *void) -> xTimer {
    timer : xTimer;
    #if true {
        ctx : *xTimerCtx = alloc(size_of(xTimerCtx));
        ctx.usr_ctx = user_ctx;
        ctx.usr_cb = cb;
        ctx.interval = interval;
        ctx.retries = retry_count;
        timer.impl_state = xx SDL_AddTimer(interval, SDL_callback_wrapper, ctx);
    }
    return timer;
}

xtimer_destroy :: (using timer : *xTimer) -> bool {
    #if true {
        if impl_state {
            free(timer.ctx);
            return SDL_RemoveTimer(xx impl_state);
        }
    }
    return false;
}