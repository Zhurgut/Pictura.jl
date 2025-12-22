const std = @import("std");
const root = @import("root.zig");
const vulkan = root.vulkan;
const image = root.image;
const PicturaImage = image.PicturaImage;
const utils = root.utils;
const shaders = root.shaders;

pub const Swapchain = struct {
    swapchain: vulkan.VkSwapchainKHR,
    images: [3]PicturaImage,
    img_format: vulkan.VkFormat,
    view_format: vulkan.VkFormat,
    semaphores: SemaphoreClub(4),
    request_recreation: bool = false,

    fn unorm_format(format: vulkan.VkFormat) vulkan.VkFormat {
        return switch (format) {
            vulkan.VK_FORMAT_B8G8R8A8_SRGB => vulkan.VK_FORMAT_B8G8R8A8_UNORM,
            vulkan.VK_FORMAT_R8G8B8A8_SRGB => vulkan.VK_FORMAT_R8G8B8A8_UNORM,
            vulkan.VK_FORMAT_B8G8R8A8_UNORM => vulkan.VK_FORMAT_B8G8R8A8_UNORM,
            vulkan.VK_FORMAT_R8G8B8A8_UNORM => vulkan.VK_FORMAT_R8G8B8A8_UNORM,
            vulkan.VK_FORMAT_A8B8G8R8_SRGB_PACK32 => vulkan.VK_FORMAT_A8B8G8R8_UNORM_PACK32,
            vulkan.VK_FORMAT_A8B8G8R8_UNORM_PACK32 => vulkan.VK_FORMAT_A8B8G8R8_UNORM_PACK32,
            else => unreachable,
        };
    }

    pub fn create(
        physical_device: vulkan.VkPhysicalDevice,
        device: vulkan.VkDevice,
        queue_family_index: u32,
        surface: vulkan.VkSurfaceKHR,
        w: u32,
        h: u32,
    ) !Swapchain {
        var out: Swapchain = undefined;

        const capabilites, const format, const colorspace = try get_infos(physical_device, queue_family_index, surface);

        const actual_w = std.math.clamp(w, capabilites.minImageExtent.width, capabilites.maxImageExtent.width);
        const actual_h = std.math.clamp(h, capabilites.minImageExtent.height, capabilites.maxImageExtent.height);

        const swapchain = try create_swapchain(device, surface, actual_w, actual_h, format, colorspace, null);
        errdefer vulkan.vkDestroySwapchainKHR.?(device, swapchain, null);

        var count: u32 = 3;
        var images: [3]vulkan.VkImage = undefined;
        const result = vulkan.vkGetSwapchainImagesKHR.?(device, swapchain, &count, &images);
        if (result != vulkan.VK_SUCCESS and result != vulkan.VK_INCOMPLETE) {
            std.debug.print("failed to get swapchain images: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_get_swapchain_images;
        }

        out.swapchain = swapchain;

        out.view_format = Swapchain.unorm_format(format);

        for (0..out.images.len) |i| {
            out.images[i] = .{
                .w = actual_w,
                .h = actual_h,
                .memory = null,
                .image = images[i],
                .image_view = try utils.create_image_view(images[i], device, out.view_format),
                .copy_img_src_descriptor_set = null,
                .last_op = .none,
                .staging_buffer_memory = null,
                .staging_buffer = null,
                .pixels = null,
            };
            errdefer {
                vulkan.vkDestroyImageView.?(device, out.images[i].image_view, null);
            }
        }

        out.img_format = format;

        out.semaphores = try SemaphoreClub(4).create(device);
        errdefer out.semaphores.destroy(device);

        return out;
    }

    // pub fn recreate() Swapchain {}

    pub fn destroy(swapchain: *Swapchain, device: vulkan.VkDevice) void {
        for (swapchain.images) |img| {
            vulkan.vkDestroyImageView.?(device, img.image_view, null);
        }
        swapchain.semaphores.destroy(device);
        vulkan.vkDestroySwapchainKHR.?(device, swapchain.swapchain, null);
    }

    pub fn present(swapchain: *Swapchain, app: *root.PicturaApp) !void {
        _ = try app.well.submit(app.device, app.queue, null, null, null, null); // we dont want all the previous work to wait for image acquired, so submit it right away

        var image_acquired: vulkan.VkSemaphore = undefined;
        const ready = try swapchain.semaphores.if_ready_get_image_acquired_semaphore(app.device, &image_acquired);

        if (!ready) {
            return;
        }

        var image_index: u32 = 0;
        const acquire_image_success = vulkan.vkAcquireNextImageKHR.?(app.device, swapchain.swapchain, 0, image_acquired, null, &image_index);

        switch (acquire_image_success) {
            vulkan.VK_SUCCESS => {},
            vulkan.VK_SUBOPTIMAL_KHR => {
                swapchain.request_recreation = true;
            },
            vulkan.VK_TIMEOUT => {
                return;
            },
            vulkan.VK_ERROR_OUT_OF_DATE_KHR => {
                // If VK_ERROR_OUT_OF_DATE_KHR is returned, no image is acquired...
                // Applications need to create a new swapchain for the surface to continue presenting if VK_ERROR_OUT_OF_DATE_KHR is returned.
                swapchain.request_recreation = true;
                return;
            },
            else => {
                std.debug.print("acquire image: {s}\n", .{vulkan.string_VkResult(acquire_image_success)});
                return error.failed_to_acquire_image;
            },
        }

        // otherwise, we are presenting!

        swapchain.semaphores.using_image_index(image_index);

        try image.copy_img(
            &swapchain.images[image_index],
            &app.canvas,
            app.pipelines.swapchain_copy_img_pipeline,
            app,
        );

        const command_buffer = try app.well.record(app.device);
        var swapchain_barrier = utils.get_image_memory_barrier(&swapchain.images[image_index], .present, app.queue_family_index);

        utils.submit_image_memory_barrier(command_buffer, &swapchain_barrier);

        var ready_to_present = swapchain.semaphores.get_ready_to_present_semaphore();

        try app.well.submit(
            app.device,
            app.queue,
            image_acquired,
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

        switch (result) {
            vulkan.VK_SUCCESS => {},
            vulkan.VK_SUBOPTIMAL_KHR, vulkan.VK_ERROR_OUT_OF_DATE_KHR => {
                swapchain.request_recreation = true;
            },
            else => {
                std.debug.print("failed to present: {s}\n", .{vulkan.string_VkResult(result)});
                return error.Vk_failed_to_present;
            },
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
                errdefer vulkan.vkDestroySemaphore.?(device, out.image_acquired[i], null);

                out.fences[i] = try utils.create_fence(device, vulkan.VK_FENCE_CREATE_SIGNALED_BIT);
                errdefer vulkan.vkDestroyFence.?(device, out.fences[i], null);

                out.used_by_image_index[i] = -1;

                out.ready_to_present[i] = try utils.create_semaphore(device);
                errdefer vulkan.vkDestroySemaphore.?(device, out.ready_to_present[i], null);
            }

            return out;
        }

        pub fn destroy(sems: *SemaphoreClub(n), device: vulkan.VkDevice) void {
            for (0..n) |i| {
                vulkan.vkDestroySemaphore.?(device, sems.image_acquired[i], null);
                vulkan.vkDestroySemaphore.?(device, sems.ready_to_present[i], null);
                vulkan.vkDestroyFence.?(device, sems.fences[i], null);
            }
        }

        pub fn if_ready_get_image_acquired_semaphore(sems: *SemaphoreClub(n), device: vulkan.VkDevice, sm: *vulkan.VkSemaphore) !bool {
            for (0..n) |i| {
                if (sems.used_by_image_index[i] == -1) {
                    var result = vulkan.vkGetFenceStatus.?(device, sems.fences[i]);
                    if (result == vulkan.VK_NOT_READY) {
                        return false;
                    }

                    result = vulkan.vkResetFences.?(device, 1, &sems.fences[i]);
                    if (result != vulkan.VK_SUCCESS) {
                        std.debug.print("failed to reset fence: {s}\n", .{vulkan.string_VkResult(result)});
                        return error.Vk_failed_to_reset_fence;
                    }

                    sems.last_image_acquired_semaphore_index = @intCast(i);
                    sm.* = sems.image_acquired[i];

                    return true;
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
            // std.debug.print("[{d}] {d} {d} {d} {d}\n", .{ idx, sems.used_by_image_index[0], sems.used_by_image_index[1], sems.used_by_image_index[2], sems.used_by_image_index[3] });
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
    var formats_buf: [20]vulkan.VkSurfaceFormatKHR = undefined;

    result = vulkan.vkGetPhysicalDeviceSurfaceFormatsKHR.?(physical_device, surface, &nr_formats, null);
    std.debug.assert(20 > nr_formats);
    result = vulkan.vkGetPhysicalDeviceSurfaceFormatsKHR.?(physical_device, surface, &nr_formats, &formats_buf);

    const formats = formats_buf[0..nr_formats];
    var final_format: ?vulkan.VkFormat = null;

    outer: for ([6]vulkan.VkFormat{
        vulkan.VK_FORMAT_B8G8R8A8_SRGB,
        vulkan.VK_FORMAT_R8G8B8A8_SRGB,
        vulkan.VK_FORMAT_A8B8G8R8_SRGB_PACK32,
        vulkan.VK_FORMAT_B8G8R8A8_UNORM,
        vulkan.VK_FORMAT_R8G8B8A8_UNORM,
        vulkan.VK_FORMAT_A8B8G8R8_UNORM_PACK32,
    }) |target_format| {
        for (formats) |available_format| {
            if (target_format == available_format.format) {
                final_format = available_format.format;
                break :outer;
            }
        }
    }

    if (final_format == null) {
        return error.format_not_supported;
    }

    return .{ capabilities, final_format.?, formats[0].colorSpace };
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
    const view_format = Swapchain.unorm_format(format);

    const view_formats = [2]vulkan.VkFormat{ format, view_format };

    const view_format_list: vulkan.VkImageFormatListCreateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_FORMAT_LIST_CREATE_INFO,
        .pNext = null,
        .viewFormatCount = 2,
        .pViewFormats = &view_formats,
    };

    const info: vulkan.VkSwapchainCreateInfoKHR = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .pNext = &view_format_list,
        .flags = vulkan.VK_SWAPCHAIN_CREATE_MUTABLE_FORMAT_BIT_KHR,
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
