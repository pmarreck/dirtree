/// The Strings struct defines every user-facing string in dirtree.
/// Each locale module must provide a `const strings: Strings` that fills all fields.
pub const Strings = struct {
    // ── Help text ──────────────────────────────────────────────
    help_title: [:0]const u8,
    help_usage: [:0]const u8,
    help_options_header: [:0]const u8,
    help_opt_help: [:0]const u8,
    help_opt_about: [:0]const u8,
    help_opt_depth: [:0]const u8,
    help_opt_simple: [:0]const u8,
    help_opt_decorated: [:0]const u8,
    help_opt_no_icons: [:0]const u8,
    help_opt_no_color: [:0]const u8,
    help_opt_no_hyperlinks: [:0]const u8,
    help_opt_default: [:0]const u8,
    help_opt_open: [:0]const u8,
    help_opt_close: [:0]const u8,
    help_opt_show: [:0]const u8,
    help_opt_hide: [:0]const u8,
    help_opt_sort: [:0]const u8,
    help_opt_asc: [:0]const u8,
    help_opt_desc: [:0]const u8,
    help_opt_show_hidden: [:0]const u8,
    help_opt_rewrite_settings: [:0]const u8,
    help_opt_config: [:0]const u8,
    help_opt_test: [:0]const u8,
    help_opt_lang: [:0]const u8,
    help_regex_note: [:0]const u8,
    help_relative_note: [:0]const u8,
    help_behavior_header: [:0]const u8,
    help_behavior_text: [:0]const u8,
    help_examples_header: [:0]const u8,
    help_example_1: [:0]const u8,
    help_example_2: [:0]const u8,
    help_example_3: [:0]const u8,

    // ── About text ─────────────────────────────────────────────
    about_text: [:0]const u8,

    // ── Hidden count fragments ─────────────────────────────────
    hidden_dir_singular: [:0]const u8,
    hidden_dir_plural: [:0]const u8,
    hidden_file_singular: [:0]const u8,
    hidden_file_plural: [:0]const u8,
    hidden_and: [:0]const u8,
    hidden_is_hidden: [:0]const u8,
    hidden_are_hidden: [:0]const u8,

    // ── Error messages ─────────────────────────────────────────
    err_depth_requires_number: [:0]const u8,
    err_sort_requires_mode: [:0]const u8,
    err_default_requires_value: [:0]const u8,
    err_default_state_conflict: [:0]const u8,
    err_default_visibility_conflict: [:0]const u8,
    err_default_accepts: [:0]const u8,
    err_open_requires_dir: [:0]const u8,
    err_close_requires_dir: [:0]const u8,
    err_show_requires_path: [:0]const u8,
    err_hide_requires_path: [:0]const u8,
    err_unknown_option: [:0]const u8,
    err_not_a_directory: [:0]const u8,
    err_regex_empty: [:0]const u8,
    err_paths_must_be_relative: [:0]const u8,
    err_out_of_memory: [:0]const u8,
    err_regex_conflict_path: [:0]const u8,
    err_regex_conflict_open: [:0]const u8,
    err_regex_conflict_close: [:0]const u8,
    err_unknown_lang: [:0]const u8,

    // ── Warning messages ───────────────────────────────────────
    warn_persist_state: [:0]const u8,

    // ── Test mode ──────────────────────────────────────────────
    test_mode_msg: [:0]const u8,

    // ── Misc ───────────────────────────────────────────────────
    err_test_bin_run: [:0]const u8,
    err_test_bin_wait: [:0]const u8,
    err_render_tree: [:0]const u8,
};
