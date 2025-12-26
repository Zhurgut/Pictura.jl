const std = @import("std");
const root = @import("root.zig");

// convert zig errors to strings :)
pub export fn error_string(err: u32) [*:0]const u8 {
    return @errorName(@errorFromInt(@as(u16, @intCast(err))));
}

pub export fn init(w: u32, h: u32, hdpi: i32) u32 {
    root.init._init(w, h, hdpi != 0) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn get_framerate() f64 {
    return 1e9 / @as(f64, @floatFromInt(root.pictura_app.last_frame_time - root.pictura_app.before_last_time));
}

pub export fn set_framerate(f: f64) f64 {
    const fr = std.math.clamp(f, 1e-6, 2000);
    root.pictura_app.target_framerate = @floatCast(fr);
    return root.pictura_app.target_framerate;
}

pub export fn get_canvas() *const anyopaque {
    return &root.pictura_app.canvas;
}

pub export fn draw_background(image: *anyopaque, r: f32, g: f32, b: f32, a: f32) u32 {
    root.image.draw_background(@ptrCast(@alignCast(image)), r, g, b, a, &root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn wait_until_next_frame() void {
    root.pictura_app.wait_until_next_frame();
}

pub export fn handle_events() u32 {
    root.pictura_app.event_handler.handle_events(&root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn present() u32 {
    root.pictura_app.swapchain.present(&root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn delay(ns: u64) void {
    root.sdl.SDL_DelayNS(ns);
}

pub export fn quit() void {
    root.init.quit();
}

pub export fn create_image(w: u32, h: u32) ?*const anyopaque {
    const mem_index = root.utils.get_device_memory_index(root.pictura_app.physical_device) catch {
        return null;
    };

    const image = root.image.PicturaImage.create(
        w,
        h,
        root.pictura_app.device,
        root.pictura_app.queue_family_index,
        mem_index,
    ) catch {
        return null;
    };

    const image_ptr = root.pictura_app.gpa.create(root.image.PicturaImage) catch {
        return null;
    };

    image_ptr.* = image;

    return image_ptr;
}

pub export fn destroy_image(image: *anyopaque) void {
    var pimage: *root.image.PicturaImage = @ptrCast(@alignCast(image));
    pimage.destroy(root.pictura_app.device, root.pictura_app.descriptor_pool);

    root.pictura_app.gpa.destroy(pimage);
}

pub export fn load_pixels(image: *anyopaque) ?[*]u32 {
    const pixels = root.image.load_pixels(@ptrCast(@alignCast(image)), &root.pictura_app) catch {
        return null;
    };
    return pixels;
}

pub export fn update_pixels(image: *anyopaque) u32 {
    root.image.update_pixels(@ptrCast(@alignCast(image)), &root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn draw_point(image: *anyopaque, x: f32, y: f32, r: f32, g: f32, b: f32, a: f32, stroke_radius: f32) u32 {
    root.image.draw_point2(@ptrCast(@alignCast(image)), x, y, r, g, b, a, stroke_radius, &root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn draw_line(
    image: *anyopaque,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    stroke_radius: f32,
    tl_x: f32,
    tl_y: f32,
    tr_x: f32,
    tr_y: f32,
    bl_x: f32,
    bl_y: f32,
    br_x: f32,
    br_y: f32,
) u32 {
    root.image.draw_line(
        @ptrCast(@alignCast(image)),
        [2]f32{ x1, y1 },
        [2]f32{ x2, y2 },
        [4]f32{ r, g, b, a },
        stroke_radius,
        [2]f32{ tl_x, tl_y },
        [2]f32{ tr_x, tr_y },
        [2]f32{ bl_x, bl_y },
        [2]f32{ br_x, br_y },
        &root.pictura_app,
    ) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn draw_ellipse(
    image: *anyopaque,
    radius_x: f32,
    radius_y: f32,
    fill_r: f32,
    fill_g: f32,
    fill_b: f32,
    fill_a: f32,
    stroke_r: f32,
    stroke_g: f32,
    stroke_b: f32,
    stroke_a: f32,
    stroke_radius: f32,
    tl_x: f32,
    tl_y: f32,
    tr_x: f32,
    tr_y: f32,
    bl_x: f32,
    bl_y: f32,
    br_x: f32,
    br_y: f32,
) u32 {
    if (radius_x >= radius_y) {
        root.image.draw_ellipse(
            @ptrCast(@alignCast(image)),
            [4]f32{ fill_r, fill_g, fill_b, fill_a },
            [4]f32{ stroke_r, stroke_g, stroke_b, stroke_a },
            [2]f32{ radius_x, radius_y },
            stroke_radius,
            [2]f32{ tl_x, tl_y },
            [2]f32{ tr_x, tr_y },
            [2]f32{ bl_x, bl_y },
            [2]f32{ br_x, br_y },
            &root.pictura_app,
        ) catch |e| {
            return @intFromError(e);
        };
        return 0;
    } else { // rotate the labels
        root.image.draw_ellipse(
            @ptrCast(@alignCast(image)),
            [4]f32{ fill_r, fill_g, fill_b, fill_a },
            [4]f32{ stroke_r, stroke_g, stroke_b, stroke_a },
            [2]f32{ radius_y, radius_x },
            stroke_radius,
            [2]f32{ bl_x, bl_y },
            [2]f32{ tl_x, tl_y },
            [2]f32{ br_x, br_y },
            [2]f32{ tr_x, tr_y },
            &root.pictura_app,
        ) catch |e| {
            return @intFromError(e);
        };
        return 0;
    }
}

pub export fn draw_rect(
    image: *anyopaque,
    w: f32,
    h: f32,
    corner_radius: f32,
    fill_r: f32,
    fill_g: f32,
    fill_b: f32,
    fill_a: f32,
    stroke_r: f32,
    stroke_g: f32,
    stroke_b: f32,
    stroke_a: f32,
    stroke_radius: f32,
    tl_x: f32,
    tl_y: f32,
    tr_x: f32,
    tr_y: f32,
    bl_x: f32,
    bl_y: f32,
    br_x: f32,
    br_y: f32,
) u32 {
    root.image.draw_rect(
        @ptrCast(@alignCast(image)),
        [4]f32{ fill_r, fill_g, fill_b, fill_a },
        [4]f32{ stroke_r, stroke_g, stroke_b, stroke_a },
        stroke_radius,
        w,
        h,
        corner_radius,
        [2]f32{ tl_x, tl_y },
        [2]f32{ tr_x, tr_y },
        [2]f32{ bl_x, bl_y },
        [2]f32{ br_x, br_y },
        &root.pictura_app,
    ) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn get_mouse_x() f32 {
    return root.pictura_app.event_handler.mouse.x;
}

pub export fn get_mouse_y() f32 {
    return root.pictura_app.event_handler.mouse.y;
}

pub export fn get_mouse_state(x: ?*f32, y: ?*f32, x_prev: ?*f32, y_prev: ?*f32, left: ?*i32, middle: ?*i32, right: ?*i32) void {
    if (x != null) {
        x.?.* = root.pictura_app.event_handler.mouse.x;
    }
    if (y != null) {
        y.?.* = root.pictura_app.event_handler.mouse.y;
    }
    if (x_prev != null) {
        x_prev.?.* = root.pictura_app.event_handler.mouse.x_prev;
    }
    if (y_prev != null) {
        y_prev.?.* = root.pictura_app.event_handler.mouse.y_prev;
    }
    if (left != null) {
        left.?.* = @intFromBool(root.pictura_app.event_handler.mouse.buttons[root.sdl.SDL_BUTTON_LEFT]);
    }
    if (middle != null) {
        middle.?.* = @intFromBool(root.pictura_app.event_handler.mouse.buttons[root.sdl.SDL_BUTTON_MIDDLE]);
    }
    if (right != null) {
        right.?.* = @intFromBool(root.pictura_app.event_handler.mouse.buttons[root.sdl.SDL_BUTTON_RIGHT]);
    }
}

pub export fn is_key_pressed(key: u8) i32 {
    return @intFromBool(root.events.is_key_pressed(key));
}

pub export fn set_mouse_position(x: f32, y: f32) void {
    root.sdl_utils.set_mouse_position(root.pictura_app.window, x, y);
}

pub export fn set_mouse_pressed_fn(f: *const fn (x: f32, y: f32, button: u32) callconv(.c) void) void {
    root.pictura_app.event_handler.mouse_pressed_fn = f;
}
pub export fn set_mouse_released_fn(f: *const fn (x: f32, y: f32, button: u32) callconv(.c) void) void {
    root.pictura_app.event_handler.mouse_released_fn = f;
}
pub export fn set_mouse_wheel_fn(f: *const fn (vert: f32, hori: f32) callconv(.c) void) void {
    root.pictura_app.event_handler.mouse_wheel_fn = f;
}
pub export fn set_mouse_moved_fn(f: *const fn (x_prev: f32, y_prev: f32, x: f32, y: f32) callconv(.c) void) void {
    root.pictura_app.event_handler.mouse_moved_fn = f;
}
pub export fn set_mouse_dragged_fn(f: *const fn (x_prev: f32, y_prev: f32, x: f32, y: f32) callconv(.c) void) void {
    root.pictura_app.event_handler.mouse_dragged_fn = f;
}
pub export fn set_key_pressed_fn(f: *const fn (key: u8, shift: i32, ctrl: i32, alt: i32) callconv(.c) void) void {
    root.pictura_app.event_handler.key_pressed_fn = f;
}
pub export fn set_key_released_fn(f: *const fn (key: u8, shift: i32, ctrl: i32, alt: i32) callconv(.c) void) void {
    root.pictura_app.event_handler.key_released_fn = f;
}

pub export fn get_display_refresh_rate() f32 {
    const r = root.sdl_utils.get_display_refresh_rate(root.pictura_app.window) catch {
        return 60.0; // sensible default instead of something like 0
    };
    return r;
}

pub export fn get_display_size(w: *u32, h: *u32) u32 {
    w.*, h.* = root.sdl_utils.get_display_size(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn get_window_position(w: *i32, h: *i32) u32 {
    w.*, h.* = root.sdl_utils.get_window_position(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_window_position(x: i32, y: i32) u32 {
    root.sdl_utils.set_window_position(root.pictura_app.window, x, y) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_fullscreen() u32 {
    root.sdl_utils.set_fullscreen(&root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_windowed() u32 {
    root.sdl_utils.set_windowed(&root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn get_window_size(w: *u32, h: *u32) void {
    w.* = root.pictura_app.canvas.w;
    h.* = root.pictura_app.canvas.h;
}

pub export fn set_window_size(w: u32, h: u32) u32 {
    root.sdl_utils.set_window_size(&root.pictura_app, w, h) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_bordered() u32 {
    root.sdl_utils.set_bordered(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_borderless() u32 {
    root.sdl_utils.set_borderless(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn grab_mouse() u32 {
    root.sdl_utils.grab_mouse(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn release_mouse() u32 {
    root.sdl_utils.release_mouse(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}
