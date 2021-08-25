const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Real = @import("config.zig").Real;
const stopWithErrorMsg = @import("exception.zig").stopWithErrorMsg;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const TypeInfo = std.builtin.TypeInfo;
const StructField = TypeInfo.StructField;
const Declaration = TypeInfo.Declaration;

pub const InputParserConfiguration = struct {
    line_buffer_size: usize = 1024,
    separator: []const u8 = " ",
    section_opening: []const u8 = "[",
    section_closing: []const u8 = "]",
    comment_character: []const u8 = "#",
};

pub const InputParserEntry = struct {
    name: []const u8,
    entry_type: type = bool,
    section: []const u8,
    default_value: ?union { int: comptime_int, float: comptime_float, string: []const u8, boolean: bool } = null,
};

pub fn InputParser(comptime config: InputParserConfiguration, comptime entries: anytype) type {
    return struct {
        const Self = @This();

        pub const InputParserResult = blk: {
            // Struct fields
            var fields: [entries.len]StructField = undefined;
            inline for (entries) |entry, i| {
                // Validate entry
                fields[i] = .{
                    .name = entry.name,
                    .field_type = entry.entry_type,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = @alignOf(entry.entry_type),
                };
            }

            // Struct declarations
            var decls: [0]Declaration = .{};

            break :blk @Type(TypeInfo{ .Struct = .{
                .layout = .Auto,
                .fields = &fields,
                .decls = &decls,
                .is_tuple = false,
            } });
        };

        pub fn parseInputFile(allocator: *Allocator, f: std.fs.File) !InputParserResult {
            // Initialize input parser result
            var parsed_entries: InputParserResult = undefined;
            inline for (entries) |entry| {
                @field(parsed_entries, entry.name) = switch (@typeInfo(entry.entry_type)) {
                    .Pointer => blk: {
                        var buf = try allocator.alloc(u8, config.line_buffer_size);
                        mem.set(u8, buf, ' ');
                        break :blk buf;
                    },
                    else => undefined,
                };
            }

            // Initialize input parser flags
            var entry_found = [_]bool{false} ** entries.len;

            // Go to the start of the file
            try f.seekTo(0);

            // Get reader
            const r = f.reader();

            // Line buffer
            var buf: [config.line_buffer_size]u8 = undefined;

            // Section name
            var current_section: [config.line_buffer_size]u8 = undefined;

            while (try r.readUntilDelimiterOrEof(&buf, '\n')) |line| {
                // Skip comments
                if (mem.startsWith(u8, line, config.comment_character)) continue;

                // Skip empty lines
                if (mem.trim(u8, line, " ").len == 0) continue;

                // Check for section
                if (mem.startsWith(u8, line, config.section_opening)) {
                    const closing_symbol = mem.indexOf(u8, line, config.section_closing);
                    if (closing_symbol) |index| {
                        mem.set(u8, &current_section, ' ');
                        mem.copy(u8, &current_section, line[1..index]);
                        continue;
                    } else {
                        try stopWithErrorMsg("Missing ']' character in section name -> {s}", .{line});
                    }
                }

                // Replace separator
                if (!mem.eql(u8, config.separator, " ")) {
                    const sep_idx = mem.indexOf(u8, line, config.separator);
                    if (sep_idx) |idx| {
                        line[idx] = ' ';
                    } else {
                        try stopWithErrorMsg("Missing separator " ++ config.separator ++ " -> {s}", .{line});
                    }
                }

                // Parse arguments
                var tokens = mem.tokenize(u8, line, " ");

                // Get key
                const key = if (tokens.next()) |token| token else {
                    try stopWithErrorMsg("Missing key value in input file -> {s}", .{line});
                    unreachable;
                };

                // Get value
                const rest = tokens.rest();
                const val = if (std.mem.indexOf(u8, rest, "#")) |index| rest[0..index] else rest;
                const val_trim = std.mem.trim(u8, val, " ");

                // Look for the corresponding input
                inline for (entries) |entry, i| {
                    const current_section_trim = mem.trim(u8, &current_section, " ");
                    var in_section = mem.eql(u8, current_section_trim, entry.section);
                    var in_entry = mem.eql(u8, key, entry.name);
                    if (in_section and in_entry) {
                        entry_found[i] = true;
                        switch (@typeInfo(entry.entry_type)) {
                            .Int => @field(parsed_entries, entry.name) = try fmt.parseInt(entry.entry_type, val_trim, 10),
                            .Float => @field(parsed_entries, entry.name) = try fmt.parseFloat(entry.entry_type, val_trim),
                            .Pointer => mem.copy(u8, @field(parsed_entries, entry.name), val_trim),
                            .Bool => @field(parsed_entries, entry.name) = blk: {
                                var buffer: [line_buffer_size]u8 = undefined;
                                var val_up = std.ascii.upperString(&buffer, val_trim);
                                if (mem.eql(u8, val_up, "ON") or mem.eql(u8, val_up, "YES") or mem.eql(u8, val_up, "TRUE")) break :blk true;
                                if (mem.eql(u8, val_up, "OFF") or mem.eql(u8, val_up, "NO") or mem.eql(u8, val_up, "FALSE")) break :blk false;
                                try stopWithErrorMsg("Bad value for entry " ++ entry.name ++ " -> {s}", .{val_trim});
                            },
                            else => unreachable,
                        }
                    }
                }
            }

            inline for (entries) |entry, i| {
                if (!entry_found[i]) {
                    if (entry.default_value) |default| {
                        switch (@typeInfo(entry.entry_type)) {
                            .Int => @field(parsed_entries, entry.name) = default.int,
                            .Float => @field(parsed_entries, entry.name) = default.float,
                            .Pointer => @field(parsed_entries, entry.name) = default.string,
                            .Bool => @field(parsed_entries, entry.name) = default.boolean,
                            else => unreachable,
                        }
                    } else {
                        try stopWithErrorMsg("Missing value for " ++ entry.name, .{});
                    }
                }
            }

            return parsed_entries;
        }

        pub fn parse(allocator: *Allocator, input_file_name: []const u8) !InputParserResult {
            var f = try std.fs.cwd().openFile(input_file_name, .{ .read = true });
            return try parseInputFile(allocator, f);
        }

        pub fn deinit(allocator: *Allocator, parsed_entries: InputParserResult) void {
            inline for (entries) |entry| {
                switch (@typeInfo(entry.entry_type)) {
                    .Pointer => allocator.free(@field(parsed_entries, entry.name)),
                    else => {},
                }
            }
        }
    };
}

pub const MdInputParser = InputParser(.{ .separator = "=" }, [_]InputParserEntry{
    .{
        .name = "mol_file",
        .entry_type = []u8,
        .section = "INPUT",
    },
    .{
        .name = "grp_file",
        .entry_type = []u8,
        .section = "INPUT",
    },
    .{
        .name = "pos_file",
        .entry_type = []u8,
        .section = "INPUT",
    },
    .{
        .name = "integrator",
        .entry_type = []u8,
        .section = "DYNAMICS",
    },
    .{
        .name = "n_steps",
        .entry_type = u64,
        .section = "DYNAMICS",
    },
    .{
        .name = "time_step",
        .entry_type = Real,
        .section = "DYNAMICS",
    },
    .{
        .name = "ensemble",
        .entry_type = []u8,
        .section = "DYNAMICS",
    },
    .{
        .name = "rng_seed",
        .entry_type = u64,
        .section = "DYNAMICS",
    },
    .{
        .name = "temperature",
        .entry_type = Real,
        .section = "DYNAMICS",
    },
    .{
        .name = "boundary_type",
        .entry_type = []u8,
        .section = "BOUNDARY",
    },
    .{
        .name = "region_size_x",
        .entry_type = Real,
        .section = "BOUNDARY",
    },
    .{
        .name = "region_size_y",
        .entry_type = Real,
        .section = "BOUNDARY",
    },
    .{
        .name = "region_size_z",
        .entry_type = Real,
        .section = "BOUNDARY",
    },
});
