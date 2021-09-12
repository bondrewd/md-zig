const std = @import("std");
const Real = @import("config.zig").Real;
const System = @import("system.zig").System;

const math = @import("math.zig");
const V = math.V;
const M = math.M;

pub const LennardJonesParameters = struct {
    id: u64,
    e: Real,
    s: Real,
};

pub const ForceField = struct {
    lennard_jones_parameters: []LennardJonesParameters = undefined,
    force_interactions: []fn (*System, []V, *M, usize) void = undefined,
    energy_interactions: []fn (*System) void = undefined,
};
