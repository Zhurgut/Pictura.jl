const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    lib_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "src/init_vulkan.c" } });

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

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
