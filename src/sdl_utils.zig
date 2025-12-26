const std = @import("std");

const root = @import("root.zig");

const sdl = root.sdl;

pub fn get_display_refresh_rate(window: *sdl.SDL_Window) !f32 {
    const display_id = sdl.SDL_GetDisplayForWindow(window);
    if (display_id == 0) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.get_display_failed;
    }
    const display_mode: ?*const sdl.SDL_DisplayMode = sdl.SDL_GetCurrentDisplayMode(display_id);
    if (display_mode == null) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.get_displaymode_failed;
    }
    return display_mode.?.refresh_rate;
}

pub fn get_display_size(window: *sdl.SDL_Window) !struct { u32, u32 } {
    const display_id = sdl.SDL_GetDisplayForWindow(window);
    if (display_id == 0) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.get_display_failed;
    }
    var rect: sdl.SDL_Rect = undefined;
    const success = sdl.SDL_GetDisplayBounds(display_id, &rect);
    if (success) {
        return .{ @intCast(rect.w - rect.x), @intCast(rect.h - rect.y) };
    } else {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.get_display_bounds_failed;
    }
}

pub fn get_window_position(window: *sdl.SDL_Window) !struct { i32, i32 } {
    var x: i32 = 0;
    var y: i32 = 0;
    const success = sdl.SDL_GetWindowPosition(window, &x, &y);
    if (success) {
        return .{ x, y };
    } else {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.get_window_position_failed;
    }
}

pub fn set_window_position(window: *sdl.SDL_Window, x: i32, y: i32) !void {
    const success = sdl.SDL_SetWindowPosition(window, x, y);
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_window_position_failed;
    }
}

pub fn set_fullscreen(app: *root.PicturaApp) !void {
    const success = sdl.SDL_SetWindowFullscreen(app.window, true);
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_fullscreen_failed;
    }

    const w, const h = try root.sdl_utils.get_display_size(app.window);
    try app.resize(@intCast(w), @intCast(h));
}

pub fn set_windowed(app: *root.PicturaApp) !void {
    var success = sdl.SDL_SetWindowFullscreen(app.window, false);
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_windowed_failed;
    }
    var w: i32 = 0;
    var h: i32 = 0;

    success = sdl.SDL_GetWindowSizeInPixels(app.window, &w, &h);
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_window_size_failed;
    }

    try app.resize(@intCast(w), @intCast(h));
}

pub fn set_window_size(app: *root.PicturaApp, w: u32, h: u32) !void {
    const success = sdl.SDL_SetWindowSize(app.window, @intCast(w), @intCast(h));
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_window_size_failed;
    }

    try app.resize(@intCast(w), @intCast(h));
}

pub fn set_bordered(window: *sdl.SDL_Window) !void {
    const success = sdl.SDL_SetWindowBordered(window, true);
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_bordered_failed;
    }
}

pub fn set_borderless(window: *sdl.SDL_Window) !void {
    const success = sdl.SDL_SetWindowBordered(window, false);
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_borderless_failed;
    }
}

pub fn grab_mouse(window: *sdl.SDL_Window) !void {
    const success = sdl.SDL_SetWindowRelativeMouseMode(window, true);
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_mouse_grab_failed;
    }
}

pub fn release_mouse(window: *sdl.SDL_Window) !void {
    const success = sdl.SDL_SetWindowRelativeMouseMode(window, false);
    if (!success) {
        std.debug.print("{s}\n", .{sdl.SDL_GetError()});
        return error.set_mouse_release_failed;
    }
}

pub fn get_mouse_position(app: *root.PicturaApp) struct { f32, f32 } {
    const m = app.event_handler.mouse;
    return .{ m.x, m.y };
}

pub fn set_mouse_position(window: *sdl.SDL_Window, x: f32, y: f32) void {
    sdl.SDL_WarpMouseInWindow(window, x, y);
}

test "sdl utils" {
    const Tester = struct {
        var grabbed: bool = false;
        var x: f32 = 0.0;
        var y: f32 = 0.0;

        fn grab(key: u8, _: i32, _: i32, _: i32) callconv(.c) void {
            if (key == 133 and !grabbed) { // CTRL
                grabbed = true;
                x, y = get_mouse_position(&root.pictura_app);
                grab_mouse(root.pictura_app.window) catch {
                    return;
                };
                set_borderless(root.pictura_app.window) catch {
                    return;
                };
            } else if (key == ' ') { // SPACE
                set_fullscreen(&root.pictura_app) catch {
                    return;
                };
            } else if (key == 'k') {
                set_window_size(&root.pictura_app, 100, 800) catch {
                    return;
                };
            }
        }

        fn release(key: u8, _: i32, _: i32, _: i32) callconv(.c) void {
            if (key == 133) { // CTRL
                grabbed = false;
                release_mouse(root.pictura_app.window) catch {
                    return;
                };
                set_mouse_position(root.pictura_app.window, x, y);
                set_bordered(root.pictura_app.window) catch {
                    return;
                };
            } else if (key == ' ') { // SPACE
                set_windowed(&root.pictura_app) catch {
                    return;
                };
            } else if (key == 'k') {
                set_window_size(&root.pictura_app, 800, 600) catch {
                    return;
                };
            }
        }

        fn move_window(px: f32, py: f32, nx: f32, ny: f32) callconv(.c) void {
            // called on mouse movement
            if (grabbed) {
                const dx: i32 = @intFromFloat(nx - px);
                const dy: i32 = @intFromFloat(ny - py);
                const cx, const cy = get_window_position(root.pictura_app.window) catch {
                    return;
                };
                set_window_position(root.pictura_app.window, cx + dx, cy + dy) catch {
                    return;
                };
            }
        }

        fn run() !void {
            try root.init._init(800, 600, false);

            std.debug.print("refresh rate: {d}\n", .{try get_display_refresh_rate(root.pictura_app.window)});
            std.debug.print("display size: {d} x {d}\n", try get_display_size(root.pictura_app.window));

            const pictura_app = &root.pictura_app;

            pictura_app.event_handler.mouse_moved_fn = &move_window;
            pictura_app.event_handler.key_pressed_fn = &grab;
            pictura_app.event_handler.key_released_fn = &release;

            while (pictura_app.running) {
                try pictura_app.event_handler.handle_events(pictura_app);
                try root.image.draw_background(&pictura_app.canvas, 0.1, 0.3, 0.8, 1.0, pictura_app);

                try pictura_app.swapchain.present(pictura_app);
                sdl.SDL_Delay(9);
            }

            root.init.quit();
        }
    };

    try Tester.run();
}
