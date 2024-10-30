const std = @import("std");
const zap = @import("zap");
const dom = @import("html/dom.zig");
const Element = @import("html/element.zig");

pub const Self = @This();

alloc: std.mem.Allocator = undefined,
ep: zap.Endpoint = undefined,

pub fn init(a: std.mem.Allocator, path: []const u8) Self {
    return .{
        .alloc = a, 
        .ep = zap.Endpoint.init(.{
            .path = path,
            .get = getPrices
        }),
    };
}

pub fn endpoint(self: *Self) *zap.Endpoint {
    return &self.ep;
}

fn getPrices(e: *zap.Endpoint, r: zap.Request) void {
    const self: *Self = @fieldParentPtr("ep", e);

    if (r.path) |path| {
        _ = path;
        
        const url = "https://lindypress.net/book?pk=5";
        const html = dom.getHtml(url, self.alloc) catch return;
        defer self.alloc.free(html);

        var elements = std.ArrayList(Element).init(self.alloc);
        defer elements.deinit();

        dom.getElements(html, &elements) catch return;
        dom.toElementsWithPrice(&elements) catch return;

        // std.json.stringify(elements.items[0], .{}, elements.items[0].writer()) catch return;

        elements.items[0].print();
        
        var string = std.ArrayList(u8).init(self.alloc);
        defer string.deinit();

        std.json.stringify(.{ .price = elements.items[0].price, .inner_html = elements.items[0].inner_html }, .{}, string.writer()) catch return;
        r.sendJson(string.items) catch return;

        // var json_buf: [256]u8 = undefined;
        // if (zap.stringifyBuf(&json_buf, .{ .status = "OK" }, .{})) |json| {
        //     r.sendJson(json) catch return;
        // }
    }
}
