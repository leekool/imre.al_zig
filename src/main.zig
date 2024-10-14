const std = @import("std");
const http = std.http;
const heap = std.heap;

pub const Errors = error{TagNotFound};

const Element = struct { tag: []const u8, inner: []const u8 };

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const html = try getHtml("https://example.com", allocator);
    defer allocator.free(html);
    std.debug.print("getHtml: {s}\n", .{html});

    const elements = try processHtml(html, allocator);
    defer allocator.free(elements);

    for (elements) |element| {
        std.debug.print("[element]\ntag: {s}\ninner: {s}\n", .{ element.tag, element.inner });
    }
}

pub fn getHtml(url: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var c = http.Client{ .allocator = allocator };
    defer c.deinit();

    var body_container = std.ArrayList(u8).init(allocator);

    const fetch_options = http.Client.FetchOptions{ 
        .location = http.Client.FetchOptions.Location{ .url = url },
        .response_storage = .{ .dynamic = &body_container }
    };

    const res = try c.fetch(fetch_options);
    const body = try body_container.toOwnedSlice();

    if (res.status != .ok) std.log.err("getHtml failed: {s}\n", .{body});

    return body;
}

pub fn processHtml(html: []const u8, allocator: std.mem.Allocator) ![]const Element {
    var elements = std.ArrayList(Element).init(allocator);
    defer elements.deinit();

    for (0.., html) |i, char| {
        if (char != '<') continue;

        const tag = getFirstTag(html[i..]) orelse continue;

        const open_tag_end_index = std.mem.indexOf(u8, html[i..], ">") orelse continue;
        const inner_start_index = i + open_tag_end_index + 1;

        const close_tag_index = try getCloseTagIndex(html[inner_start_index..], tag, allocator) orelse continue;
        const inner_end_index = close_tag_index + inner_start_index;

        const inner = html[inner_start_index..inner_end_index];
        // if (inner.len == 0) continue;

        const element = Element{
            .tag = tag,
            .inner = inner,
        };

        try elements.append(element);
    }

    return elements.toOwnedSlice();
}

pub fn getFirstTag(html: []const u8) ?[]const u8 {
    if (html.len < 2 or html[1] == '!' or html[1] == '/') return null;

    const tag_end_opt = std.mem.indexOf(u8, html, ">");
    if (tag_end_opt == null) return null;

    const tag_end = tag_end_opt.?;

    const raw_open_tag = html[1..tag_end];
    if (raw_open_tag.len == 0 or raw_open_tag[raw_open_tag.len - 1] == '/') return null;

    const space_index = std.mem.indexOf(u8, raw_open_tag, " ");
    return if (space_index == null) raw_open_tag else raw_open_tag[0..space_index.?];
}

pub fn getCloseTagIndex(html: []const u8, tag: []const u8, allocator: std.mem.Allocator) !?usize {
    const open_tag = try std.mem.concat(allocator, u8, &[_][]const u8{ "<", tag });
    defer allocator.free(open_tag);

    const close_tag = try std.mem.concat(allocator, u8, &[_][]const u8{ "</", tag, ">" });
    defer allocator.free(close_tag);

    var open_tag_count: usize = 1;
    var search_index: usize = 0;

    while (true) {
        const next_open_tag_index = std.mem.indexOf(u8, html[search_index..], open_tag);
        const next_close_tag_index = std.mem.indexOf(u8, html[search_index..], close_tag) orelse break;

        if (next_open_tag_index != null and next_open_tag_index.? < next_close_tag_index) {
            open_tag_count += 1;
            search_index += next_open_tag_index.? + tag.len + 1;
        } else {
            open_tag_count -= 1;
            search_index += next_close_tag_index + close_tag.len;

            if (open_tag_count == 0) {
                return search_index - close_tag.len;
            }
        }
    }

    return null;
}
