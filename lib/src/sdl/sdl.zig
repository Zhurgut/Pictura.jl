pub const c = @import("sdl");
pub const utils = @import("utils.zig");
pub const events = @import("events.zig");

pub fn init() !void {
    const success = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMEPAD);
    if (!success) {
        utils.print_sdl_error();
        return error.SDL_InitError;
    }
    errdefer c.SDL_Quit();
}

pub fn create_window(w: u32, h: u32) !*c.SDL_Window {
    const window = c.SDL_CreateWindow(
        "Pictura",
        @intCast(w),
        @intCast(h),
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_INPUT_FOCUS | c.SDL_WINDOW_VULKAN,
    );

    if (window == null) {
        utils.print_sdl_error();
        return error.SDL_CreateWindowError;
    }

    errdefer c.SDL_DestroyWindow(window);

    return window.?;
}
