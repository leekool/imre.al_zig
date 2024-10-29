const std = @import("std");
const http = std.http;
const heap = std.heap;

const h = @import("./html.zig");
const Element = @import("./element.zig");

const Errors = error{ NoUrl };

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var args = std.process.args();
    _ = args.skip();

    const url = args.next() orelse return Errors.NoUrl;
    const html = try h.getHtml(url, allocator);
    defer allocator.free(html);
    // std.debug.print("getHtml: {s}\n", .{html});

    var t = try std.time.Timer.start();

    var elements = std.ArrayList(Element).init(allocator);
    defer elements.deinit();

    try h.getElements(html, &elements);
    try h.toElementsWithPrice(&elements);

    for (elements.items) |element| {
        element.print();
    }

    std.debug.print("elements.items.len: {}\nexecution time: {}\n", .{ elements.items.len, std.fmt.fmtDuration(t.read()) });
}

