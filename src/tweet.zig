const std = @import("std");

pub const Media = struct {
    url: []const u8,
    base64: []const u8,
    file_type: []const u8,
};

pub const Tweet = @This();

userName: []const u8,
displayName: []const u8,
id: []const u8,
createDate: []const u8,
text: []const u8,
media: ?Media = null,

pub fn deinit(self: *Tweet, alloc: std.mem.Allocator) void {
    if (self.media == null) return;

    alloc.free(self.media.?.url);
    alloc.free(self.media.?.base64);
}
