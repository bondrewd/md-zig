const std = @import("std");
const vec = @import("vec.zig");
const Vec = @import("vec.zig").Vec;
const Real = @import("config.zig").Real;

pub const Atom = struct {
    r: Vec = .{},
    v: Vec = .{},
    a: Vec = .{},
};

pub const System = struct {
    const Self = @This();

    cell: Vec,
    atoms: std.ArrayList(Atom),

    const Configuration = struct {
        cell: [3]Real,
        temperature: Real,
    };

    pub fn init(allocator: *std.mem.Allocator, config: Configuration) Self {
        var system: System = .{
            .cell = .{},
            .atoms = std.ArrayList(Atom).init(allocator),
        };

        system.cell.x = config.cell[0];
        system.cell.y = config.cell[1];
        system.cell.z = config.cell[2];

        system.initAtoms(config.temperature);

        return system;
    }

    pub fn deinit(self: Self) void {
        self.atoms.deinit();
    }

    pub fn addAtoms(self: Self, n_atoms: usize) !void {
        var i: usize = 0;
        while (i < n_atoms) : (i += 1) {
            try self.atoms.append(Atom{});
        }
    }

    pub fn initPositions(self: Self) void {
        const cell = self.cell;
        const n_atoms = @intToFloat(Real, self.atoms.items.len);
        const delta = vec.scale(self.cell, 1.0 / n_atoms);

        for (self.atoms.items) |*atom, i| {
            atom.r.x = -0.5 * cell.x + @intToFloat(Real, i) * delta.x * cell.x;
            atom.r.y = -0.5 * cell.y + @intToFloat(Real, i) * delta.y * cell.y;
            atom.r.z = -0.5 * cell.z + @intToFloat(Real, i) * delta.z * cell.z;
        }
    }

    pub fn initVelocities(self: Self, temp: Real) void {
        var v_sum = Vec{};
        const n_atoms = @intToFloat(Real, self.atoms.items.len);
        const velocity = std.math.sqrt(3.0 * (1.0 - 1.0 / n_atoms) * temp);
        for (self.atoms.items) |*atom| {
            atom.v = vec.scale(Vec{}, velocity);
            v_sum = vec.add(v_sum, atom.v);
        }
        const v_avg = vec.scale(v_sum, 1.0 / n_atoms);

        for (self.atoms.items) |*atom| {
            atom.v = vec.sub(atom.v, v_avg);
        }
    }

    pub fn initAccelerations(self: Self) void {
        for (self.atoms.items) |*atom| {
            atom.a = Vec{};
        }
    }

    pub fn initAtoms(self: Self, temp: Real) void {
        self.initPositions();
        self.initVelocities(temp);
        self.initAccelerations();
    }
};
