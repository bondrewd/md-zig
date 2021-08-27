const std = @import("std");
const vec = @import("vec.zig");
const Real = @import("config.zig").Real;
const System = @import("system.zig").System;

pub fn lennardJonesForceInteraction(system: *System) void {
    // Number of atoms
    const n_atoms = system.atoms.len;

    // Double loop
    var i: usize = 0;
    while (i < n_atoms) : (i += 1) {
        const ri = system.atoms[i].r;
        const ei = system.lennard_jones_parameters[i].e;
        const si = system.lennard_jones_parameters[i].s;

        var j: usize = i + 1;
        while (j < n_atoms) : (j += 1) {
            const rj = system.atoms[j].r;
            const ej = system.lennard_jones_parameters[j].e;
            const sj = system.lennard_jones_parameters[j].s;

            const e = std.math.sqrt(ei * ej);
            const s = (si + sj) / 2.0;
            const s2 = s * s;
            const cut_off2 = std.math.pow(Real, 2.0, 1.0 / 3.0) * s2;

            const rij = vec.sub(ri, rj);
            const rij2 = vec.dot(rij, rij);

            if (rij2 < cut_off2) {
                const c2 = s2 / rij2;
                const c4 = c2 * c2;
                const c8 = c4 * c4;
                const c14 = c8 * c4 * c2;

                const f = 48.0 * e * (c14 - 0.5 * c8) / s2;
                const force = vec.scale(rij, f);

                system.atoms[i].f = vec.add(system.atoms[i].f, force);
                system.atoms[j].f = vec.sub(system.atoms[j].f, force);
            }
        }
    }
}

pub fn lennardJonesEnergyInteraction(system: *System) void {
    // Number of atoms
    const n_atoms = system.atoms.len;

    // Double loop
    var i: usize = 0;
    while (i < n_atoms) : (i += 1) {
        const ri = system.atoms[i].r;
        const ei = system.lennard_jones_parameters[i].e;
        const si = system.lennard_jones_parameters[i].s;

        var j: usize = i + 1;
        while (j < n_atoms) : (j += 1) {
            const rj = system.atoms[j].r;
            const ej = system.lennard_jones_parameters[j].e;
            const sj = system.lennard_jones_parameters[j].s;

            const e = std.math.sqrt(ei * ej);
            const s = (si + sj) / 2.0;
            const s2 = s * s;
            const cut_off2 = std.math.pow(Real, 2.0, 1.0 / 3.0) * s2;

            const rij = vec.sub(ri, rj);
            const rij2 = vec.dot(rij, rij);

            if (rij2 < cut_off2) {
                const c2 = s2 / rij2;
                const c4 = c2 * c2;
                const c6 = c4 * c2;
                const c12 = c6 * c6;

                const energy = 4.0 * e * (c12 - c6);

                system.properties.energy.potential += energy;
            }
        }
    }
}
