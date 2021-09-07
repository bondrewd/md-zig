const std = @import("std");

const math = @import("math.zig");
const V3 = math.V3;
const M3x3 = math.M3x3;

const Real = @import("config.zig").Real;
const System = @import("system.zig").System;

pub fn lennardJonesForceInteraction(system: *System) void {
    // Loop over neighbors
    for (system.neighbor_list.pairs) |pair| {
        const i = pair.i;
        const j = pair.j;

        const ri = system.r[i];
        const ei = system.ff.lennard_jones_parameters[i].e;
        const si = system.ff.lennard_jones_parameters[i].s;

        const rj = system.r[j];
        const ej = system.ff.lennard_jones_parameters[j].e;
        const sj = system.ff.lennard_jones_parameters[j].s;

        const e = std.math.sqrt(ei * ej);
        const s = (si + sj) / 2.0;
        const s2 = s * s;
        const cut_off2 = 6.25 * s2;

        var rij = V3.subVV(ri, rj);
        if (system.use_pbc) rij = math.wrap(rij, system.region);
        const rij2 = V3.dotVV(rij, rij);

        if (rij2 < cut_off2) {
            const c2 = s2 / rij2;
            const c4 = c2 * c2;
            const c8 = c4 * c4;
            const c14 = c8 * c4 * c2;

            const f = 48.0 * e * (c14 - 0.5 * c8) / s2;
            const force = V3.mulVS(rij, f);

            system.f[i] = V3.addVV(system.f[i], force);
            system.f[j] = V3.subVV(system.f[j], force);

            const rijf = V3.outerProductVV(rij, force);
            system.virial.addM(rijf);
        }
    }
}

pub fn lennardJonesEnergyInteraction(system: *System) void {
    // Loop over neighbors
    for (system.neighbor_list.pairs) |pair| {
        const i = pair.i;
        const j = pair.j;

        const ri = system.r[i];
        const ei = system.ff.lennard_jones_parameters[i].e;
        const si = system.ff.lennard_jones_parameters[i].s;

        const rj = system.r[j];
        const ej = system.ff.lennard_jones_parameters[j].e;
        const sj = system.ff.lennard_jones_parameters[j].s;

        const e = std.math.sqrt(ei * ej);
        const s = (si + sj) / 2.0;
        const s2 = s * s;
        const cut_off2 = 6.25 * s2;

        var rij = V3.subVV(ri, rj);
        if (system.use_pbc) rij = math.wrap(rij, system.region);
        const rij2 = V3.dotVV(rij, rij);

        if (rij2 < cut_off2) {
            const c2 = s2 / rij2;
            const c4 = c2 * c2;
            const c6 = c4 * c2;
            const c12 = c6 * c6;

            const energy = 4.0 * e * (c12 - c6);

            system.energy.potential += energy;
        }
    }
}
