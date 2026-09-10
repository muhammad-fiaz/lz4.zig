//! Internal constants for LZ4 block and frame formats.

pub const MINMATCH: usize = 4;
pub const WILDCOPYLENGTH: usize = 8;
pub const LASTLITERALS: usize = 5;
pub const MFLIMIT: usize = 12;
pub const MIN_LENGTH: usize = MFLIMIT + 1; // 13 bytes
pub const MAX_DISTANCE: usize = 65535;
pub const MAX_INPUT_SIZE: usize = 0x7E000000; // 2,113,929,216 bytes

pub const RUN_BITS: u5 = 4;
pub const RUN_MASK: u8 = (1 << RUN_BITS) - 1; // 15
pub const ML_BITS: u5 = 4;
pub const ML_MASK: u8 = (1 << ML_BITS) - 1; // 15

// Hash tables
pub const HASH_LOG_DEFAULT: u5 = 14; // 16 KB entries
pub const HASH_SIZE_DEFAULT: usize = 1 << HASH_LOG_DEFAULT;
pub const HASH_LOG_HC: u5 = 15; // 32 KB entries
pub const HASH_SIZE_HC: usize = 1 << HASH_LOG_HC;

// Compression levels & acceleration
pub const ACCELERATION_DEFAULT: u32 = 1;
pub const ACCELERATION_MAX: u32 = 65537;
pub const CLEVEL_MIN: i32 = 1;
pub const CLEVEL_DEFAULT: i32 = 1;
pub const HC_CLEVEL_MIN: i32 = 2;
pub const HC_CLEVEL_DEFAULT: i32 = 9;
pub const HC_CLEVEL_OPT_MIN: i32 = 10;
pub const HC_CLEVEL_MAX: i32 = 12;

// Frame magic numbers
pub const FRAME_MAGIC: u32 = 0x184D2204;
pub const LEGACY_MAGIC: u32 = 0x184C2102;
pub const SKIPPABLE_MAGIC_MIN: u32 = 0x184D2A50;
pub const SKIPPABLE_MAGIC_MAX: u32 = 0x184D2A5F;
pub const END_MARK: u32 = 0x00000000;

// Frame flags & sizes
pub const FRAME_VERSION: u2 = 1;
pub const UNCOMPRESSED_FLAG: u32 = 0x80000000;

pub const FRAME_HEADER_MIN_SIZE: usize = 7;
pub const FRAME_HEADER_MAX_SIZE: usize = 19;
pub const FRAME_FOOTER_MIN_SIZE: usize = 4;
pub const FRAME_FOOTER_MAX_SIZE: usize = 8;
pub const BLOCK_HEADER_SIZE: usize = 4;
pub const BLOCK_CHECKSUM_SIZE: usize = 4;
pub const CONTENT_CHECKSUM_SIZE: usize = 4;
pub const DICT_ID_SIZE: usize = 4;
pub const CONTENT_SIZE_SIZE: usize = 8;

pub const KB: usize = 1024;
pub const MB: usize = 1024 * 1024;

pub const BLOCK_SIZE_64KB: usize = 64 * KB;
pub const BLOCK_SIZE_256KB: usize = 256 * KB;
pub const BLOCK_SIZE_1MB: usize = 1 * MB;
pub const BLOCK_SIZE_4MB: usize = 4 * MB;
