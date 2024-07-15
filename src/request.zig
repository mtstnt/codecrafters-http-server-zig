const std = @import("std");
const strings = @import("./strings.zig");

const String = strings.String;

pub const Request = struct {
    const Self = @This();

    method: String,
    headers: std.StringHashMap(String),
    path: String,
    body: String,
};

pub fn parse(allocator: std.mem.Allocator, b: String) !Request {
    var line_iterator = std.mem.split(u8, b, "\r\n");

    var request = Request{
        .method = undefined,
        .path = undefined,
        .headers = std.StringHashMap(String).init(allocator),
        .body = undefined,
    };

    // Status line
    const status_line = line_iterator.next().?;
    const method, const path = try parseStatusLine(status_line);
    request.method = method;
    request.path = path;

    // Header lines
    while (line_iterator.next()) |line| {
        if (std.mem.eql(u8, line, "")) break;
        const key, const value = try parseHeaderLine(line);
        try request.headers.put(key, value);
    }

    // Body
    var body_lines = std.ArrayList([]const u8).init(allocator);
    defer body_lines.deinit();
    while (line_iterator.next()) |line| {
        const max_index = std.mem.indexOfScalar(u8, line, 0) orelse line.len;
        try body_lines.append(line[0..max_index]);
    }
    const concatted_body = try std.mem.concat(allocator, u8, body_lines.items);
    request.body = concatted_body;

    // Print request
    const stdout = std.io.getStdOut();
    try printRequest(stdout.writer(), request);

    return request;
}

fn parseStatusLine(line: String) !std.meta.Tuple(&.{ String, String }) {
    var word_iterator = std.mem.split(u8, line, " ");
    const method = word_iterator.next() orelse return error.InvalidHTTPStatusLine;
    const path = word_iterator.next() orelse return error.InvalidHTTPStatusLine;
    return .{ method, path };
}

fn parseHeaderLine(line: String) !std.meta.Tuple(&.{ String, String }) {
    var colon_iterator = std.mem.split(u8, line, ":");
    const key = colon_iterator.next() orelse return error.InvalidHTTPHeaderLine;
    var value = colon_iterator.next() orelse "";
    // Remove whitespace after colon.
    value = std.mem.trim(u8, value, " ");
    return .{ key, value };
}

fn printRequest(writer: anytype, request: Request) !void {
    _ = try writer.write("[REQUEST RECEIVED]\n");
    try std.fmt.format(writer, "Method: {s}; Path: {s}\n", .{ request.method, request.path });
    var header_it = request.headers.keyIterator();
    _ = try writer.write("Headers:\n");
    while (header_it.next()) |header| {
        const value = request.headers.get(header.*) orelse "[EMPTY VALUE]";
        try std.fmt.format(writer, "{s}:{s} ({d})\n", .{ header.*, value, value.len });
    }
    try std.fmt.format(writer, "Body: {s}\n", .{request.body});
}

const T = std.testing;
test "parse status line" {
    const method, const path = try parseStatusLine("GET /api/welcome");
    try T.expect(std.mem.eql(u8, method, "GET"));
    try T.expect(std.mem.eql(u8, path, "/api/welcome"));
}

test "parse status line with no method" {
    const err = parseStatusLine("/api/welcome");
    try T.expectError(error.InvalidHTTPStatusLine, err);
}

test "parse status line with no path" {
    const err = parseStatusLine("GET");
    try T.expectError(error.InvalidHTTPStatusLine, err);
}

test "parse header line" {
    const key, const value = try parseHeaderLine("Content-Type:application/json");
    try T.expect(std.mem.eql(u8, key, "Content-Type"));
    try T.expect(std.mem.eql(u8, value, "application/json"));
}

test "parse request from string" {
    const request_str = "GET /hello\r\nContent-Type:application/json\r\n\r\nBody";
    const request = try parse(std.heap.page_allocator, request_str);
    try T.expect(std.mem.eql(u8, request.method, "GET"));
    try T.expect(std.mem.eql(u8, request.headers.get("Content-Type").?, "application/json"));
    try T.expect(std.mem.eql(u8, request.body, "Body"));
}
