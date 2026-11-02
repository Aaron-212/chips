const std = @import("std");
const Config = @import("config.zig").Config;
const uucode = @import("uucode");

pub const Color = enum(u8) {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    default = 39,
    bright_black = 90,
    bright_red = 91,
    bright_green = 92,
    bright_yellow = 93,
    bright_blue = 94,
    bright_magenta = 95,
    bright_cyan = 96,
    bright_white = 97,
};

pub const Segment = struct {
    text: []const u8,
    fg: Color = .bright_white,
    bg: Color = .bright_black,
};

pub fn chip(writer: *std.Io.Writer, segment: Segment, config: Config) std.Io.Writer.Error!void {
    if (!config.color) return writer.writeAll(segment.text);
    try style(writer, config.chip_start, segment.bg, null);
    try style(writer, segment.text, segment.fg, segment.bg);
    try style(writer, config.chip_end, segment.bg, null);
}

pub fn multiChip(writer: *std.Io.Writer, segments: []const Segment, config: Config) std.Io.Writer.Error!void {
    if (segments.len == 0) return;
    if (segments.len == 1) return chip(writer, segments[0], config);
    if (!config.color) {
        for (segments, 0..) |segment, index| {
            if (index > 0) try writer.writeByte(' ');
            try writer.writeAll(segment.text);
        }
        return;
    }
    try style(writer, config.chip_start, segments[0].bg, null);
    for (segments, 0..) |segment, index| {
        try writer.print("\x1b[0;{d};{d}m{s}{s}{s}\x1b[0m", .{
            @backingInt(segment.fg),
            background(segment.bg),
            if (index > 0) " " else "",
            segment.text,
            if (index < segments.len - 1) " " else "",
        });
    }
    try style(writer, config.chip_end, segments[segments.len - 1].bg, null);
}

pub fn style(writer: *std.Io.Writer, value: []const u8, fg: Color, bg: ?Color) std.Io.Writer.Error!void {
    if (bg) |color| {
        try writer.print("\x1b[0;{d};{d}m{s}\x1b[0m", .{ @backingInt(fg), background(color), value });
    } else {
        try writer.print("\x1b[0;{d}m{s}\x1b[0m", .{ @backingInt(fg), value });
    }
}

fn background(color: Color) u8 {
    return @backingInt(color) + 10;
}

/// Removes terminal escape sequences and replaces control characters with spaces.
/// The caller owns the returned slice and must free it with `allocator`.
pub fn singleLine(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    var index: usize = 0;
    while (index < value.len) {
        if (value[index] == 0x1b) {
            index = escapeEnd(value, index);
            continue;
        }
        const byte = value[index];
        try out.writer.writeByte(if (byte < 0x20 or byte == 0x7f) ' ' else byte);
        index += 1;
    }
    return out.toOwnedSlice();
}

fn escapeEnd(value: []const u8, start: usize) usize {
    var index = start + 1;
    if (index == value.len) return index;
    const kind = value[index];
    index += 1;
    if (kind == '[') {
        while (index < value.len) : (index += 1) {
            if (value[index] >= 0x40 and value[index] <= 0x7e) return index + 1;
        }
    } else if (kind == ']' or kind == 'P' or kind == '_' or kind == '^') {
        while (index < value.len) : (index += 1) {
            if (value[index] == 7) return index + 1;
            if (value[index] == 0x1b and index + 1 < value.len and value[index + 1] == '\\') return index + 2;
        }
    }
    return index;
}

/// Measures grapheme display cells, excluding terminal escape sequences.
pub fn width(value: []const u8) usize {
    var iterator = uucode.grapheme.Iterator(AnsiIterator).init(.{ .value = value });
    return uucode.grapheme.wcwidthRemaining(&iterator);
}

// Skip escape sequences before decoding so styles cannot split a grapheme.
const AnsiIterator = struct {
    value: []const u8,
    i: usize = 0,

    pub fn next(self: *AnsiIterator) ?u21 {
        while (self.i < self.value.len and self.value[self.i] == 0x1b) {
            self.i = escapeEnd(self.value, self.i);
        }
        var iterator = uucode.utf8.Iterator.init(self.value[self.i..]);
        const codepoint = iterator.next();
        self.i += iterator.i;
        return codepoint;
    }
};
