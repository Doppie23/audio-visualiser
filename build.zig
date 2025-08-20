const std = @import("std");

const tests = [_][]const u8{
    "src/fft.zig",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "audio_analyser",
        .root_module = exe_mod,
    });

    if (optimize != .Debug and target.result.os.tag == .windows) {
        exe.subsystem = .Windows;
    }

    exe.linkLibC();

    // link windows libraries
    exe.linkSystemLibrary("ole32");
    exe.linkSystemLibrary("oleAut32");
    exe.linkSystemLibrary("avrt");
    exe.linkSystemLibrary("uuid");

    // raylib
    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        .shared = false,
        //.linux_display_backend = .X11,
    });
    const raylib = raylib_dep.artifact("raylib");
    exe.linkLibrary(raylib);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // tests

    const test_step = b.step("test", "Run unit tests");

    for (tests) |path| {
        const mod = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        });
        const exe_unit_tests = b.addTest(.{
            .root_module = mod,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        test_step.dependOn(&run_exe_unit_tests.step);
    }

    // uuid command

    const uuid_exe = b.addExecutable(.{
        .name = "uuid",
        .target = target,
        .optimize = optimize,
    });

    uuid_exe.addCSourceFile(.{ .file = b.path("uuid.cpp") });
    uuid_exe.linkLibCpp();

    b.installArtifact(uuid_exe);

    const uuid_run_step = b.addRunArtifact(uuid_exe);

    const uuid_step = b.step("uuid", "Build and run uuid.cpp");
    uuid_step.dependOn(&uuid_run_step.step);
}
