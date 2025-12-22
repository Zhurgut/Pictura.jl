const root = @import("root.zig");
const vulkan = root.vulkan;
const utils = root.utils;

const draw_line_spv align(64) = @embedFile(".spirv/draw_line.spv").*;
const draw_point_spv align(64) = @embedFile(".spirv/draw_point.spv").*;
const draw_rect_spv align(64) = @embedFile(".spirv/draw_rect.spv").*;
const texture_sample_spv align(64) = @embedFile(".spirv/texture_sample.spv").*;
const draw_ellipse_spv align(64) = @embedFile(".spirv/draw_ellipse.spv").*;
const draw_color_spv align(64) = @embedFile(".spirv/draw_color.spv").*;
const fullscreen_spv align(64) = @embedFile(".spirv/fullscreen.spv").*;
const quad_spv align(64) = @embedFile(".spirv/quad.spv").*;
const quad_centered_out_spv align(64) = @embedFile(".spirv/quad_centered_out.spv").*;

pub const ShaderModules = struct {
    draw_line: vulkan.VkShaderModule,
    draw_point: vulkan.VkShaderModule,
    draw_rect: vulkan.VkShaderModule,
    texture_sample: vulkan.VkShaderModule,
    draw_ellipse: vulkan.VkShaderModule,
    draw_color: vulkan.VkShaderModule,
    fullscreen: vulkan.VkShaderModule,
    quad: vulkan.VkShaderModule,
    quad_centered_out: vulkan.VkShaderModule,

    pub fn init(device: vulkan.VkDevice) !ShaderModules {
        return .{
            .draw_line = try utils.create_shader_module(&draw_line_spv, device),
            .draw_point = try utils.create_shader_module(&draw_point_spv, device),
            .draw_rect = try utils.create_shader_module(&draw_rect_spv, device),
            .texture_sample = try utils.create_shader_module(&texture_sample_spv, device),
            .draw_ellipse = try utils.create_shader_module(&draw_ellipse_spv, device),
            .draw_color = try utils.create_shader_module(&draw_color_spv, device),
            .fullscreen = try utils.create_shader_module(&fullscreen_spv, device),
            .quad = try utils.create_shader_module(&quad_spv, device),
            .quad_centered_out = try utils.create_shader_module(&quad_centered_out_spv, device),
        };
    }

    pub fn destroy(s: *ShaderModules, device: vulkan.VkDevice) void {
        vulkan.vkDestroyShaderModule.?(device, s.draw_line, null);
        vulkan.vkDestroyShaderModule.?(device, s.draw_point, null);
        vulkan.vkDestroyShaderModule.?(device, s.draw_rect, null);
        vulkan.vkDestroyShaderModule.?(device, s.texture_sample, null);
        vulkan.vkDestroyShaderModule.?(device, s.draw_ellipse, null);
        vulkan.vkDestroyShaderModule.?(device, s.draw_color, null);
        vulkan.vkDestroyShaderModule.?(device, s.fullscreen, null);
        vulkan.vkDestroyShaderModule.?(device, s.quad, null);
        vulkan.vkDestroyShaderModule.?(device, s.quad_centered_out, null);
    }
};

pub var modules: ShaderModules = undefined;
