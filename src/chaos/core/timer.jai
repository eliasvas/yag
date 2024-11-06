#import "Basic";
#import "String";
#import "SDL";

/*
    Currently this is a thin wrapper around SDL's Timer module.
    you can xtimer_make to create a timer that runs for an amount of times,
    if you provide INFINITE, it will never stop!

    TODO: is there any better way to pass the context to xTimerCtx, maybe by pointer? Context is pretty large AFAIK
    TODO: maybe we can have a return value for xTimerCallback to signify abrupt stop?
*/

U32_MAX :: 0xFFFF_FFFF;
INFINITY :: U32_MAX;

#if SDL_IMPL {
    SDL_TimerCallback :: #type (interval : u32, param : *void) -> u32 #c_call;
    SDL_AddTimer :: (interval : u32, callback : SDL_TimerCallback, userdata : *void) -> s32 #foreign SDL2;
    SDL_callback_wrapper :: (interval : u32, param : *void) -> u32 #c_call {
        timer_ctx : *xTimerCtx = xx param;
        if timer_ctx.retries > 0 {
            push_context timer_ctx.usr_ctx {
                timer_ctx.usr_cb(timer_ctx.retries, timer_ctx.usr_data);
            }
            timer_ctx.retries = ifx timer_ctx.retries == INFINITY then INFINITY else timer_ctx.retries - 1;
            return timer_ctx.interval;
        } else {
            return 0;

        }
    }
}

xTimerCallback :: #type (retries : u32, usr_data : *void);


xTimerCtx :: struct {
    usr_data : *void;
    usr_cb : xTimerCallback;
    usr_ctx : Context;
    interval : u32;
    retries : u32;
};

xTimer :: struct {
    ctx : *xTimerCtx;
    impl_state : *void;
};


// TODO: can we optionally provide allocator or something here
xtimer_make :: (interval : u32, retry_count : u32 = 0, cb: xTimerCallback, user_ctx : *void) -> xTimer {
    timer : xTimer;

    #if SDL_IMPL {
        ctx : *xTimerCtx = alloc(size_of(xTimerCtx));
        ctx.usr_data = user_ctx;
        ctx.usr_ctx = context;
        ctx.usr_cb = cb;
        ctx.interval = interval;
        ctx.retries = retry_count;
        timer.impl_state = xx SDL_AddTimer(interval, SDL_callback_wrapper, ctx);
    }

    return timer;
}

xtimer_destroy :: (using timer : *xTimer) -> bool {
    #if SDL_IMPL {
        if impl_state {
            free(timer.ctx);
            return SDL_RemoveTimer(xx impl_state);
        }
    }
    return false;
}
