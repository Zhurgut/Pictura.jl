const std = @import("std");

const root = @import("../root.zig");

const sdl3 = root.sdl3;

fn print_sdl_error() void {
    std.debug.print("{s}\n", .{sdl3.SDL_GetError()});
}

pub fn get_display_refresh_rate(window: *sdl3.SDL_Window) !f32 {
    const display_id = sdl3.SDL_GetDisplayForWindow(window);
    if (display_id == 0) {
        print_sdl_error();
        return error.get_display_failed;
    }
    const display_mode: ?*const sdl3.SDL_DisplayMode = sdl3.SDL_GetCurrentDisplayMode(display_id);
    if (display_mode == null) {
        print_sdl_error();
        return error.get_displaymode_failed;
    }
    if (display_mode.?.refresh_rate_numerator == 0) {
        std.debug.print("refresh rate read as 'unspecified', ={d}/{d}\n", .{ display_mode.?.refresh_rate_numerator, display_mode.?.refresh_rate_denominator });
        return 59.8; // fall back to 60 fps as default
    }

    return display_mode.?.refresh_rate;
}

pub fn get_display_size(window: *sdl3.SDL_Window) !struct { u32, u32 } {
    const display_id = sdl3.SDL_GetDisplayForWindow(window);
    if (display_id == 0) {
        print_sdl_error();
        return error.get_display_failed;
    }
    var rect: sdl3.SDL_Rect = undefined;
    const success = sdl3.SDL_GetDisplayBounds(display_id, &rect);
    if (success) {
        return .{ @intCast(rect.w - rect.x), @intCast(rect.h - rect.y) };
    } else {
        print_sdl_error();
        return error.get_display_bounds_failed;
    }
}

pub fn set_fullscreen(app: *root.PicturaApp) !void {
    const success = sdl3.SDL_SetWindowFullscreen(app.window, true);
    if (!success) {
        print_sdl_error();
        return error.set_fullscreen_failed;
    }

    const w, const h = try root.sdl_utils.get_display_size(app.window);
    try app.resize(@intCast(w), @intCast(h));
}

pub fn set_windowed(app: *root.PicturaApp) !void {
    var success = sdl3.SDL_SetWindowFullscreen(app.window, false);
    if (!success) {
        print_sdl_error();
        return error.set_windowed_failed;
    }
    var w: i32 = 0;
    var h: i32 = 0;

    success = sdl3.SDL_GetWindowSizeInPixels(app.window, &w, &h);
    if (!success) {
        print_sdl_error();
        return error.set_window_size_failed;
    }

    try app.resize(@intCast(w), @intCast(h));
}

pub fn set_window_size(app: *root.PicturaApp, w: u32, h: u32) !void {
    const success = sdl3.SDL_SetWindowSize(app.window, @intCast(w), @intCast(h));
    if (!success) {
        print_sdl_error();
        return error.set_window_size_failed;
    }

    try app.resize(@intCast(w), @intCast(h));
}

pub fn get_mouse_position(app: *root.PicturaApp) struct { f32, f32 } {
    const m = app.event_handler.mouse;
    return .{ m.x, m.y };
}

pub fn set_mouse_position(window: *sdl3.SDL_Window, x: f32, y: f32) void {
    sdl3.SDL_WarpMouseInWindow(window, x, y);
}
