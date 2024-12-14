const std = @import("std");
const zap = @import("zap");
const Dom = @import("html/dom.zig");
const Tweet = @import("tweet.zig");

pub const Self = @This();

alloc: std.mem.Allocator = undefined,
ep: zap.Endpoint = undefined,

pub fn init(a: std.mem.Allocator, path: []const u8) Self {
    return .{
        .alloc = a,
        .ep = zap.Endpoint.init(.{ .path = path, .get = getTweet }),
    };
}

pub fn endpoint(self: *Self) *zap.Endpoint {
    return &self.ep;
}

fn getTweet(e: *zap.Endpoint, r: zap.Request) void {
    const self: *Self = @fieldParentPtr("ep", e);
    const path = r.path orelse return;

    if (path.len <= e.settings.path.len + 2 or path[e.settings.path.len] != '/') return;

    const tweet_id = path[e.settings.path.len + 1 ..];
    var tweet = Tweet.init(self.alloc, tweet_id) catch |err| {
        std.debug.print("[getTweet] Tweet.init: {}\n", .{err});
        return;
    };
    defer tweet.deinit(self.alloc);

    const json = tweet.stringify(self.alloc) catch return;
    defer self.alloc.free(json);

    r.sendJson(json) catch |err| {
        std.debug.print("[getTweet] r.sendJson: {}\n", .{err});
        return;
    };
}
