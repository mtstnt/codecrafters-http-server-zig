const std = @import("std");
const net = std.net;

const Allocator = std.heap.page_allocator;

const BUFFER_SIZE = 4096;

fn strSplit(string: []const u8, delimiter: []const u8) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(Allocator);
    var it = std.mem.split(u8, string, delimiter);
    while (it.next()) |a| {
        if (a.len == 0) continue;
        try result.append(a);
    }
    return result.items;
}

fn strEquals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

fn strConcat(allocator: std.mem.Allocator, strs: []const []const u8) ![]const u8 {
    var total_size: usize = 0;
    for (strs) |s| {
        total_size += s.len;
    }
    var result = try allocator.alloc(u8, total_size);
    var index: usize = 0;
    for (strs) |s| {
        for (s) |c| {
            result[index] = c;
            index += 1;
        }
    }
    return result;
}

// For now, too lazy to implement map/trie data structure.
fn matchRoute(path: []const u8) ![]const u8 {
    const path_parts = try strSplit(path, "/");
    std.log.info("Path parts: {any}", .{path_parts});

    if (path_parts.len == 0) {
        return "ROOT";
    }

    if (path_parts.len >= 2 and strEquals(path_parts[0], "echo")) {
        return "ECHO";
    }

    return "404";
}

const Request = struct {
    const Self = @This();
    method: []const u8,
    path: []const u8,

    pub fn fromBytes(request_bytes: []const u8) !Self {
        const lines = try strSplit(request_bytes, "\r\n");
        if (lines.len == 0) {
            return error.EmptyRequest;
        }

        const parse_results = try strSplit(lines[0], " ");
        return Request{
            .method = parse_results[0],
            .path = parse_results[1],
        };
    }
};

pub fn main() !void {
    const address = try net.Address.resolveIp("127.0.0.1", 4221);

    std.log.info("Listening to port 4221", .{});
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    var connection = try listener.accept();

    const buffer = try Allocator.alloc(u8, BUFFER_SIZE);
    defer Allocator.free(buffer);

    _ = try connection.stream.read(buffer);

    const request = try Request.fromBytes(buffer);

    const routeKey = try matchRoute(request.path);
    std.log.info("Route key: {s}", .{routeKey});

    var response: []const u8 = undefined;
    if (strEquals(routeKey, "ROOT")) {
        response = "HTTP/1.1 200 OK\r\n\r\n";
    } else if (strEquals(routeKey, "ECHO")) {
        const path_parts = try strSplit(request.path, "/");
        const str = path_parts[1];
        const format = "HTTP/1.1 200 OK\r\nContent-Type:text/plain\r\nContent-Length:{d}\r\n\r\n{s}";
        response = try std.fmt.allocPrint(Allocator, format, .{ str.len, str });
        // TODO: Free this memory.
    } else {
        response = "HTTP/1.1 404 Not Found\r\n\r\n";
    }

    try connection.stream.writeAll(response);
    defer connection.stream.close();

    std.log.info("Exiting...", .{});
}

test "strSplit" {
    const T = std.testing;
    const splitResults = try strSplit("/echo/hello", "/");
    try T.expectEqual(splitResults.len, 2);
}

test "routeMatcher" {
    const T = std.testing;
    const routeKey = try matchRoute("/echo/hello");
    const isOk = strEquals(routeKey, "ECHO");
    try T.expect(isOk);
}
