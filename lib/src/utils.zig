const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");
const vulkan = root.vulkan;
const shaders = root.shaders;

pub fn pace_framerate(display_refresh_rate_hz: f32, judder_interval_s: f32) f32 {
    return display_refresh_rate_hz - 1 / judder_interval_s;
}
