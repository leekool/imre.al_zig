const std = @import("std");
const http = std.http;
const heap = std.heap;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const html = try getHtml("https://example.com", allocator);
    defer allocator.free(html);

    std.debug.print("getHtml response: {s}\n", .{html});
}

pub fn getHtml(url: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var c = http.Client{ .allocator = allocator };
    defer c.deinit();

    var body_container = std.ArrayList(u8).init(allocator);

    const fetch_options = http.Client.FetchOptions{ 
        .location = http.Client.FetchOptions.Location{
            .url = url,
        }, 
        .response_storage = .{ .dynamic = &body_container } 
    };

    const res = try c.fetch(fetch_options);
    const body = try body_container.toOwnedSlice();

    if (res.status != .ok) std.log.err("getHtml failed: {s}\n", .{body});

    return body;
}
