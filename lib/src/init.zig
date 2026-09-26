const std = @import("std");
const testing = std.testing;

const root = @import("root.zig");
const vulkan = root.vulkan;
const sdl = root.sdl;
const utils = root.utils;

const image = root.image;
const swapchain = root.swapchain;

const PicturaOptions = struct {
    w: u32 = 800,
    h: u32 = 600,
    borderless: bool = false,
    fullscreen: bool = false,

    instance_extensions: []const [*:0]const u8 = &.{},
    vulkan_layers: []const [*:0]const u8 = &.{},

    device_index: u32 = 0,
    features: ?*anyopaque = null,
    device_extensions: []const [*:0]const u8 = &.{},
};

pub fn init_app(options: PicturaOptions) !void {
    root.logger = try .init("info.log");

    var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const init_allocator = arena_allocator.allocator();

    try sdl.init();
    root.logger.info("sdl init", .{});
    errdefer sdl.c.SDL_Quit();

    const window = try sdl.create_window(options.w, options.h);
    root.logger.log_creation(window);
    errdefer sdl.c.SDL_DestroyWindow(window);

    const instance = try vulkan.create_instance(
        init_allocator,
        options.instance_extensions,
        options.vulkan_layers,
    );
    root.logger.log_creation(instance);
    errdefer vulkan.c.vkDestroyInstance.?(instance, null);

    const surface = try sdl.utils.create_vulkan_surface(window, instance);
    root.logger.log_creation(surface);
    errdefer sdl.c.SDL_Vulkan_DestroySurface(@ptrCast(instance), @ptrCast(surface), null);

    const physical_device = try vulkan.create_physical_device(options.device_index, instance);
    root.logger.log_creation(physical_device);

    const device, const queue_family_index = try vulkan.create_device(
        init_allocator,
        physical_device,
        options.features,
        options.device_extensions,
    );
    root.logger.log_creation(device);
    errdefer vulkan.c.vkDestroyDevice.?(device, null);

    var queue: vulkan.c.VkQueue = undefined;
    vulkan.c.vkGetDeviceQueue.?(device, queue_family_index, 0, &queue);

    root.shaders.modules = try .init(device);
    errdefer root.shaders.modules.destroy(device);

    const command_pool = try vulkan.utils.create_command_pool(device, queue_family_index);
    root.logger.log_creation(command_pool);
    errdefer vulkan.c.vkDestroyCommandPool.?(device, command_pool, null);

    const descriptor_pool = try vulkan.utils.create_descriptor_pool(device);
    root.logger.log_creation(descriptor_pool);
    errdefer vulkan.c.vkDestroyDescriptorPool.?(device, descriptor_pool, null);

    var well: root.WellOfCommands = try .create(device, command_pool, queue);
    errdefer well.destroy(device);

    var swapchain2 = try swapchain.Swapchain.create(
        physical_device,
        device,
        queue_family_index,
        surface,
        options.w,
        options.h,
    );
    errdefer swapchain2.destroy(device);

    var pipelines = try root.pipelines.Pipelines.create(device, swapchain2.view_format);
    errdefer pipelines.destroy(device);

    var canvas = try image.PicturaImage.create(
        options.w,
        options.h,
        device,
        queue_family_index,
        physical_device,
    );
    errdefer canvas.destroy(device, descriptor_pool);

    var numkeys: i32 = undefined;
    const kb = sdl.c.SDL_GetKeyboardState(&numkeys);
    root.events.keyboard = kb[0..@intCast(numkeys)];

    const now = sdl.c.SDL_GetTicksNS();
    const display = try root.sdl.utils.get_display_from_window(window);
    const framerate: f64 = root.sdl.utils.get_refresh_rate(display) catch 60;

    root.pictura_app = .{
        .window = window,
        .instance = instance,
        .physical_device = physical_device,
        .device = device,
        .queue_family_index = queue_family_index,
        .queue = queue,
        .surface = surface,
        .swapchain = swapchain2,
        .command_pool = command_pool,
        .canvas = canvas,
        .canvas_id = 1,
        .well = well,
        .descriptor_pool = descriptor_pool,
        .pipelines = pipelines,
        .running = true,
        .event_handler = .create(),
        .arena = .init(std.heap.page_allocator),
        .gpa = undefined,
        .target_framerate = utils.pace_framerate(@floatCast(framerate), 10),
        .target_time = now + 2, // target time of next frame, as soon as possible
        .last_frame_time = now + 1,
        .before_last_time = now,
    };

    root.pictura_app.gpa = root.pictura_app.arena.allocator();
}

pub fn quit() void {
    var app = root.pictura_app;

    _ = vulkan.c.vkDeviceWaitIdle.?(app.device);

    app.arena.deinit();

    app.canvas.destroy(app.device, app.descriptor_pool);

    app.pipelines.destroy(app.device);

    app.swapchain.destroy(app.device);

    app.well.destroy(app.device);

    root.logger.log_destruction(app.descriptor_pool);
    vulkan.c.vkDestroyDescriptorPool.?(app.device, app.descriptor_pool, null);

    root.logger.log_destruction(app.command_pool);
    vulkan.c.vkDestroyCommandPool.?(app.device, app.command_pool, null);

    root.shaders.modules.destroy(app.device);

    root.logger.log_destruction(app.device);
    vulkan.c.vkDestroyDevice.?(app.device, null);

    root.logger.log_destruction(app.physical_device);
    // physical device is not destroyed, it's just a hardware handle

    root.logger.log_destruction(app.surface);
    sdl.c.SDL_Vulkan_DestroySurface(@ptrCast(app.instance), @ptrCast(app.surface), null);

    root.logger.log_destruction(app.instance);
    vulkan.c.vkDestroyInstance.?(app.instance, null); // hangs :(

    root.logger.log_destruction(app.window);
    sdl.c.SDL_DestroyWindow(app.window);

    sdl.c.SDL_Quit();

    // app = std.mem.zeroes(PicturaApp);
}

test "turn it on and off" {
    try init_app(.{ .w = 600, .h = 400 });
    try std.testing.expect(true);
    quit();
}
