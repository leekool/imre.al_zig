const std = @import("std");
const http = std.http;
const heap = std.heap;
const zap = @import("zap");

const Element = @import("html/element.zig");
const PriceWeb = @import("price_web.zig");
const Dom = @import("html/dom.zig");

fn onRequest(r: zap.Request) void {
    if (r.path) |path| {
        std.debug.print("requested path: {s}\n", .{path});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // testing
    var args = std.process.args();
    _ = args.skip();

    if (args.next()) |arg| {
        var dom = Dom.init(allocator);
        defer dom.deinit();

        try dom.getHtml(arg);
        // std.debug.print("{s}\n", .{ dom.html });
        return;
    }
    // -----

    var listener = zap.Endpoint.Listener.init(
        allocator,
        .{
            .port = 3000,
            .log = true,
            .max_clients = 5000,
            .max_body_size = 100 * 1024 * 1024,
            .on_request = onRequest,
            // .public_folder = "html",
        },
    );
    defer listener.deinit();

    var priceWeb = PriceWeb.init(allocator, "/price");
    // defer priceWeb.deinit();

    try listener.register(priceWeb.endpoint());

    try listener.listen();

    std.debug.print("listening on 127.0.0.1:3000\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}
