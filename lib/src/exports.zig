const std = @import("std");
const root = @import("root.zig");

const Image = *anyopaque;
const ErrorCode = u32;

// convert zig errors to strings :)
pub export fn error_string(err: u32) [*:0]const u8 {
    return @errorName(@errorFromInt(@as(u16, @intCast(err))));
}

pub export fn init(w: u32, h: u32) ErrorCode {
    root.init.init(w, h) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn get_frametime() f64 {
    return 1e-9 * @as(f64, @floatFromInt(root.pictura_app.last_frame_time - root.pictura_app.before_last_time));
}

pub export fn set_framerate(f: f64) f64 {
    const fr = std.math.clamp(f, 0.1, 2000);
    root.pictura_app.target_framerate = @floatCast(fr);
    return root.pictura_app.target_framerate;
}

pub export fn get_canvas() Image {
    return &root.pictura_app.canvas;
}

pub export fn get_canvas_id() i64 {
    return root.pictura_app.canvas_id;
}

pub export fn wait_until_next_frame() void {
    root.pictura_app.wait_until_next_frame();
}

pub export fn draw_background(image: Image, r: f32, g: f32, b: f32, a: f32) ErrorCode {
    root.image.draw_background(@ptrCast(@alignCast(image)), r, g, b, a, &root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn handle_events() ErrorCode {
    root.pictura_app.event_handler.handle_events(&root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn present() ErrorCode {
    root.pictura_app.swapchain.present(&root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn delay(ns: u64) void {
    root.sdl.SDL_DelayNS(ns);
}

pub export fn window_close_requested() i32 {
    return @intFromBool(root.pictura_app.running == false);
}

pub export fn quit() void {
    root.init.quit();
}

pub export fn create_image(w: u32, h: u32) ?Image {
    var image = root.image.PicturaImage.create(
        w,
        h,
        root.pictura_app.device,
        root.pictura_app.queue_family_index,
        root.pictura_app.physical_device,
    ) catch {
        return null;
    };

    const image_ptr = root.pictura_app.gpa.create(root.image.PicturaImage) catch {
        image.destroy(root.pictura_app.device, root.pictura_app.descriptor_pool);
        return null;
    };

    image_ptr.* = image;

    return image_ptr;
}

pub export fn create_image_from_pixels(w: u32, h: u32, srcpixels: [*]u32) ?Image {
    var image = root.image.PicturaImage.from_pixels(
        w,
        h,
        srcpixels,
        &root.pictura_app,
    ) catch {
        return null;
    };

    const image_ptr = root.pictura_app.gpa.create(root.image.PicturaImage) catch {
        image.destroy(root.pictura_app.device, root.pictura_app.descriptor_pool);
        return null;
    };

    image_ptr.* = image;

    return image_ptr;
}

pub export fn destroy_image(image: Image) void {
    var pimage: *root.image.PicturaImage = @ptrCast(@alignCast(image));
    pimage.destroy(root.pictura_app.device, root.pictura_app.descriptor_pool);

    root.pictura_app.gpa.destroy(pimage);
}

pub export fn load_pixels(image: Image) ?[*]u32 {
    const pixels = root.image.load_pixels(@ptrCast(@alignCast(image)), &root.pictura_app) catch {
        return null;
    };
    return pixels;
}

pub export fn update_pixels(image: Image) ErrorCode {
    root.image.update_pixels(@ptrCast(@alignCast(image)), &root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn draw_point(image: Image, x: f32, y: f32, r: f32, g: f32, b: f32, a: f32, stroke_radius: f32) ErrorCode {
    root.image.draw_point2(@ptrCast(@alignCast(image)), x, y, r, g, b, a, stroke_radius, &root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn draw_line(
    image: Image,
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
) ErrorCode {
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
    image: Image,
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
) ErrorCode {
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
    image: Image,
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
) ErrorCode {
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

pub export fn draw_full_image(dst: Image, src: Image, use_nearest_sampling: i32) ErrorCode {
    root.image.draw_full_img(
        @ptrCast(@alignCast(dst)),
        @ptrCast(@alignCast(src)),
        root.pictura_app.pipelines.draw_full_img_pipeline,
        &root.pictura_app,
        use_nearest_sampling != 0,
    ) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn draw_image(
    dst: Image,
    src: Image,
    use_nearest_sampling: i32,
    dst_tl_x: f32,
    dst_tl_y: f32,
    dst_tr_x: f32,
    dst_tr_y: f32,
    dst_bl_x: f32,
    dst_bl_y: f32,
    dst_br_x: f32,
    dst_br_y: f32,
    src_tl_x: f32,
    src_tl_y: f32,
    src_tr_x: f32,
    src_tr_y: f32,
    src_bl_x: f32,
    src_bl_y: f32,
    src_br_x: f32,
    src_br_y: f32,
) ErrorCode {
    root.image.draw_img(
        @ptrCast(@alignCast(dst)),
        @ptrCast(@alignCast(src)),
        &root.pictura_app,
        [8]f32{ dst_tl_x, dst_tl_y, dst_tr_x, dst_tr_y, dst_bl_x, dst_bl_y, dst_br_x, dst_br_y },
        [8]f32{ src_tl_x, src_tl_y, src_tr_x, src_tr_y, src_bl_x, src_bl_y, src_br_x, src_br_y },
        use_nearest_sampling != 0,
    ) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn mix_channels(
    dst: Image,
    src: Image,
    w00: f32,
    w01: f32,
    w02: f32,
    w03: f32,
    w10: f32,
    w11: f32,
    w12: f32,
    w13: f32,
    w20: f32,
    w21: f32,
    w22: f32,
    w23: f32,
    w30: f32,
    w31: f32,
    w32: f32,
    w33: f32,
    of0: f32,
    of1: f32,
    of2: f32,
    of3: f32,
) ErrorCode {
    root.image.mix_channels(
        @ptrCast(@alignCast(dst)),
        @ptrCast(@alignCast(src)),
        [4]f32{ w00, w10, w20, w30 },
        [4]f32{ w01, w11, w21, w31 },
        [4]f32{ w02, w12, w22, w32 },
        [4]f32{ w03, w13, w23, w33 },
        [4]f32{ of0, of1, of2, of3 },
        &root.pictura_app,
    ) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn mix_channels2(
    dst: Image,
    src: Image,
    w00: f32,
    w01: f32,
    w02: f32,
    w03: f32,
    w04: f32,
    w05: f32,
    w06: f32,
    of0: f32,
    w10: f32,
    w11: f32,
    w12: f32,
    w13: f32,
    w14: f32,
    w15: f32,
    w16: f32,
    of1: f32,
    w20: f32,
    w21: f32,
    w22: f32,
    w23: f32,
    w24: f32,
    w25: f32,
    w26: f32,
    of2: f32,
    w30: f32,
    w31: f32,
    w32: f32,
    w33: f32,
    w34: f32,
    w35: f32,
    of3: f32,
    seed: f32,
) ErrorCode {
    root.image.mix_channels2(
        @ptrCast(@alignCast(dst)),
        @ptrCast(@alignCast(src)),
        [4]f32{ w00, w10, w20, w30 },
        [4]f32{ w01, w11, w21, w31 },
        [4]f32{ w02, w12, w22, w32 },
        [4]f32{ w03, w13, w23, w33 },
        [4]f32{ w04, w14, w24, w34 },
        [4]f32{ w05, w15, w25, w35 },
        [3]f32{ w06, w16, w26 },
        seed,
        [4]f32{ of0, of1, of2, of3 },
        &root.pictura_app,
    ) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn filter(
    dst: Image,
    src: Image,
    w00: f32,
    w01: f32,
    w02: f32,
    w10: f32,
    w11: f32,
    w12: f32,
    w20: f32,
    w21: f32,
    w22: f32,
    mx: f32,
    mn: f32,
    avg: f32,
    std_dev: f32,
    off: f32,
) ErrorCode {
    root.image.filter(
        @ptrCast(@alignCast(dst)),
        @ptrCast(@alignCast(src)),
        [9]f32{ w00, w01, w02, w10, w11, w12, w20, w21, w22 },
        mx,
        mn,
        avg,
        std_dev,
        off,
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

pub export fn get_display_size(w: *u32, h: *u32) ErrorCode {
    w.*, h.* = root.sdl_utils.get_display_size(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn get_window_position(w: *i32, h: *i32) ErrorCode {
    w.*, h.* = root.sdl_utils.get_window_position(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_window_position(x: i32, y: i32) ErrorCode {
    root.sdl_utils.set_window_position(root.pictura_app.window, x, y) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_fullscreen() ErrorCode {
    root.sdl_utils.set_fullscreen(&root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_windowed() ErrorCode {
    root.sdl_utils.set_windowed(&root.pictura_app) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn get_window_size(w: *u32, h: *u32) void {
    w.* = root.pictura_app.canvas.w;
    h.* = root.pictura_app.canvas.h;
}

pub export fn set_window_size(w: u32, h: u32) ErrorCode {
    root.sdl_utils.set_window_size(&root.pictura_app, w, h) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_bordered() ErrorCode {
    root.sdl_utils.set_bordered(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn set_borderless() ErrorCode {
    root.sdl_utils.set_borderless(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn grab_mouse() ErrorCode {
    root.sdl_utils.grab_mouse(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

pub export fn release_mouse() ErrorCode {
    root.sdl_utils.release_mouse(root.pictura_app.window) catch |e| {
        return @intFromError(e);
    };
    return 0;
}

//
// Vulkan exports for the power users:)
//
pub export fn get_vk_instance() root.vulkan.VkInstance {
    return root.pictura_app.instance;
}
pub export fn get_vk_physical_device() root.vulkan.VkPhysicalDevice {
    return root.pictura_app.physical_device;
}
pub export fn get_vk_device() root.vulkan.VkDevice {
    return root.pictura_app.device;
}
pub export fn get_vk_queue_family_index() u32 {
    return root.pictura_app.queue_family_index;
}
pub export fn get_vk_queue() root.vulkan.VkQueue {
    return root.pictura_app.queue;
}

pub export fn init2(
    w: u32,
    h: u32,
    nr_instance_extensions: u32,
    instance_extensions: ?[*][*:0]const u8,
    nr_vk_layers: u32,
    vulkan_layers: ?[*][*:0]const u8,
    features: ?*anyopaque,
    nr_device_extensions: u32,
    device_extensions: ?[*][*:0]const u8,
) ErrorCode {
    const inst_ext = if (instance_extensions != null and nr_instance_extensions != 0)
        instance_extensions.?[0..nr_instance_extensions]
    else
        null;

    const layers = if (vulkan_layers != null and nr_vk_layers != 0)
        vulkan_layers.?[0..nr_vk_layers]
    else
        null;

    const dev_ext = if (device_extensions != null and nr_device_extensions != 0)
        device_extensions.?[0..nr_device_extensions]
    else
        null;

    root.init.init2(
        w,
        h,
        inst_ext,
        layers,
        features,
        dev_ext,
    ) catch |e| {
        return @intFromError(e);
    };

    return 0;
}

pub export fn get_vk_command_buffer(out: *root.vulkan.VkCommandBuffer) ErrorCode {
    const bf = root.pictura_app.well.record(root.pictura_app.device) catch |e| {
        return @intFromError(e);
    };
    out.* = bf;
    return 0;
}

// already called begin rendering and did the memory barrier for the render target image
// no need to call end rendering yerself, just call present()
pub export fn get_vk_command_buffer_with_render_target(out: *root.vulkan.VkCommandBuffer, image: Image) ErrorCode {
    const dst: *root.image.PicturaImage = @ptrCast(@alignCast(image));

    // the user cannot access image internals, so the barrier that gets generated here is correct (the user cannot do their own diy vulkan reading and writing from/to the texture)
    var barrier = root.utils.get_image_memory_barrier(dst, .draw_dst, root.pictura_app.queue_family_index);

    const bf = root.pictura_app.well.render_into(dst, &barrier, root.pictura_app.device) catch |e| {
        return @intFromError(e);
    };

    out.* = bf;
    return 0;
}

// for no performance compromise :)
pub export fn get_vk_proc_addr(fn_name: [*:0]const u8) root.vulkan.PFN_vkVoidFunction {
    return @ptrCast(root.vulkan.vkGetDeviceProcAddr.?(root.pictura_app.device, fn_name));
}

// for completeness
pub export fn get_vk_instance_proc_addr(fn_name: [*:0]const u8) root.vulkan.PFN_vkVoidFunction {
    return @ptrCast(root.vulkan.vkGetInstanceProcAddr.?(root.pictura_app.instance, fn_name));
}
