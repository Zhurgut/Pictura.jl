const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");
const vulkan = root.vulkan;
const shaders = root.shaders;

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

pub fn get_device_memory_index(physical_device: vulkan.VkPhysicalDevice) !u32 {
    var properties: vulkan.VkPhysicalDeviceMemoryProperties = undefined;
    vulkan.vkGetPhysicalDeviceMemoryProperties.?(physical_device, &properties);
    var heap_index: usize = undefined;
    for (properties.memoryHeaps[0..properties.memoryHeapCount], 0..) |heap, i| {
        if (heap.flags == vulkan.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) {
            heap_index = i;
            break;
        }
    }
    var type_index: ?usize = null;
    for (properties.memoryTypes[0..properties.memoryTypeCount], 0..) |mem_type, i| {
        if (mem_type.heapIndex == heap_index) {
            if (mem_type.propertyFlags == vulkan.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) {
                type_index = i;
                break;
            }
        }
    }
    if (type_index) |i| {
        return @intCast(i);
    } else {
        return error.mem_type_not_found;
    }
}

pub fn get_RAM_memory_index(physical_device: vulkan.VkPhysicalDevice) !u32 {
    var properties: vulkan.VkPhysicalDeviceMemoryProperties = undefined;
    vulkan.vkGetPhysicalDeviceMemoryProperties.?(physical_device, &properties);
    var heap_index: usize = undefined;
    for (properties.memoryHeaps[0..properties.memoryHeapCount], 0..) |heap, i| {
        if (heap.flags == 0) {
            heap_index = i;
            break;
        }
    }
    var type_index: ?usize = null;
    for (properties.memoryTypes[0..properties.memoryTypeCount], 0..) |mem_type, i| {
        if (mem_type.heapIndex == heap_index) {
            if (mem_type.propertyFlags == (vulkan.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vulkan.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) {
                type_index = i;
                break;
            }
        }
    }
    if (type_index) |i| {
        return @intCast(i);
    } else {
        return error.mem_type_not_found;
    }
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

pub fn get_image_memory_barrier(image: *root.image.PicturaImage, next_op: root.image.Op, queue_family_index: u32) vulkan.VkImageMemoryBarrier2 {
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

pub fn submit_image_memory_barrier(command_buffer: vulkan.VkCommandBuffer, barrier: *vulkan.VkImageMemoryBarrier2) void {
    var dep_info = std.mem.zeroes(vulkan.VkDependencyInfo);
    dep_info.sType = vulkan.VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
    dep_info.imageMemoryBarrierCount = 1;
    dep_info.pImageMemoryBarriers = barrier;

    vulkan.vkCmdPipelineBarrier2.?(command_buffer, &dep_info);
}

pub fn image_memory_barrier(
    image: *root.image.PicturaImage,
    old_layout: vulkan.VkImageLayout,
    new_layout: vulkan.VkImageLayout,
    queue_family_index: u32,
    src_stage: vulkan.VkPipelineStageFlags2,
    src_access: vulkan.VkAccessFlags2,
    dst_stage: vulkan.VkPipelineStageFlags2,
    dst_access: vulkan.VkAccessFlags2,
) vulkan.VkImageMemoryBarrier2 {
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

    return barrier;
}

pub fn create_shader_module(spv_ptr: anytype, device: vulkan.VkDevice) !vulkan.VkShaderModule {
    std.debug.print("{*}*{d}\n", .{ spv_ptr, spv_ptr.len });

    const info: vulkan.VkShaderModuleCreateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = spv_ptr.len,
        .pCode = @ptrCast(@alignCast(spv_ptr)),
    };

    var shader: vulkan.VkShaderModule = undefined;
    const result = vulkan.vkCreateShaderModule.?(device, &info, null, &shader);

    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create shader module: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_shader_module;
    }

    return shader;
}

pub fn two_stage_graphics_pipeline(
    device: vulkan.VkDevice,
    dst_format: vulkan.VkFormat,
    vertex_shader: vulkan.VkShaderModule,
    fragment_shader: vulkan.VkShaderModule,
    pipeline_layout: vulkan.VkPipelineLayout,
    blend_enable: vulkan.VkBool32,
) !vulkan.VkPipeline {
    var pipeline_create_info = std.mem.zeroes(vulkan.VkGraphicsPipelineCreateInfo);
    pipeline_create_info.sType = vulkan.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;

    var rendering_info = std.mem.zeroes(vulkan.VkPipelineRenderingCreateInfo);
    rendering_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
    rendering_info.colorAttachmentCount = 1;
    rendering_info.pColorAttachmentFormats = &dst_format;

    pipeline_create_info.pNext = &rendering_info;
    pipeline_create_info.stageCount = 2;

    var shader_stage_create_infos = std.mem.zeroes([2]vulkan.VkPipelineShaderStageCreateInfo);
    // vertex shader:
    shader_stage_create_infos[0].sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shader_stage_create_infos[0].stage = vulkan.VK_SHADER_STAGE_VERTEX_BIT;
    shader_stage_create_infos[0].module = vertex_shader;
    shader_stage_create_infos[0].pName = "main";
    // fragment shader:
    shader_stage_create_infos[1].sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shader_stage_create_infos[1].stage = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT;
    shader_stage_create_infos[1].module = fragment_shader;
    shader_stage_create_infos[1].pName = "main";

    pipeline_create_info.pStages = &shader_stage_create_infos;

    var vertex_input_info = std.mem.zeroes(vulkan.VkPipelineVertexInputStateCreateInfo);
    vertex_input_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

    pipeline_create_info.pVertexInputState = &vertex_input_info;

    var input_assembly_info = std.mem.zeroes(vulkan.VkPipelineInputAssemblyStateCreateInfo);
    input_assembly_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    input_assembly_info.topology = vulkan.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    pipeline_create_info.pInputAssemblyState = &input_assembly_info;

    var viewport_info = std.mem.zeroes(vulkan.VkPipelineViewportStateCreateInfo);
    viewport_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewport_info.viewportCount = 1;
    viewport_info.scissorCount = 1;

    pipeline_create_info.pViewportState = &viewport_info;

    var rasterization_info = std.mem.zeroes(vulkan.VkPipelineRasterizationStateCreateInfo);
    rasterization_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterization_info.polygonMode = vulkan.VK_POLYGON_MODE_FILL;
    rasterization_info.lineWidth = 1.0;
    rasterization_info.cullMode = vulkan.VK_CULL_MODE_NONE;
    rasterization_info.frontFace = vulkan.VK_FRONT_FACE_COUNTER_CLOCKWISE; // doesnt matter when cull mode none

    pipeline_create_info.pRasterizationState = &rasterization_info;

    var multisampling_info = std.mem.zeroes(vulkan.VkPipelineMultisampleStateCreateInfo);
    multisampling_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampling_info.rasterizationSamples = vulkan.VK_SAMPLE_COUNT_1_BIT;

    pipeline_create_info.pMultisampleState = &multisampling_info;

    const color_blend_attachment: vulkan.VkPipelineColorBlendAttachmentState = .{
        .blendEnable = blend_enable,
        .srcColorBlendFactor = vulkan.VK_BLEND_FACTOR_SRC_ALPHA,
        .dstColorBlendFactor = vulkan.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = vulkan.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = vulkan.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .alphaBlendOp = vulkan.VK_BLEND_OP_ADD,
        .colorWriteMask = vulkan.VK_COLOR_COMPONENT_R_BIT | vulkan.VK_COLOR_COMPONENT_G_BIT | vulkan.VK_COLOR_COMPONENT_B_BIT | vulkan.VK_COLOR_COMPONENT_A_BIT,
    };

    var color_blend_info = std.mem.zeroes(vulkan.VkPipelineColorBlendStateCreateInfo);
    color_blend_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    color_blend_info.attachmentCount = 1;
    color_blend_info.pAttachments = &color_blend_attachment;

    pipeline_create_info.pColorBlendState = &color_blend_info;

    const dynamic_states = [2]vulkan.VkDynamicState{ vulkan.VK_DYNAMIC_STATE_VIEWPORT, vulkan.VK_DYNAMIC_STATE_SCISSOR };
    var dynamic_state_info = std.mem.zeroes(vulkan.VkPipelineDynamicStateCreateInfo);
    dynamic_state_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamic_state_info.dynamicStateCount = 2;
    dynamic_state_info.pDynamicStates = &dynamic_states;

    pipeline_create_info.pDynamicState = &dynamic_state_info;

    pipeline_create_info.layout = pipeline_layout;

    var pipeline: vulkan.VkPipeline = undefined;
    const result = vulkan.vkCreateGraphicsPipelines.?(device, null, 1, &pipeline_create_info, null, &pipeline);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create graphics pipeline: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_graphics_pipeline;
    }

    return pipeline;
}

pub fn create_descriptor_pool(device: vulkan.VkDevice) !vulkan.VkDescriptorPool {
    var sum: u32 = 0;

    const s1: vulkan.VkDescriptorPoolSize = .{
        .type = vulkan.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1024,
    };
    sum += 1024;

    const sizes = [_]vulkan.VkDescriptorPoolSize{s1};

    const info: vulkan.VkDescriptorPoolCreateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = null,
        .flags = vulkan.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
        .maxSets = sum,
        .poolSizeCount = sizes.len,
        .pPoolSizes = &sizes,
    };

    var pool: vulkan.VkDescriptorPool = undefined;
    const result = vulkan.vkCreateDescriptorPool.?(device, &info, null, &pool);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create descriptor pool: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_descriptor_pool;
    }

    return pool;
}
