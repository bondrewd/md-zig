const std = @import("std");

const File = std.fs.File;
const Reader = File.Reader;
const Writer = File.Writer;

const V = @import("../math.zig").V3;
const Real = @import("../config.zig").Real;
const MdFile = @import("md_file.zig").MdFile;
const Element = @import("../constant.zig").Element;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;
const elementFromString = @import("../constant.zig").elementFromString;

pub const Frame = struct {
    n_atoms: u64,
    elements: ArrayList(Element),
    pos: ArrayList(V),

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .n_atoms = 0,
            .elements = ArrayList(Element).init(allocator),
            .pos = ArrayList(V).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.elements.deinit();
        self.pos.deinit();
    }
};

pub const Data = struct {
    frames: ArrayList(Frame),

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .frames = ArrayList(Frame).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.frames.items) |*frame| frame.deinit();
        self.frames.deinit();
    }
};

pub const ReadDataError = error{ BadPosLine, OutOfMemory };
pub fn readData(data: *Data, r: Reader, allocator: *Allocator) ReadDataError!void {
    // State
    const State = enum { NumberOfAtoms, Comment, Positions };
    var state: State = .NumberOfAtoms;

    // Local variables
    var buf: [1024]u8 = undefined;
    var frame: ?Frame = null;

    // Iterate over lines
    var line_id: usize = 0;
    while (r.readUntilDelimiterOrEof(&buf, '\n') catch return error.BadPosLine) |line| {
        // Update line number
        line_id += 1;

        // Skip empty lines
        if (state == .NumberOfAtoms and std.mem.trim(u8, line, " ").len == 0) continue;

        switch (state) {
            // Parse number of atoms
            .NumberOfAtoms => {
                // Init frame
                if (frame) |fr| data.frames.append(fr) catch return error.OutOfMemory;
                frame = Frame.init(allocator);

                // Parse number
                const n_atoms = std.mem.trim(u8, line, " ");
                frame.?.n_atoms = std.fmt.parseInt(u64, n_atoms, 10) catch {
                    stopWithErrorMsg("Bad number of atoms value {s} in line {s}", .{ n_atoms, line });
                    unreachable;
                };

                // Update state
                state = .Comment;
                continue;
            },
            // Ignore comment
            .Comment => {
                // Update state
                state = .Positions;
                continue;
            },
            // Parse positions
            .Positions => {
                // Tokenize line
                var tokens = std.mem.tokenize(u8, line, " ");

                // Parse index
                frame.?.elements.append(if (tokens.next()) |token| elementFromString(token) catch {
                    stopWithErrorMsg("Unknown element {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing element at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                }) catch return error.OutOfMemory;

                // Parse positions
                const x = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const y = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const z = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                // Update state
                state = .NumberOfAtoms;
                frame.?.pos.append(V.fromArray(.{ x, y, z })) catch return error.OutOfMemory;
                continue;
            },
        }
    }

    if (frame) |fr| data.frames.append(fr) catch return error.OutOfMemory;
}

pub const WriteDataError = error{WriteLine};
pub fn writeFrame(n_atoms: u64, elements: ArrayList(Element), pos: ArrayList(V), w: Writer) WriteDataError!void {
    // Print time
    w.print("{d}\n", .{n_atoms}) catch return error.WriteLine;
    // Print comment
    w.print("\n", .{}) catch return error.WriteLine;
    // Print positions
    for (elements.items) |e, i| {
        w.print("{s:<12}  {d:>12.5}  {d:>12.5}  {d:>12.5}\n", .{
            e.toString(),
            pos.items[i].items[0],
            pos.items[i].items[1],
            pos.items[i].items[2],
        }) catch return error.WriteLine;
    }
}

pub fn writeData(data: *Data, w: Writer, _: *Allocator) WriteDataError!void {
    // Loop over frames
    for (data.frames.items) |frame| {
        // Print frame
        try writeFrame(frame.n_atoms, frame.elements, frame.pos, w);
        // Print new line
        w.print("\n", .{}) catch return error.WriteLine;
    }
}

pub const XyzFile = MdFile(Data, ReadDataError, readData, WriteDataError, writeData);
