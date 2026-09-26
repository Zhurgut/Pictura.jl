const std = @import("std");
const root = @import("../root.zig");
pub const c = @import("my_vulkan");
const sdl = root.sdl;
pub const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

pub fn create_instance(allocator: Allocator, custom_extensions: []const [*:0]const u8, layers: []const [*:0]const u8) !c.VkInstance {
    var nr_sdl_extensions: u32 = 0;

    // This should be called after either calling SDL_Vulkan_LoadLibrary() or creating an SDL_Window with the SDL_WINDOW_VULKAN flag.
    const sdl_extensions_ptr = sdl.c.SDL_Vulkan_GetInstanceExtensions(&nr_sdl_extensions);
    if (sdl_extensions_ptr == null) {
        sdl.utils.print_sdl_error();
        return error.failed_to_get_sdl_vulkan_instance_extensions;
    }

    const sdl_extensions: []const [*:0]const u8 = @ptrCast(sdl_extensions_ptr[0..nr_sdl_extensions]);

    var all_extensions = try allocator.alloc([*:0]const u8, nr_sdl_extensions + custom_extensions.len);
    defer allocator.free(all_extensions);

    @memcpy(all_extensions[0..nr_sdl_extensions], sdl_extensions);
    @memcpy(all_extensions[nr_sdl_extensions..], custom_extensions);
    // TODO filter out possible duplicates

    var instance: c.VkInstance = undefined;

    const result = c.create_instance(
        &instance,
        @intCast(all_extensions.len),
        all_extensions.ptr,
        @intCast(layers.len),
        layers.ptr,
    );

    if (result != c.VK_SUCCESS) {
        std.debug.print("failed to create instance: {s}\n", .{c.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }

    return instance;
}

pub fn create_physical_device(device_index: u32, instance: c.VkInstance) !c.VkPhysicalDevice {
    var physical_device: c.VkPhysicalDevice = undefined;

    const result = c.create_physical_device(&physical_device, device_index, instance);
    if (result != c.VK_SUCCESS) {
        std.debug.print("failed to create physical device: {s}\n", .{c.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }

    return physical_device;
}

pub fn create_device(
    allocator: Allocator,
    physical_device: c.VkPhysicalDevice,
    additional_features_ptr: ?*anyopaque,
    additional_dev_extensions: []const [*:0]const u8,
) !struct { c.VkDevice, u32 } {

    // features:
    var dynamic_rendering = std.mem.zeroes(c.VkPhysicalDeviceDynamicRenderingFeatures);
    dynamic_rendering.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES;
    dynamic_rendering.dynamicRendering = c.VK_TRUE;
    dynamic_rendering.pNext = additional_features_ptr;

    var sync2_feature = std.mem.zeroes(c.VkPhysicalDeviceSynchronization2Features);
    sync2_feature.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES;
    sync2_feature.synchronization2 = c.VK_TRUE;
    sync2_feature.pNext = &dynamic_rendering;

    var pageable_mem_feature = std.mem.zeroes(c.VkPhysicalDevicePageableDeviceLocalMemoryFeaturesEXT);
    pageable_mem_feature.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PAGEABLE_DEVICE_LOCAL_MEMORY_FEATURES_EXT;
    pageable_mem_feature.pNext = &sync2_feature;

    // device extensions:
    const available_extensions = try utils.get_device_extensions(allocator, physical_device);

    var device_extensions = try allocator.alloc([*:0]const u8, additional_dev_extensions.len);
    defer allocator.free(device_extensions);

    // @memcpy(device_extensions, additional_dev_extensions);

    if (utils.has_extension(available_extensions, "VK_KHR_swapchain_mutable_format")) {
        device_extensions = try allocator.realloc(device_extensions, device_extensions.len + 2);
        device_extensions[device_extensions.len - 2] = "VK_KHR_swapchain";
        device_extensions[device_extensions.len - 1] = "VK_KHR_swapchain_mutable_format";
    } else {
        return error.swapchain_mutable_format_extension_not_found_but_required;
    }

    if (utils.has_extension(available_extensions, "VK_EXT_pageable_device_local_memory")) {
        device_extensions = try allocator.realloc(device_extensions, device_extensions.len + 2);
        device_extensions[device_extensions.len - 2] = "VK_EXT_pageable_device_local_memory";
        device_extensions[device_extensions.len - 1] = "VK_EXT_memory_priority";
        pageable_mem_feature.pageableDeviceLocalMemory = c.VK_TRUE;
    }

    // TODO filter out possible duplicates

    // creating the device (and getting the queue family index)
    var device: c.VkDevice = undefined;
    var queue_family_index: u32 = 0;

    const result = c.create_device(
        &device,
        &queue_family_index,
        physical_device,
        @intCast(device_extensions.len),
        device_extensions.ptr,
        &pageable_mem_feature,
    );
    if (result != c.VK_SUCCESS) {
        std.debug.print("failed to create device: {s}\n", .{c.string_VkResult(result)});
        return error.Vk_failed_to_initialize_vulkan;
    }
    errdefer c.vkDestroyDevice.?(device, null);

    return .{ device, queue_family_index };
}
