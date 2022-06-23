const std = @import("std");
const Allocator = std.mem.Allocator;

fn FlatIntSet(comptime n_bits_: comptime_int) type {
    return struct {
        pub const n_bits = n_bits_;
        pub const Int = std.meta.Int(.unsigned, n_bits);

        storage: std.PackedIntArray(u1, 1 << n_bits),
        size: usize = 0,

        const Self = @This();

        pub fn init(alloc: Allocator) !*Self {
            const self = try alloc.create(Self);
            self.storage.setAll(0);
            return self;
        }

        pub fn deinit(self: *const Self, alloc: Allocator) void {
            alloc.destroy(self);
        }

        pub fn singleton(alloc: Allocator, int: Int) *Self {
            var self = init(alloc);
            self.storage.set(int, 1);
            return self;
        }

        pub fn contains(self: Self, int: Int) bool {
            return self.storage.get(int) == 1;
        }

        pub fn add(self: *Self, int: Int) bool {
            var result = self.contains(int);
            self.storage.set(int, 1);
            self.size += @boolToInt(!result);
            return result;
        }
    };
}

const SearchSpace = u31;
const IntSet = FlatIntSet(31);
comptime {
    std.debug.assert(SearchSpace == IntSet.Int);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var reached = try IntSet.init(alloc);
    defer reached.deinit(alloc);

    const Vec = std.ArrayListUnmanaged(SearchSpace);

    var frontier = try Vec.initCapacity(alloc, 1000);
    defer frontier.deinit(alloc);
    var next_frontier = try Vec.initCapacity(alloc, 1000);
    defer next_frontier.deinit(alloc);

    frontier.appendSliceAssumeCapacity(&[_]SearchSpace{ 1, 2, 3, 4, 5, 6, 7, 8, 9 });

    var timer = try std.time.Timer.start();

    var iters: u32 = 0;
    while (frontier.items.len > 0) : (iters += 1) {
        for (frontier.items) |n| {
            // multiplications
            comptime var rhs: u8 = 2;
            inline while (rhs <= 9) : (rhs += 1)
                if (std.math.cast(SearchSpace, std.math.mulWide(u32, n, rhs))) |prod| {
                    if (!reached.add(prod))
                        next_frontier.append(alloc, prod) catch unreachable;
                } else |_| {};
            // divisions
            rhs = 2;
            inline while (rhs <= 9) : (rhs += 1) {
                const quot = n / rhs;
                if (!reached.add(quot))
                    next_frontier.append(alloc, quot) catch unreachable;
            }
        }
        frontier.clearRetainingCapacity();
        std.mem.swap(Vec, &frontier, &next_frontier);
        std.debug.print("finished iteration #{} ({d:.3}s): {} total, {} new\n", .{
            iters,
            @intToFloat(f32, timer.read() / std.time.ns_per_ms) * 0.001,
            reached.size,
            frontier.items.len,
        });
    }

    const path = "reachable";
    std.debug.print("writing a record of reachable numbers to {s}\n", .{path});
    {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(&reached.storage.bytes);
    }

    std.debug.print("deinitializing...\n", .{});
}
