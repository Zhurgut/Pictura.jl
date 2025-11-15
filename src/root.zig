const std = @import("std");
const testing = std.testing;

const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

pub const vulkan = @cImport({
    @cInclude("src/init_vulkan.h");
});

const image = @import("image.zig");

var app: PicturaApp = undefined;

const PicturaApp = struct {
    window: ?*sdl.struct_SDL_Window,
    instance: vulkan.VkInstance,
    physical_device: vulkan.VkPhysicalDevice,
    device: vulkan.VkDevice,
    queue_family_index: u32,
    queue: vulkan.VkQueue,
    surface: vulkan.VkSurfaceKHR,
    swapchain: vulkan.VkSwapchainKHR,
    command_pool: vulkan.VkCommandPool,
    canvas: image.PicturaImage,
    arena: std.heap.ArenaAllocator,
    command_buffer_batch: CmdBufferBatch,
    render_present_data: RenderPresentData,

    fn copy_canvas_to_swapchain(app: *PicturaApp) void {
        // start final command buffer

        // change layout for writes
        // submit copy/blit canvas onto image
        // change layout to VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        // dstAccessMask member of the VkImageMemoryBarrier should be 0, and the dstStageMask parameter should be VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT.

        // end final command buffer

        // submit final command buffer to queue:
        // wait for "done rendering" (if batch was not empty) and "swapchain image available" semaphore,
        // signal "rendering finished"

        var done_copying_semaphore_info: vulkan.VkSemaphoreSubmitInfo = undefined;
        done_copying_semaphore_info = std.mem.zeroes(vulkan.VkSemaphoreSubmitInfo);
        done_copying_semaphore_info.sType = vulkan.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
        done_copying_semaphore_info.semaphore = app.render_present_data.done_copying_semaphore;
        done_copying_semaphore_info.stageMask = vulkan.VK_PIPELINE_STAGE_2_TRANSFER_BIT; // implies write from canvas to swapchain image is copy/blit/resolve

        var image_acquired_semaphore_info: vulkan.VkSemaphoreSubmitInfo = undefined;
        image_acquired_semaphore_info = std.mem.zeroes(vulkan.VkSemaphoreSubmitInfo);
        image_acquired_semaphore_info.sType = vulkan.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
        image_acquired_semaphore_info.semaphore = app.render_present_data.image_acquired_semaphore;
        image_acquired_semaphore_info.stageMask = vulkan.VK_PIPELINE_STAGE_2_TRANSFER_BIT;

        var info = std.mem.zeroes(vulkan.VkSubmitInfo2);
        info.sType = vulkan.VK_STRUCTURE_TYPE_SUBMIT_INFO_2;
        info.commandBufferInfoCount = 1;
        info.pCommandBufferInfos = &(app.render_present_data.cmd_buffer); // the final command buffer
        if (submitted_commands) {
            info.waitSemaphoreInfoCount = 2;
            info.pWaitSemaphoreInfos = ; // image_acquired_semaphore and done_rendering_semaphore
        } else {
            info.waitSemaphoreInfoCount = 1;
            info.pWaitSemaphoreInfos = ; // image_acquired_semaphore
        }
        info.signalSemaphoreInfoCount = 1;
        info.pSignalSemaphoreInfos = ; // done copying semaphore

        const result = vulkan.vkQueueSubmit2.?(queue, 1, &info, batch.fence);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to submit to queue: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_submit_to_queue;
        }


    }

    pub fn render_present(app: *PicturaApp) void {
        var image_index: u32 = undefined;
        const acquire_image_success = vulkan.vkAcquireNextImageKHR(app.device, app.swapchain, 0, image_acquired_semaphore, null, &image_index);

        // submit pending work if any
        if (app.canvas.state != .reset) {
            app.canvas.transition_to(.submitted, app.queue_family_index, app.cmd_buffer_batch, app.device);
        }

        // if there is work, we need to submit it to the queue
        var submitted_commands = false;
        if (app.command_buffer_batch.cmd_buffers.items.len > 0 and !app.command_buffer_batch.executing) {
            if (acquire_image_success == vulkan.VK_SUCCESS) {
                // if we are presenting we need to signal a semaphore
                app.command_buffer_batch.submit_to_queue(app.queue, null, done_rendering_semaphore);
                submitted_commands = true; // this means we have to wait for the done_rendering_semaphore
            } else {
                // otherwise we dont need a semaphore
                app.command_buffer_batch.submit_to_queue(app.queue, null, null);
            }  
            
        }

        // if we are not presenting
        if (acquire_image_success != vulkan.VK_SUCCESS) {
            // if there was work, we submitted it
            // wait for all work to finish and clear batch TODO BAD
            app.command_buffer_batch.wait(app.device); 
            // reset canvas
            app.canvas.transition_to(.reset, app.queue_family_index, app.cmd_buffer_batch, app.device);
            // done
            return;
            
        }

        // otherwise, we are presenting!

        const count: u32 = 3;
        const images: [3]vulkan.VkImage = undefined;
        vulkan.vkGetSwapchainImagesKHR(app.device, app.swapchain, &count, &images);
        const image = images[image_index];

        

        app.copy_canvas_to_swapchain();

        
        // queue present, wait for "done copying" semaphore



        const present_info: vulkan.VkPresentInfoKHR = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_PRESENT_REGIONS_KHR,
            .pNext = null,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &(app.render_present_data.done_copying_semaphore),
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

        app.canvas.transition_to(.reset, app.queue_family_index, app.cmd_buffer_batch, app.device);
    }
};

const RenderPresentData = struct {
    command_buffer: vulkan.VkCommandBuffer,
    done_rendering_semaphore: vulkan.VkSemaphore,
    image_acquired_semaphore: vulkan.VkSemaphore,
    done_copying_semaphore: vulkan.VkSemaphore,

    pub fn create(device: vulkan.VkDevice, command_pool: vulkan.VkCommandPool) !RenderPresentData {
        const command_buffer = try create_command_buffer(device, command_pool);
        const s1 = try create_semaphore(device);
        const s2 = try create_semaphore(device);
        const s3 = try create_semaphore(device);

        return .{
            .command_buffer = command_buffer,
            .done_rendering_semaphore = s1,
            .image_acquired_semaphore = s2,
            .done_copying_semaphore = s3,
        };
    }

    pub fn destroy(present_data: *RenderPresentData, device: vulkan.VkDevice, command_pool: vulkan.VkCommandPool) void {
        vulkan.vkFreeCommandBuffers.?(device, command_pool, 1, &(present_data.command_buffer));
        vulkan.vkDestroySemaphore.?(device, present_data.done_rendering_semaphore, null);
        vulkan.vkDestroySemaphore.?(device, present_data.image_acquired_semaphore, null);
        vulkan.vkDestroySemaphore.?(device, present_data.done_copying_semaphore, null);
    }

};

fn create_semaphore(device: vulkan.VkDevice) !vulkan.VkSemaphore {
    const info: vulkan.VkSemaphoreCreateInfo = .{
        .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };

    var semaphore: vulkan.VkSemaphore = undefined;
    const result = vulkan.vkCreateSemaphore.?(device, &info, null, &semaphore);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create semaphore: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_semaphore;
    }

    return semaphore;
}


pub const CmdBufferBatch = struct {
    allocator: std.mem.Allocator,
    cmd_buffers: std.ArrayList(vulkan.VkCommandBufferSubmitInfo),
    fence: vulkan.VkFence,
    era: u64,
    executing: bool,

    pub fn create(allocator: std.mem.Allocator, device: vulkan.VkDevice) !CmdBufferBatch {
        const list = try std.ArrayList(vulkan.VkCommandBufferSubmitInfo).initCapacity(allocator, 8);

        var fence: vulkan.VkFence = undefined;
        const info: vulkan.VkFenceCreateInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
        };
        const result = vulkan.vkCreateFence.?(device, &info, null, &fence);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to create fence: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_create_fence;
        }

        return .{
            .allocator = allocator,
            .cmd_buffers = list,
            .fence = fence,
            .era = 1,
            .executing = false,
        };
    }

    pub fn destroy(batch: *CmdBufferBatch, device: vulkan.VkDevice) void {
        vulkan.vkDestroyFence.?(device, batch.fence, null);
    }

    pub fn append(batch: *CmdBufferBatch, cmd_buffer: vulkan.VkCommandBuffer, device: vulkan.VkDevice) !u64 {
        if (batch.executing) {
            // shouldnt happend I think
            std.debug.print("the thing that shouldnt happen, happened...\n", .{});
            try batch.wait(device);
        }
        const info: vulkan.VkCommandBufferSubmitInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
            .pNext = null,
            .commandBuffer = cmd_buffer,
            .deviceMask = 0,
        };
        try batch.cmd_buffers.append(batch.allocator, info);

        return batch.era;
    }

    pub fn submit_to_queue(batch: *CmdBufferBatch, queue: vulkan.VkQueue, wait_semaphore: ?*vulkan.VkSemaphoreSubmitInfo, signal_semaphore: ?*vulkan.VkSemaphoreSubmitInfo) !void {
        var info = std.mem.zeroes(vulkan.VkSubmitInfo2);
        info.sType = vulkan.VK_STRUCTURE_TYPE_SUBMIT_INFO_2;
        info.commandBufferInfoCount = @intCast(batch.cmd_buffers.items.len);
        info.pCommandBufferInfos = @ptrCast(batch.cmd_buffers.items);

        if (wait_semaphore) |p_sem| {
            info.waitSemaphoreInfoCount = 1;
            info.pWaitSemaphoreInfos = p_sem;
        }

        if (signal_semaphore) |p_sem| {
            info.signalSemaphoreInfoCount = 1;
            info.pSignalSemaphoreInfos = p_sem;
        }

        const result = vulkan.vkQueueSubmit2.?(queue, 1, &info, batch.fence);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to submit to queue: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_submit_to_queue;
        }

        batch.executing = true;
    }

    pub fn wait(batch: *CmdBufferBatch, device: vulkan.VkDevice) !void {
        // after wait(), batch is empty

        if (!batch.executing) {
            // if there is no work, wait is idempotent
            if (batch.items.len > 0) {
                std.debug.print("cant wait on work that has not been submitted...");
                return error.invalid_usage;
            }
            return;
        }

        // we wait for a fence, because only when we know on host that device is done, we can go and modify the command buffers
        var result = vulkan.vkWaitForFences.?(device, 1, &(batch.fence), 0, 1_000_000_000); // TODO std.math.maxInt(u64)
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to wait for fence: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_wait_for_fence;
        }

        batch.executing = false;
        result = vulkan.vkResetFences.?(device, 1, &(batch.fence));
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to reset fence: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_reset_fence;
        }
        batch.cmd_buffers.clearRetainingCapacity(); // does a bit more than just wait... wait_complete()?

        batch.era += 1;
    }
};

pub fn print_error() void {
    std.debug.print("{s}\n", .{sdl.SDL_GetError()});
}

fn create_swapchain(device: vulkan.VkDevice, surface: vulkan.VkSurfaceKHR, w: u32, h: u32, old_swapchain: vulkan.VkSwapchainKHR) !vulkan.VkSwapchainKHR {
    var info = std.mem.zeroes(vulkan.VkSwapchainCreateInfoKHR);
    info.sType = vulkan.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    info.surface = surface;
    info.minImageCount = 3; // TODO not to hardcode this
    info.imageFormat = vulkan.VK_FORMAT_R8G8B8A8_UNORM; // ???
    info.imageColorSpace = vulkan.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR; // ??? imageFormat and imageColorSpace must match the format and colorSpace members, respectively, of one of the VkSurfaceFormatKHR structures returned by vkGetPhysicalDeviceSurfaceFormatsKHR for the surface
    info.imageExtent = .{ .width = w, .height = h };
    info.imageArrayLayers = 1;
    info.imageUsage = vulkan.VK_IMAGE_USAGE_TRANSFER_DST_BIT; // ???
    info.preTransform = vulkan.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
    info.compositeAlpha = vulkan.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    info.presentMode = vulkan.VK_PRESENT_MODE_FIFO_KHR;
    info.oldSwapchain = old_swapchain;

    var swapchain: vulkan.VkSwapchainKHR = undefined;
    const result = vulkan.vkCreateSwapchainKHR.?(device, &info, null, &swapchain);

    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create swapchain: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_swapchain;
    }

    return swapchain;
}

fn create_command_pool(device: vulkan.VkDevice, queue_family_index: u32) !vulkan.VkCommandPool {
    var info = std.mem.zeroes(vulkan.VkCommandPoolCreateInfo);
    info.sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    info.flags = vulkan.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    info.queueFamilyIndex = queue_family_index;

    var command_pool: vulkan.VkCommandPool = undefined;
    const result = vulkan.vkCreateCommandPool.?(device, &info, null, &command_pool);

    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create command pool: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_command_pool;
    }

    return command_pool;
}

pub fn create_command_buffer(device: vulkan.VkDevice, command_pool: vulkan.VkCommandPool) !vulkan.VkCommandBuffer {
    const info: vulkan.VkCommandBufferAllocateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = null,
        .commandPool = command_pool,
        .level = vulkan.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };

    var command_buffer: vulkan.VkCommandBuffer = undefined;
    const result = vulkan.vkAllocateCommandBuffers.?(device, &info, &command_buffer);

    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to allocate command buffer: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_allocate_command_buffer;
    }

    return command_buffer;
}


fn get_device_memory_index(physical_device: vulkan.VkPhysicalDevice) usize {
    var properties: vulkan.VkPhysicalDeviceMemoryProperties = undefined;
    vulkan.vkGetPhysicalDeviceMemoryProperties.?(physical_device, &properties);
    for (properties.memoryTypes[0..properties.memoryTypeCount]) |m| {
        std.debug.print("{d} heap: {d}\n", .{ m.propertyFlags, m.heapIndex });
    }
    return 0;
}

pub export fn init(w: u32, h: u32, hdpi: bool) u32 {
    _init(w, h, hdpi) catch |e| return @intFromError(e);
    return 0;
}

fn _init(w: u32, h: u32, hdpi: bool) !void {
    var success = sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO | sdl.SDL_INIT_GAMEPAD);
    if (!success) {
        print_error();
        return error.SDL_InitError;
    }
    errdefer sdl.SDL_Quit();

    const hdpi_flag: u32 = if (hdpi) sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY else 0;

    const window = sdl.SDL_CreateWindow(
        "Pictura",
        @intCast(w),
        @intCast(h),
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_INPUT_FOCUS | sdl.SDL_WINDOW_VULKAN | hdpi_flag,
    );
    if (window == null) {
        print_error();
        return error.SDL_CreateWindowError;
    }
    errdefer sdl.SDL_DestroyWindow(window);

    var nr_extensions: u32 = 0;
    const vk_extensions = sdl.SDL_Vulkan_GetInstanceExtensions(&nr_extensions);

    // for (vk_extensions, 0..nr_extensions) |ext, _| {
    //     std.debug.print("{s}\n", .{ext});
    // }

    const device_extensions = [_][*c]const u8{"VK_KHR_swapchain"};
    const nr_device_extensions = device_extensions.len;

    var instance: vulkan.VkInstance = undefined;
    var physical_device: vulkan.VkPhysicalDevice = undefined;
    var device: vulkan.VkDevice = undefined;
    var queue_family_index: u32 = 0;

    const result = vulkan.init_vulkan(nr_extensions, vk_extensions, nr_device_extensions, &device_extensions, &instance, &physical_device, &device, &queue_family_index);
    errdefer {
        vulkan.vkDestroyDevice.?(device, null);
        vulkan.vkDestroyInstance.?(instance, null);
    }
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to initialize vulkan: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }

    var surface: vulkan.VkSurfaceKHR = undefined;
    success = sdl.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, &surface);
    if (!success) {
        print_error();
        return error.SDL_VulkanCreateSurfaceError;
    }
    errdefer sdl.SDL_Vulkan_DestroySurface(@ptrCast(instance), @ptrCast(surface), null);

    const swapchain = try create_swapchain(device, surface, w, h, null);
    errdefer vulkan.vkDestroySwapchainKHR.?(device, swapchain, null);

    const command_pool = try create_command_pool(device, queue_family_index);
    errdefer vulkan.vkDestroyCommandPool.?(device, command_pool, null);

    var queue: vulkan.VkQueue = undefined;
    vulkan.vkGetDeviceQueue.?(device, queue_family_index, 0, &queue);

    const device_memory_index = get_device_memory_index(physical_device);
    std.debug.print("{d}", .{device_memory_index});

    var canvas = try image.PicturaImage.create(w, h, device, queue_family_index, command_pool, 1);
    errdefer canvas.destroy(device, command_pool);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator); // free everything at once in the end
    errdefer arena.deinit();

    const command_buffer_batch = try CmdBufferBatch.create(arena.allocator(), device);
    errdefer command_buffer_batch.destroy(device);

    const render_present_data = try RenderPresentData.create(device, command_pool);
    errdefer render_present_data.destroy(device);

    app = .{
        .window = window,
        .instance = instance,
        .physical_device = physical_device,
        .device = device,
        .queue_family_index = queue_family_index,
        .queue = queue,
        .surface = surface,
        .swapchain = swapchain,
        .command_pool = command_pool,
        .canvas = canvas,
        .arena = arena,
        .command_buffer_batch = command_buffer_batch,
        .render_present_data = render_present_data,
    };

    return;
}

pub export fn quit() void {
    _ = vulkan.vkDeviceWaitIdle.?(app.device);

    app.command_buffer_batch.destroy(app.device);

    app.canvas.destroy(app.device, app.command_pool);

    vulkan.vkDestroyCommandPool.?(app.device, app.command_pool, null);
    vulkan.vkDestroySwapchainKHR.?(app.device, app.swapchain, null);

    sdl.SDL_Vulkan_DestroySurface(@ptrCast(app.instance), @ptrCast(app.surface), null);

    vulkan.vkDestroyDevice.?(app.device, null);

    vulkan.vkDestroyInstance.?(app.instance, null);

    sdl.SDL_DestroyWindow(app.window);

    sdl.SDL_Quit();

    app.arena.deinit();

    // app = std.mem.zeroes(PicturaApp);
}

test "turn it on and off" {
    try _init(600, 400, false);
    try std.testing.expect(true);

    try app.canvas.transition_to(
        .recording_rendering,
        app.queue_family_index,
        &(app.command_buffer_batch),
        app.device,
        app.queue,
    );
    try app.canvas.transition_to(
        .reset,
        app.queue_family_index,
        &(app.command_buffer_batch),
        app.device,
        app.queue,
    );
    quit();
}
