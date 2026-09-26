const std = @import("std");
const testing = std.testing;

const root = @import("../root.zig");
const vulkan = root.vulkan;
const shaders = root.shaders;

const Allocator = std.mem.Allocator;

pub fn get_device_extensions(allocator: Allocator, physical_device: vulkan.c.VkPhysicalDevice) ![]const [:0]const u8 {
    var nr_extensions: u32 = 0;
    var result = vulkan.c.vkEnumerateDeviceExtensionProperties.?(physical_device, null, &nr_extensions, null);

    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to enumerate device extensions (1): {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_enumerate_dev_exts;
    }
    root.logger.info("{d} device extensions available", .{nr_extensions});

    const dev_extensions = try allocator.alloc(vulkan.c.VkExtensionProperties, nr_extensions);

    result = vulkan.c.vkEnumerateDeviceExtensionProperties.?(physical_device, null, &nr_extensions, dev_extensions.ptr);

    if (result != vulkan.c.VK_SUCCESS and result != vulkan.c.VK_INCOMPLETE) {
        std.debug.print("failed to enumerate device extensions (2): {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_enumerate_dev_exts;
    }

    const extension_names = try allocator.alloc([:0]const u8, nr_extensions);

    for (dev_extensions, 0..) |_, i| {
        const name: [:0]const u8 = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(&dev_extensions[i].extensionName)), 0);
        extension_names[i] = name;
        // root.logger.info("   {s}{*}", .{ extension_names[i], name.ptr });
    }

    return extension_names;
}

pub fn has_extension(extensions: []const [:0]const u8, target_ext: [:0]const u8) bool {
    for (extensions) |ext| {
        if (std.mem.eql(u8, ext, target_ext)) {
            return true;
        }
    }
    return false;
}

pub fn create_semaphore(device: vulkan.c.VkDevice) !vulkan.c.VkSemaphore {
    const info: vulkan.c.VkSemaphoreCreateInfo = .{
        .sType = vulkan.c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };

    var semaphore: vulkan.c.VkSemaphore = undefined;
    const result = vulkan.c.vkCreateSemaphore.?(device, &info, null, &semaphore);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to create semaphore: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_create_semaphore;
    }

    root.logger.log_creation(semaphore);
    return semaphore;
}

pub fn create_fence(device: vulkan.c.VkDevice, flags: vulkan.c.VkFenceCreateFlags) !vulkan.c.VkFence {
    var fence: vulkan.c.VkFence = undefined;
    const info: vulkan.c.VkFenceCreateInfo = .{
        .sType = vulkan.c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .pNext = null,
        .flags = flags,
    };
    const result = vulkan.c.vkCreateFence.?(device, &info, null, &fence);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to create fence: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_create_fence;
    }

    root.logger.log_creation(fence);
    return fence;
}

pub fn create_command_pool(device: vulkan.c.VkDevice, queue_family_index: u32) !vulkan.c.VkCommandPool {
    var info = std.mem.zeroes(vulkan.c.VkCommandPoolCreateInfo);
    info.sType = vulkan.c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    info.flags = vulkan.c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    info.queueFamilyIndex = queue_family_index;

    var command_pool: vulkan.c.VkCommandPool = undefined;
    const result = vulkan.c.vkCreateCommandPool.?(device, &info, null, &command_pool);

    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to create command pool: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_create_command_pool;
    }

    return command_pool;
}

pub fn create_command_buffer(device: vulkan.c.VkDevice, command_pool: vulkan.c.VkCommandPool) !vulkan.c.VkCommandBuffer {
    const info: vulkan.c.VkCommandBufferAllocateInfo = .{
        .sType = vulkan.c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = null,
        .commandPool = command_pool,
        .level = vulkan.c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };

    var command_buffer: vulkan.c.VkCommandBuffer = undefined;
    const result = vulkan.c.vkAllocateCommandBuffers.?(device, &info, &command_buffer);

    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to allocate command buffer: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_allocate_command_buffer;
    }

    // root.logger.log("command_buffer [{?}]", .{command_buffer});
    return command_buffer;
}

pub fn get_device_memory_index(physical_device: vulkan.c.VkPhysicalDevice, req_bits: u32) !u32 {
    if (req_bits == 0) {
        return error.no_memory_type_can_fulfill_your_wish; // ??? wtf
    }

    var b = req_bits;
    var properties: vulkan.c.VkPhysicalDeviceMemoryProperties = undefined;
    vulkan.c.vkGetPhysicalDeviceMemoryProperties.?(physical_device, &properties);

    for (properties.memoryTypes[0..properties.memoryTypeCount], 0..) |mem_type, i| {
        if (b == 0) {
            break;
        }

        if (((b & 0x1) != 0) and mem_type.propertyFlags == vulkan.c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) {
            return @intCast(i);
        }
        b = b >> 1;
    }

    b = req_bits;
    for (properties.memoryTypes[0..properties.memoryTypeCount], 0..) |mem_type, i| {
        if (b == 0) {
            break;
        }
        if (((b & 0x1) != 0) and (mem_type.propertyFlags & vulkan.c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) != 0) {
            return @intCast(i);
        }
        b = b >> 1;
    }

    std.debug.print("didnt find device local memory for image\n", .{});

    b = req_bits;
    for (properties.memoryTypes[0..properties.memoryTypeCount], 0..) |_, i| {
        if (b == 0) {
            break;
        }
        if (((b & 0x1) != 0)) {
            return @intCast(i);
        }
        b = b >> 1;
    }

    return error.no_mem_type_found;
}

pub fn get_RAM_memory_index(physical_device: vulkan.c.VkPhysicalDevice, req_bits: u32) !u32 {
    var b = req_bits;

    var properties: vulkan.c.VkPhysicalDeviceMemoryProperties = undefined;
    vulkan.c.vkGetPhysicalDeviceMemoryProperties.?(physical_device, &properties);
    const desired = vulkan.c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vulkan.c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
    const undesired = vulkan.c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

    for (properties.memoryTypes[0..properties.memoryTypeCount], 0..) |mem_type, i| {
        if (b == 0) {
            break;
        }
        if (((b & 0x1) != 0) and
            mem_type.propertyFlags & desired == desired and
            mem_type.propertyFlags & undesired == 0)
        {
            return @intCast(i);
        }
        b = b >> 1;
    }

    for (properties.memoryTypes[0..properties.memoryTypeCount], 0..) |mem_type, i| {
        if (b == 0) {
            break;
        }
        // host visible required
        if (((b & 0x1) != 0) and mem_type.propertyFlags & vulkan.c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT != 0) {
            return @intCast(i);
        }
        b = b >> 1;
    }

    return error.no_mem_type_found;
}

pub fn create_image(device: vulkan.c.VkDevice, w: u32, h: u32, queue_family_index: u32, format: vulkan.c.VkFormat) !vulkan.c.VkImage {
    var info: vulkan.c.VkImageCreateInfo = std.mem.zeroes(vulkan.c.VkImageCreateInfo);
    info.sType = vulkan.c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    info.flags = vulkan.c.VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT;
    info.imageType = vulkan.c.VK_IMAGE_TYPE_2D;
    info.format = format;
    info.extent = .{ .width = w, .height = h, .depth = 1 };
    info.mipLevels = 1;
    info.arrayLayers = 1;
    info.samples = vulkan.c.VK_SAMPLE_COUNT_1_BIT;
    info.tiling = vulkan.c.VK_IMAGE_TILING_OPTIMAL;
    info.usage = vulkan.c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT | vulkan.c.VK_IMAGE_USAGE_TRANSFER_DST_BIT | vulkan.c.VK_IMAGE_USAGE_SAMPLED_BIT | vulkan.c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | vulkan.c.VK_IMAGE_USAGE_STORAGE_BIT;
    info.sharingMode = vulkan.c.VK_SHARING_MODE_EXCLUSIVE;
    info.queueFamilyIndexCount = 1;
    info.pQueueFamilyIndices = &queue_family_index;
    info.initialLayout = vulkan.c.VK_IMAGE_LAYOUT_UNDEFINED;

    var image: vulkan.c.VkImage = undefined;
    const result = vulkan.c.vkCreateImage.?(device, &info, null, &image);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to create image: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_create_image;
    }

    root.logger.log_creation(image);
    return image;
}

pub fn bind_image_memory(device: vulkan.c.VkDevice, image: vulkan.c.VkImage, physical_device: vulkan.c.VkPhysicalDevice) !vulkan.c.VkDeviceMemory {
    var requirements: vulkan.c.VkMemoryRequirements = undefined;
    vulkan.c.vkGetImageMemoryRequirements.?(device, image, &requirements);

    const mem_type_index = try get_device_memory_index(physical_device, requirements.memoryTypeBits);

    const alloc_info: vulkan.c.VkMemoryAllocateInfo = .{
        .sType = vulkan.c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = requirements.size,
        .memoryTypeIndex = mem_type_index,
    };

    var memory: vulkan.c.VkDeviceMemory = undefined;
    var result = vulkan.c.vkAllocateMemory.?(device, &alloc_info, null, &memory);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to allocate memory for image: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_allocate_memory_for_image;
    }
    errdefer vulkan.c.vkFreeMemory.?(device, memory, null);

    result = vulkan.c.vkBindImageMemory.?(device, image, memory, 0);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to bind image memory: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_bind_image_memory;
    }

    root.logger.log_creation(memory);
    return memory;
}

pub fn create_image_view(image: vulkan.c.VkImage, device: vulkan.c.VkDevice, format: vulkan.c.VkFormat) !vulkan.c.VkImageView {
    var info: vulkan.c.VkImageViewCreateInfo = std.mem.zeroes(vulkan.c.VkImageViewCreateInfo);
    info.sType = vulkan.c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    info.image = image;
    info.viewType = vulkan.c.VK_IMAGE_VIEW_TYPE_2D;
    info.format = format;
    info.components = .{
        .r = vulkan.c.VK_COMPONENT_SWIZZLE_IDENTITY,
        .g = vulkan.c.VK_COMPONENT_SWIZZLE_IDENTITY,
        .b = vulkan.c.VK_COMPONENT_SWIZZLE_IDENTITY,
        .a = vulkan.c.VK_COMPONENT_SWIZZLE_IDENTITY,
    };
    info.subresourceRange = .{
        .aspectMask = vulkan.c.VK_IMAGE_ASPECT_COLOR_BIT,
        .baseMipLevel = 0,
        .levelCount = 1,
        .baseArrayLayer = 0,
        .layerCount = 1,
    };

    var image_view: vulkan.c.VkImageView = undefined;
    const result = vulkan.c.vkCreateImageView.?(device, &info, null, &image_view);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to create image view: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_create_image_view;
    }

    root.logger.log_creation(image_view);
    return image_view;
}

pub fn queue_submit_2(
    queue: vulkan.c.VkQueue,
    command_buffer: vulkan.c.VkCommandBuffer,
    comptime w: usize,
    wait_semaphores: [w]vulkan.c.VkSemaphore,
    wait_stages: [w]vulkan.c.VkPipelineStageFlags2,
    comptime s: usize,
    signal_semaphores: [s]vulkan.c.VkSemaphore,
    signal_stages: [s]vulkan.c.VkPipelineStageFlags2,
    fence: vulkan.c.VkFence,
) !void {
    const command_buffer_info: vulkan.c.VkCommandBufferSubmitInfo = .{
        .sType = vulkan.c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO,
        .pNext = null,
        .commandBuffer = command_buffer,
        .deviceMask = 0,
    };

    var submit_info = std.mem.zeroes(vulkan.c.VkSubmitInfo2);
    submit_info.sType = vulkan.c.VK_STRUCTURE_TYPE_SUBMIT_INFO_2;
    submit_info.commandBufferInfoCount = 1;
    submit_info.pCommandBufferInfos = &command_buffer_info;

    var wait_semaphore_infos: [wait_semaphores.len]vulkan.c.VkSemaphoreSubmitInfo = undefined;
    for (0..wait_semaphores.len) |i| {
        wait_semaphore_infos[i] = std.mem.zeroes(vulkan.c.VkSemaphoreSubmitInfo);
        wait_semaphore_infos[i].sType = vulkan.c.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
        wait_semaphore_infos[i].semaphore = wait_semaphores[i];
        wait_semaphore_infos[i].stageMask = wait_stages[i];
    }

    submit_info.waitSemaphoreInfoCount = wait_semaphores.len;
    submit_info.pWaitSemaphoreInfos = &wait_semaphore_infos;

    var signal_semaphore_infos: [signal_semaphores.len]vulkan.c.VkSemaphoreSubmitInfo = undefined;
    for (0..signal_semaphores.len) |i| {
        signal_semaphore_infos[i] = std.mem.zeroes(vulkan.c.VkSemaphoreSubmitInfo);
        signal_semaphore_infos[i].sType = vulkan.c.VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
        signal_semaphore_infos[i].semaphore = signal_semaphores[i];
        signal_semaphore_infos[i].stageMask = signal_stages[i];
    }

    submit_info.signalSemaphoreInfoCount = signal_semaphores.len;
    submit_info.pSignalSemaphoreInfos = &signal_semaphore_infos;

    const result = vulkan.c.vkQueueSubmit2.?(queue, 1, &submit_info, fence);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to submit to queue: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_submit_to_queue;
    }
}

pub fn wait_and_reset_fence(device: vulkan.c.VkDevice, pfence: *vulkan.c.VkFence) !void {
    var result = vulkan.c.vkWaitForFences.?(device, 1, pfence, 0, 5_000_000_000); // TODO std.math.maxInt(u64)
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to wait for fence: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_wait_for_fence;
    }

    result = vulkan.c.vkResetFences.?(device, 1, pfence);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to reset fence: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_reset_fence;
    }
}

pub fn get_image_memory_barrier(image: *root.image.PicturaImage, next_op: root.image.Op, queue_family_index: u32) vulkan.c.VkImageMemoryBarrier2 {
    const old_layout, const src_stage, const src_access = root.image.get_access_and_stage(image.last_op);
    const new_layout, const dst_stage, const dst_access = root.image.get_access_and_stage(next_op);

    const barrier = image_memory_barrier(
        image,
        old_layout,
        new_layout,
        queue_family_index,
        src_stage,
        src_access,
        dst_stage,
        dst_access,
    );

    image.last_op = next_op;

    return barrier;
}

pub fn submit_image_memory_barrier(command_buffer: vulkan.c.VkCommandBuffer, barrier: *vulkan.c.VkImageMemoryBarrier2) void {
    var dep_info = std.mem.zeroes(vulkan.c.VkDependencyInfo);
    dep_info.sType = vulkan.c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
    dep_info.imageMemoryBarrierCount = 1;
    dep_info.pImageMemoryBarriers = barrier;

    vulkan.c.vkCmdPipelineBarrier2.?(command_buffer, &dep_info);
}

pub fn image_memory_barrier(
    image: *root.image.PicturaImage,
    old_layout: vulkan.c.VkImageLayout,
    new_layout: vulkan.c.VkImageLayout,
    queue_family_index: u32,
    src_stage: vulkan.c.VkPipelineStageFlags2,
    src_access: vulkan.c.VkAccessFlags2,
    dst_stage: vulkan.c.VkPipelineStageFlags2,
    dst_access: vulkan.c.VkAccessFlags2,
) vulkan.c.VkImageMemoryBarrier2 {
    const barrier: vulkan.c.VkImageMemoryBarrier2 = .{
        .sType = vulkan.c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
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
            .aspectMask = vulkan.c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
    };

    return barrier;
}

pub fn create_shader_module(spv_ptr: anytype, device: vulkan.c.VkDevice) !vulkan.c.VkShaderModule {
    const info: vulkan.c.VkShaderModuleCreateInfo = .{
        .sType = vulkan.c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = spv_ptr.len,
        .pCode = @ptrCast(@alignCast(spv_ptr)),
    };

    var shader: vulkan.c.VkShaderModule = undefined;
    const result = vulkan.c.vkCreateShaderModule.?(device, &info, null, &shader);

    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to create shader module: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_create_shader_module;
    }

    return shader;
}

pub fn two_stage_graphics_pipeline(
    device: vulkan.c.VkDevice,
    dst_format: vulkan.c.VkFormat,
    vertex_shader: vulkan.c.VkShaderModule,
    fragment_shader: vulkan.c.VkShaderModule,
    pipeline_layout: vulkan.c.VkPipelineLayout,
    blend_enable: vulkan.c.VkBool32,
) !vulkan.c.VkPipeline {
    var pipeline_create_info = std.mem.zeroes(vulkan.c.VkGraphicsPipelineCreateInfo);
    pipeline_create_info.sType = vulkan.c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;

    var rendering_info = std.mem.zeroes(vulkan.c.VkPipelineRenderingCreateInfo);
    rendering_info.sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
    rendering_info.colorAttachmentCount = 1;
    rendering_info.pColorAttachmentFormats = &dst_format;

    pipeline_create_info.pNext = &rendering_info;
    pipeline_create_info.stageCount = 2;

    var shader_stage_create_infos = std.mem.zeroes([2]vulkan.c.VkPipelineShaderStageCreateInfo);
    // vertex shader:
    shader_stage_create_infos[0].sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shader_stage_create_infos[0].stage = vulkan.c.VK_SHADER_STAGE_VERTEX_BIT;
    shader_stage_create_infos[0].module = vertex_shader;
    shader_stage_create_infos[0].pName = "main";
    // fragment shader:
    shader_stage_create_infos[1].sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shader_stage_create_infos[1].stage = vulkan.c.VK_SHADER_STAGE_FRAGMENT_BIT;
    shader_stage_create_infos[1].module = fragment_shader;
    shader_stage_create_infos[1].pName = "main";

    pipeline_create_info.pStages = &shader_stage_create_infos;

    var vertex_input_info = std.mem.zeroes(vulkan.c.VkPipelineVertexInputStateCreateInfo);
    vertex_input_info.sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

    pipeline_create_info.pVertexInputState = &vertex_input_info;

    var input_assembly_info = std.mem.zeroes(vulkan.c.VkPipelineInputAssemblyStateCreateInfo);
    input_assembly_info.sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    input_assembly_info.topology = vulkan.c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    pipeline_create_info.pInputAssemblyState = &input_assembly_info;

    var viewport_info = std.mem.zeroes(vulkan.c.VkPipelineViewportStateCreateInfo);
    viewport_info.sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewport_info.viewportCount = 1;
    viewport_info.scissorCount = 1;

    pipeline_create_info.pViewportState = &viewport_info;

    var rasterization_info = std.mem.zeroes(vulkan.c.VkPipelineRasterizationStateCreateInfo);
    rasterization_info.sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterization_info.polygonMode = vulkan.c.VK_POLYGON_MODE_FILL;
    rasterization_info.lineWidth = 1.0;
    rasterization_info.cullMode = vulkan.c.VK_CULL_MODE_NONE;
    rasterization_info.frontFace = vulkan.c.VK_FRONT_FACE_COUNTER_CLOCKWISE; // doesnt matter when cull mode none

    pipeline_create_info.pRasterizationState = &rasterization_info;

    var multisampling_info = std.mem.zeroes(vulkan.c.VkPipelineMultisampleStateCreateInfo);
    multisampling_info.sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampling_info.rasterizationSamples = vulkan.c.VK_SAMPLE_COUNT_1_BIT;

    pipeline_create_info.pMultisampleState = &multisampling_info;

    const color_blend_attachment: vulkan.c.VkPipelineColorBlendAttachmentState = .{
        .blendEnable = blend_enable,
        .srcColorBlendFactor = vulkan.c.VK_BLEND_FACTOR_SRC_ALPHA,
        .dstColorBlendFactor = vulkan.c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = vulkan.c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = vulkan.c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = vulkan.c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .alphaBlendOp = vulkan.c.VK_BLEND_OP_ADD,
        .colorWriteMask = vulkan.c.VK_COLOR_COMPONENT_R_BIT | vulkan.c.VK_COLOR_COMPONENT_G_BIT | vulkan.c.VK_COLOR_COMPONENT_B_BIT | vulkan.c.VK_COLOR_COMPONENT_A_BIT,
    };

    var color_blend_info = std.mem.zeroes(vulkan.c.VkPipelineColorBlendStateCreateInfo);
    color_blend_info.sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    color_blend_info.attachmentCount = 1;
    color_blend_info.pAttachments = &color_blend_attachment;

    pipeline_create_info.pColorBlendState = &color_blend_info;

    const dynamic_states = [2]vulkan.c.VkDynamicState{ vulkan.c.VK_DYNAMIC_STATE_VIEWPORT, vulkan.c.VK_DYNAMIC_STATE_SCISSOR };
    var dynamic_state_info = std.mem.zeroes(vulkan.c.VkPipelineDynamicStateCreateInfo);
    dynamic_state_info.sType = vulkan.c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamic_state_info.dynamicStateCount = 2;
    dynamic_state_info.pDynamicStates = &dynamic_states;

    pipeline_create_info.pDynamicState = &dynamic_state_info;

    pipeline_create_info.layout = pipeline_layout;

    var pipeline: vulkan.c.VkPipeline = undefined;
    const result = vulkan.c.vkCreateGraphicsPipelines.?(device, null, 1, &pipeline_create_info, null, &pipeline);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to create graphics pipeline: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_create_graphics_pipeline;
    }

    return pipeline;
}

pub fn create_descriptor_pool(device: vulkan.c.VkDevice) !vulkan.c.VkDescriptorPool {
    var sum: u32 = 0;

    const s1: vulkan.c.VkDescriptorPoolSize = .{
        .type = vulkan.c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1024,
    };
    sum += 1024;

    const s2: vulkan.c.VkDescriptorPoolSize = .{
        .type = vulkan.c.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
        .descriptorCount = 1024,
    };
    sum += 1024;

    const sizes = [_]vulkan.c.VkDescriptorPoolSize{ s1, s2 };

    const info: vulkan.c.VkDescriptorPoolCreateInfo = .{
        .sType = vulkan.c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = null,
        .flags = vulkan.c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
        .maxSets = sum,
        .poolSizeCount = sizes.len,
        .pPoolSizes = &sizes,
    };

    var pool: vulkan.c.VkDescriptorPool = undefined;
    const result = vulkan.c.vkCreateDescriptorPool.?(device, &info, null, &pool);
    if (result != vulkan.c.VK_SUCCESS) {
        std.debug.print("failed to create descriptor pool: {s}\n", .{vulkan.c.string_VkResult(result)});
        return error.Vk_failed_to_create_descriptor_pool;
    }

    return pool;
}
