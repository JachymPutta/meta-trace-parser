//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const ArgParseError = error{
    MissingArgument,
    InvalidNumber,
    InvalidSeed,
    UnknownArgument,
    PrintHelp,
};

const Args = struct {
    trace: []const u8,
    num_out: u32 = 1,
    randomize: bool = false,
    start: u32 = 0,
    end: u32 = 100,

    pub fn format(
        args: Args,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll("Args{\n");
        _ = try writer.print("\ttrace: {s},\n", .{args.trace});
        _ = try writer.print("\tnum_out_files: {},\n", .{args.num_out});
        _ = try writer.print("\trandomize: {},\n", .{args.randomize});
        _ = try writer.print("\trange: {}%-{}%,\n", .{ args.start, args.end });
        try writer.writeAll("}\n");
    }
};

const HELP_TEXT =
    \\Processing meta trace files
    \\Arguments:
    \\-h / --help : Print this help message
    \\-t / --trace : Path to the meta trace file
    \\-n / --num-out : Number of output files to split the trace into
    \\-r / --randomize :  Randomize the object IDs?
    \\-s / --start : Start of the interval to keep in percentage of accesses
    \\-e / --end : End of the interval to keep in percentage of accesses
    \\   i.e 0 100 means the entire trace will be kept
    \\   20 80 means that the objects accounting from 20
    \\   to 80 percent of accesses will be kept
;

fn parse_args(allocator: Allocator) !Args {
    const args = std.process.argsAlloc(allocator) catch |err| {
        std.debug.print("Failed to allocate arguments\n", .{});
        return err;
    };

    var meta_trace_path: []const u8 = undefined;
    var num_out_files: u32 = 1;
    var randomize: bool = false;
    var start: u32 = 0;
    var end: u32 = 100;

    var i: u32 = 1;
    while (i < args.len) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print(HELP_TEXT, .{});
            return ArgParseError.PrintHelp;
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--trace")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Missing argument for -t\n", .{});
                return ArgParseError.MissingArgument;
            }
            meta_trace_path = args[i];
        } else if (std.mem.eql(u8, arg, "-n") or std.mem.eql(u8, arg, "--num-words")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Missing argument for -n\n", .{});
                return ArgParseError.MissingArgument;
            }
            num_out_files = std.fmt.parseInt(u32, args[i], 10) catch {
                std.debug.print("Invalid number for -n\n", .{});
                return ArgParseError.InvalidNumber;
            };
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--randomize")) {
            randomize = true;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--start")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Missing argument for -s\n", .{});
                return ArgParseError.MissingArgument;
            }
            start = std.fmt.parseInt(u32, args[i], 10) catch {
                std.debug.print("Invalid number for -s\n", .{});
                return ArgParseError.InvalidNumber;
            };
        } else if (std.mem.eql(u8, arg, "-e") or std.mem.eql(u8, arg, "--end")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Missing argument for -e\n", .{});
                return ArgParseError.MissingArgument;
            }
            end = std.fmt.parseInt(u32, args[i], 10) catch {
                std.debug.print("Invalid number for -e\n", .{});
                return ArgParseError.InvalidNumber;
            };
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            return ArgParseError.UnknownArgument;
        }
        i += 1;
    }

    if (i == 1) {
        std.debug.print(HELP_TEXT, .{});
        return ArgParseError.MissingArgument;
    }

    return Args{
        .trace = meta_trace_path,
        .num_out = num_out_files,
        .randomize = randomize,
        .start = start,
        .end = end,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    const args = try parse_args(allocator);

    std.debug.print("Trace: {}\n", .{args});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
test "Read bytes from a file" {
    // current working directory
    const cwd = std.fs.cwd();

    const handle = cwd.openFile("hello.txt",
        // this is the default, so could be just '.{}'
        .{ .mode = .read_only }) catch {
        // file not found
        return;
    };
    defer handle.close();

    // read into this buffer
    var buffer: [64]u8 = undefined;
    const bytes_read = handle.readAll(&buffer) catch unreachable;

    // if bytes_read is smaller than buffer.len, then EOF was reached
    try std.testing.expectEqual(@as(usize, 6), bytes_read);

    const expected_bytes = [_]u8{ 'h', 'e', 'l', 'l', 'o', '\n' };
    try std.testing.expectEqualSlices(u8, &expected_bytes, buffer[0..bytes_read]);
}
