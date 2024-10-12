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

    // const divs = try getElements(html, "p", allocator);
    // defer allocator.free(divs);

    // for (divs) |div| {
    //     std.debug.print("getElements: {s}\n", .{div});
    // }
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

pub fn getElement(html: []const u8) ?[]const u8 {
    var search_offset: usize = 0;

    while (true) {
        const open_start_opt = std.mem.indexOf(u8, html[search_offset..], "<");
        if (open_start_opt == null) return null;

        const open_start = open_start_opt.? + search_offset + 1;
        if (html[open_start] == '/') {
            search_offset = open_start;
            continue;
        }

        const open_end_opt = std.mem.indexOf(u8, html[open_start..], ">");
        if (open_end_opt == null) return null;

        const open_end = open_start + open_end_opt.?;

        var open_tag = html[open_start..open_end];
        for (open_tag) |char| {
            if (char != ' ') continue;

            const char_index = std.mem.indexOfScalar(u8, open_tag, char);

            if (char_index != null) {
                open_tag = open_tag[0..char_index.?];
            }
        }
        std.debug.print("[getElement] open_tag: {s}\n", .{open_tag});

        // closing
        var close_start_opt: ?usize = null;
        var possible_offset = open_end;

        while (true) {
            close_start_opt = std.mem.indexOf(u8, html[possible_offset..], "</");
            if (close_start_opt == null) {
                break;
            }

            const close_start_index = close_start_opt.? + possible_offset;

            if (std.mem.startsWith(u8, html[close_start_index + 2 ..], open_tag)) {
                close_start_opt = close_start_index;
                break;
            }

            possible_offset = close_start_index + 2;
        }

        if (close_start_opt == null) {
            search_offset = open_end + 1;
            continue;
        }

        const start_index = open_end + 1;
        const end_index = close_start_opt.?; // "</"

        return html[start_index..end_index];
    }

    return null;
}

pub fn getAllElements(html: []const u8, allocator: std.mem.Allocator) ![]const []const u8 {
    var element_list = std.ArrayList([]const u8).init(allocator);
    defer element_list.deinit();

    var search_offset: usize = 0;

    while (true) {
        const element = getElement(html[search_offset..]);
        if (element != null) {
            try element_list.append(element.?);
        } else {
            break;
        }

        // std.debug.print("[getAllElements] element: {s}\n", .{element.?});

        const element_index = std.mem.lastIndexOf(u8, html, element.?);
        search_offset = element_index.?;
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
