const root = @import("root.zig");
const vulkan = root.vulkan;
const utils = root.utils;

const texture_sample_spv align(64) = @embedFile(".spirv/texture_sample.spv").*;
const fullscreen_spv align(64) = @embedFile(".spirv/fullscreen.spv").*;

pub const ShaderModules = struct {
		texture_sample: vulkan.VkShaderModule,
		fullscreen: vulkan.VkShaderModule,

    pub fn init(device: vulkan.VkDevice) !ShaderModules {
        return .{
			.texture_sample = try utils.create_shader_module(&texture_sample_spv, device),
			.fullscreen = try utils.create_shader_module(&fullscreen_spv, device),
        };
    }

    pub fn destroy(s: *ShaderModules, device: vulkan.VkDevice) void {
		vulkan.vkDestroyShaderModule.?(device, s.texture_sample, null);
		vulkan.vkDestroyShaderModule.?(device, s.fullscreen, null);
    }
};

pub var modules: ShaderModules = undefined;