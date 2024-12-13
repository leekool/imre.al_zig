const std = @import("std");
const http = std.http;
const heap = std.heap;
const zap = @import("zap");

const Element = @import("html/element.zig");
const PriceWeb = @import("price_web.zig");
const XWeb = @import("x_web.zig");
const Dom = @import("html/dom.zig");

fn onRequest(r: zap.Request) void {
    if (r.path) |path| {
        std.debug.print("path: {s}\n", .{path});
    }

    r.setStatus(.not_found);
    r.sendBody("<html><body><h1>404</h1></body></html>") catch return;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var listener = zap.Endpoint.Listener.init(
        allocator,
        .{
            .port = 3000,
            .log = true,
            .public_folder = "public",
            .max_clients = 5000,
            .max_body_size = 100 * 1024 * 1024,
            .on_request = onRequest,
        },
    );
    defer listener.deinit();

    var priceWeb = PriceWeb.init(allocator, "/api/price");
    var xWeb = XWeb.init(allocator, "/api/x");

    try listener.register(priceWeb.endpoint());
    try listener.register(xWeb.endpoint());
    try listener.listen();

    std.debug.print("listening on 127.0.0.1:3000\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}
