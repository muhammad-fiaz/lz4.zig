---
title: Bit-Level & Token Encoding Example
description: Deep dive into LZ4 token structure, byte-level packing, and variable-length integer extensions.
---

# Bit-Level & Token Encoding Example

The LZ4 Block format uses a compact byte-aligned encoding scheme. Every sequence starts with a 1-byte **Token**, followed by optional variable-length literal extensions, literal bytes, a 2-byte little-endian offset, and optional variable-length match extensions.

## Token Structure

A single token byte encodes two 4-bit fields:
- **Bits 7..4 (High Nibble)**: Literal Length (0..15). If 15, additional 0xFF bytes follow.
- **Bits 3..0 (Low Nibble)**: Match Length (0..15), representing `(match_len - 4)`. If 15, additional 0xFF bytes follow.

---

## Code

```zig
const std = @import("std");
const lz4 = @import("lz4");

pub fn main() !void {
    std.debug.print("Bit-level and Variable-length Encoding:\n\n", .{});

    // 1. Variable-length integer encoding (LZ4 length extension encoding: 0xFF bytes)
    var buffer: [512]u8 = undefined;
    const test_lengths = [_]usize{ 0, 14, 15, 255, 510, 1000, 65535 };

    for (test_lengths) |len| {
        const encoded_len = lz4.utils.bitstream.encodeVariableLength(&buffer, len);
        const decoded = try lz4.utils.bitstream.decodeVariableLength(buffer[0..encoded_len], lz4.MAX_INPUT_SIZE);

        std.debug.print("Length {d:5} -> Encoded into {d} bytes: {x} (Decoded: {d})\n", .{
            len,
            encoded_len,
            buffer[0..encoded_len],
            decoded.value,
        });
    }

    // 2. Token layout: high 4 bits = literal length, low 4 bits = match length (-4)
    const token: u8 = (15 << 4) | 12; // 15+ literal length, 12+4=16 match length
    const lit_len_token: usize = token >> 4;
    const match_len_token: usize = (token & 0x0F) + lz4.MINMATCH;
    std.debug.print("\nToken 0x{X:0>2}: literal prefix {d}, match base length {d}\n", .{
        token,
        lit_len_token,
        match_len_token,
    });
}
```

---

## How Variable-Length Integers Work

When a length exceeds 14 (for literals) or 18 (for matches):
1. The token nibble stores `15` (`0x0F`).
2. The remaining length is divided by 255: for each 255, a byte with value `255` (`0xFF`) is written.
3. The final byte stores the remaining value ($0..254$).

For example:
- Length `255`: Encoded as `[0xFF, 0x00]` (2 bytes).
- Length `510`: Encoded as `[0xFF, 0xFF, 0x00]` (3 bytes).
- Length `1000`: $255 \times 3 + 235$ -> `[0xFF, 0xFF, 0xFF, 0xEB]` (4 bytes).

---

## Running via Build System

```bash
zig build run-bit_level
```

### Expected Output

```console
Bit-level and Variable-length Encoding:

Length     0 -> Encoded into 1 bytes: 00 (Decoded: 0)
Length    14 -> Encoded into 1 bytes: 0e (Decoded: 14)
Length    15 -> Encoded into 1 bytes: 0f (Decoded: 15)
Length   255 -> Encoded into 2 bytes: ff00 (Decoded: 255)
Length   510 -> Encoded into 3 bytes: ffff00 (Decoded: 510)
Length  1000 -> Encoded into 4 bytes: ffffffeb (Decoded: 1000)
Length 65535 -> Encoded into 258 bytes: ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00 (Decoded: 65535)

Token 0xFC: literal prefix 15, match base length 16
```
