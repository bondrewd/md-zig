const std = @import("std");

const File = std.fs.File;
const Reader = File.Reader;
const Writer = File.Writer;

const V = @import("../math.zig").V3;
const Real = @import("../config.zig").Real;
const MdFile = @import("md_file.zig").MdFile;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

pub const Frame = struct {
    id: ArrayList(u64),
    vel: ArrayList(V),
    time: Real,

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .id = ArrayList(u64).init(allocator),
            .vel = ArrayList(V).init(allocator),
            .time = 0.0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.id.deinit();
        self.vel.deinit();
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
    // Local variables
    var buf: [1024]u8 = undefined;
    var frame: ?Frame = null;

    // Iterate over lines
    var line_id: usize = 0;
    while (r.readUntilDelimiterOrEof(&buf, '\n') catch return error.BadPosLine) |line| {
        // Update line number
        line_id += 1;

        // Skip comments
        if (std.mem.startsWith(u8, line, "#")) continue;

        // Skip empty lines
        if (std.mem.trim(u8, line, " ").len == 0) continue;

        // Parse time line
        if (std.mem.startsWith(u8, line, "time")) {
            // Init frame
            if (frame) |fr| data.frames.append(fr) catch return error.OutOfMemory;
            frame = Frame.init(allocator);

            // Parse time
            const time = std.mem.trim(u8, line[4..], " ");
            frame.?.time = std.fmt.parseFloat(Real, time) catch {
                stopWithErrorMsg("Bad time value {s} in line {s}", .{ time, line });
                unreachable;
            };
            continue;
        }

        // Tokenize line
        var tokens = std.mem.tokenize(u8, line, " ");

        // Parse index
        frame.?.id.append(if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
            stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
            unreachable;
        } else {
            stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
            unreachable;
        }) catch return error.OutOfMemory;

        // Parse positions
        const vx = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
            stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
            unreachable;
        } else {
            stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
            unreachable;
        };

        const vy = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
            stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
            unreachable;
        } else {
            stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
            unreachable;
        };

        const vz = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
            stopWithErrorMsg("Bad x position value {s} in line {s}", .{ token, line });
            unreachable;
        } else {
            stopWithErrorMsg("Missing x position value at line #{d} -> {s}", .{ line_id, line });
            unreachable;
        };

        frame.?.vel.append(V.fromArray(.{ vx, vy, vz })) catch return error.OutOfMemory;
    }

    if (frame) |fr| data.frames.append(fr) catch return error.OutOfMemory;
}

pub const WriteDataError = error{WriteLine};
pub fn writeFrame(index: ArrayList(u64), vel: ArrayList(V), time: Real, w: Writer) WriteDataError!void {
    // Print time
    w.print("time {d:>12.3}\n", .{time}) catch return error.WriteLine;
    // Print units
    w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}\n", .{ "id", "vx", "vy", "vz" }) catch return error.WriteLine;
    w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}\n", .{ "-", "nm/ps", "nm/ps", "nm/ps" }) catch return error.WriteLine;
    // Print positions
    for (index.items) |id, i| {
        w.print("{d:>12}  {e:>12.5}  {e:>12.5}  {e:>12.5}\n", .{
            id,
            vel.items[i].items[0],
            vel.items[i].items[1],
            vel.items[i].items[2],
        }) catch return error.WriteLine;
    }
}

pub fn writeData(data: *Data, w: Writer, _: *Allocator) WriteDataError!void {
    // Loop over frames
    for (data.frames.items) |frame| {
        // Print frame
        try writeFrame(frame.id, frame.vel, frame.time, w);
        // Print new line
        w.print("\n", .{}) catch return error.WriteLine;
    }
}

pub const VelFile = MdFile(Data, ReadDataError, readData, WriteDataError, writeData);
