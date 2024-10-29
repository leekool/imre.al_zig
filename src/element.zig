const std = @import("std");
const Attribute = @import("./attribute.zig");

const Element = @This();

tag: []const u8,
index: u16,
inner_html: []const u8,
attributes: struct {
    items: [50]Attribute,
    count: usize,
},
price: ?[]const u8 = null,
parent_element: ?*Element = null, // todo

pub fn print(self: Element) void {
    std.debug.print("[element {}]\n", .{self.index});
    std.debug.print("  tag:        {s}\n", .{self.tag});
    std.debug.print("  inner_html: {s}\n", .{self.inner_html});

    if (self.price != null) std.debug.print("  price:      {s}\n", .{self.price.?});
    if (self.attributes.count > 0) std.debug.print("  attributes: {}\n", .{self.attributes.count});

    for (self.attributes.items[0..self.attributes.count]) |a| {
        std.debug.print("    key: {s}, value: {s}\n", .{ a.key, a.value });
    }
}
