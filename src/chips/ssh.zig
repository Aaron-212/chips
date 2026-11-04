const std = @import("std");
const Config = @import("../config.zig").Config;
const paint = @import("../paint.zig");

pub const Session = struct {
    username: []const u8,
    hostname: []const u8,
};

/// Reads SSH session metadata. The hostname borrows the supplied buffer.
pub fn read(environ: *const std.process.Environ.Map, buffer: *[std.posix.HOST_NAME_MAX]u8) ?Session {
    var connected = false;
    for ([_][]const u8{ "SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY" }) |key| {
        if (nonempty(environ, key) != null) connected = true;
    }
    if (!connected) return null;
    const username = nonempty(environ, "USER") orelse nonempty(environ, "LOGNAME") orelse return null;
    const hostname = std.posix.gethostname(buffer) catch return null;
    if (hostname.len == 0) return null;
    return .{ .username = username, .hostname = hostname };
}

/// Renders the username and hostname when SSH session metadata is available.
pub fn render(writer: *std.Io.Writer, allocator: std.mem.Allocator, session: ?Session, config: Config) !bool {
    const value = session orelse return false;
    const username = try paint.singleLine(allocator, value.username);
    defer allocator.free(username);
    const hostname = try paint.singleLine(allocator, value.hostname);
    defer allocator.free(hostname);
    try paint.multiChip(writer, &.{
        .{ .text = username, .fg = .black, .bg = .magenta },
        .{ .text = hostname },
    }, config);
    return true;
}

fn nonempty(environ: *const std.process.Environ.Map, key: []const u8) ?[]const u8 {
    const value = environ.get(key) orelse return null;
    return if (value.len > 0) value else null;
}
