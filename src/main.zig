const std = @import("std");
const http = std.http;
const heap = std.heap;

pub const Errors = error{ TagNotFound };

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const html = try getHtml("https://example.com", allocator);
    std.debug.print("getHtml: {s}\n", .{html});
    defer allocator.free(html);


    const div = try getElementContents(html, "a", allocator);
    std.debug.print("getElementContents: {s}\n", .{div});
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

pub fn getElementContents(html: []const u8, tag: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const tag_open: []const u8 = try std.mem.concat(allocator, u8, &[_][]const u8{"<", tag});
    defer allocator.free(tag_open);

    const tag_close: []const u8 = try std.mem.concat(allocator, u8, &[_][]const u8{"</", tag, ">"});
    defer allocator.free(tag_close);
    
    const start_index_opt = std.mem.indexOf(u8, html, tag_open);
    const end_index_opt = std.mem.indexOf(u8, html, tag_close);

    if (start_index_opt == null or end_index_opt == null) {
        return Errors.TagNotFound;
    }
    
    const start_index = start_index_opt.? + std.mem.indexOf(u8, html[start_index_opt.?..], ">").? + 1;
    const end_index = end_index_opt.?; 
    
    const substring = html[start_index..end_index];
    return substring;
}
