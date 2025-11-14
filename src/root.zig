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
};

var app: PicturaApp = undefined;

pub const CmdBufferBatch = struct {
    allocator: std.mem.Allocator,
    cmd_buffers: std.ArrayList(vulkan.VkCommandBufferSubmitInfo),
    fence: vulkan.VkFence,
    executing: bool,

    pub fn create(allocator: std.mem.Allocator, device: vulkan.VkDevice) !CmdBufferBatch {
        const list = try std.ArrayList(vulkan.VkCommandBufferSubmitInfo).initCapacity(allocator, 8);
        std.debug.print("{s}", .{@typeName(@TypeOf(list))});

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
            .executing = false,
        };
    }

    pub fn destroy(batch: *CmdBufferBatch, device: vulkan.VkDevice) void {
        vulkan.vkDestroyFence.?(device, batch.fence, null);
    }

    pub fn append(batch: *CmdBufferBatch, cmd_buffer: vulkan.VkCommandBuffer) !void {
        const info: vulkan.VkCommandBufferSubmitInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
            .pNext = null,
            .commandBuffer = cmd_buffer,
            .deviceMask = 0,
        };
        try batch.cmd_buffers.append(batch.allocator, info);
    }

    pub fn submit_to_queue(batch: *CmdBufferBatch, queue: vulkan.VkQueue) !void {
        var info = std.mem.zeroes(vulkan.VkSubmitInfo2);
        info.sType = vulkan.VK_STRUCTURE_TYPE_SUBMIT_INFO_2;
        info.commandBufferInfoCount = @intCast(batch.cmd_buffers.items.len);
        info.pCommandBufferInfos = @ptrCast(batch.cmd_buffers.items);

        const result = vulkan.vkQueueSubmit2.?(queue, 1, &info, batch.fence);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to submit to queue: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_submit_to_queue;
        }
        batch.executing = true;
    }

    pub fn wait(batch: *CmdBufferBatch, device: vulkan.VkDevice) !void {
        if (!batch.executing) {
            return error.waiting_for_hwat;
        }
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
        batch.cmd_buffers.clearRetainingCapacity();
    }
};

pub fn print_error() void {
    std.debug.print("{s}\n", .{sdl.SDL_GetError()});
}

fn create_swapchain(device: vulkan.VkDevice, surface: vulkan.VkSurfaceKHR, w: u32, h: u32, old_swapchain: vulkan.VkSwapchainKHR) !vulkan.VkSwapchainKHR {
    var info = std.mem.zeroes(vulkan.VkSwapchainCreateInfoKHR);
    info.sType = vulkan.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    info.surface = surface;
    info.minImageCount = 2; // TODO not to hardcode this
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
