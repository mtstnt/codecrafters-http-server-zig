const std = @import("std");
const strings = @import("./strings.zig");
const String = strings.String;

pub const Response = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    code: u32,
    headers: std.StringHashMap(String),
    body: String,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .code = 200,
            .headers = std.StringHashMap(String).init(allocator),
            .body = undefined,
        };
    }

    pub fn setCode(self: *Self, code: u32) *Self {
        self.code = code;
        return self;
    }

    pub fn addHeader(self: *Self, key: String, value: String) *Self {
        self.headers.put(key, value) catch unreachable;
        return self;
    }

    pub fn setBody(self: *Self, s: String) *Self {
        self.body = s;
        return self;
    }

    pub fn toString(self: *Self) !String {
        var array = std.ArrayList(u8).init(self.allocator);

        const code_description = switch (self.code) {
            200 => "OK",
            404 => "Not Found",
            else => "Unknown",
        };

        const statusLine = try std.fmt.allocPrint(
            self.allocator,
            "HTTP/1.1 {d} {s}\r\n",
            .{ self.code, code_description },
        );
        try array.appendSlice(statusLine);

        var it = self.headers.keyIterator();
        while (it.next()) |key| {
            const keyStr = key.*;
            const value = self.headers.get(keyStr) orelse "";
            const headerLine = try std.fmt.allocPrint(self.allocator, "{s}:{s}\r\n", .{ keyStr, value });
            try array.appendSlice(headerLine);
        }

        if (self.body.len > 0) {
            const contentLength = try std.fmt.allocPrint(self.allocator, "Content-Length:{d}\r\n", .{self.body.len});
            try array.appendSlice(contentLength);
        }
        try array.appendSlice("\r\n");

        try array.appendSlice(self.body);

        // Memory leak
        return array.items;
    }
};

const T = std.testing;
test "response builder" {
    var response = Response.init(std.heap.page_allocator);
    const responseStr = try response.setCode(200)
        .addHeader("Content-Type", "application/json")
        .addHeader("Content-Encoding", "gzip")
        .setBody("ASDF")
        .toString();

    try T.expect(std.mem.eql(
        u8,
        responseStr,
        "HTTP/1.1 200 OK\r\nContent-Type:application/json\r\nContent-Encoding:gzip\r\nContent-Length:4\r\n\r\nASDF",
    ));
}
