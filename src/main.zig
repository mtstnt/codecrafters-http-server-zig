const std = @import("std");
const net = std.net;

pub fn main() !void {
    const address = try net.Address.resolveIp("127.0.0.1", 4221);

    std.log.info("Listening to port 4221", .{});
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    var connection = try listener.accept();
    _ = try connection.stream.writeAll("HTTP/1.1 200 OK\r\n\r\n");
    connection.stream.close();

    std.log.info("Exiting...", .{});
}
