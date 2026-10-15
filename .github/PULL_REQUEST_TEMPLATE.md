## Description

Please provide a clear summary of the changes and reference any related issue (e.g. `Fixes #123`).

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Performance improvement / optimization
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update (typos, guides, or API reference improvements)
- [ ] CI / Build system enhancement

## Quality Checklist

- [ ] My code follows the project's formatting standard (`zig fmt --check src examples build.zig build.zig.zon`)
- [ ] Compilation check passes (`zig build check`)
- [ ] Unit and integration test suite passes (`zig build test --summary all`)
- [ ] All examples compile and execute successfully (`zig build run-all-examples`)
- [ ] Robustness fuzzer passes (`zig build fuzz --summary all`)
- [ ] Documentation builds without warnings (`bun run docs:build` in `docs/` if docs were modified)
