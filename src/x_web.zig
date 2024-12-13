const std = @import("std");
const zap = @import("zap");
const Dom = @import("html/dom.zig");
const Element = @import("html/element.zig");

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

    // works as at 13/12/24
    const part_one = "http://cdn.syndication.twimg.com/tweet-result?id=";
    const part_two = "&token=a";

    const id = path[e.settings.path.len + 1 ..];
    const url = std.mem.concat(self.alloc, u8, &[_][]const u8{ part_one, id, part_two }) catch return;

    var dom = Dom.init(self.alloc);
    defer dom.deinit();

    dom.getHtml(url) catch return;
    self.alloc.free(url);

    const json = dom.html orelse return;
    r.sendJson(json) catch return;
}
