const std = @import("std");

const Input = @import("input.zig").Input;

const math = @import("math.zig");
const V = math.V;
const M = math.M;

const MolFile = @import("file.zig").MolFile;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const LennardJones = struct {
    allocator: *Allocator,
    indexes: []u32,
    e: []f32,
    s: []f32,

    pub const Self = @This();

    pub fn init(allocator: *Allocator, input: Input) !Self {
        // Read mol file
        var mol_file = MolFile.init(allocator);
        defer mol_file.deinit();
        try mol_file.openFile(input.in_mol_file, .{});
        defer mol_file.close();
        try mol_file.readData();

        // Allocate slices
        const n = mol_file.data.lennard_jones.indexes.items.len;
        var indexes = try allocator.alloc(u32, n);
        var e = try allocator.alloc(f32, n);
        var s = try allocator.alloc(f32, n);

        // Copy information from pos file
        std.mem.copy(u32, indexes, mol_file.data.lennard_jones.indexes.items);
        std.mem.copy(f32, e, mol_file.data.lennard_jones.e.items);
        std.mem.copy(f32, s, mol_file.data.lennard_jones.s.items);

        return Self{
            .allocator = allocator,
            .indexes = indexes,
            .e = e,
            .s = s,
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.indexes);
        self.allocator.free(self.e);
        self.allocator.free(self.s);
    }
};

pub const ForceField = struct {
    allocator: *Allocator,
    lennard_jones: LennardJones,

    pub const Self = @This();

    pub fn init(allocator: *Allocator, input: Input) !Self {
        return Self{
            .allocator = allocator,
            .lennard_jones = try LennardJones.init(allocator, input),
        };
    }

    pub fn deinit(self: Self) void {
        self.lennard_jones.deinit();
    }
};

const testing = std.testing;
const dummyInput = @import("input.zig").dummyInput;

test "Force field basic usage 1" {
    var in_mol_file = ArrayList(u8).init(testing.allocator);
    defer in_mol_file.deinit();
    try in_mol_file.appendSlice("test/unit/ff_basic_usage_01.mol");
    var in_mol_file_name = in_mol_file.items;

    var input = dummyInput();
    input.in_mol_file = in_mol_file_name;

    var ff = try ForceField.init(testing.allocator, input);
    defer ff.deinit();

    // Check LJ indexes
    try testing.expect(ff.lennard_jones.indexes.len == 3);
    try testing.expect(ff.lennard_jones.indexes[0] == 1);
    try testing.expect(ff.lennard_jones.indexes[1] == 2);
    try testing.expect(ff.lennard_jones.indexes[2] == 3);

    // Check LJ e
    try testing.expect(ff.lennard_jones.e.len == 3);
    try testing.expect(ff.lennard_jones.e[0] == 0.1);
    try testing.expect(ff.lennard_jones.e[1] == 0.2);
    try testing.expect(ff.lennard_jones.e[2] == 0.3);

    // Check LJ s
    try testing.expect(ff.lennard_jones.s.len == 3);
    try testing.expect(ff.lennard_jones.s[0] == 0.1);
    try testing.expect(ff.lennard_jones.s[1] == 0.2);
    try testing.expect(ff.lennard_jones.s[2] == 0.3);
}
