//! Embedded Nerd Font for the HTML output adapter.
//!
//! `data_uri`, when non-null, is a complete CSS `@font-face` `src` value
//! (e.g. `url(data:font/woff2;base64,...)`) for the Nerd Font icon glyphs, so
//! the single-file HTML output renders icons without any external font.
//!
//! Currently null (no font embedded yet) — icon glyphs fall back to the
//! browser's default font and may render as "tofu". Embedding is a deliberate
//! follow-up: it adds a binary asset to the repo and requires verifying the
//! chosen Nerd Font's license (OFL/MIT) permits embedding. When ready, embed a
//! (subset) woff2 via `@embedFile` + base64 and expose it here.

pub const data_uri: ?[]const u8 = null;
