const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const Real = @import("config.zig").Real;
const stopWithErrorMsg = @import("exception.zig").stopWithErrorMsg;

const TypeInfo = std.builtin.TypeInfo;
const StructField = TypeInfo.StructField;
const Declaration = TypeInfo.Declaration;

pub const InputParserConfiguration = struct {
    line_buffer_size: usize = 1024,
    separator: []const u8 = " ",
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

        pub fn parseInputFile(f: std.fs.File) !InputParserResult {
            // Initialize input parser result
            var parsed_entries: InputParserResult = undefined;

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
                if (mem.startsWith(u8, line, "#")) continue;

                // Check for section
                if (mem.startsWith(u8, line, "[")) {
                    const closing_bracket = mem.indexOf(u8, line, "]");
                    if (closing_bracket) |index| {
                        mem.set(u8, &current_section, ' ');
                        mem.copy(u8, &current_section, line[1..index]);
                        continue;
                    } else {
                        try stopWithErrorMsg("Missing ']' character in section name");
                    }
                }

                // Parse arguments
                if (mem.eql(u8, config.separator, " ")) {
                    var tokens = mem.tokenize(u8, line, " ");
                    if (tokens.next()) |token| {
                        inline for (entries) |entry, i| {
                            if (mem.eql(u8, mem.trim(u8, &current_section, " "), entry.section)) {
                                if (mem.eql(u8, token, entry.name)) {
                                    entry_found[i] = true;
                                    if (tokens.next()) |val| {
                                        switch (@typeInfo(entry.entry_type)) {
                                            .Int => @field(parsed_entries, entry.name) = try fmt.parseInt(entry.entry_type, val, 10),
                                            .Float => @field(parsed_entries, entry.name) = try fmt.parseFloat(entry.entry_type, val),
                                            .Pointer => @field(parsed_entries, entry.name) = val,
                                            .Bool => @field(parsed_entries, entry.name) = blk: {
                                                if (mem.eql(u8, val, "on") or mem.eql(u8, val, "On") or mem.eql(u8, val, "ON") or mem.eql(u8, val, "yes") or mem.eql(u8, val, "Yes") or mem.eql(u8, val, "YES") or mem.eql(u8, val, "true") or mem.eql(u8, val, "True") or mem.eql(u8, val, "TRUE")) {
                                                    break :blk true;
                                                } else if (mem.eql(u8, val, "off") or mem.eql(u8, val, "Off") or mem.eql(u8, val, "OFF") or mem.eql(u8, val, "no") or mem.eql(u8, val, "No") or mem.eql(u8, val, "NO") or mem.eql(u8, val, "false") or mem.eql(u8, val, "False") or mem.eql(u8, val, "FALSE")) {
                                                    break :blk false;
                                                } else {
                                                    try stopWithErrorMsg("Bad value for entry " ++ entry.name);
                                                    unreachable;
                                                }
                                            },
                                            else => unreachable,
                                        }
                                    } else {
                                        try stopWithErrorMsg("Missing value for " ++ entry.name);
                                    }
                                }
                            }
                        }
                    }
                } else {
                    const sep = mem.indexOf(u8, line, config.separator);
                    if (sep) |idx| {
                        line[idx] = ' ';
                        var tokens = mem.tokenize(u8, line, " ");
                        if (tokens.next()) |token| {
                            inline for (entries) |entry, i| {
                                if (mem.eql(u8, mem.trim(u8, &current_section, " "), entry.section)) {
                                    if (mem.eql(u8, token, entry.name)) {
                                        entry_found[i] = true;
                                        if (tokens.next()) |val| {
                                            switch (@typeInfo(entry.entry_type)) {
                                                .Int => @field(parsed_entries, entry.name) = try fmt.parseInt(entry.entry_type, val, 10),
                                                .Float => @field(parsed_entries, entry.name) = try fmt.parseFloat(entry.entry_type, val),
                                                .Pointer => @field(parsed_entries, entry.name) = val,
                                                .Bool => @field(parsed_entries, entry.name) = blk: {
                                                    if (mem.eql(u8, val, "on") or mem.eql(u8, val, "On") or mem.eql(u8, val, "ON") or mem.eql(u8, val, "yes") or mem.eql(u8, val, "Yes") or mem.eql(u8, val, "YES") or mem.eql(u8, val, "true") or mem.eql(u8, val, "True") or mem.eql(u8, val, "TRUE")) {
                                                        break :blk true;
                                                    } else if (mem.eql(u8, val, "off") or mem.eql(u8, val, "Off") or mem.eql(u8, val, "OFF") or mem.eql(u8, val, "no") or mem.eql(u8, val, "No") or mem.eql(u8, val, "NO") or mem.eql(u8, val, "false") or mem.eql(u8, val, "False") or mem.eql(u8, val, "FALSE")) {
                                                        break :blk false;
                                                    } else {
                                                        try stopWithErrorMsg("Bad value for entry " ++ entry.name);
                                                        unreachable;
                                                    }
                                                },
                                                else => unreachable,
                                            }
                                        } else {
                                            try stopWithErrorMsg("Missing value for " ++ entry.name);
                                        }
                                    }
                                }
                            }
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
                        try stopWithErrorMsg("Missing value for " ++ entry.name);
                    }
                }
            }

            return parsed_entries;
        }

        pub fn parse(input_file_name: []const u8) !InputParserResult {
            var f = try std.fs.cwd().openFile(input_file_name, .{ .read = true });
            return try parseInputFile(f);
        }
    };
}

pub const MdInputParser = InputParser(.{ .separator = "=" }, [_]InputParserEntry{
    .{
        .name = "dt",
        .entry_type = Real,
        .section = "Dynamics",
    },
    .{
        .name = "steps",
        .entry_type = u64,
        .section = "Dynamics",
    },
    .{
        .name = "out_freq_info",
        .entry_type = u64,
        .section = "Output",
    },
});
