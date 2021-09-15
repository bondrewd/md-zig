const std = @import("std");

const Input = @import("../input.zig").Input;

const math = @import("../math.zig");
const V = math.V;
const M = math.M;

const MolFile = @import("../file.zig").MolFile;

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

    pub fn force(ri: V, ei: f32, si: f32, rj: V, ej: f32, sj: f32, region: ?V, fi: *V, fj: *V, virial: *M) void {
        // Epsilon
        const e = if (ei == ej) ei else std.math.sqrt(ei * ej);
        // Sigma
        const s = if (si == sj) si else (si + sj) / 2.0;
        const s2 = s * s;
        // Cutoff
        const cutoff2 = 6.25 * s2;

        var rij = math.v.sub(ri, rj);
        if (region) rij = math.wrap(rij, region);
        const rij2 = math.v.dot(rij, rij);

        if (rij2 < cutoff2) {
            const c2 = s2 / rij2;
            const c4 = c2 * c2;
            const c8 = c4 * c4;
            const c14 = c8 * c4 * c2;

            const f = 48.0 * e * (c14 - 0.5 * c8) / s2;
            const fij = math.v.scale(rij, f);

            fi.* = math.v.add(fi.*, fij);
            fj.* = math.v.sub(fj.*, fij);

            virial.* = math.m.add(virial.*, math.v.direct(rij, fij));
        }
    }

    pub fn energy(ri: V, ei: f32, si: f32, rj: V, ej: f32, sj: f32, region: ?V, ene: *f32) void {
        // Epsilon
        const e = if (ei == ej) ei else std.math.sqrt(ei * ej);
        // Sigma
        const s = if (si == sj) si else (si + sj) / 2.0;
        const s2 = s * s;
        // Cutoff
        const cutoff2 = 6.25 * s2;

        var rij = math.v.sub(ri, rj);
        if (region) rij = math.wrap(rij, region);
        const rij2 = math.v.dot(rij, rij);

        if (rij2 < cutoff2) {
            const c2 = s2 / rij2;
            const c4 = c2 * c2;
            const c6 = c4 * c2;
            const c12 = c6 * c6;

            ene.* += 4.0 * e * (c12 - c6);
        }
    }
};

const testing = std.testing;
const dummyInput = @import("../input.zig").dummyInput;

test "Lennard Jones basic usage 1" {
    var in_mol_file = ArrayList(u8).init(testing.allocator);
    defer in_mol_file.deinit();
    try in_mol_file.appendSlice("test/unit/lj_basic_usage_01.mol");
    var in_mol_file_name = in_mol_file.items;

    var input = dummyInput();
    input.in_mol_file = in_mol_file_name;

    var lj = try LennardJones.init(testing.allocator, input);
    defer lj.deinit();

    // Check LJ indexes
    try testing.expect(lj.indexes.len == 3);
    try testing.expect(lj.indexes[0] == 1);
    try testing.expect(lj.indexes[1] == 2);
    try testing.expect(lj.indexes[2] == 3);

    // Check LJ e
    try testing.expect(lj.e.len == 3);
    try testing.expect(lj.e[0] == 0.1);
    try testing.expect(lj.e[1] == 0.2);
    try testing.expect(lj.e[2] == 0.3);

    // Check LJ s
    try testing.expect(lj.s.len == 3);
    try testing.expect(lj.s[0] == 0.1);
    try testing.expect(lj.s[1] == 0.2);
    try testing.expect(lj.s[2] == 0.3);
}
