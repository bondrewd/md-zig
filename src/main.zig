const std = @import("std");
const Vec = @import("vec.zig").Vec;
const Real = @import("config.zig").Real;
const System = @import("system.zig").System;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var system = System.init(allocator);
    defer system.deinit();

    var args = std.os.argv;
    if (args.len != 2) try printUsage();

    //getNameList(argc, argv);
    //printNameList(stdout);
    //setParams();
    //setupJob();
    //more_cycles = 1;
    //while (more_cycles) {
    //singleStep();
    //if (step_count >= step_limit) {
    //more_cycles = 0;
    //}
    //}
}

fn singleStep() void {
    //step_count += 1;
    //time_now = step_count * dt;
    //leapFrogStep(1);
    //applyBoundaryCond();
    //computeForces();
    //leapFrogStep(2);
    //evalProps();
    //accumProps(1);
    //if (step_count % ste_avg == 0) {
    //accumProps(2);
    //printSummary(stdout);
    //accumProps(0);
    //}
}

fn setupJob() void {
    //allocArrays();
    //step_count = 0;
    //initCoords();
    //initVels();
    //initAccels();
    //accumProps(0);
}

fn printUsage() !void {
    var stdout = std.io.getStdOut().writer();

    try stdout.print("md 1.0.0\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("Molecular dynamics software.\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("Usage:\n", .{});
    try stdout.print("  ./md INPUT\n", .{});
    try stdout.print("\n", .{});
}

const Input = struct {
    dt: Real = 0,
    density: Real = 0,
    cell: Vec = .{},
    temperature: Real = 0,
    step_avg: u32 = 0,
    step_eq: u32 = 0,
    step_total: u32 = 0,
};

fn parseInput(file_name: []const u8) Input {
    var input = Input{};

    var f = try std.fs.cwd().openFile(file_name, .{ .write = false });
    var r = f.reader();

    while (try r.readUntilDelimiterOrEofAlloc) {}
    return input;
}
