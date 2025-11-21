const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");
const vulkan = root.vulkan;
const sdl = root.sdl;

const image = root.image;
const utils = root.utils;

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
    errdefer vulkan.vkDestroyInstance.?(instance, null);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create instance: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }

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
    for (0..nr_available_exts) |i| {
        const len = std.mem.indexOfSentinel(u8, 0, @ptrCast(&available_dev_exts[i].extensionName));
        if (std.mem.eql(u8, available_dev_exts[i].extensionName[0..len :0], "VK_EXT_pageable_device_local_memory")) {
            std.debug.print("pageable device memory enabled\n", .{});
            pageable_mem_available = true;
            break;
        }
    }

    const device_extensions = [3][*c]const u8{ "VK_KHR_swapchain", "VK_EXT_pageable_device_local_memory", "VK_EXT_memory_priority" };
    const nr_device_extensions: u32 = if (pageable_mem_available) 3 else 1;

    var device: vulkan.VkDevice = undefined;
    var queue_family_index: u32 = 0;

    result = vulkan.create_device(physical_device, &device, &queue_family_index, nr_device_extensions, &device_extensions);
    errdefer vulkan.vkDestroyDevice.?(device, null);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create device: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }

    var surface: vulkan.VkSurfaceKHR = undefined;
    success = sdl.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, &surface);
    if (!success) {
        print_error();
        return error.SDL_VulkanCreateSurfaceError;
    }
    errdefer sdl.SDL_Vulkan_DestroySurface(@ptrCast(instance), @ptrCast(surface), null);

    // getting ready to crate swapchain

    var supported: vulkan.VkBool32 = vulkan.VK_FALSE;
    result = vulkan.vkGetPhysicalDeviceSurfaceSupportKHR.?(physical_device, queue_family_index, surface, &supported);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to check if surface is supported: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }
    if (supported == vulkan.VK_FALSE) {
        return error.surface_not_supported_by_physical_device; // shrug
    }

    var capabilities: vulkan.VkSurfaceCapabilitiesKHR = undefined;
    result = vulkan.vkGetPhysicalDeviceSurfaceCapabilitiesKHR.?(physical_device, surface, &capabilities);
    // min and max image count in swapchain, min max extent, ...
    // supported transforms, supported usage flags
    // std.debug.assert(capabilities.supportedUsageFlags & vulkan.VK_IMAGE_USAGE_TRANSFER_DST_BIT != 0); // for example

    var nr_formats: u32 = 0;
    var formats: [20]vulkan.VkSurfaceFormatKHR = undefined;

    result = vulkan.vkGetPhysicalDeviceSurfaceFormatsKHR.?(physical_device, surface, &nr_formats, null);
    std.debug.assert(20 > nr_formats);
    result = vulkan.vkGetPhysicalDeviceSurfaceFormatsKHR.?(physical_device, surface, &nr_formats, &formats);
    for (0..nr_formats) |i| {
        std.debug.print("{d} {d}\n", .{ formats[i].format, formats[i].colorSpace });
    }

    // for swapchain we want VK_FORMAT_B8G8R8A8_SRGB (must be srgb)
    // for internal targets we want VK_FORMAT_R8G8B8A8_UNORM (because that's what we want on cpu side pixel array) TODO write function to choose format based on whats available

    const swapchain_format = vulkan.VK_FORMAT_B8G8R8A8_SRGB;
    image.format = vulkan.VK_FORMAT_R8G8B8A8_UNORM;
    const color_space = formats[0].colorSpace; // srgb nonlinear

    const swapchain = try utils.create_swapchain(device, surface, w, h, swapchain_format, color_space, null);
    errdefer vulkan.vkDestroySwapchainKHR.?(device, swapchain, null);

    const command_pool = try utils.create_command_pool(device, queue_family_index);
    errdefer vulkan.vkDestroyCommandPool.?(device, command_pool, null);

    var queue: vulkan.VkQueue = undefined;
    vulkan.vkGetDeviceQueue.?(device, queue_family_index, 0, &queue);

    const device_memory_index = utils.get_device_memory_index(physical_device);
    std.debug.print("{d}", .{device_memory_index});

    var canvas = try image.PicturaImage.create(w, h, device, queue_family_index, 1);
    errdefer canvas.destroy(device);

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
        .swapchain = swapchain,
        .swapchain_layouts = [3]vulkan.VkImageLayout{ vulkan.VK_IMAGE_LAYOUT_UNDEFINED, vulkan.VK_IMAGE_LAYOUT_UNDEFINED, vulkan.VK_IMAGE_LAYOUT_UNDEFINED },
        .command_pool = command_pool,
        .canvas = canvas,
        .well = try .create(device, command_pool, queue),
        .semaphores = try .create(device),
    };

    return;
}

pub export fn quit() void {
    var app = root.pictura_app;

    _ = vulkan.vkDeviceWaitIdle.?(app.device);

    app.semaphores.destroy(app.device);

    app.well.destroy(app.device);

    app.canvas.destroy(app.device);

    vulkan.vkDestroyCommandPool.?(app.device, app.command_pool, null);
    vulkan.vkDestroySwapchainKHR.?(app.device, app.swapchain, null);

    sdl.SDL_Vulkan_DestroySurface(@ptrCast(app.instance), @ptrCast(app.surface), null);

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
