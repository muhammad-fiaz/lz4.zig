# Security Policy

## Supported Versions

| Version | Supported          |
| :---    | :---               |
| 0.0.x   | :white_check_mark: |

## Reporting a Vulnerability

The `lz4.zig` project takes the security of data compression and decompression very seriously. Because compression libraries frequently process untrusted input from network sockets, file uploads, and untrusted storage, all decoders are designed to fail safely rather than crash, leak memory, or execute arbitrary code.

If you discover a security vulnerability, memory safety bug, buffer overrun, or denial-of-service vector (such as an unhandled panic or infinite loop), please report it responsibly:

- **Email**: [contact@muhammadfiaz.com](mailto:contact@muhammadfiaz.com)
- **Subject**: `[SECURITY] lz4.zig Vulnerability Report`

Please include:
1. A description of the issue.
2. A minimal reproducer or test payload (e.g., malformed byte slice).
3. The affected version and target architecture.

We will acknowledge receipt of your report promptly, investigate the issue, and release a coordinated fix.
