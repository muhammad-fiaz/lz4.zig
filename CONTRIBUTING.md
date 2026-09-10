# Contributing to lz4.zig

Thank you for your interest in contributing to `lz4.zig`! We welcome bug reports, documentation improvements, optimization ideas, and pull requests.

## Code of Conduct

Please be respectful and constructive in all issues, pull requests, and discussions.

## Development Workflow

### Prerequisites

- **Zig 0.17.0** (required). Download the compiler from [ziglang.org/download](https://ziglang.org/download/).

### Building and Testing

Run the standard validation workflows before submitting changes:

```bash
# 1. Format all Zig source files
zig fmt src examples build.zig build.zig.zon

# 2. Build the static library
zig build

# 3. Run all unit and integration tests
zig build test --summary all

# 4. Run the decoder robustness fuzzer
zig build fuzz

# 5. Run all example executables
zig build run-all-examples
```

## Pull Request Guidelines

1. **Pure Native Zig**: No C dependencies, `@cImport`, or runtime external processes in the published library.
2. **Formatting**: Ensure `zig fmt --check src examples build.zig build.zig.zon` passes cleanly.
3. **Tests**: Add tests for new features, edge cases, and regression scenarios.
4. **Safety & Bounds**: Verify memory safety, explicit allocator handling, and bounds checking on all untrusted inputs.

## Contact & Questions

For questions or feedback, open a GitHub Issue or email [contact@muhammadfiaz.com](mailto:contact@muhammadfiaz.com).
