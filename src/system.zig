const std = @import("std");
const vec = @import("vec.zig");
const Vec = @import("vec.zig").Vec;
const Real = @import("config.zig").Real;
const ansi = @import("ansi-zig/src/ansi.zig");

// Ansi format
const reset = ansi.reset;
const bold = ansi.bold_on;
const blue = ansi.fg_light_blue;
const yellow = ansi.fg_light_yellow;

pub const Atom = struct {
    r: Vec = .{},
    v: Vec = .{},
    a: Vec = .{},
};

pub const System = struct {
    dt: Real,
    cell: Vec,
    atoms: std.ArrayList(Atom),
    energy: Energy,

    const Energy = struct {
        kinetic: Real = 0,
        potential: Real = 0,
        total: Real = 0,
    };

    const Self = @This();

    const Configuration = struct {
        dt: Real,
        cell: [3]Real,
        n_atoms: usize,
        temperature: Real,
    };

    pub fn init(allocator: *std.mem.Allocator, config: Configuration) !Self {
        var system: System = .{
            .dt = 0,
            .cell = .{},
            .atoms = std.ArrayList(Atom).init(allocator),
            .energy = .{},
        };

        system.dt = config.dt;

        system.cell.x = config.cell[0];
        system.cell.y = config.cell[1];
        system.cell.z = config.cell[2];

        try system.initAtoms(config.n_atoms, config.temperature);

        system.updateEnergies();

        return system;
    }

    pub fn deinit(self: Self) void {
        self.atoms.deinit();
    }

    pub fn addAtoms(self: *Self, n_atoms: usize) !void {
        var i: usize = 0;
        while (i < n_atoms) : (i += 1) {
            try self.atoms.append(Atom{});
        }
    }

    pub fn initPositions(self: *Self) void {
        const cell = self.cell;
        const n_atoms = @intToFloat(Real, self.atoms.items.len);
        const delta = vec.scale(self.cell, 1.0 / (n_atoms + 1));

        for (self.atoms.items) |*atom, i| {
            atom.r.x = -0.5 * cell.x + (@intToFloat(Real, i) + 0.5) * delta.x * cell.x;
            atom.r.y = -0.5 * cell.y + (@intToFloat(Real, i) + 0.5) * delta.y * cell.y;
            atom.r.z = -0.5 * cell.z + (@intToFloat(Real, i) + 0.5) * delta.z * cell.z;
        }
    }

    pub fn initVelocities(self: *Self, temp: Real) !void {
        // Initialize random number generator
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.os.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = &prng.random;

        // Initialize local variables
        var v_sum = Vec{};
        const n_atoms = @intToFloat(Real, self.atoms.items.len);
        const velocity = std.math.sqrt(3.0 * (1.0 - 1.0 / n_atoms) * temp);

        // Initialize with random velocities
        for (self.atoms.items) |*atom| {
            // Create a random unit vector
            var v_random = Vec{ .x = rand.float(Real), .y = rand.float(Real), .z = rand.float(Real) };
            v_random = vec.normalize(v_random);

            // Assign random velocity
            atom.v = vec.scale(v_random, velocity);
            v_sum = vec.add(v_sum, atom.v);
        }

        // Calculate system velocity
        const v_avg = vec.scale(v_sum, 1.0 / n_atoms);

        // Remove system velocity
        for (self.atoms.items) |*atom| {
            atom.v = vec.sub(atom.v, v_avg);
        }
    }

    pub fn initAccelerations(self: *Self) void {
        for (self.atoms.items) |*atom| {
            atom.a = Vec{};
        }
    }

    pub fn initAtoms(self: *Self, n_atoms: usize, temp: Real) !void {
        try self.addAtoms(n_atoms);
        self.initPositions();
        try self.initVelocities(temp);
        self.initAccelerations();
    }

    pub fn updateKineticEnergy(self: *Self) void {
        var kinetic: Real = 0.0;
        for (self.atoms.items) |atom| {
            kinetic += vec.dot(atom.v, atom.v);
        }

        self.energy.kinetic = 0.5 * kinetic;
    }

    pub fn updatePotentialEnergy(self: *Self) void {
        const rr_cut = std.math.pow(Real, 2.0, 1.0 / 3.0);
        var potential: Real = 0.0;

        var i: usize = 0;
        while (i < self.atoms.items.len) : (i += 1) {
            const iatom = self.atoms.items[i];

            var j: usize = i + 1;
            while (j < self.atoms.items.len) : (j += 1) {
                const jatom = self.atoms.items[j];

                var rij: Vec = undefined;
                rij = vec.sub(iatom.r, jatom.r);
                rij = vec.wrap(rij, self.cell);

                const rr = vec.dot(rij, rij);
                if (rr < rr_cut) {
                    const rri = 1.0 / rr;
                    const rri3 = rri * rri * rri;
                    potential += 4.0 * rri3 * (rri3 - 1.0) + 1.0;
                }
            }
        }

        self.energy.potential = potential;
    }

    pub fn updateEnergies(self: *Self) void {
        self.updateKineticEnergy();
        self.updatePotentialEnergy();
        self.energy.total = self.energy.kinetic + self.energy.potential;
    }

    pub fn calculateForces(self: *Self) void {
        const rr_cut = std.math.pow(Real, 2.0, 1.0 / 3.0);

        for (self.atoms.items) |*atom| {
            atom.a.x = 0.0;
            atom.a.y = 0.0;
            atom.a.z = 0.0;
        }

        var i: usize = 0;
        while (i < self.atoms.items.len) : (i += 1) {
            const iatom = self.atoms.items[i];

            var j: usize = i + 1;
            while (j < self.atoms.items.len) : (j += 1) {
                const jatom = self.atoms.items[j];

                var rij: Vec = undefined;
                rij = vec.sub(iatom.r, jatom.r);
                rij = vec.wrap(rij, self.cell);

                const rr = vec.dot(rij, rij);
                if (rr < rr_cut) {
                    const rri = 1.0 / rr;
                    const rri3 = rri * rri * rri;
                    const f = 48.0 * rri3 * (rri3 - 0.5) * rri;
                    const force = vec.scale(rij, f);

                    self.atoms.items[i].a = vec.add(self.atoms.items[i].a, force);
                    self.atoms.items[j].a = vec.sub(self.atoms.items[j].a, force);
                }
            }
        }
    }

    pub fn step(self: *Self) void {
        for (self.atoms.items) |*atom| {
            atom.v = vec.add(atom.v, vec.scale(atom.a, self.dt / 2.0));
            atom.r = vec.add(atom.r, vec.scale(atom.v, self.dt));
            self.calculateForces();
            atom.v = vec.add(atom.v, vec.scale(atom.a, self.dt / 2.0));
        }
    }

    pub fn displayInfo(self: Self) !void {
        // Get stdout
        const stdout = std.io.getStdOut().writer();

        // Print header
        try stdout.writeAll(bold ++ yellow ++ "> SYSTEM:\n" ++ reset);
        // Print values
        try stdout.print(bold ++ blue ++ "    Total:      " ++ reset ++ bold ++ "{e:>12.5}" ++ reset ++ "\n", .{self.energy.total});
        try stdout.print(bold ++ blue ++ "    Kinetic:    " ++ reset ++ bold ++ "{e:>12.5}" ++ reset ++ "\n", .{self.energy.kinetic});
        try stdout.print(bold ++ blue ++ "    Potential:  " ++ reset ++ bold ++ "{e:>12.5}" ++ reset ++ "\n", .{self.energy.potential});
    }
};
