const std = @import("std");
const Real = @import("../config.zig").Real;
const LennardJonesParameters = @import("../ff.zig").LennardJonesParameters;
const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

const MolFileData = struct {
    id: std.ArrayList(u64),
    mass: std.ArrayList(Real),
    charge: std.ArrayList(Real),
    lj_parameters: std.ArrayList(LennardJonesParameters),
};

pub const MolFile = struct {
    allocator: *std.mem.Allocator = undefined,
    writer: ?std.fs.File.Writer = undefined,
    reader: ?std.fs.File.Reader = undefined,
    file: ?std.fs.File = undefined,
    data: MolFileData = undefined,

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .data = .{
                .id = std.ArrayList(u64).init(allocator),
                .mass = std.ArrayList(Real).init(allocator),
                .charge = std.ArrayList(Real).init(allocator),
                .lj_parameters = std.ArrayList(LennardJonesParameters).init(allocator),
            },
        };
    }

    pub fn deinit(self: Self) void {
        if (self.file) |f| f.close();
        self.data.id.deinit();
        self.data.mass.deinit();
        self.data.charge.deinit();
        self.data.lj_parameters.deinit();
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

    pub fn load(self: *Self) !void {
        // Get file
        var f = if (self.file) |file| file else {
            stopWithErrorMsg("Can't load mol file before open one", .{});
            unreachable;
        };

        // Get reader
        var r = if (self.reader) |reader| reader else {
            stopWithErrorMsg("Can't load mol file without read flag on", .{});
            unreachable;
        };

        // Got the first line
        try f.seekTo(0);

        // Declare buffer
        var buf: [1024]u8 = undefined;

        // Section name
        var current_section: [1024]u8 = undefined;

        // Iterate over lines
        var line_id: usize = 0;
        while (try r.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            // Update line number
            line_id += 1;

            // Skip comments
            if (std.mem.startsWith(u8, line, "#")) continue;

            // Skip empty lines
            if (std.mem.trim(u8, line, " ").len == 0) continue;

            // Check for section
            if (std.mem.startsWith(u8, line, "[")) {
                const closing_symbol = std.mem.indexOf(u8, line, "]");
                if (closing_symbol) |index| {
                    std.mem.set(u8, &current_section, ' ');
                    std.mem.copy(u8, &current_section, line[1..index]);
                    continue;
                } else {
                    stopWithErrorMsg("Missing ']' character in section name -> {s}", .{line});
                }
            }
            const current_section_trim = std.mem.trim(u8, &current_section, " ");

            // Parse line
            var tokens = std.mem.tokenize(u8, line, " ");
            if (std.mem.eql(u8, current_section_trim, "LENNARD-JONES")) {
                // Parse index
                const id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const e = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad epsilon value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing epsilon value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const s = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad sigma value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing sigma value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                try self.data.lj_parameters.append(LennardJonesParameters{
                    .id = id,
                    .e = e,
                    .s = s,
                });
            } else if (std.mem.eql(u8, current_section_trim, "PROPERTIES")) {
                // Parse index
                const id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                // TODO: Parse element
                _ = tokens.next();

                // TODO: Parse name
                _ = tokens.next();

                const m = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad mass value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing mass value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const q = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad charge value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing charge value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                try self.data.id.append(id);
                try self.data.mass.append(m);
                try self.data.charge.append(q);
            }
        }
    }

    pub fn printData(self: *Self) !void {
        // Get writer
        var w = self.file.writer();

        // Properties
        try w.writeAll("[ PROPERTIES ]\n");
        var i: usize = 0;
        while (i < self.data.id.items.len) : (i += 1) {
            try w.print("{d:>8} {d:>8.3} {d:>8.3}\n", .{
                self.data.id.items[i],
                self.data.mass.items[i],
                self.data.charge.items[i],
            });
        }

        try w.writeAll("\n");

        // Lennard-Jones parameters
        try w.writeAll("[ LENNARD-JONES ]\n");
        i = 0;
        while (i < self.data.id.items.len) : (i += 1) {
            try w.print("{d:>8} {d:>8.3} {d:>8.3}\n", .{
                self.data.lj_parameters.id.items[i],
                self.data.lj_parameters.e.items[i],
                self.data.lj_parameters.s.items[i],
            });
        }
    }
};
