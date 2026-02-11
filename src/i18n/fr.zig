const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Texte d'aide ──────────────────────────────────────────
    .help_title = "dirtree - Arborescences de r\xc3\xa9pertoires \xc3\xa0 \xc3\xa9tat pour humains et LLMs",
    .help_usage = "Utilisation : dirtree [OPTIONS] [CHEMIN]",
    .help_options_header = "Options :",
    .help_opt_help = "  -h, --help         Afficher ce message d'aide",
    .help_opt_about = "  -a, --about        Afficher la description d\xc3\xa9taill\xc3\xa9e",
    .help_opt_depth = "  -d, --depth N      D\xc3\xa9finir la profondeur maximale (d\xc3\xa9faut : 4)",
    .help_opt_simple = "  --simple           Sortie simple, adapt\xc3\xa9e aux LLMs",
    .help_opt_decorated = "  --decorated        Forcer la sortie d\xc3\xa9cor\xc3\xa9e (m\xc3\xaame en pipe)",
    .help_opt_no_icons = "  --no-icons         D\xc3\xa9sactiver les ic\xc3\xb4nes (mode simple + en-t\xc3\xaate d\xc3\xa9cor\xc3\xa9)",
    .help_opt_no_color = "  --no-color        D\xc3\xa9sactiver les couleurs ANSI et persister le choix",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   D\xc3\xa9sactiver les hyperliens OSC8 et persister le choix",
    .help_opt_default = "  --default X        Persister l'\xc3\xa9tat par d\xc3\xa9faut : opened|closed",
    .help_opt_open = "  -o, --open R\xc3\x89P...  Ouvrir un ou plusieurs sous-r\xc3\xa9pertoires",
    .help_opt_close = "  -c, --close R\xc3\x89P... Fermer un ou plusieurs sous-r\xc3\xa9pertoires",
    .help_opt_show = "  --show CHEMIN...   Forcer l'affichage de chemins relatifs ; regex via /motif/ ou !/motif/",
    .help_opt_hide = "  --hide CHEMIN...   Masquer des chemins relatifs ; regex via /motif/ ou !/motif/",
    .help_opt_sort = "  --sort MODE        Mode de tri : modified|alpha (d\xc3\xa9faut : modified)",
    .help_opt_asc = "  --asc              Tri croissant",
    .help_opt_desc = "  --desc             Tri d\xc3\xa9croissant (d\xc3\xa9faut)",
    .help_opt_show_hidden = "  --show-hidden      Afficher temporairement les chemins masqu\xc3\xa9s",
    .help_opt_rewrite_settings = "  --rewrite-settings R\xc3\xa9\xc3\xa9crire le fichier d'\xc3\xa9tat avec les param\xc3\xa8tres actuels",
    .help_opt_config = "  --config           Afficher la configuration effective calcul\xc3\xa9e",
        .help_opt_test = "  --test             Lancer les tests associ\xc3\xa9s",
    .help_opt_lang = "  --lang CODE        D\xc3\xa9finir la langue d'affichage (ex. en, de, fr, ja)",
    .help_regex_note = "Utilisez /motif/ ou !/motif/ avec --open/--close/--show/--hide pour des r\xc3\xa8gles regex ; les autres arguments sont des litt\xc3\xa9raux.",
    .help_relative_note = "Les chemins fournis \xc3\xa0 --show/--hide doivent \xc3\xaatre relatifs (pas de '/' initial).",
    .help_behavior_header = "Comportement :",
    .help_behavior_text = "Par d\xc3\xa9faut, quand stdout n'est pas un TTY (pipe), couleurs/ic\xc3\xb4nes/hyperliens sont d\xc3\xa9sactiv\xc3\xa9s sauf si --decorated est sp\xc3\xa9cifi\xc3\xa9.",
    .help_examples_header = "Exemples :",
    .help_example_1 = "  dirtree                       # Afficher l'arborescence du r\xc3\xa9pertoire courant",
    .help_example_2 = "  dirtree -d 3                  # Profondeur limit\xc3\xa9e \xc3\xa0 3 niveaux",
    .help_example_3 = "  dirtree --sort alpha --asc    # Tri alphab\xc3\xa9tique croissant",

    // ── Texte \xc3\xa0 propos ──────────────────────────────────────────
    .about_text = "Arborescence de r\xc3\xa9pertoires \xc3\xa0 \xc3\xa9tat (ic\xc3\xb4nes/couleurs/liens) ; --simple pour les LLMs ; persiste .dirtree-state (default/open/close/show/hide) ; regex via /motif/ ou !/motif/ ; les litt\xc3\xa9raux doivent \xc3\xaatre relatifs ; env : DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Fragments de comptage masqu\xc3\xa9 ──────────────────────────
    .hidden_dir_singular = "r\xc3\xa9pertoire",
    .hidden_dir_plural = "r\xc3\xa9pertoires",
    .hidden_file_singular = "fichier",
    .hidden_file_plural = "fichiers",
    .hidden_and = " et ",
    .hidden_is_hidden = " est masqu\xc3\xa9.",
    .hidden_are_hidden = " sont masqu\xc3\xa9s.",

    // ── Messages d'erreur ──────────────────────────────────────
    .err_depth_requires_number = "Erreur : --depth n\xc3\xa9cessite un argument num\xc3\xa9rique",
    .err_sort_requires_mode = "Erreur : --sort n\xc3\xa9cessite 'modified' ou 'alpha'",
    .err_default_requires_value = "Erreur : --default n\xc3\xa9cessite au moins une valeur",
    .err_default_state_conflict = "Erreur : conflit d'\xc3\xa9tat --default",
    .err_default_visibility_conflict = "Erreur : conflit de visibilit\xc3\xa9 --default",
    .err_default_accepts = "Erreur : --default accepte opened/closed/shown/hidden",
    .err_open_requires_dir = "Erreur : --open n\xc3\xa9cessite au moins un r\xc3\xa9pertoire",
    .err_close_requires_dir = "Erreur : --close n\xc3\xa9cessite au moins un r\xc3\xa9pertoire",
    .err_show_requires_path = "Erreur : --show n\xc3\xa9cessite au moins un chemin",
    .err_hide_requires_path = "Erreur : --hide n\xc3\xa9cessite au moins un chemin",
    .err_unknown_option = "Option inconnue",
    .err_not_a_directory = "Erreur : '{s}' n'est pas un r\xc3\xa9pertoire",
    .err_regex_empty = "Erreur : le motif regex ne doit pas \xc3\xaatre vide",
    .err_paths_must_be_relative = "Erreur : les chemins {s} doivent \xc3\xaatre relatifs (pas de '/' initial) : {s}",
    .err_out_of_memory = "M\xc3\xa9moire insuffisante",
    .err_regex_conflict_path = "Erreur : le chemin '{s}' correspond aux motifs open et close",
    .err_regex_conflict_open = "  motif open : {s}",
    .err_regex_conflict_close = "  motif close : {s}",
    .err_unknown_lang = "Erreur : code de langue inconnu '{s}'. Disponibles : {s}",

    // ── Avertissements ───────────────────────────────────────
    .warn_persist_state = "Avertissement : impossible de persister l'\xc3\xa9tat : {}",

    // ── Mode test ──────────────────────────────────────────────
    .test_mode_msg = "Mode test : les tests unitaires Zig se lancent via 'zig build test'",

    // ── Divers ──────────────────────────────────────────────────
    .err_test_bin_run = "Erreur : impossible d'ex\xc3\xa9cuter DIRTREE_TEST_BIN : {s}",
    .err_test_bin_wait = "Erreur : impossible d'attendre DIRTREE_TEST_BIN",
    .err_render_tree = "Erreur lors du rendu de l'arborescence : {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--aide", .arg = .help },
        .{ .name = "--a-propos", .arg = .about },
        .{ .name = "--profondeur", .arg = .depth },
        .{ .name = "--brut", .arg = .simple },
        .{ .name = "--decore", .arg = .decorated },
        .{ .name = "--sans-icones", .arg = .no_icons },
        .{ .name = "--sans-couleur", .arg = .no_color },
        .{ .name = "--sans-hyperliens", .arg = .no_hyperlinks },
        .{ .name = "--defaut", .arg = .default },
        .{ .name = "--ouvrir", .arg = .open },
        .{ .name = "--fermer", .arg = .close },
        .{ .name = "--montrer", .arg = .show },
        .{ .name = "--masquer", .arg = .hide },
        .{ .name = "--tri", .arg = .sort },
        .{ .name = "--ascendant", .arg = .asc },
        .{ .name = "--descendant", .arg = .desc },
        .{ .name = "--montrer-masques", .arg = .show_hidden },
        .{ .name = "--reecrire-parametres", .arg = .rewrite_settings },
        .{ .name = "--configuration", .arg = .config },
                .{ .name = "--tester", .arg = .@"test" },
        .{ .name = "--langue", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "ARBORESCENCE_SIMPLE", .var_id = .dirtree_simple },
        .{ .name = "ARBORESCENCE_DECORE", .var_id = .dirtree_decorated },
        .{ .name = "ARBORESCENCE_AUTO_SIMPLE", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "ARBORESCENCE_SCM_CHANGEMENTS_MASQUES_OU_FERMES", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
