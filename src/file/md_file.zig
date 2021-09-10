const std = @import("std");

const fs = std.fs;
const cwd = fs.cwd;

const File = std.fs.File;
const Reader = File.Reader;
const Writer = File.Writer;
const OpenFlags = File.OpenFlags;
const OpenError = File.OpenError;
const CreateFlags = File.CreateFlags;
const CreateError = File.CopyRangeError;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub fn MdFile(
    comptime DataT: type,
    comptime ReadDataErrorT: type,
    comptime readDataFn: fn (data: DataT, r: Reader, allocator: *Allocator) ReadDataErrorT!void,
    comptime WriteDataErrorT: type,
    comptime writeDataFn: fn (data: DataT, w: Writer, allocator: *Allocator) WriteDataErrorT!void,
) type {
    return struct {
        // Data
        data: DataT,
        // File allocator
        allocator: *Allocator,
        // Associated file
        file: ?File,
        reader: ?Reader,
        writer: ?Writer,

        // File internal types
        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            return Self{
                .data = DataT.init(allocator),
                .allocator = allocator,
                .file = null,
                .reader = null,
                .writer = null,
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
            self.allocator = null;
            self.close();
        }

        pub fn readData(self: *Self) ReadDataErrorT!void {
            if (self.reader == null) self.reader = self.file.?.Reader();
            try readDataFn(self.data, self.reader, self.allocator);
        }

        pub fn writeData(self: *Self) WriteDataErrorT!void {
            if (self.writer == null) self.writer = self.file.?.Writer();
            try writeDataFn(self.data, self.writer, self.allocator);
        }

        pub fn openFile(self: *Self, file_name: []const u8, flags: OpenFlags) OpenError!void {
            self.close();
            self.file = try cwd().openFile(file_name, flags);
        }

        pub fn createFile(self: *Self, file_name: []const u8, flags: CreateFlags) CreateError!void {
            self.close();
            self.file = try cwd().createFile(file_name, flags);
        }

        pub fn close(self: *Self) void {
            if (self.file) |f| {
                f.close();
                self.file = null;
                self.reader = null;
                self.writer = null;
            }
        }
    };
}
