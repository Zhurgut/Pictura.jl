const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

pub const vulkan = @cImport({
    @cInclude("src/init_vulkan.h");
});

pub const init = @import("init.zig");
pub const image = @import("image.zig");
pub const utils = @import("utils.zig");

pub var pictura_app: PicturaApp = undefined;

const PicturaApp = struct {
    window: ?*sdl.struct_SDL_Window,
    instance: vulkan.VkInstance,
    physical_device: vulkan.VkPhysicalDevice,
    device: vulkan.VkDevice,
    queue_family_index: u32,
    queue: vulkan.VkQueue,
    surface: vulkan.VkSurfaceKHR,
    swapchain: vulkan.VkSwapchainKHR,
    swapchain_layouts: [3]vulkan.VkImageLayout,
    command_pool: vulkan.VkCommandPool,
    canvas: image.PicturaImage,
    well: WellOfCommands(2),
    semaphores: SemaphoreCircle(16),

    fn copy_canvas_to_swapchain(app: *PicturaApp, swapchain_image: vulkan.VkImage, layout: vulkan.VkImageLayout) !void {
        const command_buffer = try app.well.record(app.device);
        const swapchain_image_layout = vulkan.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        const new_layout = vulkan.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;

        const subresource_layers: vulkan.VkImageSubresourceLayers = .{
            .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
            .mipLevel = 0,
            .baseArrayLayer = 0,
            .layerCount = 1,
        };

        // change layout for writes

        var swapchain_image_barrier: vulkan.VkImageMemoryBarrier2 = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
            .pNext = null,
            .srcStageMask = vulkan.VK_PIPELINE_STAGE_2_NONE,
            .srcAccessMask = vulkan.VK_ACCESS_NONE,
            .dstStageMask = vulkan.VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT,
            .dstAccessMask = vulkan.VK_ACCESS_TRANSFER_WRITE_BIT,
            .oldLayout = layout,
            .newLayout = swapchain_image_layout,
            .srcQueueFamilyIndex = app.queue_family_index,
            .dstQueueFamilyIndex = app.queue_family_index,
            .image = swapchain_image,
            .subresourceRange = .{
                .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        const canvas_barrier: vulkan.VkImageMemoryBarrier2 = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
            .pNext = null,
            .srcStageMask = vulkan.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            .srcAccessMask = vulkan.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            .dstStageMask = vulkan.VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT_KHR,
            .dstAccessMask = vulkan.VK_ACCESS_2_MEMORY_READ_BIT,
            .oldLayout = app.canvas.layout,
            .newLayout = new_layout,
            .srcQueueFamilyIndex = app.queue_family_index,
            .dstQueueFamilyIndex = app.queue_family_index,
            .image = app.canvas.image,
            .subresourceRange = .{
                .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };
        app.canvas.layout = new_layout;

        const barriers = [_]vulkan.VkImageMemoryBarrier2{ swapchain_image_barrier, canvas_barrier };

        var dep_info: vulkan.VkDependencyInfo = std.mem.zeroes(vulkan.VkDependencyInfo);
        dep_info.sType = vulkan.VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
        dep_info.imageMemoryBarrierCount = 2;
        dep_info.pImageMemoryBarriers = &barriers;

        vulkan.vkCmdPipelineBarrier2.?(command_buffer, &dep_info);

        const copy: vulkan.VkImageCopy = .{
            .srcSubresource = subresource_layers,
            .srcOffset = .{ .x = 0, .y = 0, .z = 0 },
            .dstSubresource = subresource_layers,
            .dstOffset = .{ .x = 0, .y = 0, .z = 0 },
            .extent = .{ .width = app.canvas.w, .height = app.canvas.h, .depth = 1 },
        };
        vulkan.vkCmdCopyImage.?(command_buffer, app.canvas.image, new_layout, swapchain_image, swapchain_image_layout, 1, &copy);

        swapchain_image_barrier = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
            .pNext = null,
            .srcStageMask = vulkan.VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT,
            .srcAccessMask = vulkan.VK_ACCESS_TRANSFER_WRITE_BIT,
            .dstStageMask = vulkan.VK_PIPELINE_STAGE_2_NONE, // docs say bottom of pipe, chatgpt says "none" is modern sync2 way
            .dstAccessMask = 0,
            .oldLayout = swapchain_image_layout,
            .newLayout = vulkan.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            .srcQueueFamilyIndex = app.queue_family_index,
            .dstQueueFamilyIndex = app.queue_family_index,
            .image = swapchain_image,
            .subresourceRange = .{
                .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };

        dep_info = std.mem.zeroes(vulkan.VkDependencyInfo);
        dep_info.sType = vulkan.VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
        dep_info.imageMemoryBarrierCount = 1;
        dep_info.pImageMemoryBarriers = &swapchain_image_barrier;

        vulkan.vkCmdPipelineBarrier2.?(command_buffer, &dep_info);
    }

    pub fn render_present(app: *PicturaApp) !void {
        const image_acquired = app.semaphores.get();
        const ready_to_present = app.semaphores.get();

        var image_index: u32 = 0;
        const acquire_image_success = vulkan.vkAcquireNextImageKHR.?(app.device, app.swapchain, 0, image_acquired, null, &image_index);

        assert(acquire_image_success != vulkan.VK_SUBOPTIMAL_KHR);

        if (acquire_image_success == vulkan.VK_NOT_READY) {
            try app.well.submit(app.device, app.queue, null, null, null, null);
            std.debug.print("-", .{});
            return;
        }

        // otherwise, we are presenting!

        var count: u32 = 3;
        assert(image_index < count);
        var images: [3]vulkan.VkImage = undefined;
        var result = vulkan.vkGetSwapchainImagesKHR.?(app.device, app.swapchain, &count, &images);
        if (result != vulkan.VK_SUCCESS and result != vulkan.VK_INCOMPLETE) {
            std.debug.print("failed to get swapchain images: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_present;
        }

        const swapchain_image = images[image_index];

        try app.copy_canvas_to_swapchain(swapchain_image, app.swapchain_layouts[image_index]);

        app.swapchain_layouts[image_index] = vulkan.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

        try app.well.submit(app.device, app.queue, image_acquired, vulkan.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, ready_to_present, vulkan.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT);

        const present_info: vulkan.VkPresentInfoKHR = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pNext = null,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &(ready_to_present),
            .swapchainCount = 1,
            .pSwapchains = &(app.swapchain),
            .pImageIndices = &image_index,
            .pResults = null,
        };

        result = vulkan.vkQueuePresentKHR.?(app.queue, &present_info);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to present: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_present;
        }
    }
};

pub fn SemaphoreCircle(comptime n: u32) type {
    return struct {
        crt: u32,
        semaphores: [n]vulkan.VkSemaphore,

        pub fn create(device: vulkan.VkDevice) !SemaphoreCircle(n) {
            var out: SemaphoreCircle(n) = undefined;
            out.crt = 0;
            for (0..n) |i| {
                out.semaphores[i] = try utils.create_semaphore(device);
            }
            return out;
        }

        pub fn destroy(sems: *SemaphoreCircle(n), device: vulkan.VkDevice) void {
            for (0..n) |i| {
                vulkan.vkDestroySemaphore.?(device, sems.semaphores[i], null);
            }
        }

        pub fn get(sems: *SemaphoreCircle(n)) vulkan.VkSemaphore {
            const out = sems.semaphores[sems.crt];
            sems.crt = (sems.crt + 1) % n;
            return out;
        }
    };
}

// command buffers to cycle through
pub fn WellOfCommands(comptime n: u32) type {
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

        pub fn create(device: vulkan.VkDevice, command_pool: vulkan.VkCommandPool, queue: vulkan.VkQueue) !WellOfCommands(n) {
            var well: WellOfCommands(n) = undefined;
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

        pub fn destroy(well: *WellOfCommands(n), device: vulkan.VkDevice) void {
            for (0..n) |i| {
                vulkan.vkDestroySemaphore.?(device, well.semaphores[i], null);
                vulkan.vkDestroyFence.?(device, well.fences[i], null);
            }
        }

        fn prev(well: *WellOfCommands(n)) u32 {
            return (well.crt_index + n - 1) % n;
        }

        fn next(well: *WellOfCommands(n)) u32 {
            return (well.crt_index + 1) % n;
        }

        pub fn record(well: *WellOfCommands(n), device: vulkan.VkDevice) !vulkan.VkCommandBuffer {
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

        pub fn render(well: *WellOfCommands(n), pimage: image.PicturaImage, device: vulkan.VkDevice, queue_family_index: u32) vulkan.VkCommandBuffer {
            switch (well.state) {
                .ready => {
                    well.begin_cmd_buffer(device);
                    well.begin_rendering(pimage, device, queue_family_index);
                },
                .recording => {
                    well.begin_rendering(pimage, device, queue_family_index);
                },
                .recording_rendering => {
                    well.end_rendering();
                    well.begin_rendering(pimage, device, queue_family_index);
                },
            }
            return well.command_buffers[well.crt_index];
        }

        pub fn submit(well: *WellOfCommands(n), device: vulkan.VkDevice, queue: vulkan.VkQueue, additional_wait: ?vulkan.VkSemaphore, wait_stage: ?vulkan.VkPipelineStageFlags2, additional_signal: ?vulkan.VkSemaphore, signal_stage: ?vulkan.VkPipelineStageFlags2) !void {
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

        pub fn wait(well: *WellOfCommands(n), device: vulkan.VkDevice, queue: vulkan.VkQueue) !void {
            switch (well.state) {
                .ready => {},
                .recording => {
                    try well.end_cmd_buffer();
                    try well.submit(device, queue, null, null, null, null);
                },
                .recording_rendering => {
                    well.end_rendering();
                    try well.end_cmd_buffer();
                    try well.submit(device, queue, null, null, null, null);
                },
            }

            // wait for the fence of the last submitted command buffer
            // we must not reset this fence!
            const result = vulkan.vkWaitForFences.?(device, 1, &well.fences[well.prev()], 0, 5_000_000_000); // TODO std.math.maxInt(u64)
            if (result != vulkan.VK_SUCCESS) {
                std.debug.print("failed to wait for fence: {s}\n", .{vulkan.string_VkResult(result)});
                return error.Vk_failed_to_wait_for_fence;
            }
        }

        fn begin_cmd_buffer(well: *WellOfCommands(n), device: vulkan.VkDevice) !void {
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

        fn begin_rendering(well: *WellOfCommands(n), pimage: image.PicturaImage, device: vulkan.VkDevice, queue_family_index: u32) !void {
            if (well.state == .recording_rendering) {
                well.end_rendering();
            }

            if (well.state == .ready) {
                well.begin_cmd_buffer(device);
            }

            assert(well.state == .recording);

            const command_buffer = well.command_buffers[well.crt_index];

            const barrier: vulkan.VkImageMemoryBarrier2 = .{
                .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
                .pNext = null,
                .srcStageMask = vulkan.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, // TODO narrow it down, if possible (?)
                .srcAccessMask = vulkan.VK_ACCESS_2_MEMORY_WRITE_BIT, // TODO narrow it down, if possible (?)
                .dstStageMask = vulkan.VK_PIPELINE_STAGE_ALL_GRAPHICS_BIT, // TODO narrow it down, if possible (?)
                .dstAccessMask = vulkan.VK_ACCESS_2_MEMORY_READ_BIT | vulkan.VK_ACCESS_2_MEMORY_WRITE_BIT, // TODO narrow it down, if possible (?)
                .oldLayout = pimage.layout,
                .newLayout = vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                .srcQueueFamilyIndex = queue_family_index,
                .dstQueueFamilyIndex = queue_family_index,
                .image = pimage.image,
                .subresourceRange = .{
                    .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
            };
            var dep_info: vulkan.VkDependencyInfo = std.mem.zeroes(vulkan.VkDependencyInfo);
            dep_info.sType = vulkan.VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
            dep_info.imageMemoryBarrierCount = 1;
            dep_info.pImageMemoryBarriers = &barrier;

            vulkan.vkCmdPipelineBarrier2.?(command_buffer, &dep_info);

            pimage.layout = vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

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

        fn end_rendering(well: *WellOfCommands(n)) void {
            assert(well.state == .recording_rendering);

            const command_buffer = well.command_buffers[well.crt_index];

            vulkan.vkCmdEndRendering.?(command_buffer);

            well.state = .recording;
        }

        fn end_cmd_buffer(well: *WellOfCommands(n)) !void {
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

pub export fn PL_init(w: u32, h: u32, hdpi: bool) u32 {
    init._init(w, h, hdpi) catch |e| return @intFromError(e);

    return 0;
}

test "toy example" {
    try init._init(600, 400, false);

    std.debug.print("{d}\n", .{sdl.SDL_GetTicksNS()});
    for (0..500) |_| {
        try pictura_app.render_present();

        sdl.SDL_Delay(3);
    }
    try pictura_app.well.wait(pictura_app.device, pictura_app.queue);
    std.debug.print("{d}\n", .{sdl.SDL_GetTicksNS()});

    init.quit();
}
