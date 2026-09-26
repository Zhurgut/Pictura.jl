const root = @import("../root.zig");
const vulkan = root.vulkan;
const utils = root.vulkan.utils;

const draw_line_spv align(64) = @embedFile("../.spirv/draw_line.spv").*;
const draw_point_spv align(64) = @embedFile("../.spirv/draw_point.spv").*;
const draw_image_spv align(64) = @embedFile("../.spirv/draw_image.spv").*;
const draw_rect_spv align(64) = @embedFile("../.spirv/draw_rect.spv").*;
const mix_channels_spv align(64) = @embedFile("../.spirv/mix_channels.spv").*;
const mix_channels2_spv align(64) = @embedFile("../.spirv/mix_channels2.spv").*;
const draw_ellipse_spv align(64) = @embedFile("../.spirv/draw_ellipse.spv").*;
const draw_color_spv align(64) = @embedFile("../.spirv/draw_color.spv").*;
const filter_spv align(64) = @embedFile("../.spirv/filter.spv").*;
const fullscreen_spv align(64) = @embedFile("../.spirv/fullscreen.spv").*;
const quad_spv align(64) = @embedFile("../.spirv/quad.spv").*;
const quad_centered_out_spv align(64) = @embedFile("../.spirv/quad_centered_out.spv").*;
const quad_out_spv align(64) = @embedFile("../.spirv/quad_out.spv").*;

pub const ShaderModules = struct {
    draw_line: vulkan.c.VkShaderModule,
    draw_point: vulkan.c.VkShaderModule,
    draw_image: vulkan.c.VkShaderModule,
    draw_rect: vulkan.c.VkShaderModule,
    mix_channels: vulkan.c.VkShaderModule,
    mix_channels2: vulkan.c.VkShaderModule,
    draw_ellipse: vulkan.c.VkShaderModule,
    draw_color: vulkan.c.VkShaderModule,
    filter: vulkan.c.VkShaderModule,
    fullscreen: vulkan.c.VkShaderModule,
    quad: vulkan.c.VkShaderModule,
    quad_centered_out: vulkan.c.VkShaderModule,
    quad_out: vulkan.c.VkShaderModule,

    pub fn init(device: vulkan.c.VkDevice) !ShaderModules {
        return .{
            .draw_line = try utils.create_shader_module(&draw_line_spv, device),
            .draw_point = try utils.create_shader_module(&draw_point_spv, device),
            .draw_image = try utils.create_shader_module(&draw_image_spv, device),
            .draw_rect = try utils.create_shader_module(&draw_rect_spv, device),
            .mix_channels = try utils.create_shader_module(&mix_channels_spv, device),
            .mix_channels2 = try utils.create_shader_module(&mix_channels2_spv, device),
            .draw_ellipse = try utils.create_shader_module(&draw_ellipse_spv, device),
            .draw_color = try utils.create_shader_module(&draw_color_spv, device),
            .filter = try utils.create_shader_module(&filter_spv, device),
            .fullscreen = try utils.create_shader_module(&fullscreen_spv, device),
            .quad = try utils.create_shader_module(&quad_spv, device),
            .quad_centered_out = try utils.create_shader_module(&quad_centered_out_spv, device),
            .quad_out = try utils.create_shader_module(&quad_out_spv, device),
        };
    }

    pub fn destroy(s: *ShaderModules, device: vulkan.c.VkDevice) void {
        vulkan.c.vkDestroyShaderModule.?(device, s.draw_line, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.draw_point, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.draw_image, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.draw_rect, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.mix_channels, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.mix_channels2, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.draw_ellipse, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.draw_color, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.filter, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.fullscreen, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.quad, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.quad_centered_out, null);
        vulkan.c.vkDestroyShaderModule.?(device, s.quad_out, null);
    }
};

pub var modules: ShaderModules = undefined;
