const std = @import("std");
const zap = @import("zap");

pub const Self = @This();

alloc: std.mem.Allocator = undefined,
ep: zap.Endpoint = undefined,

pub fn init(a: std.mem.Allocator, path: []const u8) Self {
    return .{
        .alloc = a, 
        .ep = zap.Endpoint.init(.{
            .path = path,
            .get = getPrices
        }),
    };
}

pub fn endpoint(self: *Self) *zap.Endpoint {
    return &self.ep;
}

fn getPrices(e: *zap.Endpoint, r: zap.Request) void {
    _ = e;
    // const self: *Self = @fieldParentPtr("ep", e);

    if (r.path) |path| {
        _ = path;
        r.sendJson("test") catch return;
    }
}
