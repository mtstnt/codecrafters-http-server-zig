const std = @import("std");
const net = std.net;

const Allocator = std.heap.page_allocator;

fn strSplit(string: []const u8, delimiter: []const u8) ![][]const u8 {
    var result = std.ArrayList([]const u8).init(Allocator);
    var it = std.mem.split(u8, string, delimiter);
    while (it.next()) |a| {
        try result.append(a);
    }
    return result.items;
}

const Request = struct {
    const Self = @This();
    method: []const u8,
    path: []const u8,

    pub fn parseFrom(request_bytes: []const u8) !Self {
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

    const buffer = try Allocator.alloc(u8, 4096);
    defer Allocator.free(buffer);

    _ = try connection.stream.read(buffer);

    const request = try Request.parseFrom(buffer);

    var response: []const u8 = undefined;
    if (!std.mem.eql(u8, request.path, "/")) {
        response = "HTTP/1.1 404 Not Found\r\n\r\n";
    } else {
        response = "HTTP/1.1 200 OK\r\n\r\n";
    }
    try connection.stream.writeAll(response);
    connection.stream.close();

    std.log.info("Exiting...", .{});
}
