const std = @import("std");
const http = std.http;
const heap = std.heap;

pub const Errors = error{TagNotFound};

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const html = try getHtml("https://example.com", allocator);
    defer allocator.free(html);
    std.debug.print("getHtml: {s}\n", .{html});

    // const el = try getElement(html);
    // std.debug.print("getElement: {s}\n", .{el});

    const elements = try getAllElements(html, allocator);
    defer allocator.free(elements);

    for (elements) |element| {
        std.debug.print("getAllElements: {s}\n", .{element});
    }
}

pub fn getHtml(url: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var c = http.Client{ .allocator = allocator };
    defer c.deinit();

    var body_container = std.ArrayList(u8).init(allocator);

    const fetch_options = http.Client.FetchOptions{ .location = http.Client.FetchOptions.Location{
        .url = url,
    }, .response_storage = .{ .dynamic = &body_container } };

    const res = try c.fetch(fetch_options);
    const body = try body_container.toOwnedSlice();

    if (res.status != .ok) std.log.err("getHtml failed: {s}\n", .{body});

    return body;
}

pub fn getFirstOpeningTag(html: []const u8) ?[]const u8 {
    var search_offset: usize = 0;

    while (true) {
        const start_opt = std.mem.indexOf(u8, html[search_offset..], "<");
        if (start_opt == null) return null;

        const start_index = start_opt.? + search_offset + 1;
        if (html[start_index] == '/') {
            search_offset = start_index + 1; // skip closing tags
            continue;
        }

        const end_opt = std.mem.indexOf(u8, html[start_index..], ">");
        if (end_opt == null) return null;

        const end_index = end_opt.? + start_index;

        var raw_open_tag = html[start_index..end_index];

        const space_index = std.mem.indexOf(u8, raw_open_tag, " ");
        const open_tag: []const u8 = if (space_index == null) raw_open_tag else raw_open_tag[0..space_index.?];

        // std.debug.print("[getFirstOpeningTag] raw_open_tag: {s}\n", .{raw_open_tag});
        std.debug.print("[getFirstOpeningTag] open_tag: {s}\n", .{open_tag});

        return open_tag;
    }
}

pub fn getClosingTagIndex(html: []const u8, tag_name: []const u8) ?usize {
    var search_offset: usize = 0;

    while (true) {
        const close_start_opt = std.mem.indexOf(u8, html[search_offset..], "</");
        if (close_start_opt == null) return null;

        const close_start_index = close_start_opt.? + search_offset;

        if (std.mem.startsWith(u8, html[close_start_index + 2 ..], tag_name)) {
            return close_start_index;
        }

        search_offset = close_start_index + 1;
    }
}

pub fn getElement(html: []const u8) ?[]const u8 {
    var search_offset: usize = 0;

    while (true) {
        const open_tag_opt = getFirstOpeningTag(html[search_offset..]);
        if (open_tag_opt == null) return null;
        const open_tag = open_tag_opt.?;

        const open_end_opt = std.mem.indexOf(u8, html[search_offset..], ">");
        if (open_end_opt == null) return null;
        const open_end = open_end_opt.? + search_offset + 1;

        const close_index_opt = getClosingTagIndex(html[open_end..], open_tag);
        if (close_index_opt == null) {
            search_offset = open_end + 1;
            continue;
        }

        const close_start_index = close_index_opt.? + open_end;

        return html[open_end..close_start_index];
    }

    return null;
}

pub fn getAllElements(html: []const u8, allocator: std.mem.Allocator) ![]const []const u8 {
    var element_list = std.ArrayList([]const u8).init(allocator);
    defer element_list.deinit();

    var search_offset: usize = 0;

    while (true) {
        const element_opt = getElement(html[search_offset..]);
        if (element_opt == null) break;
        
        const element = element_opt.?; 
        try element_list.append(element);

        const open_tag_end_opt = std.mem.indexOf(u8, html[search_offset..], ">");
        if (open_tag_end_opt == null) break;

        search_offset += open_tag_end_opt.? + 1;

        std.debug.print("[getAllElements] search_offset: {}, html.len: {}\n", .{search_offset, html.len});
    }

    return element_list.toOwnedSlice();
}

// pub fn getElement(html: []const u8, tag: []const u8, allocator: std.mem.Allocator) ![]const u8 {
//     const tag_open: []const u8 = try std.mem.concat(allocator, u8, &[_][]const u8{ "<", tag });
//     defer allocator.free(tag_open);
//
//     const tag_close: []const u8 = try std.mem.concat(allocator, u8, &[_][]const u8{ "</", tag, ">" });
//     defer allocator.free(tag_close);
//
//     const start_index_opt = std.mem.indexOf(u8, html, tag_open);
//     const end_index_opt = std.mem.indexOf(u8, html, tag_close);
//
//     if (start_index_opt == null or end_index_opt == null) {
//         return Errors.TagNotFound;
//     }
//
//     const start_index = start_index_opt.? + std.mem.indexOf(u8, html[start_index_opt.?..], ">").? + 1;
//     const end_index = end_index_opt.?;
//
//     const substring = html[start_index..end_index];
//     return substring;
// }

pub fn getElements(html: []const u8, tag: []const u8, allocator: std.mem.Allocator) ![]const []const u8 {
    var element_list = std.ArrayList([]const u8).init(allocator);
    defer element_list.deinit();

    const tag_open: []const u8 = try std.mem.concat(allocator, u8, &[_][]const u8{ "<", tag, ">" });
    defer allocator.free(tag_open);

    const tag_close: []const u8 = try std.mem.concat(allocator, u8, &[_][]const u8{ "</", tag, ">" });
    defer allocator.free(tag_close);

    var search_offset: usize = 0;

    while (true) {
        const start_index_opt = std.mem.indexOf(u8, html[search_offset..], tag_open);
        if (start_index_opt == null) break;

        const start_index = start_index_opt.? + search_offset;

        const start_end_index_opt = std.mem.indexOf(u8, html[start_index..], ">");
        if (start_end_index_opt == null) return Errors.TagNotFound;

        const start_end_index = start_index + start_end_index_opt.? + 1;

        const end_index_opt = std.mem.indexOf(u8, html[start_end_index..], tag_close);
        if (end_index_opt == null) return Errors.TagNotFound;

        const end_index = start_end_index + end_index_opt.?;

        const element_content = html[start_end_index..end_index];
        try element_list.append(element_content);

        search_offset = end_index + tag_close.len;
    }

    return element_list.toOwnedSlice();
}
