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
    const Properties = struct {
        const Energy = struct { potential: Real = 0, kinetic: Real = 0, total: Real = 0 };
        const Self = @This();

        energy: Energy = .{},
        velocity: Vec = .{},
        pressure: Vec = .{},
        virial: Vec = .{},
    };
    const Self = @This();

    box: Vec,
    atoms: std.ArrayList(Atom),
    cutoff: Real,
    props: Properties,

    pub fn init(allocator: *std.mem.Allocator) Self {
        return .{
            .box = .{},
            .atoms = std.ArrayList(Atom).init(allocator),
            .cutoff = std.math.pow(Real, 2, 1 / 6),
            .props = .{},
        };
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
        const box = self.box;
        const delta = vec.scale(self.box, 1 / self.atoms.len);
        for (self.atoms.items) |*atom, i| {
            atom.r.x = -0.5 * box.x + @intToFloat(Real, i) * delta * box.x;
            atom.r.y = -0.5 * box.y + @intToFloat(Real, i) * delta * box.y;
            atom.r.z = -0.5 * box.z + @intToFloat(Real, i) * delta * box.z;
        }
    }

    pub fn initVelocities(self: Self, temp: Real) void {
        var v_sum = Vec{};
        const velocity = std.math.sqrt(3 * (1 - 1 / self.atoms.items.len) * temp);
        for (self.atoms.items) |*atom| {
            atom.v = vec.scale(Vec{}, velocity);
            v_sum = vec.add(v_sum, atom.v);
        }
        const v_avg = vec.scale(v_sum, 1 / self.atoms.items.len);

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

    pub fn measure(self: Self) void {
        var v_sum: Vec = .{};
        var vdot_sum: Real = 0;
        var vmul_sum: Vec = .{};
        for (self.atoms.items) |*atom| {
            v_sum += vec.add(v_sum, atom.v);
            vdot_sum += vec.dot(atom.v, atom.v);
            vmul_sum = vec.add(vmul_sum, vec.mul(atom.v, atom.v));
        }
        self.props.velocity = v_sum;
        self.props.energy.kinetic = 0.5 * vdot_sum / self.atoms.items.len;
        self.props.energy.total = self.props.energy.kinetic + self.props.energy.potential;
        const volume = self.box.x * self.box.y * self.box.z;
        const density = self.atoms.items.len / volume;
        const temp = vec.sum(vmul_sum, self.props.virial);
        const pressure = vec.scale(temp, density / (3 * self.atoms.items.len));
        self.props.pressure = pressure;
    }
};
