const std = @import("std");
const Config = @import("../config.zig").Config;
const paint = @import("../paint.zig");

/// Renders command duration if it reaches the configured threshold.
/// Returns true when a chip was written.
pub fn render(writer: *std.Io.Writer, milliseconds: u64, config: Config) std.Io.Writer.Error!bool {
    if (milliseconds < config.min_duration_ms) return false;
    // Both formats fit in 64 bytes even at the maximum u64 duration.
    var buffer: [64]u8 = undefined;
    var label: std.Io.Writer = .fixed(&buffer);
    format(&label, milliseconds, config.human_readable_duration) catch unreachable;
    try paint.chip(writer, .{ .text = label.buffered() }, config);
    return true;
}

fn format(writer: *std.Io.Writer, milliseconds: u64, human_readable: bool) std.Io.Writer.Error!void {
    if (!human_readable) {
        const tenths = milliseconds / 100 + @intFromBool(milliseconds % 100 >= 50);
        if (tenths % 10 == 0) return writer.print("{d}s", .{tenths / 10});
        return writer.print("{d}.{d}s", .{ tenths / 10, tenths % 10 });
    }
    if (milliseconds == 0) return writer.writeAll("0sec");

    const units = [_]struct { milliseconds: u64, suffix: []const u8 }{
        .{ .milliseconds = 3_600_000, .suffix = "h" },
        .{ .milliseconds = 60_000, .suffix = "m" },
        .{ .milliseconds = 1_000, .suffix = "s" },
        .{ .milliseconds = 1, .suffix = "ms" },
    };
    var remaining = milliseconds;
    for (units) |unit| {
        if (unit.milliseconds == 1 and milliseconds > 60_000) break;
        const count = remaining / unit.milliseconds;
        remaining %= unit.milliseconds;
        if (count > 0) {
            try writer.print("{d}{s}", .{ count, unit.suffix });
        }
    }
}
