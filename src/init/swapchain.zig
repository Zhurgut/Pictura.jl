const std = @import("std");
const root = @import("../root.zig");
const vulkan = root.vulkan;
const PicturaImage = root.image.PicturaImage;
const utils = root.utils;
const shaders = root.shaders;

pub const Swapchain = struct {
    swapchain: vulkan.VkSwapchainKHR,
    images: [3]PicturaImage,
    semaphores: SemaphoreClub(4),
    // descriptor_sets: [3]vulkan.

    pub fn create(
        physical_device: vulkan.VkPhysicalDevice,
        device: vulkan.VkDevice,
        queue_family_index: u32,
        surface: vulkan.VkSurfaceKHR,
        w: u32,
        h: u32,
    ) !Swapchain {
        var out: Swapchain = undefined;

        _, const format, const colorspace = try get_infos(physical_device, queue_family_index, surface);

        const swapchain = try create_swapchain(device, surface, w, h, format, colorspace, null);

        var count: u32 = 3;
        var images: [3]vulkan.VkImage = undefined;
        const result = vulkan.vkGetSwapchainImagesKHR.?(device, swapchain, &count, &images);
        if (result != vulkan.VK_SUCCESS and result != vulkan.VK_INCOMPLETE) {
            std.debug.print("failed to get swapchain images: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_get_swapchain_images;
        }

        out.swapchain = swapchain;

        for (0..out.images.len) |i| {
            out.images[i] = .{
                .w = w,
                .h = h,
                .memory = null,
                .image = images[i],
                .layout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
                .image_view = try utils.create_image_view(images[i], device, format),
            };
        }

        out.semaphores = try SemaphoreClub(4).create(device);

        return out;
    }

    // pub fn recreate() Swapchain {}

    // pub fn destroy() void {}

    pub fn present(swapchain: *Swapchain, contents: *PicturaImage, app: *root.PicturaApp) !void {
        const image_acquired_sm = try swapchain.semaphores.get_image_acquired_semaphore(app.device);

        var image_index: u32 = 0;
        const acquire_image_success = vulkan.vkAcquireNextImageKHR.?(app.device, swapchain.swapchain, 0, image_acquired_sm, null, &image_index);

        std.debug.assert(acquire_image_success != vulkan.VK_SUBOPTIMAL_KHR);

        if (acquire_image_success == vulkan.VK_NOT_READY) {
            _ = try app.well.submit(app.device, app.queue, null, null, null, null);
            std.debug.print("-", .{});
            return;
        }

        // otherwise, we are presenting!

        swapchain.semaphores.using_image_index(image_index);

        var swapchain_image = swapchain.images[image_index];

        // const command_buffer = try app.well.render_into(swapchain_image, app.device, app.queue_family_index);
        const command_buffer = try app.well.record(app.device);

        const subresource_layers: vulkan.VkImageSubresourceLayers = .{
            .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
            .mipLevel = 0,
            .baseArrayLayer = 0,
            .layerCount = 1,
        };

        const canvas_barrier = utils.image_memory_barrier(
            contents,
            vulkan.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            app.queue_family_index,
            vulkan.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
            vulkan.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            vulkan.VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT_KHR,
            vulkan.VK_ACCESS_TRANSFER_READ_BIT,
        );

        var swapchain_barrier = utils.image_memory_barrier(
            &swapchain_image,
            vulkan.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            app.queue_family_index,
            vulkan.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
            vulkan.VK_ACCESS_NONE,
            vulkan.VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT_KHR,
            vulkan.VK_ACCESS_TRANSFER_WRITE_BIT,
        );

        const barriers = [2]vulkan.VkImageMemoryBarrier2{ swapchain_barrier, canvas_barrier };

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
            .extent = .{ .width = contents.w, .height = contents.h, .depth = 1 },
        };

        vulkan.vkCmdCopyImage.?(command_buffer, contents.image, contents.layout, swapchain_image.image, swapchain_image.layout, 1, &copy);

        swapchain_barrier = utils.image_memory_barrier(
            &swapchain_image,
            vulkan.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            app.queue_family_index,
            vulkan.VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT_KHR,
            vulkan.VK_ACCESS_TRANSFER_WRITE_BIT,
            vulkan.VK_PIPELINE_STAGE_2_NONE,
            vulkan.VK_ACCESS_NONE,
        );

        dep_info = std.mem.zeroes(vulkan.VkDependencyInfo);
        dep_info.sType = vulkan.VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
        dep_info.imageMemoryBarrierCount = 1;
        dep_info.pImageMemoryBarriers = &swapchain_barrier;

        vulkan.vkCmdPipelineBarrier2.?(command_buffer, &dep_info);

        var ready_to_present = swapchain.semaphores.get_ready_to_present_semaphore();

        try app.well.submit(
            app.device,
            app.queue,
            image_acquired_sm,
            vulkan.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
            ready_to_present,
            vulkan.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
        );

        try swapchain.semaphores.submitted_acquired_semaphore(app.queue);

        const present_info: vulkan.VkPresentInfoKHR = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .pNext = null,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &(ready_to_present),
            .swapchainCount = 1,
            .pSwapchains = &(swapchain.swapchain),
            .pImageIndices = &image_index,
            .pResults = null,
        };

        const result = vulkan.vkQueuePresentKHR.?(app.queue, &present_info);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to present: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_present;
        }
    }
};

pub fn SemaphoreClub(comptime n: u32) type {
    return struct {
        // semaphores for acquiring images from the swapchain, signal when image is ready
        // can only be reused once the image with the same index has been acquired from the swapchain again
        image_acquired: [n]vulkan.VkSemaphore,
        fences: [n]vulkan.VkFence,
        last_image_acquired_semaphore_index: u32,
        used_by_image_index: [n]i32, // -1 means not in use anymore

        // semaphores to wait on before presenting
        // we only know a semaphore has been waited on, once the image of the corresponding present operation has been reacquired
        ready_to_present: [n]vulkan.VkSemaphore,

        pub fn create(device: vulkan.VkDevice) !SemaphoreClub(n) {
            var out: SemaphoreClub(n) = undefined;
            for (0..n) |i| {
                out.image_acquired[i] = try utils.create_semaphore(device);
                out.fences[i] = try utils.create_fence(device, vulkan.VK_FENCE_CREATE_SIGNALED_BIT);
                out.used_by_image_index[i] = -1;
                out.ready_to_present[i] = try utils.create_semaphore(device);
            }

            return out;
        }

        pub fn destroy(sems: *SemaphoreClub(n), device: vulkan.VkDevice) void {
            for (0..n) |i| {
                vulkan.vkDestroySemaphore.?(device, sems.image_acquired[i], null);
            }
            for (0..sems.ready_to_present.len) |i| {
                vulkan.vkDestroySemaphore.?(device, sems.ready_to_present[i], null);
            }
        }

        pub fn get_image_acquired_semaphore(sems: *SemaphoreClub(n), device: vulkan.VkDevice) !vulkan.VkSemaphore {
            for (0..n) |i| {
                if (sems.used_by_image_index[i] == -1) {
                    try utils.wait_and_reset_fence(device, &sems.fences[i]);

                    sems.last_image_acquired_semaphore_index = @intCast(i);
                    return sems.image_acquired[i];
                }
            }
            unreachable;
        }

        pub fn using_image_index(sems: *SemaphoreClub(n), idx: u32) void {
            // when image acquire succeeds, call this function so the semaphore club knows what swapchain image the last semaphore is used with,
            // so it knows when the semaphore is safe to reuse again
            for (0..n) |i| {
                if (sems.used_by_image_index[i] == idx) {
                    sems.used_by_image_index[i] = -1;
                }
            }
            sems.used_by_image_index[sems.last_image_acquired_semaphore_index] = @intCast(idx);
            std.debug.print("[{d}] {d} {d} {d} {d}\n", .{ idx, sems.used_by_image_index[0], sems.used_by_image_index[1], sems.used_by_image_index[2], sems.used_by_image_index[3] });
        }

        pub fn submitted_acquired_semaphore(sems: *SemaphoreClub(n), queue: vulkan.VkQueue) !void {
            // so we submit the corresponding fence as well, so we know when we can use the semaphore again
            var submit_info = std.mem.zeroes(vulkan.VkSubmitInfo2);
            submit_info.sType = vulkan.VK_STRUCTURE_TYPE_SUBMIT_INFO_2;

            const result = vulkan.vkQueueSubmit2.?(queue, 1, &submit_info, sems.fences[sems.last_image_acquired_semaphore_index]); // only submit fence
            if (result != vulkan.VK_SUCCESS) {
                std.debug.print("failed to submit to queue: {s}\n", .{vulkan.string_VkResult(result)});
                return error.Vk_failed_to_submit_to_queue;
            }
        }

        pub fn get_ready_to_present_semaphore(sems: *SemaphoreClub(n)) vulkan.VkSemaphore {
            return sems.ready_to_present[sems.last_image_acquired_semaphore_index];
        }
    };
}

fn get_infos(physical_device: vulkan.VkPhysicalDevice, queue_family_index: u32, surface: vulkan.VkSurfaceKHR) !struct { vulkan.VkSurfaceCapabilitiesKHR, vulkan.VkFormat, vulkan.VkColorSpaceKHR } {
    var supported: vulkan.VkBool32 = vulkan.VK_FALSE;
    var result = vulkan.vkGetPhysicalDeviceSurfaceSupportKHR.?(physical_device, queue_family_index, surface, &supported);
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

    return .{ capabilities, vulkan.VK_FORMAT_B8G8R8A8_SRGB, formats[0].colorSpace }; // TODO remove hardcoding
}

pub fn create_swapchain(
    device: vulkan.VkDevice,
    surface: vulkan.VkSurfaceKHR,
    w: u32,
    h: u32,
    format: vulkan.VkFormat,
    colorspace: vulkan.VkColorSpaceKHR,
    old_swapchain: vulkan.VkSwapchainKHR,
) !vulkan.VkSwapchainKHR {
    const info: vulkan.VkSwapchainCreateInfoKHR = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = 3, // TODO not to hardcode this
        .imageFormat = format,
        .imageColorSpace = colorspace,
        .imageExtent = .{ .width = w, .height = h },
        .imageArrayLayers = 1,
        .imageUsage = vulkan.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | vulkan.VK_IMAGE_USAGE_TRANSFER_DST_BIT, // ???
        .preTransform = vulkan.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        .compositeAlpha = vulkan.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = vulkan.VK_PRESENT_MODE_FIFO_KHR,
        .oldSwapchain = old_swapchain,
    };

    var swapchain: vulkan.VkSwapchainKHR = undefined;
    const result = vulkan.vkCreateSwapchainKHR.?(device, &info, null, &swapchain);

    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create swapchain: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_swapchain;
    }

    return swapchain;
}
