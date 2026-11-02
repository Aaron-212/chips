const std = @import("std");
const c = @import("git2");
const Config = @import("../config.zig").Config;
const paint = @import("../paint.zig");

/// A snapshot copied out of libgit2; all strings belong to the caller's allocator.
pub const Repository = struct {
    project: []const u8,
    branch: []const u8,
    status: []const u8,

    pub fn deinit(self: *Repository, allocator: std.mem.Allocator) void {
        allocator.free(self.project);
        allocator.free(self.branch);
        allocator.free(self.status);
        self.* = undefined;
    }
};

/// Renders directory or repository chips from the supplied location context.
pub fn render(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    cwd: []const u8,
    home_path: []const u8,
    repository: ?Repository,
    config: Config,
) !void {
    if (config.show_git) {
        if (repository) |repo| {
            const project = try paint.singleLine(allocator, repo.project);
            defer allocator.free(project);
            const branch = try paint.singleLine(allocator, repo.branch);
            defer allocator.free(branch);
            try paint.splitChip(writer, .{ .text = "git", .bg = .magenta }, .{ .text = project }, config);
            try writer.writeByte(' ');
            try paint.splitChip(writer, .{ .text = branch, .bg = .magenta }, .{ .text = repo.status, .bg = .blue }, config);
            return;
        }
    }
    const home = std.mem.trimEnd(u8, home_path, "/");
    const abbreviated = home.len > 0 and std.mem.startsWith(u8, cwd, home) and
        (cwd.len == home.len or cwd[home.len] == '/');
    const location = if (abbreviated)
        try std.fmt.allocPrint(allocator, "~{s}", .{cwd[home.len..]})
    else
        try allocator.dupe(u8, cwd);
    defer allocator.free(location);
    const label = try paint.singleLine(allocator, location);
    defer allocator.free(label);
    try paint.chip(writer, .{ .text = label }, config);
}

/// Discovers a worktree from an absolute cwd. Git failures fall back to the directory prompt.
/// The caller must release a returned snapshot with `Repository.deinit` using the same allocator.
pub fn read(allocator: std.mem.Allocator, cwd: []const u8) std.mem.Allocator.Error!?Repository {
    if (c.git_libgit2_init() < 0) return null;
    defer _ = c.git_libgit2_shutdown();

    var repo: ?*c.git_repository = null;
    const path = try allocator.dupeSentinel(u8, cwd, 0);
    defer allocator.free(path);
    if (c.git_repository_open_ext(&repo, path, 0, null) != 0) return null;
    defer c.git_repository_free(repo);

    const workdir = c.git_repository_workdir(repo);
    if (workdir == null) return null;
    const root = std.mem.trimEnd(u8, std.mem.span(workdir), "/");
    const relative = try std.fs.path.relativeAlloc(allocator, root, null, root, cwd);
    defer allocator.free(relative);
    if (std.mem.eql(u8, relative, "..") or std.mem.startsWith(u8, relative, "../")) return null;
    const project = if (relative.len == 0 or std.mem.eql(u8, relative, "."))
        try allocator.dupe(u8, std.fs.path.basename(root))
    else
        try std.fs.path.join(allocator, &.{ std.fs.path.basename(root), relative });
    errdefer allocator.free(project);
    const branch = try branchName(allocator, repo);
    errdefer allocator.free(branch);
    return .{
        .project = project,
        .branch = branch,
        .status = try repositoryStatus(allocator, repo),
    };
}

fn branchName(allocator: std.mem.Allocator, repo: ?*c.git_repository) std.mem.Allocator.Error![]const u8 {
    var head: ?*c.git_reference = null;
    const result = c.git_repository_head(&head, repo);
    if (result == c.GIT_EUNBORNBRANCH) {
        if (c.git_reference_lookup(&head, repo, "HEAD") != 0) return allocator.dupe(u8, "unknown");
        defer c.git_reference_free(head);
        const target = c.git_reference_symbolic_target(head);
        if (target == null) return allocator.dupe(u8, "unknown");
        const name = std.mem.span(target);
        const prefix = "refs/heads/";
        return std.fmt.allocPrint(allocator, ":{s}", .{
            if (std.mem.startsWith(u8, name, prefix)) name[prefix.len..] else name,
        });
    }
    if (result != 0) return allocator.dupe(u8, "unknown");
    defer c.git_reference_free(head);

    if (c.git_repository_head_detached(repo) == 1) {
        const oid = c.git_reference_target(head);
        if (oid == null) return allocator.dupe(u8, "unknown");
        var object: ?*c.git_object = null;
        if (c.git_object_lookup(&object, repo, oid, c.GIT_OBJECT_ANY) != 0)
            return allocator.dupe(u8, "unknown");
        defer c.git_object_free(object);
        var short_id: c.git_buf = std.mem.zeroes(c.git_buf);
        defer c.git_buf_dispose(&short_id);
        if (c.git_object_short_id(&short_id, object) != 0) return allocator.dupe(u8, "unknown");
        return std.fmt.allocPrint(allocator, "@{s}", .{short_id.ptr[0..short_id.size]});
    }
    const name = c.git_reference_shorthand(head);
    if (name == null) return allocator.dupe(u8, "unknown");
    return std.fmt.allocPrint(allocator, ":{s}", .{std.mem.span(name)});
}

fn repositoryStatus(allocator: std.mem.Allocator, repo: ?*c.git_repository) std.mem.Allocator.Error![]const u8 {
    const worktree = try workingTreeStatus(allocator, repo);
    defer allocator.free(worktree);

    var stashes: usize = 0;
    if (c.git_stash_foreach(repo, countStash, &stashes) != 0) stashes = 0;
    const commits = upstreamCounts(repo);
    var buffer: [128]u8 = undefined;
    var counts: std.Io.Writer = .fixed(&buffer);
    if (stashes > 0) counts.print("${d}", .{stashes}) catch unreachable;
    if (commits.ahead > 0) counts.print("↑{d}", .{commits.ahead}) catch unreachable;
    if (commits.behind > 0) counts.print("↓{d}", .{commits.behind}) catch unreachable;
    return std.fmt.allocPrint(allocator, "{s}{s}", .{
        if (counts.end > 0 and std.mem.eql(u8, worktree, "✓")) "" else worktree,
        counts.buffered(),
    });
}

fn countStash(_: usize, _: [*c]const u8, _: [*c]const c.git_oid, payload: ?*anyopaque) callconv(.c) c_int {
    const count: *usize = @ptrCast(@alignCast(payload.?));
    count.* += 1;
    return 0;
}

const CommitCounts = struct { ahead: usize = 0, behind: usize = 0 };

fn upstreamCounts(repo: ?*c.git_repository) CommitCounts {
    var head: ?*c.git_reference = null;
    if (c.git_repository_head(&head, repo) != 0) return .{};
    defer c.git_reference_free(head);
    if (c.git_reference_is_branch(head) != 1) return .{};

    var upstream: ?*c.git_reference = null;
    if (c.git_branch_upstream(&upstream, head) != 0) return .{};
    defer c.git_reference_free(upstream);
    const local_oid = c.git_reference_target(head);
    const upstream_oid = c.git_reference_target(upstream);
    if (local_oid == null or upstream_oid == null) return .{};

    var counts: CommitCounts = .{};
    if (c.git_graph_ahead_behind(&counts.ahead, &counts.behind, repo, local_oid, upstream_oid) != 0) return .{};
    return counts;
}

fn workingTreeStatus(allocator: std.mem.Allocator, repo: ?*c.git_repository) std.mem.Allocator.Error![]const u8 {
    var options: c.git_status_options = undefined;
    if (c.git_status_options_init(&options, c.GIT_STATUS_OPTIONS_VERSION) != 0)
        return allocator.dupe(u8, "-");
    // Match --untracked-files=normal, without writing the index's stat cache.
    options.flags = c.GIT_STATUS_OPT_INCLUDE_UNTRACKED | c.GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX |
        c.GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR;
    var list: ?*c.git_status_list = null;
    if (c.git_status_list_new(&list, repo, &options) != 0) return allocator.dupe(u8, "-");
    defer c.git_status_list_free(list);

    var conflicts = false;
    var staged = false;
    var modified = false;
    var renamed = false;
    var deleted = false;
    var untracked = false;
    const index_mask = c.GIT_STATUS_INDEX_NEW | c.GIT_STATUS_INDEX_MODIFIED |
        c.GIT_STATUS_INDEX_DELETED | c.GIT_STATUS_INDEX_RENAMED | c.GIT_STATUS_INDEX_TYPECHANGE;
    const workdir_mask = c.GIT_STATUS_WT_MODIFIED | c.GIT_STATUS_WT_DELETED |
        c.GIT_STATUS_WT_RENAMED | c.GIT_STATUS_WT_TYPECHANGE | c.GIT_STATUS_WT_UNREADABLE;
    for (0..c.git_status_list_entrycount(list)) |index| {
        const entry = c.git_status_byindex(list, index);
        if (entry == null) continue;
        const flags = entry.*.status;
        if (flags & c.GIT_STATUS_CONFLICTED != 0) {
            conflicts = true;
            continue;
        }
        staged = staged or flags & index_mask != 0;
        modified = modified or flags & workdir_mask != 0;
        renamed = renamed or flags & (c.GIT_STATUS_INDEX_RENAMED | c.GIT_STATUS_WT_RENAMED) != 0;
        deleted = deleted or flags & (c.GIT_STATUS_INDEX_DELETED | c.GIT_STATUS_WT_DELETED) != 0;
        untracked = untracked or flags & c.GIT_STATUS_WT_NEW != 0;
    }
    if (!conflicts and !staged and !modified and !renamed and !deleted and !untracked) return allocator.dupe(u8, "✓");
    return std.fmt.allocPrint(allocator, "{s}{s}{s}{s}{s}{s}", .{
        if (conflicts) "↕" else "",
        if (staged) "+" else "",
        if (modified) "!" else "",
        if (renamed) "→" else "",
        if (deleted) "✗" else "",
        if (untracked) "?" else "",
    });
}
