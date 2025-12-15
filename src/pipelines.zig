const std = @import("std");
const root = @import("root.zig");

const vulkan = root.vulkan;
const utils = root.utils;
const shaders = root.shaders;
const image = root.image;

pub const Pipelines = struct {
    copy_img_src_sampler: vulkan.VkSampler,
    copy_img_src_descriptor_set_layout: vulkan.VkDescriptorSetLayout,
    copy_img_pipeline_layout: vulkan.VkPipelineLayout,

    swapchain_copy_img_pipeline: vulkan.VkPipeline,
    copy_img_pipeline: vulkan.VkPipeline,

    draw_background_pipeline_layout: vulkan.VkPipelineLayout,
    draw_background_pipeline: vulkan.VkPipeline,

    draw_point_pipeline_layout: vulkan.VkPipelineLayout,
    draw_point_pipeline: vulkan.VkPipeline,

    pub fn create(device: vulkan.VkDevice, swapchain_img_format: vulkan.VkFormat) !Pipelines {
        var out: Pipelines = undefined;

        var draw_background_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = 0,
            .size = 4 * @sizeOf(f32),
        };

        const quad_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_VERTEX_BIT,
            .offset = 0,
            .size = 10 * @sizeOf(f32),
        };

        const draw_point_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = quad_pcr.size, // after quad_pcr
            .size = 7 * @sizeOf(f32),
        };

        //
        // copy image
        //

        out.copy_img_src_sampler = try sampler(device);
        errdefer vulkan.vkDestroySampler.?(device, out.copy_img_src_sampler, null);

        out.copy_img_src_descriptor_set_layout = try copy_img_src_descriptor_set_layout(device);
        errdefer vulkan.vkDestroyDescriptorSetLayout.?(device, out.copy_img_src_descriptor_set_layout, null);

        out.copy_img_pipeline_layout = try copy_img_pipeline_layout(device, &out.copy_img_src_descriptor_set_layout);
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.copy_img_pipeline_layout, null);

        out.swapchain_copy_img_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            swapchain_img_format,
            shaders.modules.fullscreen,
            shaders.modules.texture_sample,
            out.copy_img_pipeline_layout,
            vulkan.VK_FALSE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.swapchain_copy_img_pipeline, null);

        out.copy_img_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            image.format,
            shaders.modules.fullscreen,
            shaders.modules.texture_sample,
            out.copy_img_pipeline_layout,
            vulkan.VK_FALSE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.copy_img_pipeline, null);

        //
        // draw background
        //

        out.draw_background_pipeline_layout = try draw_background_pipeline_layout(device, &draw_background_pcr);
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_background_pipeline_layout, null);

        out.draw_background_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            image.format,
            shaders.modules.fullscreen,
            shaders.modules.draw_color,
            out.draw_background_pipeline_layout,
            vulkan.VK_TRUE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_background_pipeline, null);

        //
        // draw point
        //

        out.draw_point_pipeline_layout, out.draw_point_pipeline = try draw_shape_pipeline(
            device,
            shaders.modules.draw_point,
            quad_pcr,
            draw_point_pcr,
        );
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_point_pipeline_layout, null);
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_point_pipeline, null);

        return out;
    }

    pub fn destroy(pipelines: *Pipelines, device: vulkan.VkDevice) void {
        vulkan.vkDestroyPipeline.?(device, pipelines.draw_point_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_point_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.draw_background_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_background_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.swapchain_copy_img_pipeline, null);
        vulkan.vkDestroyPipeline.?(device, pipelines.copy_img_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.copy_img_pipeline_layout, null);
        vulkan.vkDestroyDescriptorSetLayout.?(device, pipelines.copy_img_src_descriptor_set_layout, null);
        vulkan.vkDestroySampler.?(device, pipelines.copy_img_src_sampler, null);
    }
};

fn sampler(device: vulkan.VkDevice) !vulkan.VkSampler {
    var sampler_create_info = std.mem.zeroes(vulkan.VkSamplerCreateInfo);
    sampler_create_info.sType = vulkan.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler_create_info.addressModeU = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler_create_info.addressModeV = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler_create_info.addressModeW = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;

    var nearest_sampler: vulkan.VkSampler = undefined;
    const result = vulkan.vkCreateSampler.?(device, &sampler_create_info, null, &nearest_sampler);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create sampler: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_sampler;
    }

    return nearest_sampler;
}

fn copy_img_src_descriptor_set_layout(device: vulkan.VkDevice) !vulkan.VkDescriptorSetLayout {
    const sampler_binding: vulkan.VkDescriptorSetLayoutBinding = .{
        .binding = 0,
        .descriptorType = vulkan.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = 1,
        .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
        .pImmutableSamplers = null,
    };

    const layout_info: vulkan.VkDescriptorSetLayoutCreateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .bindingCount = 1,
        .pBindings = &sampler_binding,
    };

    var descriptor_set_layout: vulkan.VkDescriptorSetLayout = undefined;
    const result = vulkan.vkCreateDescriptorSetLayout.?(device, &layout_info, null, &descriptor_set_layout);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create descriptor set layout: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_descriptor_set_layout;
    }

    return descriptor_set_layout;
}

fn copy_img_pipeline_layout(device: vulkan.VkDevice, ds_layout: *vulkan.VkDescriptorSetLayout) !vulkan.VkPipelineLayout {
    var pipeline_layout_info = std.mem.zeroes(vulkan.VkPipelineLayoutCreateInfo);
    pipeline_layout_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipeline_layout_info.setLayoutCount = 1;
    pipeline_layout_info.pSetLayouts = ds_layout;

    var pipeline_layout: vulkan.VkPipelineLayout = undefined;

    const result = vulkan.vkCreatePipelineLayout.?(device, &pipeline_layout_info, null, &pipeline_layout);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create pipeline layout: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_pipeline_layout;
    }

    return pipeline_layout;
}

fn draw_background_pipeline_layout(device: vulkan.VkDevice, pcr: *vulkan.VkPushConstantRange) !vulkan.VkPipelineLayout {
    var pipeline_layout_info = std.mem.zeroes(vulkan.VkPipelineLayoutCreateInfo);
    pipeline_layout_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipeline_layout_info.pushConstantRangeCount = 1;
    pipeline_layout_info.pPushConstantRanges = pcr;

    var pipeline_layout: vulkan.VkPipelineLayout = undefined;

    const result = vulkan.vkCreatePipelineLayout.?(device, &pipeline_layout_info, null, &pipeline_layout);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create pipeline layout: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_pipeline_layout;
    }

    return pipeline_layout;
}

fn draw_shape_pipeline(
    device: vulkan.VkDevice,
    fragshader: vulkan.VkShaderModule,
    vertex_pcr: vulkan.VkPushConstantRange,
    frag_pcr: vulkan.VkPushConstantRange,
) !struct { vulkan.VkPipelineLayout, vulkan.VkPipeline } {
    const pcrs = [2]vulkan.VkPushConstantRange{ vertex_pcr, frag_pcr };

    var pipeline_layout_info = std.mem.zeroes(vulkan.VkPipelineLayoutCreateInfo);
    pipeline_layout_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipeline_layout_info.pushConstantRangeCount = 2;
    pipeline_layout_info.pPushConstantRanges = &pcrs;

    var pipeline_layout: vulkan.VkPipelineLayout = undefined;

    const result = vulkan.vkCreatePipelineLayout.?(device, &pipeline_layout_info, null, &pipeline_layout);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create pipeline layout: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_pipeline_layout;
    }
    errdefer vulkan.vkDestroyPipelineLayout.?(device, pipeline_layout, null);

    const pipeline = try utils.two_stage_graphics_pipeline(
        device,
        image.format,
        shaders.modules.quad,
        fragshader,
        pipeline_layout,
        vulkan.VK_TRUE,
    );

    return .{ pipeline_layout, pipeline };
}
