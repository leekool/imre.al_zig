const std = @import("std");

pub const Tweet = @This();

userName: []const u8,
displayName: []const u8,
id: []const u8,
createDate: []const u8,
text: []const u8,
media: ?[]const u8 = null,
