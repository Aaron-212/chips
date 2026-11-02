const std = @import("std");

/// Prompt options, matching the original Nushell implementation.
pub const Config = struct {
    color: bool = true,
    debug: bool = false,
    chip_start: []const u8 = "\u{e0b6}",
    chip_end: []const u8 = "\u{e0b4}",
    show_git: bool = true,
    min_duration_ms: u64 = 2000,
    human_readable_duration: bool = true,
    newline_before_prompt: bool = true,
    multiline: bool = true,
    indicator: []const u8 = "\u{276f} ",

    /// Parses partial JSON options. Rejects unknown fields and invalid types.
    pub fn parse(allocator: std.mem.Allocator, json: []const u8) !std.json.Parsed(Config) {
        return std.json.parseFromSlice(Config, allocator, json, .{ .allocate = .alloc_always });
    }
};
