const std = @import("std");
const builtin = @import("builtin");
const stdx = @import("stdx");
const t = stdx.testing;
const cy = @import("cyber.zig");
const os = @import("std/os.zig");

const log = cy.log.scoped(.fmt);

// This provides a simple string interpolation without comptime.

const FmtValueType = enum(u8) {
    char,
    string,
    i8,
    u8,
    i16,
    u16,
    u32,
    i32,
    i48,
    u64,
    f64,
    bool,
    ptr,
    enumt,
    err,
};

pub const FmtValue = extern struct {
    data: extern union {
        u8: u8,
        u16: u16,
        u32: u32,
        u64: u64,
        f64: f64,
        string: [*]const u8,
        char: u8,
        bool: bool,
        ptr: ?*anyopaque,
    },
    data2: extern union {
        string: u32, // string len.
    } = undefined,
    type: FmtValueType,
};

test "fmt internals." {
    try t.eq(@sizeOf(FmtValue), 16);
}

fn toFmtValueType(comptime T: type) FmtValueType {
    switch (T) {
        bool => return .bool,
        i8 => return .i8,
        u8 => return .u8,
        u16 => return .u16,
        i16 => return .i16,
        u32 => return .u32,
        i32 => return .i32,
        i48 => return .i48,
        usize,
        u64 => return .u64,
        f64 => return .f64,
        []u8,
        []const u8 => return .string,
        else => {
            if (@typeInfo(T) == .Enum) {
                return .enumt;
            } else if (@typeInfo(T) == .ErrorSet) {
                return .err;
            } else if (@typeInfo(T) == .Optional) {
                if (@typeInfo(@typeInfo(T).Optional.child) == .Pointer) {
                    return .ptr;
                } else {
                    @compileError(std.fmt.comptimePrint("Unexpected type: {}", .{T}));
                }
            } else if (@typeInfo(T) == .Pointer) {
                return .ptr;
            } else {
                @compileError(std.fmt.comptimePrint("Unexpected type: {}", .{T}));
            }
        },
    }
}

pub fn v(val: anytype) FmtValue {
    const fmt_t = comptime toFmtValueType(@TypeOf(val));
    switch (fmt_t) {
        .bool => {
            return .{
                .type = .bool,
                .data = .{
                    .bool = val,
                },
            };
        },
        .char => {
            return .{
                .type = .char,
                .data = .{
                    .u8 = val,
                }
            };
        },
        .i8 => {
            return .{
                .type = .i8,
                .data = .{
                    .u8 = @bitCast(val),
                }
            };
        },
        .u8 => {
            return .{
                .type = .u8,
                .data = .{
                    .u8 = val,
                }
            };
        },
        .i16 => {
            return .{
                .type = .i16,
                .data = .{
                    .u16 = @bitCast(val),
                }
            };
        },
        .u16 => {
            return .{
                .type = .u16,
                .data = .{
                    .u16 = val,
                }
            };
        },
        .i32 => {
            return .{
                .type = .i32,
                .data = .{
                    .u32 = @bitCast(val),
                }
            };
        },
        .u32 => {
            return .{
                .type = .u32,
                .data = .{
                    .u32 = val,
                }
            };
        },
        .i48 => {
            return .{
                .type = .i48,
                .data = .{
                    .u64 = @as(u48, @bitCast(val)),
                }
            };
        },
        .u64 => return u64v(val),
        .f64 => return .{
            .type = .f64,
            .data = .{
                .f64 = val,
            },
        },
        .string => return str(val),
        .enumt => return enumv(val),
        .err => return str(@errorName(val)),
        .ptr =>  return .{
            .type = .ptr,
            .data = .{
                .ptr = @ptrFromInt(@intFromPtr(val)),
            }
        },
    }
}

pub fn char(ch: u8) FmtValue {
    return .{
        .type = .char,
        .data = .{
            .char = ch,
        },
    };
}

pub fn u64v(n: u64) FmtValue {
    return .{
        .type = .u64,
        .data = .{
            .u64 = n,
        }
    };
}

pub fn enumv(e: anytype) FmtValue {
    const name = @tagName(e);
    return .{
        .type = .string,
        .data = .{
            .string = name.ptr,
        },
        .data2 = .{
            .string = @intCast(name.len),
        },
    };
}

pub fn str(s: []const u8) FmtValue {
    return .{
        .type = .string,
        .data = .{
            .string = s.ptr,
        },
        .data2 = .{
            .string = @intCast(s.len),
        },
    };
}

fn formatValue(writer: anytype, val: FmtValue) !void {
    switch (val.type) {
        .bool => {
            if (val.data.bool) {
                try writer.writeAll("true");
            } else {
                try writer.writeAll("false");
            }
        },
        .char => {
            try writer.writeByte(val.data.char);
        },
        .i8 => {
            try std.fmt.formatInt(@as(i8, @bitCast(val.data.u8)), 10, .lower, .{}, writer);
        },
        .u8 => {
            try std.fmt.formatInt(val.data.u8, 10, .lower, .{}, writer);
        },
        .i16 => {
            try std.fmt.formatInt(@as(i16, @bitCast(val.data.u16)), 10, .lower, .{}, writer);
        },
        .u16 => {
            try std.fmt.formatInt(val.data.u16, 10, .lower, .{}, writer);
        },
        .u32 => {
            try std.fmt.formatInt(val.data.u32, 10, .lower, .{}, writer);
        },
        .i32 => {
            try std.fmt.formatInt(@as(i32, @bitCast(val.data.u32)), 10, .lower, .{}, writer);
        },
        .i48 => {
            try std.fmt.formatInt(@as(i48, @bitCast(@as(u48, @intCast(val.data.u64)))), 10, .lower, .{}, writer);
        },
        .u64 => {
            try std.fmt.formatInt(val.data.u64, 10, .lower, .{}, writer);
        },
        .f64 => {
            try std.fmt.formatFloatDecimal(val.data.f64, .{}, writer);
        },
        .err,
        .enumt,
        .string => {
            try writer.writeAll(val.data.string[0..val.data2.string]);
        },
        .ptr => {
            try writer.writeByte('@');
            try std.fmt.formatInt(@intFromPtr(val.data.ptr), 16, .lower, .{}, writer);
        },
        // else => cy.panicFmt("unsupported {}", .{val.type}),
    }
}

pub fn format(writer: anytype, fmt: []const u8, vals: []const FmtValue) !void {
    var valIdx: u32 = 0;
    var i: u32 = 0;
    while (i < fmt.len) {
        const ch = fmt[i];
        if (ch == '{') {
            if (i + 1 < fmt.len) {
                if (fmt[i + 1] == '}') {
                    if (valIdx == vals.len) {
                        log.debug("Format expected {}th value, got {} values", .{valIdx + 1, vals.len});
                        return error.FormatError;
                    }
                    try formatValue(writer, vals[valIdx]);
                    valIdx += 1;
                    i += 2;
                    continue;
                }
            }
        }
        try writer.writeByte(ch);
        i += 1;
        continue;
    }
    if (valIdx < vals.len) {
        log.debug("Format had {} placeholders, got {} values", .{valIdx + 1, vals.len});
        return error.FormatError;
    }
}

pub fn allocFormat(alloc: std.mem.Allocator, fmt: []const u8, vals: []const FmtValue) ![]const u8 {
    @setCold(true);
    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(alloc);
    var w = buf.writer(alloc);
    try format(w, fmt, vals);
    return buf.toOwnedSlice(alloc);
}

var printMutex = std.Thread.Mutex{};

pub fn printStdout(fmt: []const u8, vals: []const FmtValue) void {
    printStdoutOrErr(fmt, vals) catch |err| {
        log.debug("{}", .{err});
        cy.fatal();
    };
}

pub fn printStdoutOrErr(fmt: []const u8, vals: []const FmtValue) !void {
    @setCold(true);
    printMutex.lock();
    defer printMutex.unlock();
    const w = std.io.getStdOut().writer();
    if (builtin.is_test) {
        if (@intFromEnum(std.log.Level.debug) <= @intFromEnum(std.testing.log_level)) {
            try format(w, fmt, vals);
        }
    } else {
        try format(w, fmt, vals);
    }
}

pub fn printDeprecated(name: []const u8, sinceVersion: []const u8, fmt: []const u8, vals: []const FmtValue) void {
    printStderr("{} is deprecated since {}: ", &.{v(name), v(sinceVersion)});
    printStderr(fmt, vals);
    printStderr("\n", &.{});
}

pub fn printStderr(fmt: []const u8, vals: []const FmtValue) void {
    printStderrOrErr(fmt, vals) catch |err| {
        log.debug("{}", .{err});
        cy.fatal();
    };
}

pub const StderrWriter = if (!cy.isWasmFreestanding) std.fs.File.Writer else HostFileWriter;

pub fn lockStderrWriter() StderrWriter {
    if (!cy.isWasmFreestanding) {
        printMutex.lock();
        return std.io.getStdErr().writer();
    } else {
        return HostFileWriter{ .fid = 2 };
    }
}

pub fn unlockPrint() void {
    if (!cy.isWasmFreestanding) {
        printMutex.unlock();
    }
}

pub fn printStderrOrErr(fmt: []const u8, vals: []const FmtValue) !void {
    @setCold(true);
    const w = lockStderrWriter();
    defer unlockPrint();
    try format(w, fmt, vals);
}

const HostFileWriter = struct {
    fid: u32,

    pub const Error = error{};

    pub fn writeByte(self: HostFileWriter, byte: u8) linksection(cy.Section) Error!void {
        os.hostFileWrite(self.fid, @ptrCast(&byte), 1);
    }

    pub fn writeAll(self: HostFileWriter, data: []const u8) linksection(cy.Section) Error!void {
        os.hostFileWrite(self.fid, data.ptr, data.len);
    }

    pub fn write(self: HostFileWriter, data: []const u8) linksection(cy.Section) Error!void {
        os.hostFileWrite(self.fid, data.ptr, data.len);
    }

    pub fn writeByteNTimes(self: HostFileWriter, byte: u8, n: usize) linksection(cy.Section) Error!void {
        var bytes: [256]u8 = undefined;
        @memset(bytes[0..], byte);

        var remaining = n;
        while (remaining > 0) {
            const to_write = @min(remaining, bytes.len);
            try self.writeAll(bytes[0..to_write]);
            remaining -= to_write;
        }
    }
};

pub fn panic(fmt: []const u8, vals: []const FmtValue) noreturn {
    @setCold(true);
    printStderr(fmt, vals);
    @panic("");
}