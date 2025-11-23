const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // var alc = std.heap.GeneralPurposeAllocator(.{}).init;
    // const gpa = alc.allocator();

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.link_libc = true;
    lib_mod.linkSystemLibrary("SDL3", .{});
    lib_mod.addIncludePath(.{ .cwd_relative = "./" });
    lib_mod.addIncludePath(.{ .cwd_relative = "C:/msys64/ucrt64/include" });
    lib_mod.addIncludePath(.{ .cwd_relative = "C:/VulkanSDK/1.4.328.1/Include" });
    // lib_mod.addIncludePath(.{ .cwd_relative = "./" });

    lib_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/init/init_vulkan.c" } });

    if (builtin.os.tag == .windows) {
        lib_mod.linkSystemLibrary("user32", .{});
        lib_mod.linkSystemLibrary("gdi32", .{});
        lib_mod.linkSystemLibrary("winmm", .{});
        lib_mod.linkSystemLibrary("ole32", .{});
        lib_mod.linkSystemLibrary("setupapi", .{});
        lib_mod.linkSystemLibrary("imm32", .{});
        lib_mod.linkSystemLibrary("version", .{});
        lib_mod.linkSystemLibrary("oleaut32", .{});
    } else if (builtin.os.tag == .linux) {
        lib_mod.linkSystemLibrary("dl", .{});
        lib_mod.linkSystemLibrary("pthread", .{});
        lib_mod.linkSystemLibrary("m", .{});
    } else if (builtin.os.tag == .macos) {
        lib_mod.linkFramework("Cocoa", .{});
        lib_mod.linkFramework("CoreAudio", .{});
    }

    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "PicturaLib",
        .root_module = lib_mod,
    });

    const shaders = try compile_shaders(b);

    lib.step.dependOn(&shaders.step);

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    lib_unit_tests.step.dependOn(&shaders.step);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn compile_shaders(b: *std.Build) !*std.Build.Step.UpdateSourceFiles {
    var alc = std.heap.GeneralPurposeAllocator(.{}).init;
    const gpa = alc.allocator();

    const usf = std.Build.Step.UpdateSourceFiles.create(b);

    const shader_file = try std.fs.cwd().createFile("src/shaders.zig", .{});
    defer shader_file.close();

    var buffer: [1024]u8 = undefined;

    var writer = shader_file.writer(&buffer);
    var shaders_zig_out = &writer.interface;

    const dir = try std.fs.cwd().openDir("src/shaders", .{ .iterate = true });
    var walker = try dir.walk(gpa);

    var entry = try walker.next();
    while (entry) |e| {
        if (e.kind == .file) {
            const path = try std.mem.concat(gpa, u8, &.{ "src\\shaders\\", e.path });
            const shadername = e.basename[0..std.mem.indexOf(u8, e.basename, ".").?];
            const out_filename = try std.fmt.allocPrint(gpa, "{s}.spv", .{shadername});
            const out_file_path = try std.fmt.allocPrint(gpa, ".spirv/{s}.spv", .{shadername});
            // std.debug.print("{s} {s}\n", .{ e.basename, path });

            var compile_shader = b.addSystemCommand(&[_][]const u8{ "glslangValidator", "-V" });
            try compile_shader.step.addWatchInput(b.path(path));
            compile_shader.addFileArg(b.path(path));
            compile_shader.addArg("-o");
            const shader_output = compile_shader.addOutputFileArg(out_filename);

            // std.debug.print("ofp: {s}\n", .{out_file_path});

            // usf.step.dependOn(&compile_shader.step);

            usf.addCopyFileToSource(shader_output, out_file_path);

            try shaders_zig_out.print("const {s}_spv = @embedFile(\"../.spirv/{s}.spv\");\n", .{ shadername, shadername });
            try shaders_zig_out.flush();
        }

        entry = try walker.next();
    }

    return usf;
}
