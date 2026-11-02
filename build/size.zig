const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.InvalidArguments;

    const binary = try std.Io.Dir.cwd().openFile(init.io, args[1], .{});
    defer binary.close(init.io);
    const size = (try binary.stat(init.io)).size;

    var buffer: [128]u8 = undefined;
    const message = try std.fmt.bufPrint(&buffer, "chips size: {Bi:.2} ({d} bytes)\n", .{ size, size });
    try std.Io.File.stdout().writeStreamingAll(init.io, message);
}
