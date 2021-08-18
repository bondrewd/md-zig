const vec = @import("vec.zig");
const System = @import("system.zig").System;

pub fn computeForces(s: System) void {
    const rr_cut = s.cutoff * s.cutoff;
    s.energy.potential = 0;
    s.props.virial = 0;

    var i: usize = 0;
    while (i < s.atoms.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < s.atoms.len) : (j += 1) {
            var dr = vec.sub(s.atoms.items[i].r, s.atoms.items[j].r);
            dr = vec.wrap(dr, s.box);
            const rr = vec.dot(dr, dr);
            if (rr < rr_cut) {
                const rri = 1 / rr;
                const rri3 = rri * rri * rri;
                const f = 48 * rri3 * (rri3 - 0.5) * rri;
                const force = vec.scale(dr, f);
                s.atoms.items[i].a = vec.add(s.atoms.items[i].a, force);
                s.atoms.items[j].a = vec.sub(s.atoms.items[j].a, force);
                s.props.energy.potential += 4 * rri3 * (rri3 - 1) + 1;
                s.props.virial = vec.add(s.props.virial, vec.mul(force, dr));
            }
        }
    }
}
