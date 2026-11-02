const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    if (target.result.os.tag == .windows) @panic("Windows targets are not supported");
    const optimize = b.standardOptimizeOption(.{});
    const libgit2 = b.dependency("libgit2", .{ .target = target, .optimize = optimize });
    const git2 = libgit2.module("git2");
    const zeit = b.dependency("zeit", .{ .target = target, .optimize = optimize }).module("zeit");
    const uucode = b.dependency("uucode", .{
        .target = target,
        .optimize = optimize,
        .fields = @as([]const []const u8, &.{
            "grapheme_break",
            "wcwidth_standalone",
            "wcwidth_zero_in_grapheme",
            "is_emoji_vs_base",
        }),
    }).module("uucode");
    const module = chipsModule(b, target, optimize, git2, zeit, uucode, "chips");
    const exe = b.addExecutable(.{
        .name = "chips",
        .root_module = mainModule(b, target, optimize, module),
    });
    const install = b.addInstallArtifact(exe, .{});
    const size_tool = b.addExecutable(.{
        .name = "chips-size",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/size.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    const size = b.addRunArtifact(size_tool);
    size.addArtifactArg(exe);
    size.has_side_effects = true;
    size.step.dependOn(&install.step);
    b.getInstallStep().dependOn(&size.step);
    b.step("size", "Build and print the binary size").dependOn(&size.step);

    const run = b.addRunArtifact(exe);
    run.addPassthruArgs();
    b.step("run", "Render a prompt").dependOn(&run.step);

    // Reuse translated declarations without linking or building the C libraries.
    const git2_headers = b.createModule(.{
        .root_source_file = git2.root_source_file,
        .target = target,
        .optimize = optimize,
    });
    const check = b.addExecutable(.{
        .name = "chips-check",
        .root_module = mainModule(b, target, optimize, chipsModule(b, target, optimize, git2_headers, zeit, uucode, null)),
    });
    const size_check = b.addExecutable(.{
        .name = "chips-size-check",
        .root_module = size_tool.root_module,
    });
    const check_step = b.step("check", "Type-check without building libgit2 or emitting a binary");
    check_step.dependOn(&check.step);
    check_step.dependOn(&size_check.step);
}

fn chipsModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    git2: *std.Build.Module,
    zeit: *std.Build.Module,
    uucode: *std.Build.Module,
    name: ?[]const u8,
) *std.Build.Module {
    const options: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "git2", .module = git2 },
            .{ .name = "zeit", .module = zeit },
            .{ .name = "uucode", .module = uucode },
        },
    };
    return if (name) |value| b.addModule(value, options) else b.createModule(options);
}

fn mainModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    chips: *std.Build.Module,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "chips", .module = chips }},
    });
}
