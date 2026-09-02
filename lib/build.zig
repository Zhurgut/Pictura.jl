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
        .root_source_file = b.path("src/sdl.h"),
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
        .root_source_file = b.path("src/init/init_vulkan.h"),
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
    vulkan_module.addCSourceFile(.{ .file = .{ .cwd_relative = "src/init/init_vulkan.c" } });

    lib_mod.addImport("vulkan", vulkan_module);

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

    const shaders = try compile_shaders(b);

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
fn compile_shaders(b: *std.Build) !*std.Build.Step.UpdateSourceFiles {
    const gpa = b.allocator;
    const io = b.graph.io;

    const usf = std.Build.Step.UpdateSourceFiles.create(b);

    const shader_file = try b.build_root.handle.createFile(io, "src/shaders.zig", .{});
    defer shader_file.close(io);

    var buffer: [1024]u8 = undefined;

    var writer = shader_file.writer(io, &buffer);
    var shaders_zig_out = &writer.interface;

    const dir = try b.build_root.handle.openDir(io, "src/shaders", .{ .iterate = true });
    var walker = try dir.walk(gpa);

    try shaders_zig_out.print(
        \\const root = @import("root.zig");
        \\const vulkan = root.vulkan;
        \\const utils = root.utils;
        \\
        \\
    , .{});

    var entry = try walker.next(io);
    while (entry) |e| {
        if (e.kind != .file) {
            entry = try walker.next(io);
            continue;
        }

        const path = try std.mem.concat(gpa, u8, &.{ "src\\shaders\\", e.path });
        const shadername = e.basename[0..std.mem.indexOf(u8, e.basename, ".").?];
        const out_filename = try std.fmt.allocPrint(gpa, "{s}.spv", .{shadername});
        const out_file_path = try std.fmt.allocPrint(gpa, "src/.spirv/{s}.spv", .{shadername});

        var compile_shader = b.addSystemCommand(&[_][]const u8{ "glslangValidator", "-V", "--target-env", "vulkan1.3" });
        compile_shader.addFileArg(b.path(path));
        compile_shader.addArg("-o");
        const shader_output = compile_shader.addOutputFileArg(out_filename);

        usf.addCopyFileToSource(shader_output, out_file_path);

        try shaders_zig_out.print("const {s}_spv align(64) = @embedFile(\".spirv/{s}.spv\").*;\n", .{ shadername, shadername });

        entry = try walker.next(io);
    }

    try shaders_zig_out.print(
        \\
        \\pub const ShaderModules = struct {{
        \\
    , .{});

    walker = try dir.walk(gpa);

    entry = try walker.next(io);
    while (entry) |e| {
        if (e.kind != .file) {
            entry = try walker.next(io);
            continue;
        }

        const shadername = e.basename[0..std.mem.indexOf(u8, e.basename, ".").?];

        try shaders_zig_out.print(
            \\    {s}: vulkan.VkShaderModule,
            \\
        , .{shadername});

        entry = try walker.next(io);
    }

    try shaders_zig_out.print(
        \\
        \\    pub fn init(device: vulkan.VkDevice) !ShaderModules {{
        \\        return .{{
        \\
    , .{});

    walker = try dir.walk(gpa);

    entry = try walker.next(io);
    while (entry) |e| {
        if (e.kind != .file) {
            entry = try walker.next(io);
            continue;
        }

        const shadername = e.basename[0..std.mem.indexOf(u8, e.basename, ".").?];

        try shaders_zig_out.print(
            \\            .{s} = try utils.create_shader_module(&{s}_spv, device),
            \\
        , .{ shadername, shadername });

        entry = try walker.next(io);
    }

    try shaders_zig_out.print(
        \\        }};
        \\    }}
        \\
        \\    pub fn destroy(s: *ShaderModules, device: vulkan.VkDevice) void {{
        \\
    , .{});

    walker = try dir.walk(gpa);

    entry = try walker.next(io);
    while (entry) |e| {
        if (e.kind != .file) {
            entry = try walker.next(io);
            continue;
        }

        const shadername = e.basename[0..std.mem.indexOf(u8, e.basename, ".").?];

        try shaders_zig_out.print(
            \\        vulkan.vkDestroyShaderModule.?(device, s.{s}, null);
            \\
        , .{shadername});

        entry = try walker.next(io);
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
