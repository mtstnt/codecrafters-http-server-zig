const std = @import("std");
const net = std.net;

const strings = @import("./strings.zig");
const httpRequest = @import("./request.zig");

const Allocator = std.heap.page_allocator;

const BUFFER_SIZE = 4096;

// For now, too lazy to implement map/trie data structure.
fn matchRoute(path: []const u8) ![]const u8 {
    const split_results = try strings.split(Allocator, path, "/");
    defer split_results.deinit();

    const path_parts = split_results.items;

    std.log.info("Path parts: {any}", .{path_parts});

    if (path_parts.len == 0) {
        return "ROOT";
    }

    if (path_parts.len >= 1 and strings.equals(path_parts[0], "user-agent")) {
        return "USER_AGENT";
    }

    if (path_parts.len >= 2 and strings.equals(path_parts[0], "echo")) {
        return "ECHO";
    }

    return "404";
}

pub fn main() !void {
    const address = try net.Address.resolveIp("127.0.0.1", 4221);

    std.log.info("Listening to port 4221", .{});
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    while (true) {
        std.debug.print("Listening for requests...\n", .{});
        const connection = try listener.accept();

        var handle = try std.Thread.spawn(
            .{ .allocator = Allocator },
            handleRequest,
            .{connection},
        );
        handle.detach();
    }

    std.log.info("Exiting...", .{});
}

fn handleRequest(connection: std.net.Server.Connection) !void {
    std.debug.print("Request received.\n", .{});

    const buffer = try Allocator.alloc(u8, BUFFER_SIZE);
    defer Allocator.free(buffer);

    // Reset the allocated buffer to zero values.
    @memset(buffer, 0);

    _ = try connection.stream.read(buffer);

    const request = try httpRequest.parse(Allocator, buffer);

    const routeKey = try matchRoute(request.path);
    std.log.info("Route key: {s}", .{routeKey});

    var response: []u8 = undefined;
    if (strings.equals(routeKey, "ROOT")) {
        const response_str = "HTTP/1.1 200 OK\r\n\r\n";
        response = try Allocator.alloc(u8, response_str.len);
        std.mem.copyForwards(u8, response, response_str);
    } else if (strings.equals(routeKey, "ECHO")) {
        const split_results = try strings.split(Allocator, request.path, "/");
        defer split_results.deinit();

        const path_parts = split_results.items;
        const str = path_parts[1];
        const format = "HTTP/1.1 200 OK\r\nContent-Type:text/plain\r\nContent-Length:{d}\r\n\r\n{s}";
        response = try std.fmt.allocPrint(Allocator, format, .{ str.len, str });
    } else if (strings.equals(routeKey, "USER_AGENT")) {
        const header_value = request.headers.get("User-Agent").?;
        const format = "HTTP/1.1 200 OK\r\nContent-Type:text/plain\r\nContent-Length:{d}\r\n\r\n{s}";
        response = try std.fmt.allocPrint(Allocator, format, .{ header_value.len, header_value });
    } else {
        const response_str = "HTTP/1.1 404 Not Found\r\n\r\n";
        response = try Allocator.alloc(u8, response_str.len);
        std.mem.copyForwards(u8, response, response_str);
    }
    defer Allocator.free(response);

    try connection.stream.writeAll(response);
    connection.stream.close();
}

test "strSplit" {
    const T = std.testing;
    const splitResults = try strings.split(Allocator, "/echo/hello", "/");
    try T.expectEqual(splitResults.items.len, 2);
}

test "routeMatcher" {
    const T = std.testing;
    const routeKey = try matchRoute("/echo/hello");
    const isOk = strings.equals(routeKey, "ECHO");
    try T.expect(isOk);
}
