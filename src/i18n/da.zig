const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Hjælpetekst ────────────────────────────────────────────
    .help_title = "dirtree - Tilstandsbevarende mappetræer for mennesker og LLM'er",
    .help_usage = "Brug: dirtree [TILVALG] [STI]",
    .help_options_header = "Tilvalg:",
    .help_opt_help = "  -h, --help         Vis denne hjælpebesked",
    .help_opt_about = "  -a, --about        Vis detaljeret beskrivelse",
    .help_opt_depth = "  -d, --depth N      Angiv maksimal dybde (standard: 4)",
    .help_opt_temp = "  -t, --temp         Anvend ændringer kun for denne kørsel (ikke gemt)",
    .help_opt_persist = "  --persist, --save  Gem også disse indstillinger (tilsidesætter non-TTY og DIRTREE_TEMP)",
    .help_opt_path = "  -p, --path PATH    Gengiv PATH, selv hvis det ligner et flag eller en underkommando",
    .help_opt_simple = "  --simple           Udskriv et enkelt, LLM-venligt tilstandstræ",
    .help_opt_decorated = "  --decorated        Tving dekoreret udskrift (selv ved pipe)",
    .help_opt_no_icons = "  --no-icons         Deaktivér ikoner (enkel tilstand + dekoreret header)",
    .help_opt_no_color = "  --no-color        Slå ANSI-farver til/fra (gemt)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning Undertryk advarslen om forældreløse noter",
    .help_opt_notes = "  --no-notes/--show-notes Skjul eller vis indlejrede noter (DIRTREE_HIDE_NOTES=1 for at skjule som standard)",
    .help_opt_notes_mode = "  --notes MODE       Notelayout: aligned (standard) eller inline",
    .help_opt_notes_leader = "  --notes-leader     Tegn svage hjælpeprikker fra navne til justerede noter",
    .warn_orphaned_prefix = "Bemærk: ",
    .warn_orphaned_suffix = " annotering(er) peger på stier, der ikke længere findes. Kør 'orphaned-notes' for at se eller 'purge-orphaned-notes' for at fjerne.",
    .warn_negation_intro = "bemærk: et negeret regex her kan vende det, du mener — !/PAT/ matcher det MODSATTE, og et indledende (?!...) lookahead er også en negation, så at kombinere dem dobbeltnegerer:",
    .warn_negation_advice = "For at fokusere på én sti, foretræk {s} PATH; for et positivt filter brug {s} /PAT/ (vis-regler har forrang over skjul). Disse regler gemmes i .dirtree-state, som er almindelig tekst, du kan redigere i hånden, når de bliver komplekse eller overlappende.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Slå OSC8-hyperlinks til/fra (gemt)",
    .help_opt_default = "  --default X        Gem standardtilstand: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Åbn en eller flere undermapper (gentag flag for at tilføje flere)",
    .help_opt_close = "  -c, --close DIR... Luk en eller flere undermapper (gentag flag for at tilføje flere)",
    .help_opt_show = "  --show PATH...     Tving visning af relative stier; omslut regex som /mønster/ eller !/mønster/",
    .help_opt_hide = "  --hide PATH...     Skjul relative stier; omslut regex som /mønster/ eller !/mønster/ (gentagelig) (kun nogle stier? brug --only)",
    .help_opt_sort = "  --sort MODE        Sorteringstilstand: modified|alpha (standard: modified)",
    .help_opt_asc = "  --asc              Sortér stigende",
    .help_opt_desc = "  --desc             Sortér faldende (standard)",
    .help_opt_show_hidden = "  --show-hidden      Vis midlertidigt stier skjult via konfiguration",
    .help_opt_rewrite_settings = "  --rewrite-settings Omskriv tilstandsfilen med de aktuelle indstillinger",
    .help_opt_config = "  --config           Vis den beregnede effektive konfiguration",
    .help_opt_test = "  --test             Kør tilhørende tests",
    .help_opt_lang = "  --lang CODE        Angiv visningssprog (f.eks. en, de, fr, ja)",
    .help_lang_available_label = "Tilgængelige sprogkoder:",
    .help_regex_note = "Brug /mønster/ eller !/mønster/ med --open/--close/--show/--hide for at tilføje regex-regler; andre argumenter behandles som bogstavelige.",
    .help_relative_note = "Stier angivet til --show/--hide skal være relative (uden indledende '/').",
    .help_behavior_header = "Adfærd:",
    .help_behavior_text = "Præsentationsindstillinger gemmes, når stdout er en terminal; ellers gælder de kun for den aktuelle påkaldelse. Som standard gemmes --open/--close/--show/--hide ændringer altid. Farve er som standard slået til for terminaloutput og slukket for andet output. --temp eller --persist/--save tilsidesætter eksplicit disse lagringsregler.",
    .persistence_note_tty = "Meddelelse: {s}: gemt, fordi stdout er en terminal; brug --temp til kun at anvende det på denne påkaldelse.",
    .persistence_note_non_tty = "Meddelelse: {s}: ikke gemt, fordi stdout ikke er en terminal; brug --persist/--save til at tilsidesætte.",
    .persistence_note_semantic = "Meddelelse: {s}: gemt, fordi ændringer til den delte projektvisning gemmes som standard; brug --temp til kun at anvende dem på denne påkaldelse.",
    .persistence_note_env = "Meddelelse: {s}: ikke gemt, fordi DIRTREE_TEMP=1; brug --persist/--save til at tilsidesætte.",
    .persistence_note_mute = "Indstil DIRTREE_MUTE_PERSISTENCE_REASON=1 for at undertrykke denne informationsmeddelelse.",
    .help_examples_header = "Eksempler:",
    .help_example_1 = "  dirtree                       # Vis træ for den aktuelle mappe",
    .help_example_2 = "  dirtree -d 3                  # Sæt dybde til 3 niveauer",
    .help_example_3 = "  dirtree --sort alpha --asc    # Sorteret alfabetisk stigende",
    .help_example_close_comment = "Klap en mappe sammen (gemt)",
    .help_example_hide_comment = "Skjul filer der matcher et regex",
    .help_example_only_comment = "Fokusér på ét undertræ, skjul søskende",
    .help_example_localized_comment = "Lokaliserede kontaktnavne virker også",

    // ── Om-tekst ───────────────────────────────────────────────
    .about_text = "Tilstandsbevarende mappetræ (ikoner/farver/links); --simple for LLM'er; gemmer .dirtree-state (default/open/close/show/hide); regex via /mønster/ eller !/mønster/; bogstavelige skal være relative; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Fragmenter til statistik ───────────────────────────────
    .hidden_dir_singular = "mappe",
    .hidden_dir_plural = "mapper",
    .hidden_file_singular = "fil",
    .hidden_file_plural = "filer",
    .hidden_and = " og ",
    .hidden_is_hidden = " er skjult.",
    .hidden_are_hidden = " er skjult.",
    .stats_shown = " vist",
    .stats_hidden = " skjult.",
    .stats_line_singular = "linje",
    .stats_line_plural = "linjer",
    .stats_separator = "; ",

    .stats_scm_kept = " ikke skjult, da den indgår i det aktuelle git/jj-ændringssæt",
    // ── Hjælpetekst (nye flag) ─────────────────────────────────
    .help_opt_max_lines = "  --max-lines N      Angiv tærskel for advarsel om stor udskrift (standard: 500)",
    .help_opt_override_warning = "  --override-warning Undertryk advarslen om stor udskrift",
    .help_opt_only = "  --only PATH        Fokusér på et undertræ og klap søskendemapper sammen (gentagelig)",
    .help_opt_html = "  --html [FILE]      Skriv et selvstændigt HTML-træ til FILE (- = stdout; udelad = åbn i browser)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  Skjul symlink-mål; --no-targets fjerner også hyperlinks (portabelt output)",

    // ── Advarsler (stor udskrift) ──────────────────────────────
    .warn_large_output_prefix = "Advarsel: udskriften er ~",
    .warn_large_output_mid = " linjer (tærskel: ",
    .warn_large_output_suffix = "). Overvej: --depth N eller --hide-mønstre.",

    // ── Fejlmeddelelser ────────────────────────────────────────
    .err_max_lines_requires_number = "Fejl: --max-lines kræver et numerisk argument (en: Error: --max-lines requires a numeric argument)",
    .err_only_requires_path = "Fejl: --only kræver et sti-argument (en: Error: --only requires a path argument)",
    .err_depth_requires_number = "Fejl: --depth kræver et numerisk argument (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "Fejl: --path kræver et mappe-argument (en: Error: --path requires a directory argument)",
    .err_notes_requires_mode = "Fejl: --notes kræver 'aligned' eller 'inline' (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "Fejl: --sort kræver 'modified' eller 'alpha' (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "Fejl: --default kræver mindst én værdi (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "Fejl: --default tilstandskonflikt (en: Error: --default state conflict)",
    .err_default_accepts = "Fejl: --default accepterer opened/closed (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "Fejl: --open kræver mindst én mappe (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "Fejl: --close kræver mindst én mappe (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "Fejl: --show kræver mindst én sti (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "Fejl: --hide kræver mindst én sti (en: Error: --hide requires at least one path)",
    .err_unknown_option = "Ukendt tilvalg (en: Unknown option)",
    .err_not_a_directory = "Fejl: '{s}' er ikke en mappe (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "Fejl: regex-mønster må ikke være tomt (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "Fejl: {s}-stier skal være relative (uden indledende '/'): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "Ikke nok hukommelse (en: Out of memory)",
    .err_regex_conflict_path = "Fejl: stien '{s}' matcher både open- og close-mønstre (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  open-mønster: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  close-mønster: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "Fejl: ugyldigt regex-mønster: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "Fejl: ukendt sprogkode '{s}'. Tilgængelige: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Fejl: annotate kræver en sti (en: Error: annotate requires a path)",
    .err_annotate_requires_description = "Fejl: annotate kræver en beskrivelse (brug \"\" for at rydde) (en: Error: annotate requires a description (use \"\" to clear))",
    .err_annotate_multiline = "Fejl: annoteringsbeskrivelse skal være en enkelt linje (en: Error: annotation description must be a single line)",
    .err_annotate_too_many_args = "Fejl: annotate accepterer præcis to positionelle argumenter: <path> <description> (en: Error: annotate accepts exactly two positional arguments: <path> <description>)",
    .help_opt_annotate = "  annotate PATH DESC Gem en enlinjes note om en fil eller mappe (alias: note; tom DESC rydder)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] Vis noter, hvis målstier ikke længere findes",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] Fjern noter, hvis målstier ikke længere findes",
    .help_subcommands =
    \\<annotate>
    \\Brug: dirtree annotate PATH DESC
    \\      dirtree note PATH DESC          (alias)
    \\
    \\Gem en enlinjes note om en fil eller mappe. Noten gemmes i
    \\.dirtree-state og vises ved siden af PATH, næste gang træet tegnes.
    \\
    \\Argumenter:
    \\  PATH   fil eller mappe, relativ til den aktuelle mappe
    \\  DESC   noteteksten; angiv en tom streng "" for at rydde en eksisterende note
    \\
    \\Eksempler:
    \\  dirtree annotate src/main.zig "CLI-indgangspunkt"
    \\  dirtree note docs "designnoter findes her"
    \\  dirtree annotate README.md ""        # ryd noten for README.md
    \\</annotate>
    \\<orphaned_notes>
    \\Brug: dirtree orphaned-notes [DIR]
    \\
    \\Vis noter, hvis målsti ikke længere findes — for eksempel efter at en fil
    \\er blevet omdøbt, flyttet eller slettet. DIR er som standard den aktuelle mappe.
    \\Kun læsning: intet ændres. Brug purge-orphaned-notes for at fjerne dem.
    \\
    \\Eksempler:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\Brug: dirtree purge-orphaned-notes [DIR]
    \\
    \\Fjern noter, hvis målsti ikke længere findes. DIR er som standard den aktuelle
    \\mappe. Kør orphaned-notes først for at se præcis, hvad der bliver fjernet.
    \\
    \\Eksempler:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "Forældreløse noter (stier, der ikke længere findes):",
    .orphaned_none = "Ingen forældreløse noter.",
    .purge_header = "Forældreløse noter fjernet:",
    .purge_none = "Ingen forældreløse noter at fjerne.",
    .help_opt_version = "  --version          Vis version (offline; læser cachelagret besked om tilgængelig opdatering)",
    .help_opt_version_check = "  --version-check    Tving et nyt onlinetjek mod GitHub releases-API'et",

    // ── Advarsler ──────────────────────────────────────────────
    .warn_persist_state = "Advarsel: kunne ikke gemme tilstand: {}",

    // ── Testtilstand ───────────────────────────────────────────
    .test_mode_msg = "Testtilstand: Zig-unit-tests køres via 'zig build test'",

    // ── Diverse ────────────────────────────────────────────────
    .err_test_bin_run = "Fejl: kunne ikke køre DIRTREE_TEST_BIN: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "Fejl: kunne ikke vente på DIRTREE_TEST_BIN (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "Fejl ved gengivelse af træ: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--hjaelp", .arg = .help },
        .{ .name = "--om", .arg = .about },
        .{ .name = "--dybde", .arg = .depth },
        .{ .name = "--sti", .arg = .path },
        .{ .name = "--enkel", .arg = .simple },
        .{ .name = "--dekoreret", .arg = .decorated },
        .{ .name = "--ingen-ikoner", .arg = .no_icons },
        .{ .name = "--ingen-farve", .arg = .no_color },
        .{ .name = "--farve", .arg = .color },
        .{ .name = "--ingen-foraeldreloes-advarsel", .arg = .no_orphan_warning },
        .{ .name = "--ingen-noter", .arg = .no_notes },
        .{ .name = "--vis-noter", .arg = .show_notes },
        .{ .name = "--noter", .arg = .notes },
        .{ .name = "--note-hjaelpelinjer", .arg = .note_leader },
        .{ .name = "--ingen-hyperlinks", .arg = .no_hyperlinks },
        .{ .name = "--henvisninger", .arg = .hyperlinks },
        .{ .name = "--standard", .arg = .default },
        .{ .name = "--aabn", .arg = .open },
        .{ .name = "--luk", .arg = .close },
        .{ .name = "--vis", .arg = .show },
        .{ .name = "--skjul", .arg = .hide },
        .{ .name = "--sortering", .arg = .sort },
        .{ .name = "--stigende", .arg = .asc },
        .{ .name = "--faldende", .arg = .desc },
        .{ .name = "--vis-skjulte", .arg = .show_hidden },
        .{ .name = "--omskriv-indstillinger", .arg = .rewrite_settings },
        .{ .name = "--konfiguration", .arg = .config },
        .{ .name = "--sprog", .arg = .lang },
        .{ .name = "--midlertidig", .arg = .temporary },
        .{ .name = "annoter", .arg = .annotate },
        .{ .name = "foraeldreloese-noter", .arg = .orphaned_notes },
        .{ .name = "rens-foraeldreloese-noter", .arg = .purge_orphaned_notes },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "MAPPETRAE_ENKEL", .var_id = .dirtree_simple },
        .{ .name = "MAPPETRAE_DEKORERET", .var_id = .dirtree_decorated },
        .{ .name = "MAPPETRAE_AUTO_ENKEL", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPET_STDOUT", .var_id = .piped_stdout },
        .{ .name = "MAPPETRAE_SKJUL_NOTER", .var_id = .dirtree_hide_notes },
        .{ .name = "MAPPETRAE_SCM_AENDRINGER_FORBLIVER_SKJULT_ELLER_LUKKET", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
