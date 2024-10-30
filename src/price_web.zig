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
        .ep = zap.Endpoint.init(.{ .path = path, .get = getPrices }),
    };
}

pub fn endpoint(self: *Self) *zap.Endpoint {
    return &self.ep;
}

fn getPrices(e: *zap.Endpoint, r: zap.Request) void {
    const self: *Self = @fieldParentPtr("ep", e);
    const path = r.path orelse return;

    if (path.len <= e.settings.path.len + 2 or path[e.settings.path.len] != '/') return;

    var url = path[e.settings.path.len + 1 ..];

    // need to find out why defer causes a segmentation fault...
    if (r.query) |query| {
        url = std.mem.concat(self.alloc, u8, &[_][]const u8{ url, "?", query }) catch return;
        // defer self.alloc.free(url);
    }

    var dom = Dom.init(self.alloc);
    defer dom.deinit();

    // dom.getHtml(if (r.query != null) query_url else path_url) catch return;
    dom.getHtml(url) catch return;
    if (r.query != null) self.alloc.free(url);

    dom.getElements() catch return;
    dom.toElementsWithPrice() catch return;

    const json = dom.elementsToJson() catch return;
    defer self.alloc.free(json);

    r.sendJson(json) catch return;
}
