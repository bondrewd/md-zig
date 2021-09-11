const std = @import("std");
const Real = @import("../config.zig").Real;
const System = @import("../system.zig").System;
const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

const XyzFileData = struct {
    id: std.ArrayList(u64),
    x: std.ArrayList(Real),
    y: std.ArrayList(Real),
    z: std.ArrayList(Real),
};

pub const XyzFile = struct {
    allocator: *std.mem.Allocator = undefined,
    writer: ?std.fs.File.Writer = undefined,
    reader: ?std.fs.File.Reader = undefined,
    file: ?std.fs.File = undefined,
    data: XyzFileData = undefined,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .data = .{
                .id = std.ArrayList(u64).init(allocator),
                .x = std.ArrayList(Real).init(allocator),
                .y = std.ArrayList(Real).init(allocator),
                .z = std.ArrayList(Real).init(allocator),
            },
        };
    }

    pub fn deinit(self: Self) void {
        if (self.file) |file| file.close();
        self.data.id.deinit();
        self.data.x.deinit();
        self.data.y.deinit();
        self.data.z.deinit();
    }

    pub fn openFile(self: *Self, file_name: []const u8, flags: std.fs.File.OpenFlags) !void {
        var file = try std.fs.cwd().openFile(file_name, flags);
        self.file = file;
        if (flags.read) self.reader = file.reader();
        if (flags.write) self.writer = file.writer();
    }

    pub fn createFile(self: *Self, file_name: []const u8, flags: std.fs.File.CreateFlags) !void {
        var file = try std.fs.cwd().createFile(file_name, flags);
        self.file = file;
        if (flags.read) self.reader = file.reader();
        self.writer = file.writer();
    }

    pub fn load(_: *Self) !void {}

    pub fn printDataFromSystem(self: Self, system: *System) !void {
        // Get writer
        var w = if (self.writer) |w| w else {
            stopWithErrorMsg("Can't print xyz file before open or create one", .{});
            unreachable;
        };

        // Write number of entries
        try w.print("{d}\n", .{system.r.items.len});
        // Write comment line
        try w.writeAll("\n");
        // Write positions
        for (system.r.items) |r| {
            try w.print("H  {d:>8.3}  {d:>8.3}  {d:>8.3}\n", .{
                r.items[0],
                r.items[1],
                r.items[2],
            });
        }
    }
};
