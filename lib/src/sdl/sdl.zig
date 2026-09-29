pub const c = @import("sdl");
pub const utils = @import("utils.zig");
pub const events = @import("events.zig");
const root = @import("../root.zig");

pub fn init() !void {
    const success = c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMEPAD);
    if (!success) {
        utils.print_sdl_error();
        return error.SDL_InitError;
    }
    errdefer c.SDL_Quit();
}

pub fn create_window(options: root.init.PicturaOptions) !*c.SDL_Window {
    const window = c.SDL_CreateWindow(
        "Pictura",
        @intCast(options.w),
        @intCast(options.h),
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_INPUT_FOCUS | c.SDL_WINDOW_VULKAN |
            (if (options.fullscreen) c.SDL_WINDOW_FULLSCREEN else 0) |
            (if (options.borderless) c.SDL_WINDOW_BORDERLESS else 0) |
            (if (options.transparent) c.SDL_WINDOW_TRANSPARENT else 0),
    );

    if (window == null) {
        utils.print_sdl_error();
        return error.SDL_CreateWindowError;
    }

    errdefer c.SDL_DestroyWindow(window);

    return window.?;
}
