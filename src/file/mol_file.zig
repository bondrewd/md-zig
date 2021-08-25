const std = @import("std");
const Real = @import("../config.zig").Real;
const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

pub const LennardJonesParameters = struct {
    id: u64 = undefined,
    e: Real = undefined,
    s: Real = undefined,
};

pub const AtomProperty = struct {
    id: u64 = undefined,
    mass: Real = undefined,
    charge: Real = undefined,
};

pub const MolFileParserConfiguration = struct {
    line_buffer_size: usize = 1024,
    section_opening: []const u8 = "[",
    section_closing: []const u8 = "]",
    comment_character: []const u8 = "#",
};

pub fn MolFile(comptime config: MolFileParserConfiguration) type {
    return struct {
        allocator: *std.mem.Allocator,
        lennard_jones_parameters: std.ArrayList(LennardJonesParameters),
        atom_properties: std.ArrayList(AtomProperty),

        const Self = @This();

        pub fn initFile(allocator: *std.mem.Allocator, file: std.fs.File) !Self {
            // Init MolFile
            var mol_file = Self{
                .allocator = allocator,
                .lennard_jones_parameters = std.ArrayList(LennardJonesParameters).init(allocator),
                .atom_properties = std.ArrayList(AtomProperty).init(allocator),
            };

            // Got the first line
            try file.seekTo(0);

            // Get reader
            var r = file.reader();

            // Declare buffer
            var buf: [config.line_buffer_size]u8 = undefined;

            // Section name
            var current_section: [config.line_buffer_size]u8 = undefined;

            // Iterate over lines
            var line_id: usize = 0;
            while (try r.readUntilDelimiterOrEof(&buf, '\n')) |line| {
                // Update line number
                line_id += 1;

                // Skip comments
                if (std.mem.startsWith(u8, line, config.comment_character)) continue;

                // Skip empty lines
                if (std.mem.trim(u8, line, " ").len == 0) continue;

                // Check for section
                if (std.mem.startsWith(u8, line, config.section_opening)) {
                    const closing_symbol = std.mem.indexOf(u8, line, config.section_closing);
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

                    try mol_file.atom_properties.append(AtomProperty{
                        .id = id,
                        .mass = m,
                        .charge = q,
                    });
                }
            }

            return mol_file;
        }

        pub fn init(allocator: *std.mem.Allocator, file_name: []const u8) !Self {
            // Open pos file
            var f = try std.fs.cwd().openFile(file_name, .{ .read = true });

            // Parse file
            return try initFile(allocator, f);
        }

        pub fn deinit(self: Self) void {
            self.lennard_jones_parameters.deinit();
            self.atom_properties.deinit();
        }
    };
}
