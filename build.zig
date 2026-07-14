const std = @import("std");

const tests = [_][]const u8{
    "src/fft.zig",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.artifact("raylib");

    const raylib_translate_c = b.addTranslateC(.{
        .root_source_file = raylib_dep.path("src/raylib.h"),
        .target = target,
        .optimize = optimize,
    });

    const rlgl_translate_c = b.addTranslateC(.{
        .root_source_file = raylib_dep.path("src/rlgl.h"),
        .target = target,
        .optimize = optimize,
    });

    const win_translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/win.h"),
        .target = target,
        .optimize = optimize,
    });

    win_translate_c.linkSystemLibrary("ole32", .{});
    win_translate_c.linkSystemLibrary("oleAut32", .{});
    win_translate_c.linkSystemLibrary("avrt", .{});
    win_translate_c.linkSystemLibrary("uuid", .{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{
                .name = "raylib",
                .module = raylib_translate_c.createModule(),
            },
            .{
                .name = "rlgl",
                .module = rlgl_translate_c.createModule(),
            },
            .{
                .name = "win",
                .module = win_translate_c.createModule(),
            },
        },
    });

    const exe = b.addExecutable(.{
        .name = "audio_analyser",
        .root_module = exe_mod,
    });

    if (optimize != .Debug and target.result.os.tag == .windows) {
        exe.subsystem = .Windows;
    }

    exe.root_module.linkLibrary(raylib);

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
            .link_libc = true,
        });
        const exe_unit_tests = b.addTest(.{
            .root_module = mod,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        test_step.dependOn(&run_exe_unit_tests.step);
    }

    // uuid command
    const uuid_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });

    const uuid_exe = b.addExecutable(.{
        .name = "uuid",
        .root_module = uuid_mod,
    });

    uuid_exe.root_module.addCSourceFile(.{ .file = b.path("uuid.cpp") });

    b.installArtifact(uuid_exe);

    const uuid_run_step = b.addRunArtifact(uuid_exe);

    const uuid_step = b.step("uuid", "Build and run uuid.cpp");
    uuid_step.dependOn(&uuid_run_step.step);
}
