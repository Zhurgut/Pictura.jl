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

    const swapchain = try utils.create_swapchain(device, surface, w, h, null);
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
