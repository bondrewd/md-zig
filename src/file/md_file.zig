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
        data: DataT,
        allocator: *Allocator,
        file: File = undefined,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            return Self{
                .data = DataT.init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
            self.allocator = null;
            self.file.close();
        }

        pub fn readData(self: *Self) ReadDataErrorT!void {
            try readDataFn(self.data, self.file.Reader(), self.allocator);
        }

        pub fn writeData(self: *Self) WriteDataErrorT!void {
            try writeDataFn(self.data, self.file.Writer(), self.allocator);
        }

        pub fn openFile(self: *Self, file_name: []const u8, flags: OpenFlags) OpenError!void {
            self.file = try cwd().openFile(file_name, flags);
        }

        pub fn createFile(self: *Self, file_name: []const u8, flags: CreateFlags) CreateError!void {
            self.file = try cwd().createFile(file_name, flags);
        }
    };
}
