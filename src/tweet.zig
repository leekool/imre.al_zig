const std = @import("std");
const Dom = @import("html/dom.zig");

pub const Media = struct {
    url: []const u8,
    base64: []const u8,
    fileType: []const u8,
};

pub const Tweet = @This();

userName: []const u8,
displayName: []const u8,
id: []const u8,
createDate: []const u8,
text: []const u8,
media: ?[]Media = null,
quote: ?*Tweet = null,

const TweetErrors = error{
    Invalid,
    OutOfMemory,
    FetchError,
};

pub fn init(a: std.mem.Allocator, id: []const u8) TweetErrors!Tweet {
    var dom = Dom.init(a);
    defer dom.deinit();

    // works as at 13/12/24
    const start = "http://cdn.syndication.twimg.com/tweet-result?id=";
    const end = "&token=a";
    const url = try std.mem.concat(a, u8, &[_][]const u8{ start, id, end });
    defer a.free(url);

    dom.getUrl(url) catch return TweetErrors.FetchError;

    const x_tweet = std.json.parseFromSlice(std.json.Value, a, dom.html.?, .{}) catch return TweetErrors.Invalid;
    defer x_tweet.deinit();

    var tweet = try parseTweet(x_tweet.value, a);
    getMedia(&tweet, x_tweet.value, &dom, a) catch return TweetErrors.Invalid;
    getQuote(&tweet, x_tweet.value, a) catch return TweetErrors.Invalid;

    return tweet;
}

pub fn deinit(self: *Tweet, a: std.mem.Allocator) void {
    a.free(self.userName);
    a.free(self.displayName);
    a.free(self.id);
    a.free(self.createDate);
    a.free(self.text);

    if (self.media != null) {
        for (self.media.?) |m| {
            a.free(m.url);
            a.free(m.base64);
        }

        a.free(self.media.?);
    }

    if (self.quote) |quote_ptr| {
        quote_ptr.deinit(a);
        a.destroy(quote_ptr);
    }
}

pub fn stringify(self: *Tweet, a: std.mem.Allocator) ![]const u8 {
    const json = try std.json.stringifyAlloc(a, self, .{});
    return json;
}

fn parseTweet(x_tweet: std.json.Value, a: std.mem.Allocator) !Tweet {
    const t = x_tweet.object;

    const tweet = Tweet{
        .userName = try a.dupe(u8, t.get("user").?.object.get("screen_name").?.string),
        .displayName = try a.dupe(u8, t.get("user").?.object.get("name").?.string),
        .id = try a.dupe(u8, t.get("id_str").?.string),
        .createDate = try a.dupe(u8, t.get("created_at").?.string),
        .text = try a.dupe(u8, t.get("text").?.string),
    };

    return tweet;
}

fn getMedia(tweet: *Tweet, x_tweet: std.json.Value, dom: *Dom, a: std.mem.Allocator) !void {
    const media_details = x_tweet.object.get("mediaDetails");
    if (media_details == null) return;

    const media_arr = media_details.?.array;
    if (media_arr.items.len == 0) return;

    var buf = std.ArrayList(Media).init(a);
    defer buf.deinit();

    for (media_arr.items) |m| {
        var url = m.object.get("media_url_https").?.string;
        if (std.mem.indexOf(u8, url, "https") != null) {
            const http = url[0..4];
            const url_end = url[5..];
            url = try std.mem.concat(a, u8, &[_][]const u8{ http, url_end });
        }

        try dom.getUrl(url);

        // process result
        const encoder = std.base64.standard.Encoder;
        const base64 = try a.alloc(u8, encoder.calcSize(dom.html.?.len));
        _ = encoder.encode(base64, dom.html.?);

        var char_i = url.len;
        while (char_i > 0) { // find last '.'
            char_i -= 1;
            if (url[char_i] == '.') break;
        }

        const file_type = url[char_i + 1 ..];

        try buf.append(Tweet.Media{
            .url = url,
            .base64 = base64,
            .fileType = file_type,
        });
    }

    tweet.media = try buf.toOwnedSlice();
}

fn getQuote(tweet: *Tweet, x_tweet: std.json.Value, a: std.mem.Allocator) !void {
    const quote_obj = x_tweet.object.get("quoted_tweet");
    if (quote_obj == null) return;

    const id = quote_obj.?.object.get("id_str").?.string;

    const quoted_tweet = try Tweet.init(a, id);
    const quote_ptr = try a.create(Tweet);

    quote_ptr.* = quoted_tweet;
    tweet.quote = quote_ptr;
}
