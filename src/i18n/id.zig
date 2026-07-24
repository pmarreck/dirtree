const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Teks bantuan ───────────────────────────────────────────
    .help_title = "dirtree - Pohon direktori berstatus untuk manusia dan LLM",
    .help_usage = "Penggunaan: dirtree [OPSI] [JALUR]",
    .help_options_header = "Opsi:",
    .help_opt_help = "  -h, --help         Tampilkan pesan bantuan ini",
    .help_opt_about = "  -a, --about        Tampilkan deskripsi terperinci",
    .help_opt_depth = "  -d, --depth N      Atur kedalaman maksimum (bawaan: 4)",
    .help_opt_temp = "  -t, --temp         Terapkan perubahan untuk proses ini saja (tidak disimpan)",
    .help_opt_persist = "  --persist, --save  Simpan juga pengaturan ini (mengganti non-TTY dan DIRTREE_TEMP)",
    .help_opt_path = "  -p, --path PATH    Render PATH meskipun tampak seperti flag atau subperintah",
    .help_opt_simple = "  --simple           Keluarkan pohon berstatus yang sederhana dan ramah-LLM",
    .help_opt_decorated = "  --decorated        Paksa keluaran berdekorasi (bahkan saat di-pipe)",
    .help_opt_no_icons = "  --no-icons         Nonaktifkan ikon (mode sederhana + header berdekorasi)",
    .help_opt_no_color = "  --no-color        Aktifkan/nonaktifkan warna ANSI (disimpan)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning Tekan peringatan catatan yatim",
    .help_opt_notes = "  --no-notes/--show-notes Sembunyikan atau tampilkan catatan sebaris (DIRTREE_HIDE_NOTES=1 untuk sembunyi secara bawaan)",
    .help_opt_notes_mode = "  --notes MODE       Tata letak catatan: aligned (bawaan) atau inline",
    .help_opt_notes_leader = "  --notes-leader     Gambar titik pemandu redup dari nama ke catatan yang disejajarkan",
    .warn_orphaned_prefix = "Catatan: ",
    .warn_orphaned_suffix = " anotasi menunjuk ke jalur yang tidak ada lagi. Jalankan 'orphaned-notes' untuk melihat atau 'purge-orphaned-notes' untuk menghapus.",
    .warn_negation_intro = "catatan: regex yang dinegasikan di sini dapat membalik maksud Anda — !/PAT/ mencocokkan KEBALIKANNYA, dan lookahead (?!...) di depan juga merupakan negasi, sehingga menggabungkannya berarti negasi ganda:",
    .warn_negation_advice = "Untuk berfokus pada satu jalur, gunakan {s} PATH; untuk filter positif gunakan {s} /PAT/ (aturan show lebih diprioritaskan daripada hide). Aturan ini disimpan ke .dirtree-state, berupa teks biasa yang dapat Anda sunting sendiri ketika menjadi rumit atau tumpang tindih.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Aktifkan/nonaktifkan hyperlink OSC8 (disimpan)",
    .help_opt_default = "  --default X        Simpan status bawaan: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Buka satu atau beberapa subdirektori (ulangi flag untuk menambah)",
    .help_opt_close = "  -c, --close DIR... Tutup satu atau beberapa subdirektori (ulangi flag untuk menambah)",
    .help_opt_show = "  --show PATH...     Paksa tampilkan jalur relatif; bungkus regex sebagai /pola/ atau !/pola/",
    .help_opt_hide = "  --hide PATH...     Sembunyikan jalur relatif; bungkus regex sebagai /pola/ atau !/pola/ (dapat diulang) (ingin menyimpan hanya beberapa jalur? gunakan --only)",
    .help_opt_sort = "  --sort MODE        Mode pengurutan: modified|alpha (bawaan: modified)",
    .help_opt_asc = "  --asc              Urutkan menaik",
    .help_opt_desc = "  --desc             Urutkan menurun (bawaan)",
    .help_opt_show_hidden = "  --show-hidden      Tampilkan sementara jalur yang disembunyikan via konfigurasi",
    .help_opt_rewrite_settings = "  --rewrite-settings Tulis ulang berkas status dengan pengaturan saat ini",
    .help_opt_config = "  --config           Tampilkan konfigurasi efektif yang dihitung",
    .help_opt_test = "  --test             Jalankan tes terkait",
    .help_opt_lang = "  --lang CODE        Atur bahasa tampilan (mis. en, de, fr, ja)",
    .help_lang_available_label = "Kode bahasa yang tersedia:",
    .help_regex_note = "Gunakan /pola/ atau !/pola/ dengan --open/--close/--show/--hide untuk menambah aturan regex; argumen lain diperlakukan sebagai literal.",
    .help_relative_note = "Jalur yang diberikan ke --show/--hide harus relatif (tanpa '/' di depan).",
    .help_behavior_header = "Perilaku:",
    .help_behavior_text = "Pengaturan presentasi disimpan ketika stdout adalah terminal; jika tidak, mereka hanya berlaku untuk pemanggilan saat ini. Secara default, perubahan --open/--close/--show/--hide selalu disimpan. Warna aktif secara default untuk keluaran terminal dan mati untuk keluaran lainnya. --temp atau --persist/--save secara eksplisit mengesampingkan aturan penyimpanan ini.",
    .persistence_note_tty = "Pesan: {s}: disimpan karena stdout adalah terminal; gunakan --temp untuk menerapkannya hanya pada pemanggilan ini.",
    .persistence_note_non_tty = "Pesan: {s}: tidak disimpan karena stdout bukan terminal; gunakan --persist/--save untuk mengganti.",
    .persistence_note_semantic = "Pesan: {s}: disimpan karena perubahan pada tampilan proyek bersama disimpan secara default; gunakan --temp untuk menerapkannya hanya pada pemanggilan ini.",
    .persistence_note_env = "Pesan: {s}: tidak disimpan karena DIRTREE_TEMP=1; gunakan --persist/--save untuk mengganti.",
    .persistence_note_mute = "Atur DIRTREE_MUTE_PERSISTENCE_REASON=1 untuk menyembunyikan pesan informasi ini.",
    .help_examples_header = "Contoh:",
    .help_example_1 = "  dirtree                       # Tampilkan pohon direktori saat ini",
    .help_example_2 = "  dirtree -d 3                  # Atur kedalaman ke 3 tingkat",
    .help_example_3 = "  dirtree --sort alpha --asc    # Diurutkan secara alfabetis menaik",
    .help_example_close_comment = "Ciutkan sebuah direktori (disimpan)",
    .help_example_hide_comment = "Sembunyikan berkas yang cocok dengan regex",
    .help_example_only_comment = "Berfokus pada satu subpohon, sembunyikan saudaranya",
    .help_example_localized_comment = "Nama switch yang dilokalkan juga berfungsi",

    // ── Teks tentang ───────────────────────────────────────────
    .about_text = "Pohon direktori berstatus (ikon/warna/tautan); --simple untuk LLM; menyimpan .dirtree-state (default/open/close/show/hide); regex via /pola/ atau !/pola/; literal harus relatif; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Fragmen hitungan tersembunyi ───────────────────────────
    .hidden_dir_singular = "direktori",
    .hidden_dir_plural = "direktori",
    .hidden_file_singular = "berkas",
    .hidden_file_plural = "berkas",
    .hidden_and = " dan ",
    .hidden_is_hidden = " disembunyikan.",
    .hidden_are_hidden = " disembunyikan.",
    .stats_shown = " ditampilkan",
    .stats_hidden = " disembunyikan.",
    .stats_line_singular = "baris",
    .stats_line_plural = "baris",
    .stats_separator = "; ",

    .stats_scm_kept = " tidak disembunyikan karena termasuk dalam changeset git/jj saat ini",
    // ── Teks bantuan (flag baru) ───────────────────────────────
    .help_opt_max_lines = "  --max-lines N      Atur ambang peringatan keluaran besar (bawaan: 500)",
    .help_opt_override_warning = "  --override-warning Tekan peringatan keluaran besar",
    .help_opt_only = "  --only PATH        Berfokus pada satu subpohon, menciutkan direktori saudara (dapat diulang)",
    .help_opt_html = "  --html [FILE]      Tulis pohon HTML mandiri ke FILE (- = stdout; kosongkan = buka di peramban)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  Sembunyikan target symlink; --no-targets juga menghapus hyperlink (keluaran portabel)",

    // ── Pesan peringatan (keluaran besar) ──────────────────────
    .warn_large_output_prefix = "Peringatan: keluaran sekitar ~",
    .warn_large_output_mid = " baris (ambang: ",
    .warn_large_output_suffix = "). Pertimbangkan: --depth N atau pola --hide.",

    // ── Pesan kesalahan ────────────────────────────────────────
    .err_max_lines_requires_number = "Kesalahan: --max-lines memerlukan argumen numerik (en: Error: --max-lines requires a numeric argument)",
    .err_only_requires_path = "Kesalahan: --only memerlukan argumen jalur (en: Error: --only requires a path argument)",
    .err_depth_requires_number = "Kesalahan: --depth memerlukan argumen numerik (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "Kesalahan: --path memerlukan argumen direktori (en: Error: --path requires a directory argument)",
    .err_notes_requires_mode = "Kesalahan: --notes memerlukan 'aligned' atau 'inline' (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "Kesalahan: --sort memerlukan 'modified' atau 'alpha' (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "Kesalahan: --default memerlukan setidaknya satu nilai (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "Kesalahan: konflik status --default (en: Error: --default state conflict)",
    .err_default_accepts = "Kesalahan: --default menerima opened/closed (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "Kesalahan: --open memerlukan setidaknya satu direktori (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "Kesalahan: --close memerlukan setidaknya satu direktori (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "Kesalahan: --show memerlukan setidaknya satu jalur (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "Kesalahan: --hide memerlukan setidaknya satu jalur (en: Error: --hide requires at least one path)",
    .err_unknown_option = "Opsi tidak dikenal (en: Unknown option)",
    .err_not_a_directory = "Kesalahan: '{s}' bukan direktori (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "Kesalahan: pola regex tidak boleh kosong (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "Kesalahan: jalur {s} harus relatif (tanpa '/' di depan): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "Kehabisan memori (en: Out of memory)",
    .err_regex_conflict_path = "Kesalahan: jalur '{s}' cocok dengan pola open dan close (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  pola open: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  pola close: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "Kesalahan: pola regex tidak valid: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "Kesalahan: kode bahasa tidak dikenal '{s}'. Tersedia: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Kesalahan: annotate memerlukan sebuah jalur (en: Error: annotate requires a path)",
    .err_annotate_requires_description = "Kesalahan: annotate memerlukan sebuah deskripsi (gunakan \"\" untuk mengosongkan) (en: Error: annotate requires a description (use \"\" to clear))",
    .err_annotate_multiline = "Kesalahan: deskripsi anotasi harus satu baris (en: Error: annotation description must be a single line)",
    .err_annotate_too_many_args = "Kesalahan: annotate menerima tepat dua argumen posisional: <path> <description> (en: Error: annotate accepts exactly two positional arguments: <path> <description>)",
    .help_opt_annotate = "  annotate PATH DESC Simpan catatan satu baris tentang berkas atau direktori (alias: note; DESC kosong menghapus)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] Daftar catatan yang jalur targetnya tidak ada lagi",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] Hapus catatan yang jalur targetnya tidak ada lagi",
    .help_subcommands =
    \\<annotate>
    \\Penggunaan: dirtree annotate PATH DESC
    \\            dirtree note PATH DESC          (alias)
    \\
    \\Simpan catatan satu baris tentang sebuah berkas atau direktori. Catatan disimpan di
    \\.dirtree-state dan ditampilkan di samping PATH saat pohon ditampilkan berikutnya.
    \\
    \\Argumen:
    \\  PATH   berkas atau direktori, relatif terhadap direktori saat ini
    \\  DESC   teks catatan; berikan string kosong "" untuk menghapus catatan yang ada
    \\
    \\Contoh:
    \\  dirtree annotate src/main.zig "titik masuk CLI"
    \\  dirtree note docs "catatan desain ada di sini"
    \\  dirtree annotate README.md ""        # hapus catatan pada README.md
    \\</annotate>
    \\<orphaned_notes>
    \\Penggunaan: dirtree orphaned-notes [DIR]
    \\
    \\Daftar catatan yang jalur targetnya tidak ada lagi — misalnya setelah sebuah
    \\berkas diganti nama, dipindahkan, atau dihapus. DIR secara default adalah direktori saat ini.
    \\Ini hanya-baca: tidak ada yang diubah. Gunakan purge-orphaned-notes untuk menghapusnya.
    \\
    \\Contoh:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\Penggunaan: dirtree purge-orphaned-notes [DIR]
    \\
    \\Hapus catatan yang jalur targetnya tidak ada lagi. DIR secara default adalah
    \\direktori saat ini. Jalankan orphaned-notes terlebih dahulu untuk melihat pratinjau persis apa
    \\yang akan dihapus.
    \\
    \\Contoh:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "Catatan yatim (jalur yang tidak ada lagi):",
    .orphaned_none = "Tidak ada catatan yatim.",
    .purge_header = "Catatan yatim yang dihapus:",
    .purge_none = "Tidak ada catatan yatim untuk dihapus.",
    .help_opt_version = "  --version          Tampilkan versi (luring; membaca pemberitahuan pembaruan tersimpan)",
    .help_opt_version_check = "  --version-check    Paksa pemeriksaan daring baru terhadap API rilis GitHub",

    // ── Pesan peringatan ───────────────────────────────────────
    .warn_persist_state = "Peringatan: tidak dapat menyimpan status: {}",

    // ── Mode tes ───────────────────────────────────────────────
    .test_mode_msg = "Mode tes: menjalankan tes unit zig dilakukan via 'zig build test'",

    // ── Lain-lain ──────────────────────────────────────────────
    .err_test_bin_run = "Kesalahan: tidak dapat menjalankan DIRTREE_TEST_BIN: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "Kesalahan: tidak dapat menunggu DIRTREE_TEST_BIN (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "Kesalahan saat me-render pohon: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--bantuan", .arg = .help },
        .{ .name = "--tentang", .arg = .about },
        .{ .name = "--kedalaman", .arg = .depth },
        .{ .name = "--jalur", .arg = .path },
        .{ .name = "--sederhana", .arg = .simple },
        .{ .name = "--berdekorasi", .arg = .decorated },
        .{ .name = "--tanpa-ikon", .arg = .no_icons },
        .{ .name = "--tanpa-warna", .arg = .no_color },
        .{ .name = "--warna", .arg = .color },
        .{ .name = "--tanpa-peringatan-yatim", .arg = .no_orphan_warning },
        .{ .name = "--tanpa-catatan", .arg = .no_notes },
        .{ .name = "--tampilkan-catatan", .arg = .show_notes },
        .{ .name = "--tata-catatan", .arg = .notes },
        .{ .name = "--pemandu-catatan", .arg = .note_leader },
        .{ .name = "--tanpa-hyperlink", .arg = .no_hyperlinks },
        .{ .name = "--tautan", .arg = .hyperlinks },
        .{ .name = "--bawaan", .arg = .default },
        .{ .name = "--buka", .arg = .open },
        .{ .name = "--tutup", .arg = .close },
        .{ .name = "--tampilkan", .arg = .show },
        .{ .name = "--sembunyikan", .arg = .hide },
        .{ .name = "--urutkan", .arg = .sort },
        .{ .name = "--menaik", .arg = .asc },
        .{ .name = "--menurun", .arg = .desc },
        .{ .name = "--tampilkan-tersembunyi", .arg = .show_hidden },
        .{ .name = "--tulis-ulang-pengaturan", .arg = .rewrite_settings },
        .{ .name = "--konfigurasi", .arg = .config },
        .{ .name = "--tes", .arg = .@"test" },
        .{ .name = "--bahasa", .arg = .lang },
        .{ .name = "--sementara", .arg = .temporary },
        .{ .name = "--hanya", .arg = .only },
        .{ .name = "anotasi", .arg = .annotate },
        .{ .name = "catatan-yatim", .arg = .orphaned_notes },
        .{ .name = "bersihkan-catatan-yatim", .arg = .purge_orphaned_notes },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "POHONDIREKTORI_SEDERHANA", .var_id = .dirtree_simple },
        .{ .name = "POHONDIREKTORI_BERDEKORASI", .var_id = .dirtree_decorated },
        .{ .name = "POHONDIREKTORI_AUTO_SEDERHANA", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPA_STDOUT", .var_id = .piped_stdout },
        .{ .name = "POHONDIREKTORI_SEMBUNYIKAN_CATATAN", .var_id = .dirtree_hide_notes },
        .{ .name = "POHONDIREKTORI_PERUBAHAN_SCM_TETAP_TERSEMBUNYI_ATAU_TERTUTUP", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
