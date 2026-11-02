const std = @import("std");
const zeit = @import("zeit");
const Config = @import("../config.zig").Config;
const paint = @import("../paint.zig");

/// Renders the supplied local wall-clock label.
pub fn render(writer: *std.Io.Writer, label: []const u8, config: Config) std.Io.Writer.Error!void {
    try paint.chip(writer, .{ .text = label }, config);
}

/// Formats the current local time as HH:MM:SS, or a placeholder if the timezone cannot be loaded.
pub fn localTime(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ: *const std.process.Environ.Map,
    buffer: *[8]u8,
) []const u8 {
    const zone = localZone(allocator, io, environ) catch return "--:--:--";
    defer zone.deinit();
    const time = zeit.instant(.{ .now = io }, &zone).time();
    return std.fmt.bufPrint(buffer, "{d:0>2}:{d:0>2}:{d:0>2}", .{
        time.hour, time.minute, time.second,
    }) catch unreachable;
}

fn localZone(allocator: std.mem.Allocator, io: std.Io, environ: *const std.process.Environ.Map) !zeit.TimeZone {
    const config: zeit.EnvConfig = .{
        .tz = environ.get("TZ"),
        .tzdir = environ.get("TZDIR"),
    };
    if (config.tz) |name| {
        const path = if (std.mem.startsWith(u8, name, ":")) name[1..] else name;
        if (name.len > 0 and path.len == 0) return error.InvalidTimeZone;
        // zeit's local() expects a ':' prefix for IANA names and TZif paths.
        if (std.meta.stringToEnum(zeit.Location, path)) |location| {
            return zeit.loadTimeZone(allocator, io, location, config);
        }
        if (std.fs.path.isAbsolute(path)) {
            const prefixed = try std.fmt.allocPrint(allocator, ":{s}", .{path});
            defer allocator.free(prefixed);
            return zeit.local(allocator, io, .{ .tz = prefixed, .tzdir = config.tzdir });
        }
    }
    return zeit.local(allocator, io, config);
}
