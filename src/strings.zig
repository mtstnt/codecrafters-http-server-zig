const std = @import("std");

pub const String = []const u8;

pub fn split(allocator: std.mem.Allocator, string: String, delimiter: String) !std.ArrayList(String) {
    var result = std.ArrayList([]const u8).init(allocator);
    var it = std.mem.split(u8, string, delimiter);
    while (it.next()) |a| {
        if (a.len == 0) continue;
        try result.append(a);
    }
    return result;
}

pub fn equals(a: String, b: String) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}
