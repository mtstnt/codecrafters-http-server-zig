const std = @import("std");
const strings = @import("./strings.zig");
const String = strings.String;

pub const Response = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    method: String,
    headers: std.StringHashMap(String),
    body: String,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .method = undefined,
            .headers = std.StringHashMap(String).init(allocator),
            .body = undefined,
        };
    }

    pub fn addHeader(self: *Self, key: String, value: String) !*Self {
        try self.headers.put(key, value);
        return self;
    }
};
