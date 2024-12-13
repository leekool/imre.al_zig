const std = @import("std");
const zap = @import("zap");
const Dom = @import("html/dom.zig");
const Element = @import("html/element.zig");
const Tweet = @import("tweet.zig");

pub const Self = @This();

alloc: std.mem.Allocator = undefined,
ep: zap.Endpoint = undefined,

pub fn init(a: std.mem.Allocator, path: []const u8) Self {
    return .{
        .alloc = a,
        .ep = zap.Endpoint.init(.{ .path = path, .get = getTweet }),
    };
}

pub fn endpoint(self: *Self) *zap.Endpoint {
    return &self.ep;
}

fn getTweet(e: *zap.Endpoint, r: zap.Request) void {
    const self: *Self = @fieldParentPtr("ep", e);
    const path = r.path orelse return;

    if (path.len <= e.settings.path.len + 2 or path[e.settings.path.len] != '/') return;

    // works as at 13/12/24
    const part_one = "http://cdn.syndication.twimg.com/tweet-result?id=";
    const part_two = "&token=a";

    const id = path[e.settings.path.len + 1 ..];
    const url = std.mem.concat(self.alloc, u8, &[_][]const u8{ part_one, id, part_two }) catch return;
    defer self.alloc.free(url);

    var dom = Dom.init(self.alloc);
    defer dom.deinit();

    dom.getHtml(url) catch return;

    const full_tweet = std.json.parseFromSlice(std.json.Value, self.alloc, dom.html orelse return, .{}) catch |err| {
        std.debug.print("[getTweet] json.parseFromSlice: {}\n", .{err});
        return;
    };
    defer full_tweet.deinit();

    const parsed_tweet = parseTweet(full_tweet.value);

    const json = std.json.stringifyAlloc(self.alloc, parsed_tweet, .{}) catch |err| {
        std.debug.print("[getTweet] json.stringifyAlloc: {}\n", .{err});
        return;
    };
    defer self.alloc.free(json);

    r.sendJson(json) catch return;
}

// fn parseTweet(self: *Self, full_tweet: std.json.Value) !Tweet {
fn parseTweet(full_tweet: std.json.Value) Tweet {
    const t = full_tweet.object;

    const tweet = Tweet{
        .userName = t.get("user").?.object.get("name").?.string,
        .displayName = t.get("user").?.object.get("screen_name").?.string,
        .id = t.get("id_str").?.string,
        .createDate = t.get("created_at").?.string,
        .text = t.get("text").?.string,
    };

    // const parsed_tweet = std.json.parseFromValue(Tweet, self.alloc, full_tweet, .{}) catch |err| {
    //     std.debug.print("[parseTweet] error: {}\n", .{err});
    //     return err;
    // };
    // _ = parsed_tweet;

    return tweet;
}
