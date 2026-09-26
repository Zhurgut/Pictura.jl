const std = @import("std");
const root = @import("../root.zig");
const sdl = root.sdl;
const vulkan = root.vulkan;

pub fn print_sdl_error() void {
    std.debug.print("{s}\n", .{sdl.c.SDL_GetError()});
}

pub fn create_vulkan_surface(window: *sdl.c.SDL_Window, instance: vulkan.c.VkInstance) !vulkan.c.VkSurfaceKHR {
    var surface: vulkan.c.VkSurfaceKHR = undefined;
    const success = sdl.c.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, @ptrCast(&surface));
    if (!success) {
        sdl.utils.print_sdl_error();
        return error.SDL_VulkanCreateSurfaceError;
    }
    return surface;
}

//      __  __
//     |  \/  |___ _  _ ___ ___
//     | |\/| / _ \ || (_-</ -_)
//     |_|  |_\___/\_,_/__/\___|
//

pub fn get_mouse_position(app: *root.PicturaApp) struct { f32, f32 } {
    const m = app.event_handler.mouse;
    return .{ m.x, m.y };
}

pub fn set_mouse_position(window: *sdl.c.SDL_Window, x: f32, y: f32) void {
    sdl.c.SDL_WarpMouseInWindow(window, x, y);
}

//     __      ___         _
//     \ \    / (_)_ _  __| |_____ __ __
//      \ \/\/ /| | ' \/ _` / _ \ V  V /
//       \_/\_/ |_|_||_\__,_\___/\_/\_/
//

pub fn get_window_position(window: *sdl.c.SDL_Window) !struct { i32, i32 } {
    var x: i32 = 0;
    var y: i32 = 0;
    const success = sdl.c.SDL_GetWindowPosition(window, &x, &y);
    if (success) {
        return .{ x, y };
    } else {
        print_sdl_error();
        return error.get_window_position_failed;
    }
}

pub fn set_window_position(window: *sdl.c.SDL_Window, x: i32, y: i32) !void {
    const success = sdl.c.SDL_SetWindowPosition(window, x, y);
    if (!success) {
        print_sdl_error();
        return error.set_window_position_failed;
    }
}

pub fn set_bordered(window: *sdl.c.SDL_Window) !void {
    const success = sdl.c.SDL_SetWindowBordered(window, true);
    if (!success) {
        print_sdl_error();
        return error.set_bordered_failed;
    }
}

pub fn set_borderless(window: *sdl.c.SDL_Window) !void {
    const success = sdl.c.SDL_SetWindowBordered(window, false);
    if (!success) {
        print_sdl_error();
        return error.set_borderless_failed;
    }
}

pub fn grab_mouse(window: *sdl.c.SDL_Window) !void {
    const success = sdl.c.SDL_SetWindowRelativeMouseMode(window, true);
    if (!success) {
        print_sdl_error();
        return error.set_mouse_grab_failed;
    }
}

pub fn release_mouse(window: *sdl.c.SDL_Window) !void {
    const success = sdl.c.SDL_SetWindowRelativeMouseMode(window, false);
    if (!success) {
        print_sdl_error();
        return error.set_mouse_release_failed;
    }
}

pub fn set_fullscreen(window: *sdl.c.SDL_Window) !void {
    const success = sdl.c.SDL_SetWindowFullscreen(window, true);
    if (!success) {
        print_sdl_error();
        return error.set_fullscreen_failed;
    }
}

pub fn set_windowed(window: *sdl.c.SDL_Window) !void {
    const success = sdl.c.SDL_SetWindowFullscreen(window, false);
    if (!success) {
        print_sdl_error();
        return error.set_windowed_failed;
    }
}

pub fn set_window_size(window: *sdl.c.SDL_Window, w: u32, h: u32) !void {
    const success = sdl.c.SDL_SetWindowSize(window, @intCast(w), @intCast(h));
    if (!success) {
        print_sdl_error();
        return error.set_window_size_failed;
    }
}

//      ___  _         _
//     |   \(_)____ __| |__ _ _  _
//     | |) | (_-< '_ \ / _` | || |
//     |___/|_/__/ .__/_\__,_|\_, |
//               |_|          |__/

pub fn get_display_from_window(window: *sdl.c.SDL_Window) !sdl.c.SDL_DisplayID {
    const display_id = sdl.c.SDL_GetDisplayForWindow(window);
    if (display_id == 0) {
        print_sdl_error();
        return error.get_display_failed;
    }
    return display_id;
}

pub fn get_display_name(display_id: sdl.c.SDL_DisplayID) ![*:0]const u8 {
    const name = sdl.c.SDL_GetDisplayName(display_id);
    if (name == null) {
        print_sdl_error();
        return error.get_display_name_failed;
    }
    return name.?;
}

pub fn get_display_size(display_id: sdl.c.SDL_DisplayID) !struct { u32, u32 } {
    const display_mode: ?*const sdl.c.SDL_DisplayMode = sdl.c.SDL_GetCurrentDisplayMode(display_id);
    if (display_mode) |dm| {
        return .{ @intCast(dm.w), @intCast(dm.h) };
    } else {
        print_sdl_error();
        return error.get_displaymode_failed;
    }
}

pub fn get_refresh_rate(display_id: sdl.c.SDL_DisplayID) !f64 {
    const display_mode: ?*const sdl.c.SDL_DisplayMode = sdl.c.SDL_GetCurrentDisplayMode(display_id);
    if (display_mode) |dm| {
        if (dm.refresh_rate_numerator == 0) {
            return error.refresh_rate_unspecified;
        }
        return @as(f64, dm.refresh_rate_numerator) / dm.refresh_rate_denominator;
    } else {
        print_sdl_error();
        return error.get_displaymode_failed;
    }
}

pub fn get_pixel_density(display_id: sdl.c.SDL_DisplayID) !f64 {
    const display_mode: ?*const sdl.c.SDL_DisplayMode = sdl.c.SDL_GetCurrentDisplayMode(display_id);
    if (display_mode) |dm| {
        return dm.pixel_density;
    } else {
        print_sdl_error();
        return error.get_displaymode_failed;
    }
}

//      _____       _
//     |_   _|__ __| |_
//       | |/ -_|_-<  _|
//       |_|\___/__/\__|
//

pub fn print_info() !void {
    var display_count: i32 = 0;
    const display_ids = sdl.c.SDL_GetDisplays(&display_count);
    defer sdl.c.SDL_free(display_ids);

    std.debug.print("SDL video driver: {s}\n", .{sdl.c.SDL_GetCurrentVideoDriver()});

    for (0..@intCast(display_count)) |i| {
        const d = display_ids[i];
        const w, const h = try get_display_size(d);
        std.debug.print("{s}\n{d} FPS\n{d}x{d}\n", .{
            get_display_name(d) catch "",
            get_refresh_rate(d) catch 0,
            w,
            h,
        });
    }
}

test "sdl display infos" {
    _ = sdl.c.SDL_SetHint(sdl.c.SDL_HINT_VIDEO_DRIVER, "wayland");
    try root.init.init_app(.{ .w = 800, .h = 600 });

    const pictura_app = &root.pictura_app;

    try pictura_app.event_handler.handle_events(pictura_app);
    try pictura_app.swapchain.present(pictura_app);

    try print_info();

    root.init.quit();
}

test "sdl utils" {
    // if (!root.test_all) {
    //     return;
    // }

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
                set_fullscreen(root.pictura_app.window) catch {
                    return;
                };
            } else if (key == 'k') {
                set_window_size(root.pictura_app.window, 100, 800) catch {
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
                set_windowed(root.pictura_app.window) catch {
                    return;
                };
            } else if (key == 'k') {
                set_window_size(root.pictura_app.window, 800, 600) catch {
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
            _ = sdl.c.SDL_SetHint(sdl.c.SDL_HINT_VIDEO_DRIVER, "wayland");
            try root.init.init_app(.{ .w = 800, .h = 600 });

            std.debug.print("refresh rate: {d}\n", .{get_refresh_rate(try get_display_from_window(root.pictura_app.window)) catch -1});
            std.debug.print("display size: {d} x {d}\n", try get_display_size(try get_display_from_window(root.pictura_app.window)));

            const pictura_app = &root.pictura_app;

            pictura_app.event_handler.mouse_moved_fn = &move_window;
            pictura_app.event_handler.key_pressed_fn = &grab;
            pictura_app.event_handler.key_released_fn = &release;

            while (pictura_app.running) {
                try pictura_app.event_handler.handle_events(pictura_app);
                try root.image.draw_background(&pictura_app.canvas, 0.1, 0.3, 0.8, 1.0, pictura_app);

                try pictura_app.swapchain.present(pictura_app);
                sdl.c.SDL_Delay(9);
            }

            root.init.quit();
        }
    };

    try Tester.run();
}
