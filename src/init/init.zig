const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const vulkan = root.vulkan;
const sdl = root.sdl;

const image = root.image;
const utils = root.utils;
const swapchain = root.swapchain;

fn print_error() void {
    std.debug.print("{s}\n", .{sdl.SDL_GetError()});
}

pub fn _init(w: u32, h: u32, hdpi: bool) !void {
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

    var instance: vulkan.VkInstance = undefined;
    var physical_device: vulkan.VkPhysicalDevice = undefined;

    var result = vulkan.create_instance_and_physical_device(nr_extensions, vk_extensions, &instance, &physical_device);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create instance: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }
    errdefer vulkan.vkDestroyInstance.?(instance, null);

    var nr_available_exts: u32 = 0;
    result = vulkan.vkEnumerateDeviceExtensionProperties.?(physical_device, null, &nr_available_exts, null);
    std.debug.assert(500 >= nr_available_exts);
    var available_dev_exts: [500]vulkan.VkExtensionProperties = undefined;
    result = vulkan.vkEnumerateDeviceExtensionProperties.?(physical_device, null, &nr_available_exts, &available_dev_exts);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to enumerate device extensions: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_enumerate_dev_exts;
    }

    var pageable_mem_available = false;
    var swapchain_mutable_format = false;
    for (0..nr_available_exts) |i| {
        const len = std.mem.indexOfSentinel(u8, 0, @ptrCast(&available_dev_exts[i].extensionName));
        if (std.mem.eql(u8, available_dev_exts[i].extensionName[0..len :0], "VK_EXT_pageable_device_local_memory")) {
            std.debug.print("pageable device memory enabled\n", .{});
            pageable_mem_available = true;
        }
        if (std.mem.eql(u8, available_dev_exts[i].extensionName[0..len :0], "VK_KHR_swapchain_mutable_format")) {
            swapchain_mutable_format = true;
        }
    }

    if (!swapchain_mutable_format) {
        return error.mutable_format_not_available;
    }

    const device_extensions = [4][*c]const u8{ "VK_KHR_swapchain", "VK_KHR_swapchain_mutable_format", "VK_EXT_pageable_device_local_memory", "VK_EXT_memory_priority" };
    const nr_device_extensions: u32 = if (pageable_mem_available) 4 else 2;

    var device: vulkan.VkDevice = undefined;
    var queue_family_index: u32 = 0;

    result = vulkan.create_device(physical_device, &device, &queue_family_index, nr_device_extensions, &device_extensions);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create device: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }
    errdefer vulkan.vkDestroyDevice.?(device, null);

    root.shaders.modules = try .init(device);

    var surface: vulkan.VkSurfaceKHR = undefined;
    success = sdl.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, &surface);
    if (!success) {
        print_error();
        return error.SDL_VulkanCreateSurfaceError;
    }
    errdefer sdl.SDL_Vulkan_DestroySurface(@ptrCast(instance), @ptrCast(surface), null);

    image.format = vulkan.VK_FORMAT_R8G8B8A8_UNORM;

    var swapchain2 = try swapchain.Swapchain.create(physical_device, device, queue_family_index, surface, w, h);
    errdefer swapchain2.destroy(device);

    const command_pool = try utils.create_command_pool(device, queue_family_index);
    errdefer vulkan.vkDestroyCommandPool.?(device, command_pool, null);

    var queue: vulkan.VkQueue = undefined;
    vulkan.vkGetDeviceQueue.?(device, queue_family_index, 0, &queue);

    const device_memory_index = try utils.get_device_memory_index(physical_device);
    std.debug.print("{d}", .{device_memory_index});

    var canvas = try image.PicturaImage.create(w, h, device, queue_family_index, 1);
    errdefer canvas.destroy(device);

    const descriptor_pool = try utils.create_descriptor_pool(device);
    errdefer vulkan.vkDestroyDescriptorPool.?(device, descriptor_pool, null);

    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator); // free everything at once in the end
    // errdefer arena.deinit();

    root.pictura_app = .{
        .window = window,
        .instance = instance,
        .physical_device = physical_device,
        .device = device,
        .queue_family_index = queue_family_index,
        .queue = queue,
        .surface = surface,
        .swapchain = swapchain2,
        .command_pool = command_pool,
        .canvas = canvas,
        .well = try .create(device, command_pool, queue),
        .descriptor_pool = descriptor_pool,
        .pipelines = try .create(device, swapchain2.view_format),
    };

    return;
}

pub export fn quit() void {
    var app = root.pictura_app;

    _ = vulkan.vkDeviceWaitIdle.?(app.device);

    app.pipelines.destroy(app.device);

    vulkan.vkDestroyDescriptorPool.?(app.device, app.descriptor_pool, null);

    app.well.destroy(app.device);

    app.canvas.destroy(app.device);

    vulkan.vkDestroyCommandPool.?(app.device, app.command_pool, null);

    app.swapchain.destroy(app.device);

    sdl.SDL_Vulkan_DestroySurface(@ptrCast(app.instance), @ptrCast(app.surface), null);

    root.shaders.modules.destroy(app.device);

    vulkan.vkDestroyDevice.?(app.device, null);

    vulkan.vkDestroyInstance.?(app.instance, null);

    sdl.SDL_DestroyWindow(app.window);

    sdl.SDL_Quit();

    // app.arena.deinit();

    // app = std.mem.zeroes(PicturaApp);
}

// test "turn it on and off" {
//     try _init(600, 400, false);
//     try std.testing.expect(true);
//     quit();
// }
