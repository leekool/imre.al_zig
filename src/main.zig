const std = @import("std");
const http = std.http;
const heap = std.heap;

pub const Errors = error{TagNotFound};

const Element = struct { tag: []const u8, inner: []const u8 };

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // const html = try getHtml("https://example.com", allocator);
    const html = try getHtml("https://burypink.neocities.org/anime.html", allocator);
    // const html = try getHtml("https://maillotofc.com/products/reproduction-of-found-german-military-trainer-_-black?variant=44108846530725", allocator);
    defer allocator.free(html);
    std.debug.print("getHtml: {s}\n", .{html});

    var t = try std.time.Timer.start();
    const elements = try getElements(html, allocator);
    defer allocator.free(elements);
    for (elements) |element| {
        if (std.mem.indexOf(u8, element.tag, "div") == null) continue;
        // if (std.mem.indexOf(u8, element.tag, "script") != null) continue;
        // if (std.mem.indexOf(u8, element.inner, "$") == null) continue;
        std.debug.print("[element]\ntag: {s}\ninner: {s}\n", .{ element.tag, element.inner });
    }
    std.debug.print("{}\n", .{std.fmt.fmtDuration(t.read())});

    // const nested_elements = try getNestedElements(elements, allocator);
    // defer allocator.free(nested_elements);

    std.debug.print("elements.len: {}\n", .{elements.len});
}

pub fn getHtml(url: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var c = http.Client{ .allocator = allocator };
    defer c.deinit();

    var body_container = std.ArrayList(u8).init(allocator);

    const fetch_options = http.Client.FetchOptions{ .location = http.Client.FetchOptions.Location{ .url = url }, .response_storage = .{ .dynamic = &body_container } };

    const res = try c.fetch(fetch_options);
    const body = try body_container.toOwnedSlice();

    if (res.status != .ok) std.log.err("getHtml failed: {s}\n", .{body});

    return body;
}

// very basic
pub fn getNestedElements(elements: []const Element, allocator: std.mem.Allocator) ![]const Element {
    var nested_elements = std.ArrayList(Element).init(allocator);
    defer nested_elements.deinit();

    for (elements) |element| {
        const end_index_a = std.mem.indexOf(u8, element.inner, "/>");
        const end_index_b = std.mem.indexOf(u8, element.inner, "</");

        if (end_index_a == null and end_index_b == null) {
            try nested_elements.append(element);
        }
    }

    return nested_elements.toOwnedSlice();
}

pub fn getElements(html: []const u8, allocator: std.mem.Allocator) ![]const Element {
    var elements = std.ArrayList(Element).init(allocator);
    defer elements.deinit();

    for (0.., html) |i, char| {
        if (char != '<') continue;

        const tag = getFirstTag(html[i..]) orelse continue;

        const open_tag_end_index = std.mem.indexOf(u8, html[i..], ">") orelse continue;
        const inner_start_index = i + open_tag_end_index + 1;

        // const close_tag_index = try getCloseTagIndex(html[inner_start_index..], tag, allocator) orelse continue;
        const close_tag_index = try getCloseTagIndex(html[inner_start_index..], tag) orelse continue;
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
    const start_tag_end_index = std.mem.indexOf(u8, html, ">") orelse return null;
    var tag = html[1 .. start_tag_end_index];


    if (tag.len == 0 or tag[0] == '/' or tag[tag.len - 1] == '/' or tag[0] == '!') {
        return null;
    }

    const space_index_opt = std.mem.indexOf(u8, tag, " ");
    if (space_index_opt != null) tag = tag[0..space_index_opt.?];

    const break_index_opt = std.mem.indexOf(u8, tag, "\n");
    if (break_index_opt != null) tag = tag[0..break_index_opt.?];

    return tag;
}

pub fn getCloseTagIndex(html: []const u8, tag: []const u8) !?usize {
    var open_tag_count: usize = 1;
    var search_index: usize = 0;
    const open_tag_len = tag.len + 1; // "<" + tag
    const close_tag_len = tag.len + 3; // "</" + tag + ">"

    while (search_index < html.len) {
        const next_tag_index = std.mem.indexOf(u8, html[search_index..], "<") orelse break;
        search_index += next_tag_index;

        // check if opening tag
        if (std.mem.startsWith(u8, html[search_index + 1 ..], tag)) {
            if (html[search_index + 1 + tag.len] != '/') {
                open_tag_count += 1;
                search_index += open_tag_len;
                continue;
            }
        }

        // check if closing tag
        if (std.mem.startsWith(u8, html[search_index + 2 ..], tag) and html[search_index + 1] == '/') {
            open_tag_count -= 1;
            search_index += close_tag_len;

            if (open_tag_count == 0) {
                return search_index - close_tag_len;
            }
        }

        search_index += 1;
    }

    return null;
}
