const std = @import("std");
const Config = @import("../config.zig").Config;
const paint = @import("../paint.zig");

/// Renders nonzero exit codes. Returns true when a chip was written.
pub fn render(writer: *std.Io.Writer, status: i32, config: Config) std.Io.Writer.Error!bool {
    if (status == 0) return false;
    var buffer: [32]u8 = undefined;
    const label = signalName(status) orelse (std.fmt.bufPrint(&buffer, "{d}", .{status}) catch unreachable);
    try paint.multiChip(writer, &.{ .{ .text = "exit", .bg = .red }, .{ .text = label } }, config);
    return true;
}

fn signalName(status: i32) ?[]const u8 {
    const Signal = std.posix.SIG;
    return switch (status) {
        // Conventional shell statuses: 128 + the signal number.
        128 + @backingInt(Signal.HUP) => "SIGHUP",
        128 + @backingInt(Signal.INT) => "SIGINT",
        128 + @backingInt(Signal.QUIT) => "SIGQUIT",
        128 + @backingInt(Signal.ILL) => "SIGILL",
        128 + @backingInt(Signal.TRAP) => "SIGTRAP",
        128 + @backingInt(Signal.ABRT) => "SIGABRT",
        128 + @backingInt(Signal.BUS) => "SIGBUS",
        128 + @backingInt(Signal.FPE) => "SIGFPE",
        128 + @backingInt(Signal.KILL) => "SIGKILL",
        128 + @backingInt(Signal.USR1) => "SIGUSR1",
        128 + @backingInt(Signal.SEGV) => "SIGSEGV",
        128 + @backingInt(Signal.USR2) => "SIGUSR2",
        128 + @backingInt(Signal.PIPE) => "SIGPIPE",
        128 + @backingInt(Signal.ALRM) => "SIGALRM",
        128 + @backingInt(Signal.TERM) => "SIGTERM",
        128 + @backingInt(Signal.XCPU) => "SIGXCPU",
        128 + @backingInt(Signal.XFSZ) => "SIGXFSZ",

        // Nushell statuses: the negative signal number.
        -@as(i32, @backingInt(Signal.HUP)) => "SIGHUP",
        -@as(i32, @backingInt(Signal.INT)) => "SIGINT",
        -@as(i32, @backingInt(Signal.QUIT)) => "SIGQUIT",
        -@as(i32, @backingInt(Signal.ILL)) => "SIGILL",
        -@as(i32, @backingInt(Signal.TRAP)) => "SIGTRAP",
        -@as(i32, @backingInt(Signal.ABRT)) => "SIGABRT",
        -@as(i32, @backingInt(Signal.BUS)) => "SIGBUS",
        -@as(i32, @backingInt(Signal.FPE)) => "SIGFPE",
        -@as(i32, @backingInt(Signal.KILL)) => "SIGKILL",
        -@as(i32, @backingInt(Signal.USR1)) => "SIGUSR1",
        -@as(i32, @backingInt(Signal.SEGV)) => "SIGSEGV",
        -@as(i32, @backingInt(Signal.USR2)) => "SIGUSR2",
        -@as(i32, @backingInt(Signal.PIPE)) => "SIGPIPE",
        -@as(i32, @backingInt(Signal.ALRM)) => "SIGALRM",
        -@as(i32, @backingInt(Signal.TERM)) => "SIGTERM",
        -@as(i32, @backingInt(Signal.XCPU)) => "SIGXCPU",
        -@as(i32, @backingInt(Signal.XFSZ)) => "SIGXFSZ",
        else => null,
    };
}
