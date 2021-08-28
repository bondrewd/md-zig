const std = @import("std");
const Real = @import("../config.zig").Real;
const LennardJonesParameters = @import("../ff.zig").LennardJonesParameters;
const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

pub const MolFile = struct {
    allocator: *std.mem.Allocator,
    id: std.ArrayList(u64),
    mass: std.ArrayList(Real),
    charge: std.ArrayList(Real),
    lennard_jones_parameters: std.ArrayList(LennardJonesParameters),

    const Self = @This();

    pub fn init(allocator: *std.mem.Allocator, file_name: []const u8) !Self {
        // Open pos file
        var file = try std.fs.cwd().openFile(file_name, .{ .read = true });

        // Init MolFile
        var mol_file = Self{
            .allocator = allocator,
            .id = std.ArrayList(u64).init(allocator),
            .mass = std.ArrayList(Real).init(allocator),
            .charge = std.ArrayList(Real).init(allocator),
            .lennard_jones_parameters = std.ArrayList(LennardJonesParameters).init(allocator),
        };

        // Got the first line
        try file.seekTo(0);

        // Get reader
        var r = file.reader();

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
                    try stopWithErrorMsg("Missing ']' character in section name -> {s}", .{line});
                }
            }
            const current_section_trim = std.mem.trim(u8, &current_section, " ");

            // Parse line
            var tokens = std.mem.tokenize(u8, line, " ");
            if (std.mem.eql(u8, current_section_trim, "LENNARD-JONES")) {
                // Parse index
                const id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    try stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const e = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    try stopWithErrorMsg("Bad epsilon value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing epsilon value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const s = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    try stopWithErrorMsg("Bad sigma value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing sigma value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                try mol_file.lennard_jones_parameters.append(LennardJonesParameters{
                    .id = id,
                    .e = e,
                    .s = s,
                });
            } else if (std.mem.eql(u8, current_section_trim, "PROPERTIES")) {
                // Parse index
                const id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    try stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const m = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    try stopWithErrorMsg("Bad mass value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing mass value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                const q = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    try stopWithErrorMsg("Bad charge value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    try stopWithErrorMsg("Missing charge value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };

                try mol_file.id.append(id);
                try mol_file.mass.append(m);
                try mol_file.charge.append(q);
            }
        }

        return mol_file;
    }

    pub fn deinit(self: Self) void {
        self.id.deinit();
        self.mass.deinit();
        self.charge.deinit();
        self.lennard_jones_parameters.deinit();
    }
};
