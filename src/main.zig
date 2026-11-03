const std = @import("std");
const chips = @import("chips");

const usage =
    \\Usage: chips [OPTIONS]
    \\       chips _chips {nu|zsh}
    \\Render the chip prompt. Output has no trailing newline after the indicator.
    \\Use _chips to print a shell integration script.
    \\
    \\  --cwd PATH          Working directory (default: PWD or .)
    \\  --home PATH         Home directory to abbreviate (default: HOME)
    \\  --venv PATH         Use a virtual environment's directory name
    \\  --venv-prompt TEXT  Virtual environment label (default: VIRTUAL_ENV_PROMPT)
    \\  --status CODE       Previous exit code (default: 0)
    \\  --duration MS       Previous command duration (default: 0)
    \\  --columns COUNT     Terminal width for multiline alignment (default: 0)
    \\  --part PART         prompt, left, right, or indicator (default: prompt)
    \\  --indicator TEXT    Override the indicator text, for example in vi mode
    \\  --config JSON       Partial prompt configuration (see README.md)
    \\  --no-color          Disable ANSI colors (also honors NO_COLOR)
    \\  --help              Show this help
    \\
;

const ValueFlag = enum { cwd, home, venv, @"venv-prompt", status, duration, columns, part, indicator, config };

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.Writer.init(.stdout(), init.io, &stdout_buffer);
    if (args.len > 1 and std.mem.eql(u8, args[1], "_chips")) {
        if (args.len != 3) fail(init.io, "expected: chips _chips {{nu|zsh}}", .{});
        const script = if (std.mem.eql(u8, args[2], "nu"))
            @embedFile("shell/chips.nu")
        else if (std.mem.eql(u8, args[2], "zsh"))
            @embedFile("shell/chips.zsh")
        else
            fail(init.io, "unsupported shell: {s} (expected nu or zsh)", .{args[2]});
        try stdout.interface.writeAll(script);
        try stdout.interface.flush();
        return;
    }
    var context: chips.Context = .{
        .cwd = init.environ_map.get("PWD") orelse try std.process.currentPathAlloc(init.io, allocator),
        .home = init.environ_map.get("HOME") orelse "",
        .venv = init.environ_map.get("VIRTUAL_ENV_PROMPT") orelse "",
    };
    var part: chips.Part = .prompt;
    var config_json: []const u8 = "{}";
    var no_color = init.environ_map.contains("NO_COLOR");
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const flag = args[index];
        if (std.mem.eql(u8, flag, "--help")) {
            try stdout.interface.writeAll(usage);
            try stdout.interface.flush();
            return;
        }
        if (std.mem.eql(u8, flag, "--no-color")) {
            no_color = true;
            continue;
        }
        if (!std.mem.startsWith(u8, flag, "--")) fail(init.io, "unknown option: {s}", .{flag});
        const option = std.meta.stringToEnum(ValueFlag, flag[2..]) orelse
            fail(init.io, "unknown option: {s}", .{flag});
        index += 1;
        if (index == args.len) fail(init.io, "missing value for {s}", .{flag});
        const value = args[index];
        switch (option) {
            .cwd => context.cwd = value,
            .home => context.home = value,
            .venv => context.venv = std.fs.path.basename(value),
            .@"venv-prompt" => context.venv = value,
            .status => context.status = std.fmt.parseInt(i32, value, 10) catch
                fail(init.io, "invalid exit code: {s}", .{value}),
            .duration => context.duration_ms = std.fmt.parseInt(u64, value, 10) catch
                fail(init.io, "invalid duration: {s}", .{value}),
            .columns => context.columns = std.fmt.parseInt(usize, value, 10) catch
                fail(init.io, "invalid terminal width: {s}", .{value}),
            .part => part = std.meta.stringToEnum(chips.Part, value) orelse
                fail(init.io, "invalid prompt part: {s}", .{value}),
            .indicator => context.indicator = value,
            .config => config_json = value,
        }
    }
    const parsed = chips.Config.parse(allocator, config_json) catch |err|
        fail(init.io, "invalid configuration: {s}", .{@errorName(err)});
    defer parsed.deinit();
    var config = parsed.value;
    config.color = config.color and !no_color;
    if (!std.fs.path.isAbsolute(context.cwd)) {
        const cwd = try std.process.currentPathAlloc(init.io, allocator);
        context.cwd = try std.fs.path.resolveAlloc(allocator, &.{ cwd, context.cwd });
    }
    const start = std.Io.Clock.Timestamp.now(init.io, .awake);
    var clock_buffer: [8]u8 = undefined;
    context.clock = chips.clock.localTime(allocator, init.io, init.environ_map, &clock_buffer);
    const has_left = part == .prompt or part == .left;
    if (has_left and config.show_git) context.repository = try chips.location.read(allocator, init.io, context.cwd);
    defer if (context.repository) |*repository| repository.deinit(allocator);
    if (has_left and config.debug) {
        try chips.render(&stdout.interface, allocator, context, config, .left);
        const elapsed = start.durationTo(.now(init.io, .awake)).raw.toNanoseconds();
        const hundredths = @divTrunc(@max(elapsed, 0), 10000);
        try stdout.interface.print("{d}.{d:0>2}ms ", .{ @divTrunc(hundredths, 100), @mod(hundredths, 100) });
        if (part == .prompt) try chips.render(&stdout.interface, allocator, context, config, .indicator);
    } else {
        try chips.render(&stdout.interface, allocator, context, config, part);
    }
    try stdout.interface.flush();
}

fn fail(io: std.Io, comptime format: []const u8, args: anytype) noreturn {
    var buffer: [512]u8 = undefined;
    var stderr = std.Io.File.Writer.init(.stderr(), io, &buffer);
    stderr.interface.print("chips: " ++ format ++ "\nRun chips --help for usage.\n", args) catch {};
    stderr.interface.flush() catch {};
    std.process.exit(2);
}
