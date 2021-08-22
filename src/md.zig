const std = @import("std");
const ansi = @import("ansi-zig/src/ansi.zig");

const Input = @import("input.zig").Input;
const System = @import("system.zig").System;
const Reporter = @import("reporter.zig").Reporter;
const ProgressBar = @import("bar.zig").ProgressBar;

const argparse = @import("argparse-zig/src/argparse.zig");
const ArgumentParser = argparse.ArgumentParser;
const ArgumentParserOption = argparse.ArgumentParserOption;

// Ansi format
const reset = ansi.reset;
const bold = ansi.bold_on;
const blue = ansi.fg_light_blue;
const yellow = ansi.fg_light_yellow;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    const args = try ArgParser.parse(allocator);
    defer ArgParser.deinitArgs(args);

    const input = try Input.init(args.input);
    try input.displayValues();

    var system = try System.init(allocator, .{
        .dt = input.dt,
        .cell = input.cell,
        .density = input.density,
        .temperature = input.temperature,
    });
    defer system.deinit();
    try system.displayInfo();

    const of = try std.fs.cwd().createFile(args.output, .{});
    const ow = of.writer();
    const reporter = Reporter.init(&system);
    try reporter.writeHeader(ow);
    try reporter.report(ow, 0);

    const stdout = std.io.getStdOut().writer();
    const bar = ProgressBar.init(stdout, .{});

    try stdout.writeAll(bold ++ yellow ++ "> PROGRESS:\n" ++ reset);

    var istep: usize = 1;
    while (istep <= input.step_total) : (istep += 1) {
        system.step();
        try bar.displayProgress(istep, 1, input.step_total);

        if (istep % input.step_save == 0) {
            system.updateEnergies();
            try reporter.report(ow, istep);
        }
    }
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
