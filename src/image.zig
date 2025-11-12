const std = @import("std");
const testing = std.testing;

const vulkan = @cImport({
    @cInclude("src/init_vulkan.h");
});

const ImageState = enum {
    reset,
    recording,
    rendering,
};

fn create_image(device: vulkan.VkDevice, w: u32, h: u32, queue_family_index: u32) !vulkan.VkImage {
    var info: vulkan.VkImageCreateInfo = std.mem.zeroes(vulkan.VkImageCreateInfo);
    info.sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    info.imageType = vulkan.VK_IMAGE_TYPE_2D;
    info.format = vulkan.VK_FORMAT_R8G8B8A8_UNORM; // TODO remove hardcoding...
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

fn bind_image_memory(device: vulkan.VkDevice, image: vulkan.VkImage, mem_type_index: u32) !vulkan.VkDeviceMemory {
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

fn create_image_view(image: vulkan.VkImage, device: vulkan.VkDevice) !vulkan.VkImageView {
    var info: vulkan.VkImageViewCreateInfo = std.mem.zeroes(vulkan.VkImageViewCreateInfo);
    info.sType = vulkan.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    info.image = image;
    info.viewType = vulkan.VK_IMAGE_VIEW_TYPE_2D;
    info.format = vulkan.VK_FORMAT_R8G8B8A8_UNORM;
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

fn create_command_buffer(device: vulkan.VkDevice, command_pool: vulkan.VkCommandPool) !vulkan.VkCommandBuffer {
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

pub const PicturaImage = struct {
    state: ImageState,
    memory: vulkan.VkDeviceMemory,
    image: vulkan.VkImage,
    image_view: vulkan.VkImageView,
    command_buffer: vulkan.VkCommandBuffer,

    pub fn create(w: u32, h: u32, device: vulkan.VkDevice, queue_family_index: u32, command_pool: vulkan.VkCommandPool, memory_type_index: u32) !PicturaImage {
        const image = try create_image(device, w, h, queue_family_index);
        errdefer vulkan.vkDestroyImage.?(device, image, null);

        const memory = try bind_image_memory(device, image, memory_type_index);
        errdefer vulkan.vkFreeMemory.?(device, memory, null);

        const image_view = try create_image_view(image, device);
        errdefer vulkan.vkDestroyImageView.?(device, image_view, null);

        const command_buffer = try create_command_buffer(device, command_pool);

        return PicturaImage{
            .state = .reset,
            .image = image,
            .memory = memory,
            .image_view = image_view,
            .command_buffer = command_buffer,
        };
    }

    pub fn destroy(pimage: *PicturaImage, device: vulkan.VkDevice, command_pool: vulkan.VkCommandPool) void {
        vulkan.vkFreeCommandBuffers.?(device, command_pool, 1, &(pimage.command_buffer));
        vulkan.vkDestroyImageView.?(device, pimage.image_view, null);
        vulkan.vkFreeMemory.?(device, pimage.memory, null);
        vulkan.vkDestroyImage.?(device, pimage.image, null);

        pimage.* = std.mem.zeroes(PicturaImage);
    }
};
