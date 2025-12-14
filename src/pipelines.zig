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

    pub fn create(device: vulkan.VkDevice, swapchain_img_format: vulkan.VkFormat) !Pipelines {
        var out: Pipelines = undefined;

        //
        // copy image
        //

        var sampler_create_info = std.mem.zeroes(vulkan.VkSamplerCreateInfo);
        sampler_create_info.sType = vulkan.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
        sampler_create_info.addressModeU = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_create_info.addressModeV = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_create_info.addressModeW = vulkan.VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;

        var nearest_sampler: vulkan.VkSampler = undefined;
        var result = vulkan.vkCreateSampler.?(device, &sampler_create_info, null, &nearest_sampler);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to create sampler: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_create_sampler;
        }
        errdefer vulkan.vkDestroySampler.?(device, nearest_sampler, null);

        out.copy_img_src_sampler = nearest_sampler;

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
        result = vulkan.vkCreateDescriptorSetLayout.?(device, &layout_info, null, &descriptor_set_layout);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to create descriptor set layout: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_create_descriptor_set_layout;
        }
        errdefer vulkan.vkDestroyDescriptorSetLayout.?(device, descriptor_set_layout, null);

        out.copy_img_src_descriptor_set_layout = descriptor_set_layout;

        var pipeline_layout_info = std.mem.zeroes(vulkan.VkPipelineLayoutCreateInfo);
        pipeline_layout_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipeline_layout_info.setLayoutCount = 1;
        pipeline_layout_info.pSetLayouts = &descriptor_set_layout;

        var pipeline_layout: vulkan.VkPipelineLayout = undefined;

        result = vulkan.vkCreatePipelineLayout.?(device, &pipeline_layout_info, null, &pipeline_layout);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to create pipeline layout: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_create_pipeline_layout;
        }
        errdefer vulkan.vkDestroyPipelineLayout.?(device, pipeline_layout, null);

        out.copy_img_pipeline_layout = pipeline_layout;

        out.swapchain_copy_img_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            swapchain_img_format,
            shaders.modules.fullscreen,
            shaders.modules.texture_sample,
            pipeline_layout,
            vulkan.VK_FALSE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.swapchain_copy_img_pipeline, null);

        out.copy_img_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            image.format,
            shaders.modules.fullscreen,
            shaders.modules.texture_sample,
            pipeline_layout,
            vulkan.VK_FALSE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.copy_img_pipeline, null);

        //
        // draw background
        //

        const push_constant_range: vulkan.VkPushConstantRange = .{
            .stageFlags = vulkan.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = 0,
            .size = 4 * @sizeOf(f32),
        };

        pipeline_layout_info = std.mem.zeroes(vulkan.VkPipelineLayoutCreateInfo);
        pipeline_layout_info.sType = vulkan.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipeline_layout_info.pushConstantRangeCount = 1;
        pipeline_layout_info.pPushConstantRanges = &push_constant_range;

        result = vulkan.vkCreatePipelineLayout.?(device, &pipeline_layout_info, null, &pipeline_layout);
        if (result != vulkan.VK_SUCCESS) {
            std.debug.print("failed to create pipeline layout: {s}\n", .{vulkan.string_VkResult(result)});
            return error.Vk_failed_to_create_pipeline_layout;
        }
        errdefer vulkan.vkDestroyPipelineLayout.?(device, pipeline_layout, null);

        out.draw_background_pipeline_layout = pipeline_layout;

        out.draw_background_pipeline = try utils.two_stage_graphics_pipeline(
            device,
            image.format,
            shaders.modules.fullscreen,
            shaders.modules.draw_color,
            pipeline_layout,
            vulkan.VK_TRUE,
        );
        errdefer vulkan.vkDestroyPipeline.?(device, out.draw_background_pipeline, null);

        return out;
    }

    pub fn destroy(pipelines: *Pipelines, device: vulkan.VkDevice) void {
        vulkan.vkDestroyPipeline.?(device, pipelines.draw_background_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.draw_background_pipeline_layout, null);
        vulkan.vkDestroyPipeline.?(device, pipelines.swapchain_copy_img_pipeline, null);
        vulkan.vkDestroyPipeline.?(device, pipelines.copy_img_pipeline, null);
        vulkan.vkDestroyPipelineLayout.?(device, pipelines.copy_img_pipeline_layout, null);
        vulkan.vkDestroyDescriptorSetLayout.?(device, pipelines.copy_img_src_descriptor_set_layout, null);
        vulkan.vkDestroySampler.?(device, pipelines.copy_img_src_sampler, null);
    }
};
