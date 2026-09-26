const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.link_libc = true;

    //      ___ ___  _
    //     / __|   \| |
    //     \__ \ |) | |__
    //     |___/___/|____|
    //
    const sdl3 = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    lib_mod.linkLibrary(sdl3.artifact("SDL3"));

    const translate_c_sdl = b.addTranslateC(.{
        .root_source_file = b.path("src/sdl/sdl.h"),
        .target = target,
        .optimize = optimize,
    });

    translate_c_sdl.addIncludePath(sdl3.path("include"));
    const sdl_module = translate_c_sdl.createModule();
    lib_mod.addImport("sdl", sdl_module);

    //     __   __    _ _
    //     \ \ / /  _| | |____ _ _ _
    //      \ V / || | | / / _` | ' \
    //       \_/ \_,_|_|_\_\__,_|_||_|
    //
    const vulkan_headers = b.dependency("vulkan-headers", .{});
    const vulkan_utility_libraries = b.dependency("vulkan-utility-libraries", .{});
    const volk = b.dependency("volk", .{});

    const translate_c_vulkan = b.addTranslateC(.{
        .root_source_file = b.path("src/vulkan/my_vulkan.h"),
        .target = target,
        .optimize = optimize,
    });

    translate_c_vulkan.addIncludePath(volk.path("."));
    translate_c_vulkan.addIncludePath(vulkan_headers.path("include"));
    translate_c_vulkan.addIncludePath(vulkan_utility_libraries.path("include"));

    const vulkan_module = translate_c_vulkan.createModule();
    vulkan_module.addIncludePath(volk.path("."));
    vulkan_module.addIncludePath(vulkan_headers.path("include"));
    vulkan_module.addIncludePath(vulkan_utility_libraries.path("include"));
    vulkan_module.addCSourceFile(.{ .file = .{ .cwd_relative = "src/vulkan/my_vulkan.c" } });

    lib_mod.addImport("my_vulkan", vulkan_module);

    //      ___      _ _    _
    //     | _ )_  _(_) |__| |
    //     | _ \ || | | / _` |
    //     |___/\_,_|_|_\__,_|
    //
    if (target.result.os.tag == .windows) {
        lib_mod.linkSystemLibrary("user32", .{});
        lib_mod.linkSystemLibrary("gdi32", .{});
        lib_mod.linkSystemLibrary("winmm", .{});
        lib_mod.linkSystemLibrary("ole32", .{});
        lib_mod.linkSystemLibrary("setupapi", .{});
        lib_mod.linkSystemLibrary("imm32", .{});
        lib_mod.linkSystemLibrary("version", .{});
        lib_mod.linkSystemLibrary("oleaut32", .{});
    }

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "pictura",
        .root_module = lib_mod,
    });

    const shaders = try spv_shaders(b);

    lib.step.dependOn(&shaders.step);

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    lib_unit_tests.step.dependOn(&shaders.step);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

//      ___ _            _
//     / __| |_  __ _ __| |___ _ _ ___
//     \__ \ ' \/ _` / _` / -_) '_(_-<
//     |___/_||_\__,_\__,_\___|_| /__/
//

const ShaderFile = struct {
    path: []const u8, // e.g., "src/shaders/fragment/quad.frag"
    name: []const u8, // e.g., "quad"
};

fn get_shader_files(b: *std.Build) ![]ShaderFile {
    const io = b.graph.io;
    const gpa = b.allocator;

    var shader_files = std.ArrayList(ShaderFile).empty;
    errdefer shader_files.deinit(gpa);

    var dir = try b.build_root.handle.openDir(io, "src/shaders", .{ .iterate = true });
    defer dir.close(io);

    var walker = try dir.walk(gpa);
    defer walker.deinit();

    while (try walker.next(io)) |e| {
        if (e.kind != .file) continue;
        if (std.mem.endsWith(u8, e.basename, ".zig")) continue;

        const path = try std.fmt.allocPrint(gpa, "src/shaders/{s}", .{e.path});

        const dot_idx = std.mem.indexOfScalar(u8, e.basename, '.') orelse e.basename.len;
        const stem = e.basename[0..dot_idx];
        const name = try gpa.dupe(u8, stem);

        try shader_files.append(gpa, .{
            .path = path,
            .name = name,
        });
    }

    return try shader_files.toOwnedSlice(gpa);
}

fn compile_shaders(b: *std.Build, files: []ShaderFile) !*std.Build.Step.UpdateSourceFiles {
    const gpa = b.allocator;
    const usf = std.Build.Step.UpdateSourceFiles.create(b);

    for (files) |shader| {
        const out_filename = try std.fmt.allocPrint(gpa, "{s}.spv", .{shader.name});
        const out_file_path = try std.fmt.allocPrint(gpa, "src/.spirv/{s}", .{out_filename});

        var compile_shader = b.addSystemCommand(&[_][]const u8{ "glslangValidator", "-V", "--target-env", "vulkan1.3" });
        compile_shader.addFileArg(b.path(shader.path));
        compile_shader.addArg("-o");

        const shader_output = compile_shader.addOutputFileArg(out_filename);

        usf.addCopyFileToSource(shader_output, out_file_path);
    }

    return usf;
}

fn spv_shaders(b: *std.Build) !*std.Build.Step.UpdateSourceFiles {
    const io = b.graph.io;

    const shader_files = try get_shader_files(b);
    // TODO assert all shader_file.name are unique

    const usf = try compile_shaders(b, shader_files);

    const shader_file = try b.build_root.handle.createFile(io, "src/shaders/shaders.zig", .{});
    defer shader_file.close(io);

    var buffer: [1024]u8 = undefined;

    var writer = shader_file.writer(io, &buffer);
    var shaders_zig_out = &writer.interface;

    try shaders_zig_out.print(
        \\const root = @import("../root.zig");
        \\const vulkan = root.vulkan;
        \\const utils = root.vulkan.utils;
        \\
        \\
    , .{});

    for (shader_files) |shader| {
        try shaders_zig_out.print("const {s}_spv align(64) = @embedFile(\"../.spirv/{s}.spv\").*;\n", .{ shader.name, shader.name });
    }

    try shaders_zig_out.print(
        \\
        \\pub const ShaderModules = struct {{
        \\
    , .{});

    for (shader_files) |shader| {
        try shaders_zig_out.print(
            \\    {s}: vulkan.c.VkShaderModule,
            \\
        , .{shader.name});
    }

    try shaders_zig_out.print(
        \\
        \\    pub fn init(device: vulkan.c.VkDevice) !ShaderModules {{
        \\        return .{{
        \\
    , .{});

    for (shader_files) |shader| {
        try shaders_zig_out.print(
            \\            .{s} = try utils.create_shader_module(&{s}_spv, device),
            \\
        , .{ shader.name, shader.name });
    }

    try shaders_zig_out.print(
        \\        }};
        \\    }}
        \\
        \\    pub fn destroy(s: *ShaderModules, device: vulkan.c.VkDevice) void {{
        \\
    , .{});

    for (shader_files) |shader| {
        try shaders_zig_out.print(
            \\        vulkan.c.vkDestroyShaderModule.?(device, s.{s}, null);
            \\
        , .{shader.name});
    }

    try shaders_zig_out.print(
        \\    }}
        \\}};
        \\
        \\pub var modules: ShaderModules = undefined;
        \\
    , .{});

    try shaders_zig_out.flush();

    return usf;
}
