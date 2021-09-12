const std = @import("std");

const File = std.fs.File;
const Reader = File.Reader;
const Writer = File.Writer;

const Real = @import("../config.zig").Real;
const MdFile = @import("md_file.zig").MdFile;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const stopWithErrorMsg = @import("../exception.zig").stopWithErrorMsg;

pub const Properties = struct {
    id: ArrayList(u64),
    element: ArrayList([]u8),
    name: ArrayList([]u8),
    mass: ArrayList(Real),
    charge: ArrayList(Real),

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .id = ArrayList(u64).init(allocator),
            .element = ArrayList([]u8).init(allocator),
            .name = ArrayList([]u8).init(allocator),
            .mass = ArrayList(Real).init(allocator),
            .charge = ArrayList(Real).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.id.deinit();
        for (self.element.items) |element| self.element.allocator.free(element);
        self.element.deinit();
        for (self.name.items) |name| self.name.allocator.free(name);
        self.name.deinit();
        self.mass.deinit();
        self.charge.deinit();
    }
};

pub const LennardJones = struct {
    id: ArrayList(u64),
    e: ArrayList(Real),
    s: ArrayList(Real),

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .id = ArrayList(u64).init(allocator),
            .e = ArrayList(Real).init(allocator),
            .s = ArrayList(Real).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.id.deinit();
        self.e.deinit();
        self.s.deinit();
    }
};

pub const HarmonicBond = struct {
    i_id: ArrayList(u64),
    j_id: ArrayList(u64),
    k: ArrayList(Real),
    b: ArrayList(Real),

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .i_id = ArrayList(u64).init(allocator),
            .j_id = ArrayList(u64).init(allocator),
            .k = ArrayList(Real).init(allocator),
            .b = ArrayList(Real).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.i_id.deinit();
        self.j_id.deinit();
        self.k.deinit();
        self.b.deinit();
    }
};

pub const HarmonicAngle = struct {
    i_id: ArrayList(u64),
    j_id: ArrayList(u64),
    k_id: ArrayList(u64),
    k: ArrayList(Real),
    t: ArrayList(Real),

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .i_id = ArrayList(u64).init(allocator),
            .j_id = ArrayList(u64).init(allocator),
            .k_id = ArrayList(u64).init(allocator),
            .k = ArrayList(Real).init(allocator),
            .t = ArrayList(Real).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.i_id.deinit();
        self.j_id.deinit();
        self.k_id.deinit();
        self.k.deinit();
        self.t.deinit();
    }
};

pub const Data = struct {
    properties: Properties,
    lennard_jones: LennardJones,
    harmonic_bond: HarmonicBond,
    harmonic_angle: HarmonicAngle,

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .properties = Properties.init(allocator),
            .lennard_jones = LennardJones.init(allocator),
            .harmonic_bond = HarmonicBond.init(allocator),
            .harmonic_angle = HarmonicAngle.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.properties.deinit();
        self.lennard_jones.deinit();
        self.harmonic_bond.deinit();
        self.harmonic_angle.deinit();
    }
};

pub const ReadDataError = error{ BadMolLine, OutOfMemory };
pub fn readData(data: *Data, r: Reader, allocator: *Allocator) ReadDataError!void {
    // Section enum
    const Section = enum {
        Properties,
        LennardJones,
        HarmonicBond,
        HarmonicAngle,
    };

    // Local variables
    var buf: [1024]u8 = undefined;

    // Section name
    var section: Section = undefined;

    // Iterate over lines
    var line_id: usize = 0;
    while (r.readUntilDelimiterOrEof(&buf, '\n') catch return error.BadMolLine) |line| {
        // Update line number
        line_id += 1;

        // Skip comments
        if (std.mem.startsWith(u8, line, "#")) continue;

        // Skip empty lines
        if (std.mem.trim(u8, line, " ").len == 0) continue;

        // Parse section name
        if (std.mem.startsWith(u8, line, "[")) {
            const closing_symbol = std.mem.indexOf(u8, line, "]");
            if (closing_symbol) |index| {
                const section_name = std.mem.trim(u8, line[1..index], " ");
                if (std.mem.eql(u8, section_name, "PROPERTIES")) section = .Properties;
                if (std.mem.eql(u8, section_name, "LENNARD-JONES")) section = .LennardJones;
                if (std.mem.eql(u8, section_name, "HARMONIC-BOND")) section = .HarmonicBond;
                if (std.mem.eql(u8, section_name, "HARMONIC-ANGLE")) section = .HarmonicAngle;
                continue;
            } else {
                stopWithErrorMsg("Missing ']' character in section name -> {s}", .{line});
            }
        }

        // Tokenize line
        var tokens = std.mem.tokenize(u8, line, " ");

        // Parse section line
        switch (section) {
            .Properties => {
                // Parse index
                const id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.properties.id.append(id) catch return error.OutOfMemory;

                // Parse element
                const element = if (tokens.next()) |token| token else {
                    stopWithErrorMsg("Missing element name at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.properties.element.append(blk: {
                    var list = ArrayList(u8).init(allocator);
                    list.appendSlice(element) catch return error.OutOfMemory;
                    break :blk list.toOwnedSlice();
                }) catch return error.OutOfMemory;

                // Parse name
                const name = if (tokens.next()) |token| token else {
                    stopWithErrorMsg("Missing atom name at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.properties.name.append(blk: {
                    var list = ArrayList(u8).init(allocator);
                    list.appendSlice(name) catch return error.OutOfMemory;
                    break :blk list.toOwnedSlice();
                }) catch return error.OutOfMemory;

                // Parse mass
                const mass = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad mass value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing mass value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.properties.mass.append(mass) catch return error.OutOfMemory;

                // Parse charge
                const charge = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad charge value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing charge value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.properties.charge.append(charge) catch return error.OutOfMemory;
            },
            .LennardJones => {
                // Parse index
                const id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.lennard_jones.id.append(id) catch return error.OutOfMemory;

                // Parse epsilon
                const e = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad epsilon value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing epsilon value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.lennard_jones.e.append(e) catch return error.OutOfMemory;

                // Parse sigma
                const s = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad sigma value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing sigma value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.lennard_jones.s.append(s) catch return error.OutOfMemory;
            },
            .HarmonicBond => {
                // Parse i-index
                const i_id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad i-index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing i-index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_bond.i_id.append(i_id) catch return error.OutOfMemory;

                // Parse j-index
                const j_id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad j-index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing j-index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_bond.j_id.append(j_id) catch return error.OutOfMemory;

                // Parse k0
                const k = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad force constant value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing force constant value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_bond.k.append(k) catch return error.OutOfMemory;

                // Parse b0
                const b = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad equilibrium length value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing equilibrium length value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_bond.b.append(b) catch return error.OutOfMemory;
            },
            .HarmonicAngle => {
                // Parse i-index
                const i_id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad i-index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing i-index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_angle.i_id.append(i_id) catch return error.OutOfMemory;

                // Parse j-index
                const j_id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad j-index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing j-index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_angle.j_id.append(j_id) catch return error.OutOfMemory;

                // Parse k-index
                const k_id = if (tokens.next()) |token| std.fmt.parseInt(u64, token, 10) catch {
                    stopWithErrorMsg("Bad k-index value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing k-index value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_angle.k_id.append(k_id) catch return error.OutOfMemory;

                // Parse k0
                const k = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad force constant value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing force constant value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_angle.k.append(k) catch return error.OutOfMemory;

                // Parse t0
                const t = if (tokens.next()) |token| std.fmt.parseFloat(Real, token) catch {
                    stopWithErrorMsg("Bad equilibrium angle value {s} in line {s}", .{ token, line });
                    unreachable;
                } else {
                    stopWithErrorMsg("Missing equilibrium angle value at line #{d} -> {s}", .{ line_id, line });
                    unreachable;
                };
                data.harmonic_angle.t.append(t) catch return error.OutOfMemory;
            },
        }
    }
}

pub const WriteDataError = error{WriteLine};
pub fn writeProperties(properties: Properties, w: Writer) WriteDataError!void {
    // Print section name
    w.print("[ PROPERTIES ]\n", .{}) catch return error.WriteLine;
    // Print units
    w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}  {s:>12}\n", .{
        "id",
        "element",
        "name",
        "mass",
        "charge",
    }) catch return error.WriteLine;
    w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}  {s:>12}\n", .{
        "-",
        "-",
        "-",
        "g/mol",
        "e",
    }) catch return error.WriteLine;
    // Print properties
    for (properties.id.items) |id, i| {
        w.print("{d:>12}  {s:>12}  {s:>12}  {d:>12.5}  {d:>12.5}\n", .{
            id,
            properties.element.items[i],
            properties.name.items[i],
            properties.mass.items[i],
            properties.charge.items[i],
        }) catch return error.WriteLine;
    }
}

pub fn writeLennardJones(lennard_jones: LennardJones, w: Writer) WriteDataError!void {
    // Print section name
    w.print("[ LENNARD-JONES ]\n", .{}) catch return error.WriteLine;
    // Print units
    w.print("#{s:>11}  {s:>12}  {s:>12}\n", .{
        "id",
        "epsilon",
        "sigma",
    }) catch return error.WriteLine;
    w.print("#{s:>11}  {s:>12}  {s:>12}\n", .{
        "-",
        "kJ/mol",
        "nm",
    }) catch return error.WriteLine;
    // Print harmonic bonds
    for (lennard_jones.id.items) |id, i| {
        w.print("{d:>12}  {d:>12.5}  {d:>12.5}\n", .{
            id,
            lennard_jones.e.items[i],
            lennard_jones.s.items[i],
        }) catch return error.WriteLine;
    }
}

pub fn writeHarmonicBond(harmonic_bond: HarmonicBond, w: Writer) WriteDataError!void {
    // Print section name
    w.print("[ HARMONIC-BOND ]\n", .{}) catch return error.WriteLine;
    // Print units
    w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}\n", .{
        "i-index",
        "j-index",
        "k0",
        "b0",
    }) catch return error.WriteLine;
    w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}\n", .{
        "-",
        "-",
        "kJ/mol-nm",
        "nm",
    }) catch return error.WriteLine;
    // Print harmonic bonds
    for (harmonic_bond.i_id.items) |i_id, i| {
        w.print("{d:>12}  {d:>12}  {d:>12.5}  {d:>12.5}\n", .{
            i_id,
            harmonic_bond.j_id.items[i],
            harmonic_bond.k.items[i],
            harmonic_bond.b.items[i],
        }) catch return error.WriteLine;
    }
}

pub fn writeHarmonicAngle(harmonic_angle: HarmonicAngle, w: Writer) WriteDataError!void {
    // Print section name
    w.print("[ HARMONIC-ANGLE ]\n", .{}) catch return error.WriteLine;
    // Print units
    w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}  {s:>12}\n", .{
        "i-index",
        "j-index",
        "k-index",
        "k0",
        "b0",
    }) catch return error.WriteLine;
    w.print("#{s:>11}  {s:>12}  {s:>12}  {s:>12}  {s:>12}\n", .{
        "-",
        "-",
        "-",
        "kJ/mol-nm",
        "nm",
    }) catch return error.WriteLine;
    // Print harmonic angles
    for (harmonic_angle.i_id.items) |i_id, i| {
        w.print("{d:>12}  {d:>12}  {d:>12}  {d:>12.5}  {d:>12.5}\n", .{
            i_id,
            harmonic_angle.j_id.items[i],
            harmonic_angle.k_id.items[i],
            harmonic_angle.k.items[i],
            harmonic_angle.t.items[i],
        }) catch return error.WriteLine;
    }
}

pub fn writeData(data: *Data, w: Writer, _: *Allocator) WriteDataError!void {
    // Print proterties section
    try writeProperties(data.properties, w);
    // Print new line
    w.print("\n", .{}) catch return error.WriteLine;

    // Print lennard-jones section
    try writeLennardJones(data.lennard_jones, w);
    // Print new line
    w.print("\n", .{}) catch return error.WriteLine;

    // Print harmonic-bond section
    try writeHarmonicBond(data.harmonic_bond, w);
    // Print new line
    w.print("\n", .{}) catch return error.WriteLine;

    // Print harmonic-angle section
    try writeHarmonicAngle(data.harmonic_angle, w);
}

pub const MolFile = MdFile(Data, ReadDataError, readData, WriteDataError, writeData);
