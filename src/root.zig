const std = @import("std");
const testing = std.testing;

const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const vulkan = @cImport({
    @cInclude("src/init_vulkan.h");
});

const PicturaApp = struct {
    window: ?*sdl.struct_SDL_Window,
    instance: vulkan.VkInstance,
    device: vulkan.VkDevice,
    queue_family_index: u32,
    surface: vulkan.VkSurfaceKHR,
    swapchain: vulkan.VkSwapchainKHR,
};

var app: PicturaApp = undefined;

pub fn print_error() void {
    std.debug.print("{s}\n", .{sdl.SDL_GetError()});
}

pub fn create_swapchain(device: vulkan.VkDevice, surface: vulkan.VkSurfaceKHR, w: u32, h: u32, old_swapchain: vulkan.VkSwapchainKHR) !vulkan.VkSwapchainKHR {
    var info: vulkan.VkSwapchainCreateInfoKHR = std.mem.zeroes(vulkan.VkSwapchainCreateInfoKHR);
    info.sType = vulkan.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    info.surface = surface;
    info.minImageCount = 2; // TODO not to hardcode this
    info.imageFormat = vulkan.VK_FORMAT_B8G8R8A8_SRGB; // ???
    // info.imageFormat = 0xffffffff; // ???
    info.imageColorSpace = vulkan.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR; // ??? imageFormat and imageColorSpace must match the format and colorSpace members, respectively, of one of the VkSurfaceFormatKHR structures returned by vkGetPhysicalDeviceSurfaceFormatsKHR for the surface
    info.imageExtent = .{ .width = w, .height = h };
    info.imageArrayLayers = 1; // no idea what are these layers?
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

pub export fn init(w: u32, h: u32, hdpi: bool) u32 {
    var success = sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO | sdl.SDL_INIT_GAMEPAD);
    if (!success) {
        print_error();
        return @intFromError(error.SDL_InitError);
    }

    const hdpi_flag: u32 = if (hdpi) sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY else 0;

    const window = sdl.SDL_CreateWindow(
        "Pictura",
        @intCast(w),
        @intCast(h),
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_INPUT_FOCUS | sdl.SDL_WINDOW_VULKAN | hdpi_flag,
    );

    if (window == null) {
        print_error();
        return @intFromError(error.SDL_CreateWindowError);
    }

    var nr_extensions: u32 = 0;
    const vk_extensions = sdl.SDL_Vulkan_GetInstanceExtensions(&nr_extensions);

    // for (vk_extensions, 0..nr_extensions) |ext, _| {
    //     std.debug.print("{s}\n", .{ext});
    // }

    const device_extensions = [_][*c]const u8{"VK_KHR_swapchain"};
    const nr_device_extensions = device_extensions.len;

    var instance: vulkan.VkInstance = undefined;
    var device: vulkan.VkDevice = undefined;
    var queue_family_index: u32 = 0;

    const result = vulkan.init_vulkan(nr_extensions, vk_extensions, nr_device_extensions, &device_extensions, &instance, &device, &queue_family_index);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to initialize vulkan: {s}\n", .{vulkan.string_VkResult(result)});
        return @intFromError(error.Vk_failed_to_initialize_vulkan);
    }

    var surface: vulkan.VkSurfaceKHR = undefined;
    success = sdl.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, &surface);

    if (!success) {
        print_error();
        return @intFromError(error.SDL_VulkanCreateSurfaceError);
    }

    const swapchain = create_swapchain(device, surface, w, h, null) catch |e| return @intFromError(e);

    app = .{
        .window = window,
        .instance = instance,
        .device = device,
        .queue_family_index = queue_family_index,
        .surface = surface,
        .swapchain = swapchain,
    };

    return 0;
}

pub export fn quit() void {
    _ = vulkan.vkDeviceWaitIdle.?(app.device);

    vulkan.vkDestroySwapchainKHR.?(app.device, app.swapchain, null);

    sdl.SDL_Vulkan_DestroySurface(@ptrCast(app.instance), @ptrCast(app.surface), null);

    vulkan.vkDestroyDevice.?(app.device, null);

    vulkan.vkDestroyInstance.?(app.instance, null);

    sdl.SDL_DestroyWindow(app.window);

    sdl.SDL_Quit();

    app = std.mem.zeroes(PicturaApp);
}

test "turn it on and off" {
    const success = init(600, 400, false);
    try std.testing.expect(success == 0);

    // var event: sdl.SDL_Event = undefined;

    // outer: while (true) {
    //     sdl.SDL_Delay(20);
    //     while (sdl.SDL_PollEvent(&event) == true) {
    //         switch (event.type) {
    //             sdl.SDL_EVENT_QUIT => break :outer,
    //             else => {},
    //         }
    //     }
    // }

    quit();
}
