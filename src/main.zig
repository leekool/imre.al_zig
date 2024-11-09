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

    // const CERT_FILE = "mycert.pem";
    // const KEY_FILE = "mykey.pem";
    //
    // std.fs.cwd().access(CERT_FILE, .{}) catch |err| {
    //     std.debug.print("error: file `{s}`: {any}\n", .{ CERT_FILE, err });
    //     std.process.exit(1);
    // };
    //
    // std.fs.cwd().access(KEY_FILE, .{}) catch |err| {
    //     std.debug.print("error: file `{s}`: {any}\n", .{ KEY_FILE, err });
    //     std.process.exit(1);
    // };
    //
    // const tls = try zap.Tls.init(.{
    //     .server_name = "localhost:4443",
    //     .public_certificate_file = CERT_FILE,
    //     .private_key_file = KEY_FILE,
    // });
    // defer tls.deinit();

    var listener = zap.Endpoint.Listener.init(
        allocator,
        .{
            .port = 3000,
            .log = true,
            .max_clients = 5000,
            .max_body_size = 100 * 1024 * 1024,
            .on_request = onRequest,
            // .tls = tls,
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
