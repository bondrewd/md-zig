const std = @import("std");
const argparse = @import("argparse-zig/src/argparse.zig");

const ArgumentParser = argparse.ArgumentParser;
const ArgumentParserOption = argparse.ArgumentParserOption;

const Vec = @import("vec.zig").Vec;
const Real = @import("config.zig").Real;
const System = @import("system.zig").System;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var system = System.init(allocator);
    defer system.deinit();

    const args = try ArgParser.parse(allocator);
    defer ArgParser.deinitArgs(args);

    std.log.info("Input file:  {s}", .{args.input});
    std.log.info("Output file: {s}", .{args.output});

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

const ArgParser = ArgumentParser(.{
    .bin_name = "md",
    .bin_info = "Molecular Dynamics software.",
    .bin_usage = "./md OPTION [OPTION...]",
    .bin_version = .{ .major = 0, .minor = 1, .patch = 0 },
    .display_error = true,
}, [_]ArgumentParserOption{
    .{
        .name = "input",
        .long = "--input",
        .short = "-i",
        .description = "Input file name (Required)",
        .metavar = "<FILE> [FILE...]",
        .argument_type = []const u8,
        .takes = .One,
        .required = true,
    },
    .{
        .name = "output",
        .long = "--output",
        .short = "-o",
        .description = "Output file name (Defult: out.md)",
        .metavar = "<FILE> [FILE...]",
        .argument_type = []const u8,
        .takes = .One,
        .default_value = .{ .string = "out.md" },
    },
});
