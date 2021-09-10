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

pub fn MdFile(comptime DataT: type, comptime ErrorT: type) type {
    return struct {
        // Data
        data: ArrayList(DataT),
        // File allocator
        allocator: *Allocator,
        // Associated file
        file: ?File,
        reader: ?Reader,
        writer: ?Writer,
        // Functions
        setDataFn: SetDataFnT,
        readDataFn: ReadDataFnT,
        printDataFn: PrintDataFnT,

        // File internal types
        const Self = @This();
        const SetDataFnT = fn (*Self, []DataT) ErrorT!void;
        const ReadDataFnT = fn (*Self) ErrorT!void;
        const PrintDataFnT = fn (*Self) ErrorT!void;

        pub fn init(allocator: *Allocator, setFn: SetDataFnT, readFn: ReadDataFnT, printFn: PrintDataFnT) Self {
            return Self{
                .data = ArrayList(DataT).init(allocator),
                .allocator = allocator,
                .file = null,
                .reader = null,
                .writer = null,
                .setDataFn = setFn,
                .readDataFn = readFn,
                .printDataFn = printFn,
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
            self.allocator = null;
            self.close();
        }

        pub fn setData(self: *Self, data: DataT) ErrorT!void {
            try self.setDataFn(self, data);
        }

        pub fn readData(self: *Self) ErrorT!void {
            try self.readDataFn(self);
        }

        pub fn printData(self: *Self) ErrorT!void {
            try self.printDataFn(self);
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
