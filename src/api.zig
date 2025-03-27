const std = @import("std");
const http = std.http;

const body_max_len = 1024 * 1024;

pub const ApiError = error{
    UnknownRequestMethod,
    NoBody,
    UnknownStatusCode,
};

// http

pub const HttpResponse = struct {
    status_code: http.Status,
    body: ?[]u8,

    fn init(status_code: http.Status, body: ?[]u8) HttpResponse {
        const http_response = HttpResponse{
            .status_code = status_code,
            .body = body,
        };
        return http_response;
    }

    pub fn deinit(self: *HttpResponse, allocator: std.mem.Allocator) void {
        if (self.body) |body| {
            allocator.free(body);
        }
    }
};

pub fn makeHttpRequest(allocator: std.mem.Allocator, method: http.Method, url: []const u8, args: ?[]const []const u8, body: ?[]u8) !HttpResponse {
    var http_client = http.Client{ .allocator = allocator };
    errdefer http_client.deinit();

    const uri_string = join: {
        if (args) |valid_args| {
            const args_joined = try std.mem.join(allocator, "&", valid_args);
            errdefer allocator.free(args_joined);
            const uri_string = try std.mem.join(allocator, "?", &.{ url, args_joined });
            allocator.free(args_joined);
            break :join uri_string;
        } else {
            const uri_string = try allocator.dupe(u8, url);
            break :join uri_string;
        }
    };
    errdefer allocator.free(uri_string);

    const uri = try std.Uri.parse(uri_string);

    const headers = [_]http.Header{
        .{ .name = "Content-Type", .value = "application/json" },
    };

    var server_header_buffer: [1024]u8 = undefined;
    var req = try http_client.open(method, uri, .{ .extra_headers = &headers, .server_header_buffer = &server_header_buffer });
    errdefer req.deinit();

    // switch (method) {
    //     .GET => {
    //         try req.send();
    //         try req.finish();
    //         try req.wait();
    //     },
    // .POST => {
    if (body) |valid_body| {
        req.transfer_encoding = .{ .content_length = valid_body.len };
        try req.send();
        try req.writeAll(valid_body);
        try req.finish();
        try req.wait();
    } else {
        try req.send();
        try req.finish();
        try req.wait();
    }
    // },

    // else => {
    // return ApiError.UnknownRequestMethod;
    // },
    // }

    const status_code = req.response.status;
    const body_buffer = try req.reader().readAllAlloc(allocator, body_max_len);
    // var body_buffer: ?[]u8 = null;
    // const body_length = req.response.content_length;
    // if (body_length) |length| {
    //     if (length != 0) {
    //         body_buffer = try allocator.alloc(u8, length);
    //         errdefer allocator.free(body_buffer.?);
    //         _ = try req.readAll(body_buffer.?);
    //     }
    // }

    req.deinit();
    allocator.free(uri_string);
    http_client.deinit();

    const http_response = HttpResponse.init(status_code, body_buffer);
    return http_response;
}
