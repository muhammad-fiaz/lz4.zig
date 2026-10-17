---
title: Installation & Setup
description: How to add and integrate lz4.zig in your Zig projects using the Zig 0.17.0 build system.
keywords: install lz4 zig, build.zig.zon lz4, zig package manager, zig 0.17.0 dependencies, fetch lz4
---

# Installation & Setup

`lz4.zig` is packaged using the standard Zig package manager and targets **Zig 0.17.0**. It has zero external dependencies, requires no C compiler or `@cImport`, and builds cleanly across all major platforms.

Repository: [https://github.com/muhammad-fiaz/lz4.zig](https://github.com/muhammad-fiaz/lz4.zig)

---

## Prerequisites

- **Zig Compiler**: Version **0.17.0** or compatible.
  - Verify your installed toolchain: `zig version`
  - Download official prebuilt binaries from [ziglang.org/download](https://ziglang.org/download/).

---

## Adding to `build.zig.zon`

Add `lz4.zig` to your project's `build.zig.zon` using `zig fetch`.

### Option 1: Stable Release (Recommended)

To install the verified stable `0.0.1` release archive:

```bash
zig fetch --save https://github.com/muhammad-fiaz/lz4.zig/archive/refs/tags/0.0.1.tar.gz
```

Your `build.zig.zon` will be updated with:

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .fingerprint = 0x1234567890abcdef,
    .dependencies = .{
        .lz4 = .{
            .url = "https://github.com/muhammad-fiaz/lz4.zig/archive/refs/tags/0.0.1.tar.gz",
            .hash = "lz4-0.0.1-...",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

### Option 2: Latest / Dev / Nightly

To follow the latest changes on the `main` branch:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/lz4.zig.git
```

This generates:

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .fingerprint = 0x1234567890abcdef,
    .dependencies = .{
        .lz4 = .{
            .url = "git+https://github.com/muhammad-fiaz/lz4.zig.git",
            .hash = "lz4-...",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

---

## Configuring `build.zig`

Import the `lz4` dependency in your project's `build.zig` and attach it to your executable, library, or test target:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Resolve the lz4 package dependency
    const lz4_dep = b.dependency("lz4", .{
        .target = target,
        .optimize = optimize,
    });
    const lz4_mod = lz4_dep.module("lz4");

    // 2. Attach to your application executable
    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lz4", .module = lz4_mod },
            },
        }),
    });

    b.installArtifact(exe);

    // 3. Alternatively, attach via root_module helper
    // exe.root_module.addImport("lz4", lz4_mod);
}
```

---

## Importing in Code

In your source code (`src/main.zig`), import the library directly:

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    const original = "Hello from lz4.zig on Zig 0.17.0!";
    var comp_buf: [256]u8 = undefined;

    const comp_len = try lz4.compress(original, &comp_buf);
    std.debug.print("Compressed to {d} bytes (bound: {d})\n", .{
        comp_len,
        lz4.compressBound(original.len),
    });

    var decomp_buf: [256]u8 = undefined;
    const decomp_len = try lz4.decompress(comp_buf[0..comp_len], &decomp_buf);
    std.debug.print("Restored: {s}\n", .{decomp_buf[0..decomp_len]});
}
```

---

## Cross-Compilation

Because `lz4.zig` is implemented entirely in pure native Zig with no C dependencies or host-specific assumptions, cross-compilation requires no external sysroots:

```bash
# Build for 64-bit Linux ARM64
zig build -Dtarget=aarch64-linux

# Build for 64-bit Windows x86_64
zig build -Dtarget=x86_64-windows

# Build for macOS Apple Silicon
zig build -Dtarget=aarch64-macos

# Build for 32-bit Linux x86
zig build -Dtarget=x86-linux

# Build for 32-bit Windows x86
zig build -Dtarget=x86-windows

# Build for RISC-V 64 Linux
zig build -Dtarget=riscv64-linux
```
