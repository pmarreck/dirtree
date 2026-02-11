const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Testo di aiuto ──────────────────────────────────────────
    .help_title = "dirtree - Alberi di directory con stato per umani e LLM",
    .help_usage = "Uso: dirtree [OPZIONI] [PERCORSO]",
    .help_options_header = "Opzioni:",
    .help_opt_help = "  -h, --help         Mostra questo messaggio di aiuto",
    .help_opt_about = "  -a, --about        Mostra la descrizione dettagliata",
    .help_opt_depth = "  -d, --depth N      Imposta la profondit\xc3\xa0 massima (predefinito: 4)",
    .help_opt_simple = "  --simple           Output semplice, adatto ai LLM",
    .help_opt_decorated = "  --decorated        Forza output decorato (anche in pipe)",
    .help_opt_no_icons = "  --no-icons         Disattiva le icone (modo semplice + intestazione decorata)",
    .help_opt_no_color = "  --no-color        Disattiva i colori ANSI e persisti la preferenza",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Disattiva i collegamenti OSC8 e persisti la preferenza",
    .help_opt_default = "  --default X        Persisti lo stato predefinito: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Apri una o pi\xc3\xb9 sottodirectory",
    .help_opt_close = "  -c, --close DIR... Chiudi una o pi\xc3\xb9 sottodirectory",
    .help_opt_show = "  --show PERC...     Mostra forzatamente percorsi relativi; regex come /pattern/ o !/pattern/",
    .help_opt_hide = "  --hide PERC...     Nascondi percorsi relativi; regex come /pattern/ o !/pattern/",
    .help_opt_sort = "  --sort MODO        Modalit\xc3\xa0 di ordinamento: modified|alpha (predefinito: modified)",
    .help_opt_asc = "  --asc              Ordine crescente",
    .help_opt_desc = "  --desc             Ordine decrescente (predefinito)",
    .help_opt_show_hidden = "  --show-hidden      Mostra temporaneamente i percorsi nascosti dalla configurazione",
    .help_opt_rewrite_settings = "  --rewrite-settings Riscrivi il file di stato con le impostazioni correnti",
    .help_opt_config = "  --config           Mostra la configurazione effettiva calcolata",
        .help_opt_test = "  --test             Esegui i test associati",
    .help_opt_lang = "  --lang CODICE      Imposta la lingua di visualizzazione (es. en, de, fr, ja)",
    .help_regex_note = "Usa /pattern/ o !/pattern/ con --open/--close/--show/--hide per regole regex; gli altri argomenti sono trattati come letterali.",
    .help_relative_note = "I percorsi forniti a --show/--hide devono essere relativi (senza '/' iniziale).",
    .help_behavior_header = "Comportamento:",
    .help_behavior_text = "Per impostazione predefinita, quando stdout non \xc3\xa8 un TTY (pipe), colori/icone/collegamenti vengono disattivati a meno che non si specifichi --decorated.",
    .help_examples_header = "Esempi:",
    .help_example_1 = "  dirtree                       # Mostra l'albero della directory corrente",
    .help_example_2 = "  dirtree -d 3                  # Profondit\xc3\xa0 limitata a 3 livelli",
    .help_example_3 = "  dirtree --sort alpha --asc    # Ordinato alfabeticamente in modo crescente",

    // ── Testo informazioni ──────────────────────────────────────
    .about_text = "Albero di directory con stato (icone/colori/collegamenti); --simple per i LLM; persiste .dirtree-state (default/open/close/show/hide); regex tramite /pattern/ o !/pattern/; i letterali devono essere relativi; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Frammenti conteggio nascosti ────────────────────────────
    .hidden_dir_singular = "directory",
    .hidden_dir_plural = "directory",
    .hidden_file_singular = "file",
    .hidden_file_plural = "file",
    .hidden_and = " e ",
    .hidden_is_hidden = " \xc3\xa8 nascosto.",
    .hidden_are_hidden = " sono nascosti.",

    // ── Messaggi di errore ──────────────────────────────────────
    .err_depth_requires_number = "Errore: --depth richiede un argomento numerico",
    .err_sort_requires_mode = "Errore: --sort richiede 'modified' o 'alpha'",
    .err_default_requires_value = "Errore: --default richiede almeno un valore",
    .err_default_state_conflict = "Errore: conflitto di stato in --default",
    .err_default_visibility_conflict = "Errore: conflitto di visibilit\xc3\xa0 in --default",
    .err_default_accepts = "Errore: --default accetta opened/closed/shown/hidden",
    .err_open_requires_dir = "Errore: --open richiede almeno una directory",
    .err_close_requires_dir = "Errore: --close richiede almeno una directory",
    .err_show_requires_path = "Errore: --show richiede almeno un percorso",
    .err_hide_requires_path = "Errore: --hide richiede almeno un percorso",
    .err_unknown_option = "Opzione sconosciuta",
    .err_not_a_directory = "Errore: '{s}' non \xc3\xa8 una directory",
    .err_regex_empty = "Errore: il pattern regex non deve essere vuoto",
    .err_paths_must_be_relative = "Errore: i percorsi {s} devono essere relativi (senza '/' iniziale): {s}",
    .err_out_of_memory = "Memoria insufficiente",
    .err_regex_conflict_path = "Errore: il percorso '{s}' corrisponde sia al pattern open che close",
    .err_regex_conflict_open = "  pattern open: {s}",
    .err_regex_conflict_close = "  pattern close: {s}",
    .err_unknown_lang = "Errore: codice lingua sconosciuto '{s}'. Disponibili: {s}",

    // ── Avvertenze ──────────────────────────────────────────────
    .warn_persist_state = "Avvertimento: impossibile persistere lo stato: {}",

    // ── Modalit\xc3\xa0 test ──────────────────────────────────────────
    .test_mode_msg = "Modalit\xc3\xa0 test: i test unitari Zig si eseguono con 'zig build test'",

    // ── Varie ──────────────────────────────────────────────────
    .err_test_bin_run = "Errore: impossibile eseguire DIRTREE_TEST_BIN: {s}",
    .err_test_bin_wait = "Errore: impossibile attendere DIRTREE_TEST_BIN",
    .err_render_tree = "Errore nel rendering dell'albero: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--aiuto", .arg = .help },
        .{ .name = "--informazioni", .arg = .about },
        .{ .name = "--profondita", .arg = .depth },
        .{ .name = "--semplice", .arg = .simple },
        .{ .name = "--decorato", .arg = .decorated },
        .{ .name = "--senza-icone", .arg = .no_icons },
        .{ .name = "--senza-colore", .arg = .no_color },
        .{ .name = "--senza-collegamenti", .arg = .no_hyperlinks },
        .{ .name = "--predefinito", .arg = .default },
        .{ .name = "--apri", .arg = .open },
        .{ .name = "--chiudi", .arg = .close },
        .{ .name = "--mostra", .arg = .show },
        .{ .name = "--nascondi", .arg = .hide },
        .{ .name = "--ordina", .arg = .sort },
        .{ .name = "--crescente", .arg = .asc },
        .{ .name = "--decrescente", .arg = .desc },
        .{ .name = "--mostra-nascosti", .arg = .show_hidden },
        .{ .name = "--riscrivi-impostazioni", .arg = .rewrite_settings },
        .{ .name = "--configurazione", .arg = .config },
                .{ .name = "--prova", .arg = .@"test" },
        .{ .name = "--lingua", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "ALBERO_SEMPLICE", .var_id = .dirtree_simple },
        .{ .name = "ALBERO_DECORATO", .var_id = .dirtree_decorated },
        .{ .name = "ALBERO_AUTO_SEMPLICE", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "ALBERO_SCM_MODIFICHE_NASCOSTE_O_CHIUSE", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
