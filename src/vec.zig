const std = @import("std");
const Real = @import("config.zig").Real;

pub const Vec = struct {
    x: Real = 0,
    y: Real = 0,
    z: Real = 0,
};

pub fn add(v1: Vec, v2: Vec) Vec {
    return .{
        .x = v1.x + v2.x,
        .y = v1.y + v2.y,
        .z = v1.z + v2.z,
    };
}

pub fn sub(v1: Vec, v2: Vec) Vec {
    return .{
        .x = v1.x - v2.x,
        .y = v1.y - v2.y,
        .z = v1.z - v2.z,
    };
}

pub fn mul(v1: Vec, v2: Vec) Vec {
    return .{
        .x = v1.x * v2.x,
        .y = v1.y * v2.y,
        .z = v1.z * v2.z,
    };
}

pub fn dot(v1: Vec, v2: Vec) Real {
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

pub fn norm(v: Vec) Real {
    return std.math.sqrt(dot(v, v));
}

pub fn normalize(v: Vec) Vec {
    return scale(v, norm(v));
}

pub fn scale(v: Vec, s: Real) Vec {
    return .{
        .x = v.x * s,
        .y = v.y * s,
        .z = v.z * s,
    };
}

pub fn wrap(v: Vec, box: Vec) Vec {
    var wrapped = v;

    if (v.x > 0.5 * box.x) {
        wrapped.x -= box.x;
    } else if (v.x < -0.5 * box.x) {
        wrapped.x += box.x;
    }

    if (v.y > 0.5 * box.y) {
        wrapped.y -= box.y;
    } else if (v.y < -0.5 * box.y) {
        wrapped.y += box.y;
    }

    if (v.z > 0.5 * box.z) {
        wrapped.z -= box.z;
    } else if (v.z < -0.5 * box.z) {
        wrapped.z += box.z;
    }

    return wrapped;
}
