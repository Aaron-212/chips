const std = @import("std");
const paint = @import("paint.zig");
const duration = @import("chips/duration.zig");
const exit = @import("chips/exit.zig");
const venv = @import("chips/venv.zig");

pub const Config = @import("config.zig").Config;
pub const location = @import("chips/location.zig");
pub const clock = @import("chips/clock.zig");
pub const Part = enum { prompt, left, right, indicator };

/// Shell metadata and repository snapshot for one redraw.
pub const Context = struct {
    cwd: []const u8 = ".",
    home: []const u8 = "",
    venv: []const u8 = "",
    status: i32 = 0,
    duration_ms: u64 = 0,
    columns: usize = 0,
    clock: []const u8 = "00:00:00",
    repository: ?location.Repository = null,
    indicator: ?[]const u8 = null,
};

/// Formats a prompt part. All repository I/O is performed by the caller.
pub fn render(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    context: Context,
    config: Config,
    part: Part,
) !void {
    switch (part) {
        .prompt => {
            try renderLeft(writer, allocator, context, config);
            try renderIndicator(writer, context, config);
        },
        .left => try renderLeft(writer, allocator, context, config),
        .right => if (!config.multiline) try renderRight(writer, context, config),
        .indicator => try renderIndicator(writer, context, config),
    }
}

fn renderLeft(writer: *std.Io.Writer, allocator: std.mem.Allocator, context: Context, config: Config) !void {
    if (config.newline_before_prompt) try writer.writeByte('\n');
    var left: std.Io.Writer.Allocating = .init(allocator);
    defer left.deinit();
    if (try venv.render(&left.writer, allocator, context.venv, config)) try left.writer.writeByte(' ');
    try location.render(&left.writer, allocator, context.cwd, context.home, context.repository, config);
    try writer.writeAll(left.written());
    if (!config.multiline) return writer.writeByte(' ');

    var right: std.Io.Writer.Allocating = .init(allocator);
    defer right.deinit();
    try renderRight(&right.writer, context, config);
    const used = paint.width(left.written()) + paint.width(right.written());
    if (context.columns > used) {
        try writer.splatByteAll(' ', context.columns - used);
        try writer.writeAll(right.written());
    }
    try writer.writeByte('\n');
}

fn renderRight(writer: *std.Io.Writer, context: Context, config: Config) std.Io.Writer.Error!void {
    if (try duration.render(writer, context.duration_ms, config)) try writer.writeByte(' ');
    if (try exit.render(writer, context.status, config)) try writer.writeByte(' ');
    try clock.render(writer, context.clock, config);
}

fn renderIndicator(writer: *std.Io.Writer, context: Context, config: Config) std.Io.Writer.Error!void {
    const value = context.indicator orelse config.indicator;
    if (!config.color) return writer.writeAll(value);
    try paint.style(writer, value, if (context.status == 0) .green else .red, null);
}
