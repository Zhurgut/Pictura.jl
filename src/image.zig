const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");
const vulkan = root.vulkan;
const utils = root.utils;

pub const Op = enum {
    none,
    present,
    copy_src,
    draw_dst,
    load_pixels,
};

pub fn get_access_and_stage(op: Op) struct { vulkan.VkImageLayout, vulkan.VkPipelineStageFlags2, vulkan.VkAccessFlags2 } {
    return switch (op) {
        .none => .{ vulkan.VK_IMAGE_LAYOUT_UNDEFINED, vulkan.VK_PIPELINE_STAGE_2_NONE, vulkan.VK_ACCESS_2_NONE },
        .present => .{ vulkan.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, vulkan.VK_PIPELINE_STAGE_2_NONE, vulkan.VK_ACCESS_2_NONE },
        .copy_src => .{ vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, vulkan.VK_PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT, vulkan.VK_ACCESS_2_SHADER_SAMPLED_READ_BIT },
        .draw_dst => .{ vulkan.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, vulkan.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, vulkan.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT | vulkan.VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT },
        .load_pixels => .{ vulkan.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, vulkan.VK_PIPELINE_STAGE_TRANSFER_BIT, vulkan.VK_ACCESS_TRANSFER_READ_BIT },
    };
}

pub var format: vulkan.VkFormat = undefined; // the standart format for PicturaImages, set during init

pub const PicturaImage = struct {
    w: u32,
    h: u32,
    memory: ?vulkan.VkDeviceMemory,
    image: vulkan.VkImage,
    image_view: vulkan.VkImageView, // we always just need one view, we dont do anything fancy with these
    copy_img_src_descriptor_set: ?vulkan.VkDescriptorSet,
    last_op: Op,
    staging_buffer: ?vulkan.VkBuffer,
    staging_buffer_memory: ?vulkan.VkDeviceMemory,
    pixels: ?[*]u32, // ptr to pixels in host memory

    pub fn create(w: u32, h: u32, device: vulkan.VkDevice, queue_family_index: u32, memory_type_index: u32) !PicturaImage {
        const image = try utils.create_image(device, w, h, queue_family_index, format);
        errdefer vulkan.vkDestroyImage.?(device, image, null);

        const memory = try utils.bind_image_memory(device, image, memory_type_index);
        errdefer vulkan.vkFreeMemory.?(device, memory, null);

        const image_view = try utils.create_image_view(image, device, format);
        errdefer vulkan.vkDestroyImageView.?(device, image_view, null);

        return PicturaImage{
            .w = w,
            .h = h,
            .memory = memory,
            .image = image,
            .image_view = image_view,
            .copy_img_src_descriptor_set = null,
            .last_op = .none,
            .staging_buffer = null,
            .staging_buffer_memory = null,
            .pixels = null,
        };
    }

    pub fn get_copy_img_src_ds(
        pimage: *PicturaImage,
        device: vulkan.VkDevice,
        d_pool: vulkan.VkDescriptorPool,
        pipelines: *root.Pipelines,
    ) !vulkan.VkDescriptorSet {
        if (pimage.copy_img_src_descriptor_set) |set| {
            return set;
        }

        const info: vulkan.VkDescriptorSetAllocateInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .pNext = null,
            .descriptorPool = d_pool,
            .descriptorSetCount = 1,
            .pSetLayouts = &pipelines.copy_img_src_descriptor_set_layout,
        };
        var set: vulkan.VkDescriptorSet = undefined;
        const result = vulkan.vkAllocateDescriptorSets.?(device, &info, &set);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to allocate descriptor set: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_allocate_descriptor_set;
        }

        const image_info: vulkan.VkDescriptorImageInfo = .{
            .sampler = pipelines.copy_img_src_sampler,
            .imageView = pimage.image_view,
            .imageLayout = vulkan.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
        };

        var write_ds = std.mem.zeroes(vulkan.VkWriteDescriptorSet);
        write_ds.sType = vulkan.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
        write_ds.dstSet = set;
        write_ds.descriptorCount = 1;
        write_ds.descriptorType = vulkan.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
        write_ds.pImageInfo = &image_info;

        vulkan.vkUpdateDescriptorSets.?(device, 1, &write_ds, 0, null); // never update it again!

        pimage.copy_img_src_descriptor_set = set;

        return set;
    }

    pub fn get_staging_buffer(pimage: *PicturaImage, app: *root.PicturaApp) !struct { vulkan.VkDeviceMemory, vulkan.VkBuffer } {
        if (pimage.staging_buffer != null and pimage.staging_buffer_memory != null) {
            return .{ pimage.staging_buffer_memory.?, pimage.staging_buffer.? };
        }

        const info: vulkan.VkBufferCreateInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = pimage.w * pimage.h * 4,
            .usage = vulkan.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | vulkan.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            .sharingMode = vulkan.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 1,
            .pQueueFamilyIndices = &app.queue_family_index,
        };

        var buffer: vulkan.VkBuffer = undefined;

        var result = vulkan.vkCreateBuffer.?(app.device, &info, null, &buffer);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to create staging buffer: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_create_staging_buffer;
        }
        errdefer vulkan.vkDestroyBuffer.?(app.device, buffer, null);

        var requirements: vulkan.VkMemoryRequirements = undefined;
        vulkan.vkGetBufferMemoryRequirements.?(app.device, buffer, &requirements);

        const alloc_info: vulkan.VkMemoryAllocateInfo = .{
            .sType = vulkan.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = requirements.size,
            .memoryTypeIndex = try utils.get_RAM_memory_index(app.physical_device),
        };

        var memory: vulkan.VkDeviceMemory = undefined;
        result = vulkan.vkAllocateMemory.?(app.device, &alloc_info, null, &memory);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to allocate memory for staging buffer: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_allocate_memory_for_buffer;
        }
        errdefer vulkan.vkFreeMemory.?(app.device, memory, null);

        result = vulkan.vkBindBufferMemory.?(app.device, buffer, memory, 0);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to bind buffer memory: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_bind_buffer_memory;
        }

        pimage.staging_buffer_memory = memory;
        pimage.staging_buffer = buffer;

        return .{ memory, buffer };
    }

    pub fn destroy(pimage: *PicturaImage, device: vulkan.VkDevice, descriptor_pool: vulkan.VkDescriptorPool) void {
        if (pimage.staging_buffer_memory) |mem| {
            pimage.pixels = null;
            vulkan.vkUnmapMemory.?(device, mem);
            vulkan.vkFreeMemory.?(device, mem, null);
        }
        if (pimage.staging_buffer) |buf| {
            vulkan.vkDestroyBuffer.?(device, buf, null);
        }

        if (pimage.copy_img_src_descriptor_set) |ds| {
            const result = vulkan.vkFreeDescriptorSets.?(device, descriptor_pool, 1, &ds);

            if (result != vulkan.VK_SUCCESS) {
                std.debug.print("failed to free descriptorset: {s}\n", .{vulkan.string_VkResult(result)});
                // dont return an error here, this should never happen
            }
        }

        pimage.pixels = null;
        pimage.staging_buffer_memory = null;
        pimage.staging_buffer = null;
        pimage.copy_img_src_descriptor_set = null;

        vulkan.vkDestroyImageView.?(device, pimage.image_view, null);
        if (pimage.memory) |mem| {
            vulkan.vkFreeMemory.?(device, mem, null);
        }

        vulkan.vkDestroyImage.?(device, pimage.image, null);

        pimage.* = std.mem.zeroes(PicturaImage);
    }
};

pub fn copy_img(dst: *PicturaImage, src: *PicturaImage, pipeline: vulkan.VkPipeline, app: *root.PicturaApp) !void {
    var command_buffer = try app.well.record(app.device);

    var src_barrier = utils.get_image_memory_barrier(src, .copy_src, app.queue_family_index);
    utils.submit_image_memory_barrier(command_buffer, &src_barrier);

    var dst_barrier = utils.get_image_memory_barrier(dst, .draw_dst, app.queue_family_index);
    command_buffer = try app.well.render_into(dst, &dst_barrier, app.device);

    const w = dst.w;
    const h = dst.h;
    const viewport: vulkan.VkViewport = .{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(w),
        .height = @floatFromInt(h),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    const scissor: vulkan.VkRect2D = .{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{ .width = w, .height = h },
    };

    vulkan.vkCmdSetViewport.?(command_buffer, 0, 1, &viewport);
    vulkan.vkCmdSetScissor.?(command_buffer, 0, 1, &scissor);

    vulkan.vkCmdBindPipeline.?(command_buffer, vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);

    var descriptor_set = try src.get_copy_img_src_ds(
        app.device,
        app.descriptor_pool,
        &app.pipelines,
    );

    vulkan.vkCmdBindDescriptorSets.?(
        command_buffer,
        vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS,
        app.pipelines.copy_img_pipeline_layout,
        0,
        1,
        &descriptor_set,
        0,
        null,
    );

    vulkan.vkCmdDraw.?(command_buffer, 3, 1, 0, 0);
}

pub fn draw_background(dst: *PicturaImage, r: f32, g: f32, b: f32, a: f32, app: *root.PicturaApp) !void {
    const color = [4]f32{ r, g, b, a };

    var barrier = utils.get_image_memory_barrier(dst, .draw_dst, app.queue_family_index);
    const command_buffer = try app.well.render_into(dst, &barrier, app.device);

    const w = dst.w;
    const h = dst.h;
    const viewport: vulkan.VkViewport = .{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(w),
        .height = @floatFromInt(h),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    const scissor: vulkan.VkRect2D = .{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{ .width = w, .height = h },
    };

    vulkan.vkCmdSetViewport.?(command_buffer, 0, 1, &viewport);
    vulkan.vkCmdSetScissor.?(command_buffer, 0, 1, &scissor);

    vulkan.vkCmdBindPipeline.?(command_buffer, vulkan.VK_PIPELINE_BIND_POINT_GRAPHICS, app.pipelines.draw_background_pipeline);
    vulkan.vkCmdPushConstants.?(command_buffer, app.pipelines.draw_background_pipeline_layout, vulkan.VK_SHADER_STAGE_FRAGMENT_BIT, 0, @sizeOf(@TypeOf(color)), &color);

    vulkan.vkCmdDraw.?(command_buffer, 3, 1, 0, 0);
}

pub fn load_pixels(pimage: *PicturaImage, app: *root.PicturaApp) ![*]u32 {
    const command_buffer = try app.well.record(app.device);

    var barrier = utils.get_image_memory_barrier(pimage, .load_pixels, app.queue_family_index);
    utils.submit_image_memory_barrier(command_buffer, &barrier);

    const memory, const staging_buffer = try pimage.get_staging_buffer(app);

    var region = std.mem.zeroes(vulkan.VkBufferImageCopy2);
    region.sType = vulkan.VK_STRUCTURE_TYPE_BUFFER_IMAGE_COPY_2;
    region.imageSubresource = .{
        .aspectMask = vulkan.VK_IMAGE_ASPECT_COLOR_BIT,
        .mipLevel = 0,
        .baseArrayLayer = 0,
        .layerCount = 1,
    };
    region.imageExtent = .{
        .width = pimage.w,
        .height = pimage.h,
        .depth = 1,
    };

    const copy_info: vulkan.VkCopyImageToBufferInfo2 = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_COPY_IMAGE_TO_BUFFER_INFO_2,
        .pNext = null,
        .srcImage = pimage.image,
        .srcImageLayout = vulkan.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        .dstBuffer = staging_buffer,
        .regionCount = 1,
        .pRegions = &region,
    };

    vulkan.vkCmdCopyImageToBuffer2.?(command_buffer, &copy_info);

    try app.well.wait(app.device, app.queue);

    if (pimage.pixels == null) {
        var data_ptr: ?*anyopaque = null;

        const result = vulkan.vkMapMemory.?(app.device, memory, 0, pimage.w * pimage.h * 4, 0, &data_ptr);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to map memory: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_map_memory;
        }

        pimage.pixels = @ptrCast(@alignCast(data_ptr));
    }

    return pimage.pixels.?;
}
