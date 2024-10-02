const std = @import("std");
const http = std.http;
const heap = std.heap;

const Client = http.Client;
const RequestOptions = Client.RequestOptions;

const FetchReq = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;

    allocator: Allocator,
    client: std.http.Client,
    body: std.ArrayList(u8),

    pub fn init(allocator: Allocator) Self {
        const c = Client{ .allocator = allocator };
        return Self{
            .allocator = allocator,
            .client = c,
            .body = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.client.deinit();
        self.body.deinit();
    }

    pub fn get(self: *Self, url: []const u8, headers: []http.Header) !Client.FetchResult {
        const fetch_options = Client.FetchOptions{
            .location = Client.FetchOptions.Location{
                .url = url,
            },
            .extra_headers = headers,
            .response_storage = .{ .dynamic = &self.body },
        };

        const res = try self.client.fetch(fetch_options);
        return res;
    }

    pub fn post(self: *Self, url: []const u8, body: []const u8, headers: []http.Header) !Client.FetchResult {
        const fetch_options = Client.FetchOptions{
            .location = Client.FetchOptions.Location{
                .url = url,
            },
            .extra_headers = headers,
            .method = .POST,
            .payload = body,
            .response_storage = .{ .dynamic = &self.body },
        };

        const res = try self.client.fetch(fetch_options);
        return res;
    }
};

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const html = try getHtml("https://example.com", allocator);
    defer allocator.free(html);

    std.debug.print("getHtml response: {s}\n", .{html});
}

pub fn getHtml(url: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var req = FetchReq.init(allocator);
    defer req.deinit();

    const res = try req.get(url, &.{});
    const body = try req.body.toOwnedSlice();

    if (res.status != .ok) std.log.err("getHtml failed: {s}\n", .{body});

    return body;
}
