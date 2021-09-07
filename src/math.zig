const la = @import("la-zig/src/la.zig");
const Real = @import("config.zig").Real;

// Vector type
pub const V3 = la.types.V(Real, 3);
// Matrix type
pub const M3x3 = la.types.M(Real, 3, 3);

// Wrap vector inside box
pub fn wrap(v: V3, box: V3) V3 {
    var wrapped = v;

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        if (v.items[i] > 0.5 * box.items[i]) {
            wrapped.items[i] -= box.items[i];
        } else if (v.items[i] < -0.5 * box.items[i]) {
            wrapped.items[i] += box.items[i];
        }
    }

    return wrapped;
}
