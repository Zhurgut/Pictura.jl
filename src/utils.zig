const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");
const vulkan = root.vulkan;

pub fn create_semaphore(device: vulkan.VkDevice) !vulkan.VkSemaphore {
    const info: vulkan.VkSemaphoreCreateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
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

pub fn create_fence(device: vulkan.VkDevice, flags: vulkan.VkFenceCreateFlags) !vulkan.VkFence {
    var fence: vulkan.VkFence = undefined;
    const info: vulkan.VkFenceCreateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .pNext = null,
        .flags = flags,
    };
    const result = vulkan.vkCreateFence.?(device, &info, null, &fence);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create fence: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_fence;
    }
    return fence;
}

pub fn create_command_pool(device: vulkan.VkDevice, queue_family_index: u32) !vulkan.VkCommandPool {
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

pub fn get_device_memory_index(physical_device: vulkan.VkPhysicalDevice) usize {
    var properties: vulkan.VkPhysicalDeviceMemoryProperties = undefined;
    vulkan.vkGetPhysicalDeviceMemoryProperties.?(physical_device, &properties);
    for (properties.memoryTypes[0..properties.memoryTypeCount]) |m| {
        std.debug.print("{d} heap: {d}\n", .{ m.propertyFlags, m.heapIndex });
    }
    return 0;
}

pub fn create_image(device: vulkan.VkDevice, w: u32, h: u32, queue_family_index: u32, format: vulkan.VkFormat) !vulkan.VkImage {
    var info: vulkan.VkImageCreateInfo = std.mem.zeroes(vulkan.VkImageCreateInfo);
    info.sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    info.imageType = vulkan.VK_IMAGE_TYPE_2D;
    info.format = format;
    info.extent = .{ .width = w, .height = h, .depth = 1 };
    info.mipLevels = 1;
    info.arrayLayers = 1;
    info.samples = vulkan.VK_SAMPLE_COUNT_1_BIT;
    info.tiling = vulkan.VK_IMAGE_TILING_OPTIMAL;
    info.usage = vulkan.VK_IMAGE_USAGE_TRANSFER_SRC_BIT | vulkan.VK_IMAGE_USAGE_TRANSFER_DST_BIT | vulkan.VK_IMAGE_USAGE_SAMPLED_BIT | vulkan.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | vulkan.VK_IMAGE_USAGE_STORAGE_BIT;
    info.sharingMode = vulkan.VK_SHARING_MODE_EXCLUSIVE;
    info.queueFamilyIndexCount = 1;
    info.pQueueFamilyIndices = &queue_family_index;
    info.initialLayout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED;

    var image: vulkan.VkImage = undefined;
    const result = vulkan.vkCreateImage.?(device, &info, null, &image);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create image: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_image;
    }

    return image;
}

pub fn bind_image_memory(device: vulkan.VkDevice, image: vulkan.VkImage, mem_type_index: u32) !vulkan.VkDeviceMemory {
    var requirements: vulkan.VkMemoryRequirements = undefined;
    vulkan.vkGetImageMemoryRequirements.?(device, image, &requirements);

    const alloc_info: vulkan.VkMemoryAllocateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = requirements.size,
        .memoryTypeIndex = mem_type_index,
    };

    var memory: vulkan.VkDeviceMemory = undefined;
    var result = vulkan.vkAllocateMemory.?(device, &alloc_info, null, &memory);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to allocate memory for image: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_allocate_memory_for_image;
    }
    errdefer vulkan.vkFreeMemory.?(device, memory, null);

    result = vulkan.vkBindImageMemory.?(device, image, memory, 0);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to bind image memory: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_bind_image_memory;
    }

    return memory;
}

pub fn create_image_view(image: vulkan.VkImage, device: vulkan.VkDevice, format: vulkan.VkFormat) !vulkan.VkImageView {
    var info: vulkan.VkImageViewCreateInfo = std.mem.zeroes(vulkan.VkImageViewCreateInfo);
    info.sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    info.image = image;
    info.viewType = vulkan.VK_IMAGE_VIEW_TYPE_2D;
    info.format = format;
    info.components = .{
        .r = vulkan.VK_COMPONENT_SWIZZLE_IDENTITY,
        .g = vulkan.VK_COMPONENT_SWIZZLE_IDENTITY,
        .b = vulkan.VK_COMPONENT_SWIZZLE_IDENTITY,
        .a = vulkan.VK_COMPONENT_SWIZZLE_IDENTITY,
    };
    info.subresourceRange = .{
        .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
        .baseMipLevel = 0,
        .levelCount = 1,
        .baseArrayLayer = 0,
        .layerCount = 1,
    };

    var image_view: vulkan.VkImageView = undefined;
    const result = vulkan.vkCreateImageView.?(device, &info, null, &image_view);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create image view: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_image_view;
    }

    return image_view;
}

pub fn queue_submit_2(
    queue: vulkan.VkQueue,
    command_buffer: vulkan.VkCommandBuffer,
    comptime w: usize,
    wait_semaphores: [w]vulkan.VkSemaphore,
    wait_stages: [w]vulkan.VkPipelineStageFlags2,
    comptime s: usize,
    signal_semaphores: [s]vulkan.VkSemaphore,
    signal_stages: [s]vulkan.VkPipelineStageFlags2,
    fence: vulkan.VkFence,
) !void {
    const command_buffer_info: vulkan.VkCommandBufferSubmitInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
        .pNext = null,
        .commandBuffer = command_buffer,
        .deviceMask = 0,
    };

    var submit_info = std.mem.zeroes(vulkan.VkSubmitInfo2);
    submit_info.sType = vulkan.VK_STRUCTURE_TYPE_SUBMIT_INFO_2;
    submit_info.commandBufferInfoCount = 1;
    submit_info.pCommandBufferInfos = &command_buffer_info;

    var wait_semaphore_infos: [wait_semaphores.len]vulkan.VkSemaphoreSubmitInfo = undefined;
    for (0..wait_semaphores.len) |i| {
        wait_semaphore_infos[i] = std.mem.zeroes(vulkan.VkSemaphoreSubmitInfo);
        wait_semaphore_infos[i].sType = vulkan.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
        wait_semaphore_infos[i].semaphore = wait_semaphores[i];
        wait_semaphore_infos[i].stageMask = wait_stages[i];
    }

    submit_info.waitSemaphoreInfoCount = wait_semaphores.len;
    submit_info.pWaitSemaphoreInfos = &wait_semaphore_infos;

    var signal_semaphore_infos: [signal_semaphores.len]vulkan.VkSemaphoreSubmitInfo = undefined;
    for (0..signal_semaphores.len) |i| {
        signal_semaphore_infos[i] = std.mem.zeroes(vulkan.VkSemaphoreSubmitInfo);
        signal_semaphore_infos[i].sType = vulkan.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
        signal_semaphore_infos[i].semaphore = signal_semaphores[i];
        signal_semaphore_infos[i].stageMask = signal_stages[i];
    }

    submit_info.signalSemaphoreInfoCount = signal_semaphores.len;
    submit_info.pSignalSemaphoreInfos = &signal_semaphore_infos;

    const result = vulkan.vkQueueSubmit2.?(queue, 1, &submit_info, fence);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to submit to queue: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_submit_to_queue;
    }
}

pub fn wait_and_reset_fence(device: vulkan.VkDevice, pfence: *vulkan.VkFence) !void {
    var result = vulkan.vkWaitForFences.?(device, 1, pfence, 0, 5_000_000_000); // TODO std.math.maxInt(u64)
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to wait for fence: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_wait_for_fence;
    }

    result = vulkan.vkResetFences.?(device, 1, pfence);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to reset fence: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_reset_fence;
    }
}

pub fn image_memory_barrier(
    image: *root.image.PicturaImage,
    new_layout: vulkan.VkImageLayout,
    queue_family_index: u32,
    src_stage: vulkan.VkPipelineStageFlags2,
    src_access: vulkan.VkAccessFlags2,
    dst_stage: vulkan.VkPipelineStageFlags2,
    dst_access: vulkan.VkAccessFlags2,
) vulkan.VkImageMemoryBarrier2 {
    const old_layout = image.layout;
    const barrier: vulkan.VkImageMemoryBarrier2 = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
        .pNext = null,
        .srcStageMask = src_stage,
        .srcAccessMask = src_access,
        .dstStageMask = dst_stage,
        .dstAccessMask = dst_access,
        .oldLayout = old_layout,
        .newLayout = new_layout,
        .srcQueueFamilyIndex = queue_family_index,
        .dstQueueFamilyIndex = queue_family_index,
        .image = image.image,
        .subresourceRange = .{
            .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
    };
    image.layout = new_layout;

    return barrier;
}

// pub fn two_stage_graphics_pipeline() vulkan.
