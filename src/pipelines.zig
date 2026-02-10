const std = @import("std");
const root = @import("root.zig");

const vulkan = root.vulkan;
const utils = root.utils;
const shaders = root.shaders;
const image = root.image;

pub const Pipelines = struct {
    nearest_sampler: vulkan.VkSampler,
    linear_sampler: vulkan.VkSampler,

    sample_ds_layout: vulkan.VkDescriptorSetLayout,
    draw_full_img_pipeline_layout: vulkan.VkPipelineLayout,

    swapchain_draw_full_img_pipeline: vulkan.VkPipeline,
    draw_full_img_pipeline: vulkan.VkPipeline,

    draw_img_pipeline_layout: vulkan.VkPipelineLayout,
    draw_img_pipeline: vulkan.VkPipeline,

    draw_background_pipeline_layout: vulkan.VkPipelineLayout,
    draw_background_pipeline: vulkan.VkPipeline,

    draw_point_pipeline_layout: vulkan.VkPipelineLayout,
    draw_point_pipeline: vulkan.VkPipeline,

    draw_line_pipeline_layout: vulkan.VkPipelineLayout,
    draw_line_pipeline: vulkan.VkPipeline,

    draw_ellipse_pipeline_layout: vulkan.VkPipelineLayout,
    draw_ellipse_pipeline: vulkan.VkPipeline,

    draw_rect_pipeline_layout: vulkan.VkPipelineLayout,
    draw_rect_pipeline: vulkan.VkPipeline,

    mix1_pipeline_layout: vulkan.VkPipelineLayout,
    mix1_pipeline: vulkan.VkPipeline,

    mix2_pipeline_layout: vulkan.VkPipelineLayout,
    mix2_pipeline: vulkan.VkPipeline,

    storage_img_dsl: vulkan.VkDescriptorSetLayout,

    filter_pipeline_layout: vulkan.VkPipelineLayout,
    filter_pipeline: vulkan.VkPipeline,

    pub fn create(device: vulkan.VkDevice, swapchain_img_format: vulkan.VkFormat) !Pipelines {
        var out: Pipelines = undefined;

        var draw_img_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_VERTEX_BIT,
            .offset = 0,
            .size = 20 * @sizeOf(f32),
        };

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

        const draw_line_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = quad_pcr.size, // after quad_pcr
            .size = 9 * @sizeOf(f32),
        };

        const draw_ellipse_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = quad_pcr.size, // after quad_pcr
            .size = 19 * @sizeOf(f32),
        };

        const draw_rect_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = quad_pcr.size, // after quad_pcr
            .size = 12 * @sizeOf(f32),
        };

        var mix1_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = 0,
            .size = 20 * @sizeOf(f32),
        };

        var mix2_pcr: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = 0,
            .size = 32 * @sizeOf(f32),
        };

        //
        // copy image
        //

        out.nearest_sampler = try nearest_sampler(device);
        errdefer vulkan.vkDestroySampler.?(device, out.nearest_sampler, null);
        out.linear_sampler = try linear_sampler(device);
        errdefer vulkan.vkDestroySampler.?(device, out.linear_sampler, null);

        out.sample_ds_layout = try sample_descriptor_set_layout(device);
        errdefer vulkan.vkDestroyDescriptorSetLayout.?(device, out.sample_ds_layout, null);

        // copy the full image from one texture into another, nearest sampler for max speed
        out.draw_full_img_pipeline_layout = try draw_full_img_pipeline_layout(device, &out.sample_ds_layout);
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_full_img_pipeline_layout, null);

        out.swapchain_draw_full_img_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            swapchain_img_format,
            shaders.modules.fullscreen,
            shaders.modules.draw_image,
            out.draw_full_img_pipeline_layout,
            vulkan.VK_FALSE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.swapchain_draw_full_img_pipeline, null);

        out.draw_full_img_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            image.view_format,
            shaders.modules.fullscreen,
            shaders.modules.draw_image,
            out.draw_full_img_pipeline_layout,
            vulkan.VK_FALSE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_full_img_pipeline, null);

        // draw one image onto another image, providing src and dst rect
        out.draw_img_pipeline_layout = try draw_img_pipeline_layout(device, &draw_img_pcr, &out.sample_ds_layout);
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_img_pipeline_layout, null);

        out.draw_img_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            image.view_format,
            shaders.modules.quad_out,
            shaders.modules.draw_image,
            out.draw_img_pipeline_layout,
            vulkan.VK_TRUE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_img_pipeline, null);

        //
        // draw background
        //

        out.draw_background_pipeline_layout = try draw_background_pipeline_layout(device, &draw_background_pcr);
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_background_pipeline_layout, null);

        out.draw_background_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            image.view_format,
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
            false,
        );
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_point_pipeline_layout, null);
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_point_pipeline, null);

        out.draw_line_pipeline_layout, out.draw_line_pipeline = try draw_shape_pipeline(
            device,
            shaders.modules.draw_line,
            quad_pcr,
            draw_line_pcr,
            false,
        );
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_line_pipeline_layout, null);
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_line_pipeline, null);

        out.draw_ellipse_pipeline_layout, out.draw_ellipse_pipeline = try draw_shape_pipeline(
            device,
            shaders.modules.draw_ellipse,
            quad_pcr,
            draw_ellipse_pcr,
            true,
        );
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_ellipse_pipeline_layout, null);
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_ellipse_pipeline, null);

        out.draw_rect_pipeline_layout, out.draw_rect_pipeline = try draw_shape_pipeline(
            device,
            shaders.modules.draw_rect,
            quad_pcr,
            draw_rect_pcr,
            true,
        );
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.draw_rect_pipeline_layout, null);
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_rect_pipeline, null);

        out.mix1_pipeline_layout, out.mix1_pipeline = try mix_channels_pipeline(
            device,
            shaders.modules.mix_channels,
            &out.sample_ds_layout,
            &mix1_pcr,
        );
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.mix1_pipeline_layout, null);
        errdefer vulkan.vkDestroyPipeline.?(device, out.mix1_pipeline, null);

        out.mix2_pipeline_layout, out.mix2_pipeline = try mix_channels_pipeline(
            device,
            shaders.modules.mix_channels2,
            &out.sample_ds_layout,
            &mix2_pcr,
        );
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.mix2_pipeline_layout, null);
        errdefer vulkan.vkDestroyPipeline.?(device, out.mix2_pipeline, null);

        out.storage_img_dsl = try storage_image_descriptor_set_layout(device);
        errdefer vulkan.vkDestroyDescriptorSetLayout.?(device, out.storage_img_dsl, null);

        out.filter_pipeline_layout, out.filter_pipeline = try compute_filter_pipeline(
            device,
            shaders.modules.filter,
            out.storage_img_dsl,
        );
        errdefer vulkan.vkDestroyPipelineLayout.?(device, out.filter_pipeline_layout, null);
        errdefer vulkan.vkDestroyPipeline.?(device, out.filter_pipeline, null);

        return out;
    }

    pub fn destroy(pipelines: *Pipelines, device: vulkan.VkDevice) void {
        vulkan.vkDestroyPipeline.?(device, pipelines.filter_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.filter_pipeline_layout, null);

        vulkan.vkDestroyDescriptorSetLayout.?(device, pipelines.storage_img_dsl, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.mix2_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.mix2_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.mix1_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.mix1_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.draw_rect_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_rect_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.draw_ellipse_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_ellipse_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.draw_line_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_line_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.draw_point_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_point_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.draw_background_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_background_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.draw_img_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_img_pipeline_layout, null);

        vulkan.vkDestroyPipeline.?(device, pipelines.swapchain_draw_full_img_pipeline, null);
        vulkan.vkDestroyPipeline.?(device, pipelines.draw_full_img_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_full_img_pipeline_layout, null);
        vulkan.vkDestroyDescriptorSetLayout.?(device, pipelines.sample_ds_layout, null);

        vulkan.vkDestroySampler.?(device, pipelines.nearest_sampler, null);
        vulkan.vkDestroySampler.?(device, pipelines.linear_sampler, null);
    }
};

fn nearest_sampler(device: vulkan.VkDevice) !vulkan.VkSampler {
    var sampler_create_info = std.mem.zeroes(vulkan.VkSamplerCreateInfo);
    sampler_create_info.sType = vulkan.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler_create_info.addressModeU = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler_create_info.addressModeV = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler_create_info.addressModeW = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;

    var sampler: vulkan.VkSampler = undefined;
    const result = vulkan.vkCreateSampler.?(device, &sampler_create_info, null, &sampler);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create sampler: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_sampler;
    }

    return sampler;
}

fn linear_sampler(device: vulkan.VkDevice) !vulkan.VkSampler {
    var sampler_create_info = std.mem.zeroes(vulkan.VkSamplerCreateInfo);
    sampler_create_info.sType = vulkan.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
    sampler_create_info.magFilter = vulkan.VK_FILTER_LINEAR;
    sampler_create_info.minFilter = vulkan.VK_FILTER_LINEAR;
    sampler_create_info.addressModeU = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler_create_info.addressModeV = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
    sampler_create_info.addressModeW = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;

    var sampler: vulkan.VkSampler = undefined;
    const result = vulkan.vkCreateSampler.?(device, &sampler_create_info, null, &sampler);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create sampler: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_sampler;
    }

    return sampler;
}

fn sample_descriptor_set_layout(device: vulkan.VkDevice) !vulkan.VkDescriptorSetLayout {
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

fn draw_full_img_pipeline_layout(device: vulkan.VkDevice, ds_layout: *vulkan.VkDescriptorSetLayout) !vulkan.VkPipelineLayout {
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

fn draw_img_pipeline_layout(device: vulkan.VkDevice, pcr: *vulkan.VkPushConstantRange, ds_layout: *vulkan.VkDescriptorSetLayout) !vulkan.VkPipelineLayout {
    var pipeline_layout_info = std.mem.zeroes(vulkan.VkPipelineLayoutCreateInfo);
    pipeline_layout_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipeline_layout_info.setLayoutCount = 1;
    pipeline_layout_info.pSetLayouts = ds_layout;
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
    centered: bool,
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
        image.view_format,
        if (centered) shaders.modules.quad_centered_out else shaders.modules.quad,
        fragshader,
        pipeline_layout,
        vulkan.VK_TRUE,
    );

    return .{ pipeline_layout, pipeline };
}

fn mix_channels_pipeline(
    device: vulkan.VkDevice,
    fragshader: vulkan.VkShaderModule,
    ds_layout: *vulkan.VkDescriptorSetLayout,
    frag_pcr: *vulkan.VkPushConstantRange,
) !struct { vulkan.VkPipelineLayout, vulkan.VkPipeline } {
    var pipeline_layout_info = std.mem.zeroes(vulkan.VkPipelineLayoutCreateInfo);
    pipeline_layout_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipeline_layout_info.setLayoutCount = 1;
    pipeline_layout_info.pSetLayouts = ds_layout;
    pipeline_layout_info.pushConstantRangeCount = 1;
    pipeline_layout_info.pPushConstantRanges = frag_pcr;

    var pipeline_layout: vulkan.VkPipelineLayout = undefined;

    const result = vulkan.vkCreatePipelineLayout.?(device, &pipeline_layout_info, null, &pipeline_layout);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create pipeline layout: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_pipeline_layout;
    }
    errdefer vulkan.vkDestroyPipelineLayout.?(device, pipeline_layout, null);

    const pipeline = try utils.two_stage_graphics_pipeline(
        device,
        image.view_format,
        shaders.modules.fullscreen,
        fragshader,
        pipeline_layout,
        vulkan.VK_FALSE,
    );

    return .{ pipeline_layout, pipeline };
}

fn storage_image_descriptor_set_layout(
    device: vulkan.VkDevice,
) !vulkan.VkDescriptorSetLayout {
    const img_binding: vulkan.VkDescriptorSetLayoutBinding = .{
        .binding = 0,
        .descriptorType = vulkan.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
        .descriptorCount = 1,
        .stageFlags = vulkan.VK_SHADER_STAGE_COMPUTE_BIT,
        .pImmutableSamplers = null,
    };

    const layout_info: vulkan.VkDescriptorSetLayoutCreateInfo = .{
        .sType = vulkan.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .bindingCount = 1,
        .pBindings = &img_binding,
    };

    var descriptor_set_layout: vulkan.VkDescriptorSetLayout = undefined;
    const result = vulkan.vkCreateDescriptorSetLayout.?(device, &layout_info, null, &descriptor_set_layout);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create descriptor set layout: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_descriptor_set_layout;
    }

    return descriptor_set_layout;
}

fn compute_filter_pipeline(
    device: vulkan.VkDevice,
    shader: vulkan.VkShaderModule,
    img_dsl: vulkan.VkDescriptorSetLayout,
) !struct { vulkan.VkPipelineLayout, vulkan.VkPipeline } {
    const pcr: vulkan.VkPushConstantRange = .{
        .stageFlags = vulkan.VK_SHADER_STAGE_COMPUTE_BIT,
        .offset = 0,
        .size = 14 * @sizeOf(f32),
    };

    const dsls = [2]vulkan.VkDescriptorSetLayout{ img_dsl, img_dsl };

    var pipeline_layout_info = std.mem.zeroes(vulkan.VkPipelineLayoutCreateInfo);
    pipeline_layout_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipeline_layout_info.setLayoutCount = 2;
    pipeline_layout_info.pSetLayouts = &dsls;
    pipeline_layout_info.pushConstantRangeCount = 1;
    pipeline_layout_info.pPushConstantRanges = &pcr;

    var pipeline_layout: vulkan.VkPipelineLayout = undefined;

    var result = vulkan.vkCreatePipelineLayout.?(device, &pipeline_layout_info, null, &pipeline_layout);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create pipeline layout: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_pipeline_layout;
    }
    errdefer vulkan.vkDestroyPipelineLayout.?(device, pipeline_layout, null);

    var shader_stage_info = std.mem.zeroes(vulkan.VkPipelineShaderStageCreateInfo);
    shader_stage_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shader_stage_info.stage = vulkan.VK_SHADER_STAGE_COMPUTE_BIT;
    shader_stage_info.module = shader;
    shader_stage_info.pName = "main";

    var pipeline_create_info = std.mem.zeroes(vulkan.VkComputePipelineCreateInfo);
    pipeline_create_info.sType = vulkan.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
    pipeline_create_info.stage = shader_stage_info;
    pipeline_create_info.layout = pipeline_layout;

    var pipeline: vulkan.VkPipeline = undefined;

    result = vulkan.vkCreateComputePipelines.?(device, null, 1, &pipeline_create_info, null, &pipeline);
    if (result != vulkan.VK_SUCCESS) {
        std.debug.print("failed to create pipeline: {s}\n", .{vulkan.string_VkResult(result)});
        return error.Vk_failed_to_create_pipeline;
    }
    errdefer vulkan.vkDestroyPipeline.?(device, pipeline, null);

    return .{ pipeline_layout, pipeline };
}
