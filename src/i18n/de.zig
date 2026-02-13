const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Hilfetext ──────────────────────────────────────────────
    .help_title = "dirtree - Zustandsbehaftete Verzeichnisbäume für Menschen und LLMs",
    .help_usage = "Verwendung: dirtree [OPTIONEN] [PFAD]",
    .help_options_header = "Optionen:",
    .help_opt_help = "  -h, --help         Diese Hilfemeldung anzeigen",
    .help_opt_about = "  -a, --about        Detaillierte Beschreibung anzeigen",
    .help_opt_depth = "  -d, --depth N      Maximale Tiefe festlegen (Standard: 4)",
    .help_opt_simple = "  --simple           Einfache, LLM-freundliche Baumausgabe",
    .help_opt_decorated = "  --decorated        Dekorierte Ausgabe erzwingen (auch bei Pipe)",
    .help_opt_no_icons = "  --no-icons         Symbole deaktivieren (einfach + dekorierter Header)",
    .help_opt_no_color = "  --no-color        ANSI-Farben deaktivieren und Einstellung speichern",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   OSC8-Hyperlinks deaktivieren und Einstellung speichern",
    .help_opt_default = "  --default X        Standard-Zustand speichern: opened|closed",
    .help_opt_open = "  -o, --open VERZ... Ein oder mehrere Unterverz. öffnen",
    .help_opt_close = "  -c, --close VERZ.. Ein oder mehrere Unterverz. schließen",
    .help_opt_show = "  --show PFAD...     Relative Pfade anzeigen; Regex als /muster/ oder !/muster/",
    .help_opt_hide = "  --hide PFAD...     Relative Pfade verbergen; Regex als /muster/ oder !/muster/",
    .help_opt_sort = "  --sort MODUS       Sortiermodus: modified|alpha (Standard: modified)",
    .help_opt_asc = "  --asc              Aufsteigend sortieren",
    .help_opt_desc = "  --desc             Absteigend sortieren (Standard)",
    .help_opt_show_hidden = "  --show-hidden      Verborgene Pfade temporär anzeigen",
    .help_opt_rewrite_settings = "  --rewrite-settings Zustandsdatei mit aktuellen Einstellungen neu schreiben",
    .help_opt_config = "  --config           Berechnete effektive Konfiguration anzeigen",
    .help_opt_test = "  --test             Zugehörige Tests ausführen",
    .help_opt_lang = "  --lang CODE        Anzeigesprache festlegen (z.B. en, de, fr, ja)",
    .help_regex_note = "/muster/ oder !/muster/ mit --open/--close/--show/--hide für Regex-Regeln; andere Argumente sind Literale.",
    .help_relative_note = "Pfade für --show/--hide müssen relativ sein (kein führendes '/').",
    .help_behavior_header = "Verhalten:",
    .help_behavior_text = "Standardmäßig werden bei Pipe-Ausgabe Farben/Symbole/Hyperlinks deaktiviert, es sei denn --decorated ist angegeben.",
    .help_examples_header = "Beispiele:",
    .help_example_1 = "  dirtree                       # Baum des aktuellen Verzeichnisses",
    .help_example_2 = "  dirtree -d 3                  # Tiefe auf 3 Ebenen setzen",
    .help_example_3 = "  dirtree --sort alpha --asc    # Alphabetisch aufsteigend sortiert",

    // ── Über-Text ──────────────────────────────────────────────
    .about_text = "Zustandsbehafteter Verzeichnisbaum (Symbole/Farben/Links); --simple für LLMs; speichert .dirtree-state (default/open/close/show/hide); Regex über /muster/ oder !/muster/; Literale müssen relativ sein; Env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Versteckte Zählung ─────────────────────────────────────
    .hidden_dir_singular = "Verzeichnis",
    .hidden_dir_plural = "Verzeichnisse",
    .hidden_file_singular = "Datei",
    .hidden_file_plural = "Dateien",
    .hidden_and = " und ",
    .hidden_is_hidden = " ist verborgen.",
    .hidden_are_hidden = " sind verborgen.",
    .stats_shown = " angezeigt",
    .stats_hidden = " versteckt.",
    .stats_line_singular = "Zeile",
    .stats_line_plural = "Zeilen",
    .stats_separator = "; ",

    // ── Fehlermeldungen ────────────────────────────────────────
    .err_depth_requires_number = "Fehler: --depth erfordert ein numerisches Argument",
    .err_sort_requires_mode = "Fehler: --sort erfordert 'modified' oder 'alpha'",
    .err_default_requires_value = "Fehler: --default erfordert mindestens einen Wert",
    .err_default_state_conflict = "Fehler: --default Zustandskonflikt",
    .err_default_visibility_conflict = "Fehler: --default Sichtbarkeitskonflikt",
    .err_default_accepts = "Fehler: --default akzeptiert opened/closed/shown/hidden",
    .err_open_requires_dir = "Fehler: --open erfordert mindestens ein Verzeichnis",
    .err_close_requires_dir = "Fehler: --close erfordert mindestens ein Verzeichnis",
    .err_show_requires_path = "Fehler: --show erfordert mindestens einen Pfad",
    .err_hide_requires_path = "Fehler: --hide erfordert mindestens einen Pfad",
    .err_unknown_option = "Unbekannte Option",
    .err_not_a_directory = "Fehler: '{s}' ist kein Verzeichnis",
    .err_regex_empty = "Fehler: Regex-Muster darf nicht leer sein",
    .err_paths_must_be_relative = "Fehler: {s}-Pfade müssen relativ sein (kein führendes '/'): {s}",
    .err_out_of_memory = "Nicht genügend Speicher",
    .err_regex_conflict_path = "Fehler: Pfad '{s}' passt auf Open- und Close-Muster",
    .err_regex_conflict_open = "  Open-Muster: {s}",
    .err_regex_conflict_close = "  Close-Muster: {s}",
    .err_unknown_lang = "Fehler: Unbekannter Sprachcode '{s}'. Verfügbar: {s}",

    // ── Warnungen ──────────────────────────────────────────────
    .warn_persist_state = "Warnung: Zustand konnte nicht gespeichert werden: {}",

    // ── Testmodus ──────────────────────────────────────────────
    .test_mode_msg = "Testmodus: Zig-Unit-Tests werden über 'zig build test' ausgeführt",

    // ── Sonstiges ──────────────────────────────────────────────
    .err_test_bin_run = "Fehler: DIRTREE_TEST_BIN konnte nicht ausgeführt werden: {s}",
    .err_test_bin_wait = "Fehler: Warten auf DIRTREE_TEST_BIN fehlgeschlagen",
    .err_render_tree = "Fehler beim Rendern des Baums: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--hilfe", .arg = .help },
        .{ .name = "--ueber", .arg = .about },
        .{ .name = "--tiefe", .arg = .depth },
        .{ .name = "--einfach", .arg = .simple },
        .{ .name = "--dekoriert", .arg = .decorated },
        .{ .name = "--keine-symbole", .arg = .no_icons },
        .{ .name = "--keine-farbe", .arg = .no_color },
        .{ .name = "--keine-hyperlinks", .arg = .no_hyperlinks },
        .{ .name = "--standard", .arg = .default },
        .{ .name = "--oeffnen", .arg = .open },
        .{ .name = "--schliessen", .arg = .close },
        .{ .name = "--zeigen", .arg = .show },
        .{ .name = "--verbergen", .arg = .hide },
        .{ .name = "--sortierung", .arg = .sort },
        .{ .name = "--aufsteigend", .arg = .asc },
        .{ .name = "--absteigend", .arg = .desc },
        .{ .name = "--verborgene-zeigen", .arg = .show_hidden },
        .{ .name = "--einstellungen-neu-schreiben", .arg = .rewrite_settings },
        .{ .name = "--konfiguration", .arg = .config },
        .{ .name = "--testen", .arg = .@"test" },
        .{ .name = "--sprache", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "VERZEICHNISBAUM_EINFACH", .var_id = .dirtree_simple },
        .{ .name = "VERZEICHNISBAUM_DEKORIERT", .var_id = .dirtree_decorated },
        .{ .name = "VERZEICHNISBAUM_AUTO_EINFACH", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPE_STDOUT", .var_id = .piped_stdout },
        .{ .name = "VERZEICHNISBAUM_SCM_AENDERUNGEN_VERBORGEN_ODER_GESCHLOSSEN", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
