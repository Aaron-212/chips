const std = @import("std");
const Config = @import("../config.zig").Config;
const paint = @import("../paint.zig");

/// Renders a nonempty virtual-environment label. Returns true when a chip was written.
pub fn render(writer: *std.Io.Writer, allocator: std.mem.Allocator, prompt: []const u8, config: Config) !bool {
    if (prompt.len == 0) return false;
    const label = try paint.singleLine(allocator, prompt);
    defer allocator.free(label);
    try paint.splitChip(writer, .{ .text = "venv", .fg = .black, .bg = .cyan }, .{ .text = label }, config);
    return true;
}
