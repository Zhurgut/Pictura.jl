const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const vulkan = root.vulkan;
const sdl = root.sdl;

const image = root.image;
const utils = root.utils;
const swapchain = root.swapchain;

const MAX_INSTANCE_EXTENSIONS: u32 = 64;
const MAX_LAYERS: u32 = 64;
const MAX_DEV_EXTENSIONS: u32 = 512;

fn print_sdl_error() void {
    std.debug.print("{s}\n", .{sdl.SDL_GetError()});
}

pub fn create_window_and_vkinstance(w: u32, h: u32, additional_extensions: ?[][*:0]const u8, layers: ?[][*:0]const u8) !struct { *sdl.SDL_Window, vulkan.VkInstance } {
    const success = sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO | sdl.SDL_INIT_GAMEPAD);
    if (!success) {
        print_sdl_error();
        return error.SDL_InitError;
    }
    errdefer sdl.SDL_Quit();

    const window: ?*sdl.SDL_Window = sdl.SDL_CreateWindow(
        "Pictura",
        @intCast(w),
        @intCast(h),
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_INPUT_FOCUS | sdl.SDL_WINDOW_VULKAN,
    );
    if (window == null) {
        print_sdl_error();
        return error.SDL_CreateWindowError;
    }
    errdefer sdl.SDL_DestroyWindow(window.?);

    var nr_extensions: u32 = 0;
    const vk_extensions = sdl.SDL_Vulkan_GetInstanceExtensions(&nr_extensions);

    var all_extensions: [MAX_INSTANCE_EXTENSIONS](?[*:0]const u8) = undefined;
    @memmove(all_extensions[0..nr_extensions], vk_extensions);

    if (additional_extensions) |addexts| {
        @memmove(all_extensions[nr_extensions .. nr_extensions + addexts.len], addexts);
        nr_extensions += @intCast(addexts.len);
    }

    var instance: vulkan.VkInstance = undefined;

    const result = if (layers) |ls|
        vulkan.create_instance(&instance, nr_extensions, &all_extensions, @intCast(ls.len), ls.ptr)
    else
        vulkan.create_instance(&instance, nr_extensions, &all_extensions, 0, null);

    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create instance: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }
    errdefer vulkan.vkDestroyInstance.?(instance, null);

    return .{ window.?, instance };
}

fn add_mutable_swapchain_format_ext(out: [*][*:0]const u8, next_idx: u32, all: []vulkan.VkExtensionProperties) u32 {
    for (all) |ext| {
        const len = std.mem.indexOfSentinel(u8, 0, @ptrCast(&ext.extensionName));
        if (std.mem.eql(u8, ext.extensionName[0..len :0], "VK_KHR_swapchain_mutable_format")) {
            out[next_idx] = "VK_KHR_swapchain";
            out[next_idx + 1] = "VK_KHR_swapchain_mutable_format";
            return 2;
        }
    }
    std.debug.print("VK_KHR_swapchain_mutable_format extension not found, gonna try anyways...\n", .{});
    return 0;
}

fn add_pageable_dev_mem_ext(out: [*][*:0]const u8, next_idx: u32, all: []vulkan.VkExtensionProperties, pageable_mem_feature: *vulkan.VkPhysicalDevicePageableDeviceLocalMemoryFeaturesEXT) u32 {
    for (all) |ext| {
        const len = std.mem.indexOfSentinel(u8, 0, @ptrCast(&ext.extensionName));
        if (std.mem.eql(u8, ext.extensionName[0..len :0], "VK_EXT_pageable_device_local_memory")) {
            out[next_idx] = "VK_EXT_pageable_device_local_memory";
            out[next_idx + 1] = "VK_EXT_memory_priority";
            pageable_mem_feature.pageableDeviceLocalMemory = vulkan.VK_TRUE;
            return 2;
        }
    }
    return 0;
}

pub fn create_device(instance: vulkan.VkInstance, dev_index: u32, additional_features_ptr: ?*anyopaque, additional_dev_extensions: ?[][*:0]const u8) !struct { vulkan.VkPhysicalDevice, vulkan.VkDevice, u32 } {
    // physical device:

    var physical_device: vulkan.VkPhysicalDevice = undefined;

    var result = vulkan.create_physical_device(&physical_device, dev_index, instance);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create physical device: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }

    // features:

    var dynamic_rendering = std.mem.zeroes(vulkan.VkPhysicalDeviceDynamicRenderingFeatures);
    dynamic_rendering.sType = vulkan.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES;
    dynamic_rendering.dynamicRendering = vulkan.VK_TRUE;
    dynamic_rendering.pNext = additional_features_ptr;

    var sync2_feature = std.mem.zeroes(vulkan.VkPhysicalDeviceSynchronization2Features);
    sync2_feature.sType = vulkan.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES;
    sync2_feature.synchronization2 = vulkan.VK_TRUE;
    sync2_feature.pNext = &dynamic_rendering;

    var pageable_mem_feature = std.mem.zeroes(vulkan.VkPhysicalDevicePageableDeviceLocalMemoryFeaturesEXT);
    pageable_mem_feature.sType = vulkan.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PAGEABLE_DEVICE_LOCAL_MEMORY_FEATURES_EXT;
    pageable_mem_feature.pNext = &sync2_feature;

    // device extensions:

    var nr_available_exts: u32 = 0;
    result = vulkan.vkEnumerateDeviceExtensionProperties.?(physical_device, null, &nr_available_exts, null);
    if (nr_available_exts > MAX_DEV_EXTENSIONS) {
        std.debug.print("wont be able to enumerate all device extensions, of which there are {d}\n", .{nr_available_exts});
    }
    var available_dev_exts: [MAX_DEV_EXTENSIONS]vulkan.VkExtensionProperties = undefined;

    result = vulkan.vkEnumerateDeviceExtensionProperties.?(physical_device, null, &nr_available_exts, &available_dev_exts);
    if (result != vulkan.VK_SUCCESS and result != vulkan.VK_INCOMPLETE) {
        std.debug.print("failed to enumerate device extensions: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_enumerate_dev_exts;
    }

    const all_dev_exts = available_dev_exts[0..@min(MAX_DEV_EXTENSIONS, nr_available_exts)];
    var enabled_exts: [MAX_DEV_EXTENSIONS][*:0]const u8 = undefined;

    var nr_exts: u32 = 0;

    nr_exts += add_mutable_swapchain_format_ext(&enabled_exts, nr_exts, all_dev_exts);
    nr_exts += add_pageable_dev_mem_ext(&enabled_exts, nr_exts, all_dev_exts, &pageable_mem_feature);

    if (additional_dev_extensions) |exts| {
        @memmove(enabled_exts[nr_exts .. nr_exts + exts.len], exts);
        nr_exts += @intCast(exts.len);
    }

    // creating the device (and getting the queue family index)

    var device: vulkan.VkDevice = undefined;
    var queue_family_index: u32 = 0;

    result = vulkan.create_device(&device, &queue_family_index, physical_device, nr_exts, &enabled_exts, &pageable_mem_feature);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create device: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }
    errdefer vulkan.vkDestroyDevice.?(device, null);

    return .{ physical_device, device, queue_family_index };
}

pub fn init_app(
    w: u32,
    h: u32,
    window: *sdl.SDL_Window,
    instance: vulkan.VkInstance,
    physical_device: vulkan.VkPhysicalDevice,
    device: vulkan.VkDevice,
    queue_family_index: u32,
) !void {
    var queue: vulkan.VkQueue = undefined;
    vulkan.vkGetDeviceQueue.?(device, queue_family_index, 0, &queue);

    root.shaders.modules = try .init(device);
    errdefer root.shaders.modules.destroy(device);

    const command_pool = try utils.create_command_pool(device, queue_family_index);
    errdefer vulkan.vkDestroyCommandPool.?(device, command_pool, null);

    var surface: vulkan.VkSurfaceKHR = undefined;
    const success = sdl.SDL_Vulkan_CreateSurface(window, @ptrCast(instance), null, &surface);
    if (!success) {
        print_sdl_error();
        return error.SDL_VulkanCreateSurfaceError;
    }
    errdefer sdl.SDL_Vulkan_DestroySurface(@ptrCast(instance), @ptrCast(surface), null);

    const descriptor_pool = try utils.create_descriptor_pool(device);
    errdefer vulkan.vkDestroyDescriptorPool.?(device, descriptor_pool, null);

    var well: root.WellOfCommands = try .create(device, command_pool, queue);
    errdefer well.destroy(device);

    var swapchain2 = try swapchain.Swapchain.create(physical_device, device, queue_family_index, surface, w, h);
    errdefer swapchain2.destroy(device);

    var pipelines = try root.pipelines.Pipelines.create(device, swapchain2.view_format);
    errdefer pipelines.destroy(device);

    var canvas = try image.PicturaImage.create(w, h, device, queue_family_index, physical_device);
    errdefer canvas.destroy(device, descriptor_pool);

    var numkeys: i32 = undefined;
    const kb = sdl.SDL_GetKeyboardState(&numkeys);
    root.events.keyboard = kb[0..@intCast(numkeys)];

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator); // free everything at once in the end
    errdefer arena.deinit();

    const now = sdl.SDL_GetTicksNS();
    const framerate = try root.sdl_utils.get_display_refresh_rate(window) - 1;

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
        .canvas_id = 1,
        .well = well,
        .descriptor_pool = descriptor_pool,
        .pipelines = pipelines,
        .running = true,
        .event_handler = .create(),
        .arena = arena,
        .gpa = arena.allocator(),
        .target_framerate = framerate,
        .target_time = now + 2, // target time of next frame, as soon as possible
        .last_frame_time = now + 1,
        .before_last_time = now,
    };
}

pub fn init2(
    w: u32,
    h: u32,
    instance_extensions: ?[][*:0]const u8,
    vulkan_layers: ?[][*:0]const u8,
    features: ?*anyopaque,
    device_extensions: ?[][*:0]const u8,
) !void {
    const window, const instance = try create_window_and_vkinstance(
        w,
        h,
        instance_extensions,
        vulkan_layers,
    );
    errdefer sdl.SDL_Quit();
    errdefer sdl.SDL_DestroyWindow(window);
    errdefer vulkan.vkDestroyInstance.?(instance, null);

    const physical_device, const device, const queue_family_index = try create_device(
        instance,
        0,
        features,
        device_extensions,
    );
    errdefer vulkan.vkDestroyDevice.?(device, null);

    try init_app(
        w,
        h,
        window,
        instance,
        physical_device,
        device,
        queue_family_index,
    );
    errdefer root.shaders.modules.destroy(device);
    errdefer vulkan.vkDestroyCommandPool.?(device, root.pictura_app.command_pool, null);
    errdefer sdl.SDL_Vulkan_DestroySurface(@ptrCast(instance), @ptrCast(root.pictura_app.surface), null);
    errdefer vulkan.vkDestroyDescriptorPool.?(device, root.pictura_app.descriptor_pool, null);
    errdefer root.pictura_app.well.destroy(device);
    errdefer root.pictura_app.swapchain.destroy(device);
    errdefer root.pictura.pipelines.destroy(device);
    errdefer root.pictura_app.canvas.destroy(device, root.pictura_app.descriptor_pool);
    errdefer root.pictura_app.arena.deinit();

    return;
}

pub fn init(w: u32, h: u32) !void {
    try init2(w, h, null, null, null, null);
}

pub fn quit() void {
    var app = root.pictura_app;

    _ = vulkan.vkDeviceWaitIdle.?(app.device);

    app.arena.deinit();

    app.canvas.destroy(app.device, app.descriptor_pool);

    app.pipelines.destroy(app.device);

    app.swapchain.destroy(app.device);

    app.well.destroy(app.device);

    vulkan.vkDestroyDescriptorPool.?(app.device, app.descriptor_pool, null);

    sdl.SDL_Vulkan_DestroySurface(@ptrCast(app.instance), @ptrCast(app.surface), null);

    vulkan.vkDestroyCommandPool.?(app.device, app.command_pool, null);

    root.shaders.modules.destroy(app.device);

    vulkan.vkDestroyDevice.?(app.device, null);

    // vulkan.vkDestroyInstance.?(app.instance, null); // hangs :(

    sdl.SDL_DestroyWindow(app.window);

    sdl.SDL_Quit();

    // app = std.mem.zeroes(PicturaApp);
}

// test "turn it on and off" {
//     try _init(600, 400, false);
//     try std.testing.expect(true);
//     quit();
// }
