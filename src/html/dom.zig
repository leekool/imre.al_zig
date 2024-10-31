const std = @import("std");
const http = std.http;
const mem = std.mem;
const Element = @import("element.zig");
const Attribute = @import("attribute.zig");

pub const Dom = @This();

alloc: std.mem.Allocator = undefined,
html: []const u8 = undefined,
elements: std.ArrayList(Element) = undefined,

pub fn init(a: std.mem.Allocator) Dom {
    return .{
        .alloc = a,
        .elements = std.ArrayList(Element).init(a),
    };
}

pub fn deinit(self: *Dom) void {
    self.alloc.free(self.html);
    self.elements.deinit();
}

pub fn getHtml(self: *Dom, url: []const u8) !void {
    var c = http.Client{ .allocator = self.alloc };
    defer c.deinit();

    var body_container = std.ArrayList(u8).init(self.alloc);

    const extra_headers = try getExtraHeaders(self, url);
    defer self.alloc.free(extra_headers);

    const fetch_options = http.Client.FetchOptions{
        .location = http.Client.FetchOptions.Location{
            .url = url,
        },
        .headers = http.Client.Request.Headers{
            .user_agent = http.Client.Request.Headers.Value{ .override = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" },
        },
        // .extra_headers = &[_]http.Header{
        //     .{
        //         .name = "Referer",
        //         .value = referer_url
        //     },
        // },
        .extra_headers = extra_headers,
        .response_storage = .{
            .dynamic = &body_container,
        },
    };

    const res = c.fetch(fetch_options) catch |err| {
        std.debug.print("[getHtml] res: {}\n", .{err});
        return err;
    };

    const body = try body_container.toOwnedSlice();

    if (res.status != .ok) std.debug.print("[getHtml] res: {s}\n", .{body});

    self.html = body;
}

pub fn getExtraHeaders(self: *Dom, url: []const u8) ![]http.Header {
    const archive_url = "https://web.archive.org/web/";

    var buf: [10]u8 = undefined;
    const now = std.time.timestamp();
    const now_str = try std.fmt.bufPrint(&buf, "{}", .{now});

    var referer_url = std.ArrayList(u8).init(self.alloc);
    try referer_url.appendSlice(archive_url);
    try referer_url.appendSlice(now_str);
    try referer_url.appendSlice(url);
    // const referer_url: []const u8 = try std.mem.concat(self.alloc, u8, &[_][]const u8{ archive_url, now_str, url });
    // defer self.alloc.free(referer_url);
    defer referer_url.deinit();

    var headers = std.ArrayList(http.Header).init(self.alloc);

    try headers.append(http.Header{
        .name = "sec-ch-ua-platform",
        .value = "\"Windows\"",
    });
    try headers.append(http.Header{
        .name = "sec-ch-ua-platform",
        .value = "\"Windows\"",
    });
    try headers.append(http.Header{
        .name = "sec-ch-ua",
        .value = "\"Chromium\";v=\"130\", \"Google Chrome\";v=\"130\", \"Not?A_Brand\";v=\"99\"",
    });
    try headers.append(http.Header{
        .name = "sec-ch-ua-mobile",
        .value = "?0",
    });
    // try headers.append(http.Header{
    //     .name = "Referer",
    //     .value = try referer_url.toOwnedSlice(),
    // });
    try headers.append(http.Header{
        .name = "DNT",
        .value = "1",
    });

    return headers.toOwnedSlice();
}

pub fn getElements(self: *Dom) !void {
    const html = self.html;
    var element_count: u16 = 0;

    for (0.., html) |i, char| {
        if (char != '<') continue;

        const full_tag = getFirstOpeningTag(html[i..]) orelse continue;
        const tag = getElementNameFromTag(full_tag);

        const open_tag_end_index = mem.indexOf(u8, html[i..], ">") orelse continue;
        const inner_start_index = i + open_tag_end_index + 1;

        const close_tag_index = try getCloseTagIndex(html[inner_start_index..], tag) orelse continue;
        const inner_end_index = close_tag_index + inner_start_index;

        const inner = html[inner_start_index..inner_end_index];
        if (inner.len == 0) continue;

        element_count += 1;

        var attributes: [50]Attribute = undefined;
        const attribute_count = fillElementAttributes(full_tag, &attributes);

        const element = Element{ .tag = tag, .index = element_count, .inner_html = inner, .attributes = .{ .items = attributes, .count = attribute_count } };

        try self.elements.append(element);
    }
}

pub fn elementsToJson(self: *Dom) ![]const u8 {
    var l = std.ArrayList(Element.Json).init(self.alloc);
    defer l.deinit();

    for (self.elements.items) |e| {
        try l.append(Element.Json{ .tag = e.tag, .index = e.index, .innerHtml = e.inner_html, .attributes = e.attributes.items[0..e.attributes.count], .price = e.price orelse "" });
    }

    return std.json.stringifyAlloc(self.alloc, l.items, .{});
}

fn fillElementAttributes(start_tag: []const u8, attributes: *[50]Attribute) usize {
    if (mem.startsWith(u8, start_tag, "script")) return 0; // todo: handle script tags

    // std.debug.print("start_tag: {s}\n", .{start_tag});

    var attribute_count: usize = 0;
    var base_index: usize = 0;

    while (base_index < start_tag.len) {
        const start = start_tag[base_index..];

        const equal_index = mem.indexOf(u8, start, "=") orelse break;
        const key_start = mem.lastIndexOf(u8, start[0..equal_index], " ") orelse break;
        const key = start[key_start..equal_index];

        const value_surround_char = start[equal_index + 1];
        if (value_surround_char != '"' and value_surround_char != '\'') break;

        const value_start = equal_index + 2;
        const value_end_index = mem.indexOf(u8, start[value_start..], &[1]u8{value_surround_char}) orelse break;

        var value = start[value_start .. value_start + value_end_index];
        value = mem.trim(u8, value, &[2]u8{ ' ', '\n' });

        base_index += value_start + value_end_index + 1;
        if (value.len == 0 or key.len == 0) continue;

        attributes[attribute_count] = Attribute{ .key = key, .value = value };
        attribute_count += 1;
    }

    return attribute_count;
}

// returns what's between "<" and ">" including attributes
fn getFirstOpeningTag(html: []const u8) ?[]const u8 {
    const start_tag_end_index = mem.indexOf(u8, html, ">") orelse return null;
    const tag = html[1..start_tag_end_index];

    if (tag.len == 0 or tag[0] == '/' or tag[tag.len - 1] == '/' or tag[0] == '!' or tag[0] == '=') {
        return null;
    }

    return tag;
}

fn getElementNameFromTag(tag: []const u8) []const u8 {
    var name = tag;

    const space_index_opt = mem.indexOf(u8, tag, " ");
    if (space_index_opt != null) name = tag[0..space_index_opt.?];

    const break_index_opt = mem.indexOf(u8, tag, "\n");
    if (break_index_opt != null) name = tag[0..break_index_opt.?];

    return name;
}

fn getCloseTagIndex(html: []const u8, tag: []const u8) !?usize {
    var open_tag_count: usize = 1;
    var search_index: usize = 0;
    const open_tag_len = tag.len + 1; // "<" + tag
    const close_tag_len = tag.len + 3; // "</" + tag + ">"

    while (search_index < html.len) {
        const next_tag_index = mem.indexOf(u8, html[search_index..], "<") orelse break;
        search_index += next_tag_index;

        // check if opening tag
        if (mem.startsWith(u8, html[search_index + 1 ..], tag)) {
            if (html[search_index + 1 + tag.len] != '/') {
                open_tag_count += 1;
                search_index += open_tag_len;
                continue;
            }
        }

        // check if closing tag
        if (mem.startsWith(u8, html[search_index + 2 ..], tag) and html[search_index + 1] == '/') {
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

pub fn toElementsWithPrice(self: *Dom) !void {
    // try removeElementsWithChildren(self.elements);
    try removeElementsWithChildren(self);

    var count: usize = 0;

    for (self.elements.items) |*element| {
        if (mem.indexOf(u8, element.tag, "script") != null) continue; // todo: handle script tag
        if (!getPrice(element)) continue;

        self.elements.items[count] = element.*;
        count += 1;
    }

    try self.elements.resize(count);
}

// assumes element's inner html includes "$"
fn getPrice(element: *Element) bool {
    // if (!hasNumber(element.inner_html)) return false;

    const start_index = mem.indexOf(u8, element.inner_html, "$") orelse return false;
    const start_slice = element.inner_html[start_index..];

    var first_digit_index: ?usize = null;
    var last_digit_index: ?usize = null;

    for (0.., start_slice) |i, byte| {
        if (!std.ascii.isDigit(byte)) continue;

        first_digit_index = i;
        break;
    }

    if (first_digit_index == null) return false;

    for (0.., start_slice[first_digit_index.?..]) |i, byte| {
        if (i == start_slice[first_digit_index.?..].len - 1) {
            last_digit_index = first_digit_index.? + i + 1;
            break;
        }

        if (std.ascii.isDigit(byte) or byte == '.' or byte == ',') continue;

        last_digit_index = first_digit_index.? + i + 1;
        break;
    }

    const price = start_slice[first_digit_index.?..last_digit_index.?];
    element.price = price;

    return true;
}

fn hasNumber(slice: []const u8) bool {
    for (slice) |byte| {
        if (byte >= '0' and byte <= '9') return true;
    }

    return false;
}

// very basic check for elements with children
fn removeElementsWithChildren(self: *Dom) !void {
    var count: usize = 0;

    for (self.elements.items) |element| {
        if (mem.indexOf(u8, element.inner_html, "</") != null) continue;
        if (mem.indexOf(u8, element.inner_html, "/>") != null) continue;

        self.elements.items[count] = element;
        count += 1;
    }

    try self.elements.resize(count);
}
