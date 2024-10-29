const std = @import("std");
const http = std.http;
const heap = std.heap;
const zap = @import("zap");

const dom = @import("html/dom.zig");
const Element = @import("html/element.zig");

const PriceWeb = @import("price_web.zig");

const Errors = error{ NoUrl };

fn on_request(r: zap.Request) void {
    if (r.path) |path| {
        std.debug.print("requested path: {s}\n", .{ path });
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var listener = zap.Endpoint.Listener.init(
        allocator,
        .{
            .port = 3000,
            .on_request = on_request,
            .log = true,
            .public_folder = "html",
            .max_clients = 5000,
            .max_body_size = 100 * 1024 * 1024,
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

// pub fn main() !void {
//     var gpa = heap.GeneralPurposeAllocator(.{}){};
//     defer std.debug.assert(gpa.deinit() == .ok);
//     const allocator = gpa.allocator();
//
//     var args = std.process.args();
//     _ = args.skip();
//
//     const url = args.next() orelse return Errors.NoUrl;
//     const html = try dom.getHtml(url, allocator);
//     defer allocator.free(html);
//     // std.debug.print("getHtml: {s}\n", .{html});
//
//     var t = try std.time.Timer.start();
//
//     var elements = std.ArrayList(Element).init(allocator);
//     defer elements.deinit();
//
//     try dom.getElements(html, &elements);
//     try dom.toElementsWithPrice(&elements);
//
//     for (elements.items) |element| {
//         element.print();
//     }
//
//     std.debug.print("elements.items.len: {}\nexecution time: {}\n", .{ elements.items.len, std.fmt.fmtDuration(t.read()) });
// }
