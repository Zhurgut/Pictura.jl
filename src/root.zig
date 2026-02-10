const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const builtin = @import("builtin");

pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

pub const vulkan = if (builtin.os.tag == .windows) @cImport({
    @cDefine("WINDOWS", {});
    @cInclude("src/init/init_vulkan.h");
}) else @cImport({
    @cInclude("src/init/init_vulkan.h");
});

pub const init = @import("init/init.zig");
pub const image = @import("image.zig");
pub const utils = @import("utils.zig");
pub const swapchain = @import("swapchain.zig");
pub const shaders = @import("shaders.zig");
pub const events = @import("events.zig");
pub const sdl_utils = @import("sdl_utils.zig");
pub const pipelines = @import("pipelines.zig");
pub const exports = @import("exports.zig");
comptime {
    _ = exports;
}

pub var pictura_app: PicturaApp = undefined;

pub const WellOfCommands = WellOfCommands2(128);

pub const PicturaApp = struct {
    window: *sdl.SDL_Window,
    instance: vulkan.VkInstance,
    physical_device: vulkan.VkPhysicalDevice,
    device: vulkan.VkDevice,
    queue_family_index: u32,
    queue: vulkan.VkQueue,
    surface: vulkan.VkSurfaceKHR,
    swapchain: swapchain.Swapchain,
    command_pool: vulkan.VkCommandPool,
    canvas: image.PicturaImage,
    well: WellOfCommands,
    descriptor_pool: vulkan.VkDescriptorPool,
    pipelines: pipelines.Pipelines,
    running: bool,
    event_handler: events.EventHandler,
    arena: std.heap.ArenaAllocator,
    gpa: std.mem.Allocator,
    target_framerate: f32,
    target_time: u64,
    last_frame_time: u64,
    before_last_time: u64,

    // call before handle events
    pub fn wait_until_next_frame(app: *PicturaApp) void {
        const now = sdl.SDL_GetTicksNS();

        const time_to_sleep: u64 = @intCast(@max(0, @as(i64, @intCast(app.target_time)) - @as(i64, @intCast(now))));
        if (time_to_sleep > 0) {
            sdl.SDL_DelayNS(time_to_sleep);
        } else {
            // forget about the old target time
            // just pretend 'target time' was 'now' and move on
            app.target_time = now;
        }

        app.target_time += @intFromFloat(@floor(@as(f32, 1e9) / app.target_framerate));

        app.before_last_time = app.last_frame_time;
        app.last_frame_time = now;
    }

    pub fn resize(app: *PicturaApp, target_w: u32, target_h: u32) !void {
        if (app.canvas.w == target_w and app.canvas.h == target_h) {
            return;
        }
        std.debug.print("resizing\n", .{});
        try app.well.wait(app.device, app.queue); // make sure old resources are no longer in use

        app.swapchain.destroy(app.device);

        var swapchain2 = try swapchain.Swapchain.create(
            app.physical_device,
            app.device,
            app.queue_family_index,
            app.surface,
            target_w,
            target_h,
        );
        errdefer swapchain2.destroy(app.device);

        const w = swapchain2.images[0].w; // actual image size that we got after resizing
        const h = swapchain2.images[0].h;

        var new_canvas = try image.PicturaImage.create(
            w,
            h,
            app.device,
            app.queue_family_index,
            app.physical_device,
        );
        errdefer new_canvas.destroy(app.device, app.descriptor_pool);

        try image.draw_full_img(&new_canvas, &app.canvas, app.pipelines.draw_full_img_pipeline, app);

        try app.well.wait(app.device, app.queue); // make sure old resources are no longer in use

        app.canvas.destroy(app.device, app.descriptor_pool);

        app.canvas = new_canvas;
        app.swapchain = swapchain2;
    }
};

// command buffers to cycle through
fn WellOfCommands2(comptime n: u32) type {
    return struct {
        state: State,
        crt_index: u32,
        command_buffers: [n]vulkan.VkCommandBuffer,
        semaphores: [n]vulkan.VkSemaphore,
        fences: [n]vulkan.VkFence,

        pub const State = enum {
            ready,
            recording,
            recording_rendering,
        };

        pub fn create(device: vulkan.VkDevice, command_pool: vulkan.VkCommandPool, queue: vulkan.VkQueue) !WellOfCommands2(n) {
            var well: WellOfCommands2(n) = undefined;
            well.state = .ready;
            well.crt_index = 0;
            for (0..n) |i| {
                well.command_buffers[i] = try utils.create_command_buffer(device, command_pool);
                well.semaphores[i] = try utils.create_semaphore(device);
                well.fences[i] = try utils.create_fence(device, vulkan.VK_FENCE_CREATE_SIGNALED_BIT);
            }

            try well.begin_cmd_buffer(device);
            try well.end_cmd_buffer();

            const command_buffer = well.command_buffers[well.crt_index];

            try utils.queue_submit_2(
                queue,
                command_buffer,
                0,
                [0]vulkan.VkSemaphore{},
                [0]vulkan.VkPipelineStageFlags2{},
                1,
                [1]vulkan.VkSemaphore{well.semaphores[well.crt_index]},
                [1]vulkan.VkPipelineStageFlags2{vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT},
                well.fences[well.crt_index],
            ); // fencepost

            well.crt_index = well.next();
            well.state = .ready;

            std.debug.print("created well\n", .{});

            return well;
        }

        pub fn destroy(well: *WellOfCommands2(n), device: vulkan.VkDevice) void {
            for (0..n) |i| {
                vulkan.vkDestroySemaphore.?(device, well.semaphores[i], null);
                vulkan.vkDestroyFence.?(device, well.fences[i], null);
            }
        }

        fn prev(well: *WellOfCommands2(n)) u32 {
            return (well.crt_index + n - 1) % n;
        }

        fn next(well: *WellOfCommands2(n)) u32 {
            return (well.crt_index + 1) % n;
        }

        pub fn record(well: *WellOfCommands2(n), device: vulkan.VkDevice) !vulkan.VkCommandBuffer {
            switch (well.state) {
                .ready => {
                    try well.begin_cmd_buffer(device);
                },
                .recording => {},
                .recording_rendering => {
                    well.end_rendering();
                },
            }
            return well.command_buffers[well.crt_index];
        }

        pub fn render_into(well: *WellOfCommands2(n), pimage: *image.PicturaImage, barrier: *vulkan.VkImageMemoryBarrier2, device: vulkan.VkDevice) !vulkan.VkCommandBuffer {
            switch (well.state) {
                .ready => {
                    try well.begin_cmd_buffer(device);
                    try well.begin_rendering(pimage, barrier, device);
                },
                .recording => {
                    try well.begin_rendering(pimage, barrier, device);
                },
                .recording_rendering => {
                    well.end_rendering();
                    try well.begin_rendering(pimage, barrier, device);
                },
            }
            return well.command_buffers[well.crt_index];
        }

        // do not reset fence returned by this!
        pub fn submit(
            well: *WellOfCommands2(n),
            device: vulkan.VkDevice,
            queue: vulkan.VkQueue,
            additional_wait: ?vulkan.VkSemaphore,
            wait_stage: ?vulkan.VkPipelineStageFlags2,
            additional_signal: ?vulkan.VkSemaphore,
            signal_stage: ?vulkan.VkPipelineStageFlags2,
        ) !void {
            switch (well.state) {
                .ready => {
                    try well.begin_cmd_buffer(device);
                    try well.end_cmd_buffer();
                },
                .recording => {
                    try well.end_cmd_buffer();
                },
                .recording_rendering => {
                    well.end_rendering();
                    try well.end_cmd_buffer();
                },
            }

            const command_buffer = well.command_buffers[well.crt_index];

            if (additional_wait) |wait_s| {
                if (additional_signal) |signal_s| {
                    try utils.queue_submit_2(
                        queue,
                        command_buffer,
                        2,
                        [2]vulkan.VkSemaphore{ well.semaphores[well.prev()], wait_s },
                        [2]vulkan.VkPipelineStageFlags2{ vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, wait_stage.? },
                        2,
                        [2]vulkan.VkSemaphore{ well.semaphores[well.crt_index], signal_s },
                        [2]vulkan.VkPipelineStageFlags2{ vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, signal_stage.? },
                        well.fences[well.crt_index],
                    );
                } else {
                    try utils.queue_submit_2(
                        queue,
                        command_buffer,
                        2,
                        [2]vulkan.VkSemaphore{ well.semaphores[well.prev()], wait_s },
                        [2]vulkan.VkPipelineStageFlags2{ vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, wait_stage.? },
                        1,
                        [1]vulkan.VkSemaphore{well.semaphores[well.crt_index]},
                        [1]vulkan.VkPipelineStageFlags2{vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT},
                        well.fences[well.crt_index],
                    );
                }
            } else {
                if (additional_signal) |signal_s| {
                    try utils.queue_submit_2(
                        queue,
                        command_buffer,
                        1,
                        [1]vulkan.VkSemaphore{well.semaphores[well.prev()]},
                        [1]vulkan.VkPipelineStageFlags2{vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT},
                        2,
                        [2]vulkan.VkSemaphore{ well.semaphores[well.crt_index], signal_s },
                        [2]vulkan.VkPipelineStageFlags2{ vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, signal_stage.? },
                        well.fences[well.crt_index],
                    );
                } else {
                    try utils.queue_submit_2(
                        queue,
                        command_buffer,
                        1,
                        [1]vulkan.VkSemaphore{well.semaphores[well.prev()]},
                        [1]vulkan.VkPipelineStageFlags2{vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT},
                        1,
                        [1]vulkan.VkSemaphore{well.semaphores[well.crt_index]},
                        [1]vulkan.VkPipelineStageFlags2{vulkan.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT},
                        well.fences[well.crt_index],
                    );
                }
            }

            well.crt_index = well.next();
            well.state = .ready;
        }

        pub fn wait(well: *WellOfCommands2(n), device: vulkan.VkDevice, queue: vulkan.VkQueue) !void {
            try well.submit(device, queue, null, null, null, null);

            assert(well.state == .ready);

            // wait for the fence of the last submitted command buffer
            // we must not reset this fence!
            const result = vulkan.vkWaitForFences.?(device, 1, &well.fences[well.prev()], 0, 5_000_000_000); // TODO std.math.maxInt(u64)
            if (result != vulkan.VK_SUCCESS) {
                std.debug.print("failed to wait for fence: {s}\n", .{vulkan.string_VkResult(result)});
                return error.Vk_failed_to_wait_for_fence;
            }
        }

        fn begin_cmd_buffer(well: *WellOfCommands2(n), device: vulkan.VkDevice) !void {
            assert(well.state == .ready);

            try utils.wait_and_reset_fence(device, &well.fences[well.crt_index]);

            const command_buffer = well.command_buffers[well.crt_index];

            const info: vulkan.VkCommandBufferBeginInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
                .pNext = null,
                .flags = vulkan.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
                .pInheritanceInfo = null,
            };

            const result = vulkan.vkBeginCommandBuffer.?(command_buffer, &info);
            if (result != vulkan.VK_SUCCESS) {
                std.debug.print("failed to begin command buffer: {s}\n", .{vulkan.string_VkResult(result)});
                return error.Vk_failed_to_begin_command_buffer;
            }

            well.state = .recording;
        }

        fn begin_rendering(well: *WellOfCommands2(n), pimage: *image.PicturaImage, barrier: *vulkan.VkImageMemoryBarrier2, device: vulkan.VkDevice) !void {
            if (well.state == .recording_rendering) {
                well.end_rendering();
            }

            if (well.state == .ready) {
                try well.begin_cmd_buffer(device);
            }

            assert(well.state == .recording);

            const command_buffer = well.command_buffers[well.crt_index];

            utils.submit_image_memory_barrier(command_buffer, barrier);

            var color_attachment: vulkan.VkRenderingAttachmentInfo = std.mem.zeroes(vulkan.VkRenderingAttachmentInfo);
            color_attachment.sType = vulkan.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
            color_attachment.imageView = pimage.image_view;
            color_attachment.imageLayout = vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

            const rendering_info: vulkan.VkRenderingInfo = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_RENDERING_INFO,
                .pNext = null,
                .flags = 0,
                .renderArea = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{ .width = pimage.w, .height = pimage.h },
                },
                .layerCount = 1,
                .viewMask = 0,
                .colorAttachmentCount = 1,
                .pColorAttachments = &color_attachment,
                .pDepthAttachment = null,
                .pStencilAttachment = null,
            };

            vulkan.vkCmdBeginRendering.?(command_buffer, &rendering_info);

            well.state = .recording_rendering;
        }

        fn end_rendering(well: *WellOfCommands2(n)) void {
            assert(well.state == .recording_rendering);

            const command_buffer = well.command_buffers[well.crt_index];

            vulkan.vkCmdEndRendering.?(command_buffer);

            well.state = .recording;
        }

        fn end_cmd_buffer(well: *WellOfCommands2(n)) !void {
            if (well.state == .recording_rendering) {
                well.end_rendering();
            }

            assert(well.state == .recording);

            const command_buffer = well.command_buffers[well.crt_index];

            const result = vulkan.vkEndCommandBuffer.?(command_buffer);
            if (result != vulkan.VK_SUCCESS) {
                std.debug.print("failed to end command buffer: {s}\n", .{vulkan.string_VkResult(result)});
                return error.Vk_failed_to_end_command_buffer;
            }
        }
    };
}

pub const test_all: bool = false;

test "main test example" {
    const w = 800;
    const h = 600;
    try init.init(w, h);
    defer init.quit();

    try image.draw_background(&pictura_app.canvas, 1.0, 1.0, 1.0, 1.0, &pictura_app);

    try image.draw_ellipse(
        &pictura_app.canvas,
        [4]f32{ 0.1, 0.2, 0.8, 0.9 },
        [4]f32{ 0.6, 0.1, 0.6, 0.8 },
        [2]f32{ 250, 102 },
        4,
        [2]f32{ 162.364, 327.396 - 200 },
        [2]f32{ 690.5, 439.964 - 200 },
        [2]f32{ 111.5, 566.036 - 200 },
        [2]f32{ 639.636, 678.604 - 200 },
        &pictura_app,
    );

    try image.draw_rect(
        &pictura_app.canvas,
        [4]f32{ 0.1, 0.6, 0.2, 0.9 },
        [4]f32{ 0.6, 0.8, 0.2, 0.6 },
        5,
        450,
        200,
        20,
        [2]f32{ 162.364, 327.396 - 20 },
        [2]f32{ 690.5, 439.964 - 20 },
        [2]f32{ 111.5, 566.036 - 20 },
        [2]f32{ 639.636, 678.604 - 20 },
        &pictura_app,
    );

    const pixels = try image.load_pixels(&pictura_app.canvas, &pictura_app);

    var background: image.PicturaImage = try .from_pixels(w, h, pixels, &pictura_app);
    defer background.destroy(pictura_app.device, pictura_app.descriptor_pool);

    try image.mix_channels(
        &background,
        &pictura_app.canvas,

        [4]f32{ 0.21, 0.21, 0.21, 0 }, // how much of red to put in each location
        [4]f32{ 0.72, 0.72, 0.72, 0 }, // ...
        [4]f32{ 0.07, 0.07, 0.07, 0 },
        [4]f32{ 0, 0, 0, 0 },
        [4]f32{ 0, 0, 0, 0.5 },
        &pictura_app,
    );
    const bg_pixels = try image.load_pixels(&background, &pictura_app);
    std.debug.assert(127 == (bg_pixels[0] & 0xff000000) >> 24);

    try image.mix_channels2(
        &background,
        &pictura_app.canvas,

        [4]f32{ 0.21 * 0.8, 0.21 * 0.8, 0.21 * 0.8, 0 },
        [4]f32{ 0.72 * 0.8, 0.72 * 0.8, 0.72 * 0.8, 0 },
        [4]f32{ 0.07 * 0.8, 0.07 * 0.8, 0.07 * 0.8, 0 },
        [4]f32{ 0.2, 0, 0, 0 },
        [4]f32{ 0, 0.2, 0, 0 },
        [4]f32{ 0, 0, 0.2, 0 },
        [3]f32{ 0.1, 0.1, 0.1 },
        0.123,
        [4]f32{ -0.05, -0.05, -0.05, 1 },
        &pictura_app,
    );

    var img2 = try image.PicturaImage.create(
        w,
        h,
        pictura_app.device,
        pictura_app.queue_family_index,
        pictura_app.physical_device,
    );
    defer img2.destroy(pictura_app.device, pictura_app.descriptor_pool);

    const start = sdl.SDL_GetTicksNS();
    while (pictura_app.running) {
        pictura_app.wait_until_next_frame();
        try pictura_app.event_handler.handle_events(&pictura_app);

        try image.draw_full_img(&img2, &background, pictura_app.pipelines.draw_full_img_pipeline, &pictura_app);

        const x = pictura_app.event_handler.mouse.x;
        const y = pictura_app.event_handler.mouse.y;
        const s = 250;
        try image.draw_img(
            &img2,
            &pictura_app.canvas,
            &pictura_app,
            [8]f32{ x, y - s, x + s, y, x - s, y, x, y + s },
            [8]f32{ 50, 50, @floatFromInt(w - 50), 50, 50, @floatFromInt(h - 50), @floatFromInt(w - 50), @floatFromInt(h - 50) },
        );

        try image.draw_full_img(&pictura_app.canvas, &img2, pictura_app.pipelines.draw_full_img_pipeline, &pictura_app);

        try image.draw_line(
            &pictura_app.canvas,
            [2]f32{ 300, 300 },
            [2]f32{ pictura_app.event_handler.mouse.x, pictura_app.event_handler.mouse.y },
            [4]f32{ 0.2, 0.1, 0.8, 1.0 },
            3.3,
            [2]f32{ 0, 0 },
            [2]f32{ 3000, 0 },
            [2]f32{ 0, 3000 },
            [2]f32{ 3000, 3000 },
            &pictura_app,
        );

        if (events.is_key_pressed('m')) {
            std.debug.print("m", .{});
        }
        if (events.is_key_pressed(events.SHIFT)) {
            std.debug.print("SHIFT!", .{});
        }

        // std.debug.print("framerate: {d}\n", .{exports.get_framerate()});

        try pictura_app.swapchain.present(&pictura_app);
    }
    const stop = sdl.SDL_GetTicksNS();
    std.debug.print("{any}\n", .{@as(f64, @floatFromInt(stop - start)) * 1e-9});

    try pictura_app.well.wait(pictura_app.device, pictura_app.queue);
}
