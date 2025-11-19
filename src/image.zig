const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");
const vulkan = root.vulkan;
const utils = root.utils;

pub const PicturaImage = struct {
    w: u32,
    h: u32,
    memory: vulkan.VkDeviceMemory,
    image: vulkan.VkImage,
    layout: vulkan.VkImageLayout,
    image_view: vulkan.VkImageView,

    pub fn create(w: u32, h: u32, device: vulkan.VkDevice, queue_family_index: u32, memory_type_index: u32) !PicturaImage {
        const image = try utils.create_image(device, w, h, queue_family_index);
        errdefer vulkan.vkDestroyImage.?(device, image, null);

        const memory = try utils.bind_image_memory(device, image, memory_type_index);
        errdefer vulkan.vkFreeMemory.?(device, memory, null);

        const image_view = try utils.create_image_view(image, device);
        errdefer vulkan.vkDestroyImageView.?(device, image_view, null);

        return PicturaImage{
            .w = w,
            .h = h,
            .memory = memory,
            .image = image,
            .layout = vulkan.VK_IMAGE_LAYOUT_UNDEFINED,
            .image_view = image_view,
        };
    }

    pub fn destroy(pimage: *PicturaImage, device: vulkan.VkDevice) void {
        vulkan.vkDestroyImageView.?(device, pimage.image_view, null);
        vulkan.vkFreeMemory.?(device, pimage.memory, null);
        vulkan.vkDestroyImage.?(device, pimage.image, null);

        pimage.* = std.mem.zeroes(PicturaImage);
    }
};
