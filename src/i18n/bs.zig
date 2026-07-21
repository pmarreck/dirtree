const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Tekst pomoći ───────────────────────────────────────────
    .help_title = "dirtree - Stablo direktorija sa stanjem za ljude i LLM-ove",
    .help_usage = "Upotreba: dirtree [OPCIJE] [PUTANJA]",
    .help_options_header = "Opcije:",
    .help_opt_help = "  -h, --help         Prikaži ovu poruku pomoći",
    .help_opt_about = "  -a, --about        Prikaži detaljan opis",
    .help_opt_depth = "  -d, --depth N      Postavi maksimalnu dubinu (zadano: 4)",
    .help_opt_temp = "  -t, --temp         Primijeni promjene samo za ovo pokretanje (nije sačuvano)",
    .help_opt_path = "  -p, --path PATH    Prikaži PATH čak i ako izgleda kao zastavica ili podnaredba",
    .help_opt_simple = "  --simple           Ispiši jednostavno stablo sa stanjem, pogodno za LLM-ove",
    .help_opt_decorated = "  --decorated        Prisili ukrašeni ispis (čak i kada se preusmjerava)",
    .help_opt_no_icons = "  --no-icons         Onemogući ikone (jednostavni način + ukrašeno zaglavlje)",
    .help_opt_no_color = "  --no-color        Uključi/isključi ANSI boje (sačuvano)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning Potisni upozorenje o napuštenim bilješkama",
    .help_opt_notes = "  --no-notes/--show-notes Sakrij ili prikaži ugrađene bilješke (DIRTREE_HIDE_NOTES=1 za skrivanje po zadanom)",
    .help_opt_notes_mode = "  --notes MODE       Raspored bilješki: aligned (zadano) ili inline",
    .help_opt_notes_leader = "  --notes-leader     Iscrtaj prigušene tačkice od imena do poravnatih bilješki",
    .warn_orphaned_prefix = "Napomena: ",
    .warn_orphaned_suffix = " bilješki(a) upućuje na putanje koje više ne postoje. Pokreni 'orphaned-notes' za pregled ili 'purge-orphaned-notes' za uklanjanje.",
    .warn_negation_intro = "napomena: negirani regex ovdje može preokrenuti vašu namjeru — !/PAT/ pogađa SUPROTNO, a vodeći (?!...) lookahead je također negacija, pa njihovo kombiniranje daje dvostruku negaciju:",
    .warn_negation_advice = "Da se fokusirate na jednu putanju, koristite {s} PATH; za pozitivan filter koristite {s} /PAT/ (pravila prikazivanja imaju prednost nad skrivanjem). Ova pravila se spremaju u .dirtree-state, što je obični tekst koji možete ručno urediti kada postanu složena ili se preklapaju.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Uključi/isključi OSC8 hiperveze (sačuvano)",
    .help_opt_default = "  --default X        Sačuvaj zadano stanje: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Otvori jedan ili više poddirektorija (ponovi zastavicu za dodavanje)",
    .help_opt_close = "  -c, --close DIR... Zatvori jedan ili više poddirektorija (ponovi zastavicu za dodavanje)",
    .help_opt_show = "  --show PATH...     Prisilno prikaži relativne putanje; regex umotaj kao /uzorak/ ili !/uzorak/",
    .help_opt_hide = "  --hide PATH...     Sakrij relativne putanje; regex umotaj kao /uzorak/ ili !/uzorak/ (ponovljivo) (želite zadržati samo neke putanje? koristite --only)",
    .help_opt_sort = "  --sort MODE        Način sortiranja: modified|alpha (zadano: modified)",
    .help_opt_asc = "  --asc              Sortiraj uzlazno",
    .help_opt_desc = "  --desc             Sortiraj silazno (zadano)",
    .help_opt_show_hidden = "  --show-hidden      Privremeno prikaži putanje skrivene putem konfiguracije",
    .help_opt_rewrite_settings = "  --rewrite-settings Prepiši datoteku stanja koristeći trenutne postavke",
    .help_opt_config = "  --config           Prikaži izračunatu efektivnu konfiguraciju",
    .help_opt_test = "  --test             Pokreni pridružene testove",
    .help_opt_lang = "  --lang CODE        Postavi jezik prikaza (npr. en, de, fr, ja)",
    .help_lang_available_label = "Dostupni jezički kodovi:",
    .help_regex_note = "Koristite /uzorak/ ili !/uzorak/ uz --open/--close/--show/--hide za dodavanje regex pravila; ostali argumenti se tretiraju kao doslovni.",
    .help_relative_note = "Putanje proslijeđene uz --show/--hide moraju biti relativne (bez vodeće '/').",
    .help_behavior_header = "Ponašanje:",
    .help_behavior_text = "Po zadanom, kada stdout nije TTY (preusmjeren), boje/ikone/hiperveze su onemogućene osim ako je naveden --decorated.",
    .help_examples_header = "Primjeri:",
    .help_example_1 = "  dirtree                       # Prikaži stablo trenutnog direktorija",
    .help_example_2 = "  dirtree -d 3                  # Postavi dubinu na 3 nivoa",
    .help_example_3 = "  dirtree --sort alpha --asc    # Sortirano abecedno uzlazno",
    .help_example_close_comment = "Sklopi direktorij (sačuvano)",
    .help_example_hide_comment = "Sakrij datoteke koje odgovaraju regexu",
    .help_example_only_comment = "Fokusiraj se na jedno podstablo, sakrij susjede",
    .help_example_localized_comment = "Lokalizovani nazivi prekidača također rade",

    // ── Tekst opisa ────────────────────────────────────────────
    .about_text = "Stablo direktorija sa stanjem (ikone/boje/veze); --simple za LLM-ove; sprema .dirtree-state (default/open/close/show/hide); regex putem /uzorak/ ili !/uzorak/; doslovni moraju biti relativni; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Fragmenti brojanja skrivenih ───────────────────────────
    .hidden_dir_singular = "direktorij",
    .hidden_dir_plural = "direktorija",
    .hidden_file_singular = "datoteka",
    .hidden_file_plural = "datoteka",
    .hidden_and = " i ",
    .hidden_is_hidden = " je skriven.",
    .hidden_are_hidden = " su skriveni.",
    .stats_shown = " prikazano",
    .stats_hidden = " skriveno.",
    .stats_line_singular = "linija",
    .stats_line_plural = "linija",
    .stats_separator = "; ",

    .stats_scm_kept = " nije skriveno jer je uključeno u trenutni git/jj skup promjena",
    // ── Tekst pomoći (nove zastavice) ──────────────────────────
    .help_opt_max_lines = "  --max-lines N      Postavi prag upozorenja za veliki ispis (zadano: 500)",
    .help_opt_override_warning = "  --override-warning Potisni upozorenje o velikom ispisu",
    .help_opt_only = "  --only PATH        Fokusiraj se na podstablo, sklapajući susjedne direktorije (ponovljivo)",
    .help_opt_html = "  --html [FILE]      Zapiši samostalno HTML stablo u FILE (- = stdout; izostavi = otvori u pregledniku)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  Sakrij ciljeve simboličkih linkova; --no-targets uklanja i hiperveze (prenosivi izlaz)",


    // ── Upozorenja (veliki ispis) ──────────────────────────────
    .warn_large_output_prefix = "Upozorenje: ispis je ~",
    .warn_large_output_mid = " linija (prag: ",
    .warn_large_output_suffix = "). Razmotrite: --depth N ili --hide uzorke.",

    // ── Poruke o greškama ──────────────────────────────────────
    .err_max_lines_requires_number = "Greška: --max-lines zahtijeva numerički argument (en: Error: --max-lines requires a numeric argument)",
    .err_only_requires_path = "Greška: --only zahtijeva argument putanje (en: Error: --only requires a path argument)",
    .err_depth_requires_number = "Greška: --depth zahtijeva numerički argument (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "Greška: --path zahtijeva argument direktorija (en: Error: --path requires a directory argument)",
    .err_notes_requires_mode = "Greška: --notes zahtijeva 'aligned' ili 'inline' (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "Greška: --sort zahtijeva 'modified' ili 'alpha' (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "Greška: --default zahtijeva najmanje jednu vrijednost (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "Greška: sukob stanja --default (en: Error: --default state conflict)",
    .err_default_accepts = "Greška: --default prihvata opened/closed (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "Greška: --open zahtijeva najmanje jedan direktorij (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "Greška: --close zahtijeva najmanje jedan direktorij (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "Greška: --show zahtijeva najmanje jednu putanju (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "Greška: --hide zahtijeva najmanje jednu putanju (en: Error: --hide requires at least one path)",
    .err_unknown_option = "Nepoznata opcija (en: Unknown option)",
    .err_not_a_directory = "Greška: '{s}' nije direktorij (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "Greška: regex uzorak ne smije biti prazan (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "Greška: {s} putanje moraju biti relativne (bez vodeće '/'): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "Nema dovoljno memorije (en: Out of memory)",
    .err_regex_conflict_path = "Greška: putanja '{s}' odgovara i open i close uzorcima (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  open uzorak: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  close uzorak: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "Greška: nevažeći regex uzorak: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "Greška: nepoznat jezički kod '{s}'. Dostupno: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Greška: annotate zahtijeva putanju (en: Error: annotate requires a path)",
    .err_annotate_requires_description = "Greška: annotate zahtijeva opis (koristite \"\" za brisanje) (en: Error: annotate requires a description (use \"\" to clear))",
    .err_annotate_multiline = "Greška: opis bilješke mora biti u jednoj liniji (en: Error: annotation description must be a single line)",
    .err_annotate_too_many_args = "Greška: annotate prihvata tačno dva pozicijska argumenta: <putanja> <opis> (en: Error: annotate accepts exactly two positional arguments: <path> <description>)",
    .help_opt_annotate = "  annotate PATH DESC Sačuvaj jednolinijsku bilješku o datoteci ili direktoriju (alias: note; prazan DESC briše)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] Izlistaj bilješke čije ciljne putanje više ne postoje",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] Ukloni bilješke čije ciljne putanje više ne postoje",
    .help_subcommands =
    \\<annotate>
    \\Upotreba: dirtree annotate PATH DESC
    \\          dirtree note PATH DESC          (alias)
    \\
    \\Sačuvaj jednolinijsku bilješku o datoteci ili direktoriju. Bilješka se
    \\čuva u .dirtree-state i prikazuje pored PATH pri sljedećem iscrtavanju stabla.
    \\
    \\Argumenti:
    \\  PATH   datoteka ili direktorij, relativno u odnosu na trenutni direktorij
    \\  DESC   tekst bilješke; proslijedi prazan niz "" za brisanje postojeće bilješke
    \\
    \\Primjeri:
    \\  dirtree annotate src/main.zig "ulazna tačka CLI-ja"
    \\  dirtree note docs "ovdje se nalaze bilješke o dizajnu"
    \\  dirtree annotate README.md ""        # obriši bilješku na README.md
    \\</annotate>
    \\<orphaned_notes>
    \\Upotreba: dirtree orphaned-notes [DIR]
    \\
    \\Izlistaj bilješke čija ciljna putanja više ne postoji — na primjer nakon što je
    \\datoteka preimenovana, premještena ili izbrisana. DIR se podrazumijevano odnosi na trenutni direktorij.
    \\Ovo je samo za čitanje: ništa se ne mijenja. Koristi purge-orphaned-notes za njihovo uklanjanje.
    \\
    \\Primjeri:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\Upotreba: dirtree purge-orphaned-notes [DIR]
    \\
    \\Ukloni bilješke čija ciljna putanja više ne postoji. DIR se podrazumijevano odnosi
    \\na trenutni direktorij. Prvo pokreni orphaned-notes za pregled onoga što će tačno
    \\biti uklonjeno.
    \\
    \\Primjeri:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "Napuštene bilješke (putanje koje više ne postoje):",
    .orphaned_none = "Nema napuštenih bilješki.",
    .purge_header = "Uklonjene napuštene bilješke:",
    .purge_none = "Nema napuštenih bilješki za uklanjanje.",
    .help_opt_version = "  --version          Prikaži verziju (offline; čita keširanu obavijest o dostupnom ažuriranju)",
    .help_opt_version_check = "  --version-check    Prisili svježu online provjeru putem GitHub releases API-ja",

    // ── Upozorenja ─────────────────────────────────────────────
    .warn_persist_state = "Upozorenje: stanje se nije moglo sačuvati: {}",

    // ── Testni način ───────────────────────────────────────────
    .test_mode_msg = "Testni način: pokretanje zig jediničnih testova radi se putem 'zig build test'",

    // ── Ostalo ─────────────────────────────────────────────────
    .err_test_bin_run = "Greška: DIRTREE_TEST_BIN se nije mogao pokrenuti: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "Greška: čekanje na DIRTREE_TEST_BIN nije uspjelo (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "Greška pri iscrtavanju stabla: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--pomoc", .arg = .help },
        .{ .name = "--opis", .arg = .about },
        .{ .name = "--dubina", .arg = .depth },
        .{ .name = "--putanja", .arg = .path },
        .{ .name = "--jednostavno", .arg = .simple },
        .{ .name = "--ukraseno", .arg = .decorated },
        .{ .name = "--bez-ikona", .arg = .no_icons },
        .{ .name = "--bez-boje", .arg = .no_color },
        .{ .name = "--boja", .arg = .color },
        .{ .name = "--bez-upozorenja-o-napustenim", .arg = .no_orphan_warning },
        .{ .name = "--bez-biljeski", .arg = .no_notes },
        .{ .name = "--prikazi-biljeske", .arg = .show_notes },
        .{ .name = "--biljeske", .arg = .notes },
        .{ .name = "--vodec-biljeski", .arg = .note_leader },
        .{ .name = "--bez-hiperveza", .arg = .no_hyperlinks },
        .{ .name = "--hiperveze", .arg = .hyperlinks },
        .{ .name = "--zadano", .arg = .default },
        .{ .name = "--otvori", .arg = .open },
        .{ .name = "--zatvori", .arg = .close },
        .{ .name = "--prikazi", .arg = .show },
        .{ .name = "--sakrij", .arg = .hide },
        .{ .name = "--sortiraj", .arg = .sort },
        .{ .name = "--uzlazno", .arg = .asc },
        .{ .name = "--silazno", .arg = .desc },
        .{ .name = "--prikazi-skrivene", .arg = .show_hidden },
        .{ .name = "--prepisi-postavke", .arg = .rewrite_settings },
        .{ .name = "--konfiguracija", .arg = .config },
        .{ .name = "--testiraj", .arg = .@"test" },
        .{ .name = "--jezik", .arg = .lang },
        .{ .name = "--privremeno", .arg = .temporary },
        .{ .name = "--samo", .arg = .only },
        .{ .name = "zabiljezi", .arg = .annotate },
        .{ .name = "napustene-biljeske", .arg = .orphaned_notes },
        .{ .name = "ocisti-napustene-biljeske", .arg = .purge_orphaned_notes },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "STABLODIREKTORIJA_JEDNOSTAVNO", .var_id = .dirtree_simple },
        .{ .name = "STABLODIREKTORIJA_UKRASENO", .var_id = .dirtree_decorated },
        .{ .name = "STABLODIREKTORIJA_AUTO_JEDNOSTAVNO", .var_id = .dirtree_auto_simple },
        .{ .name = "PREUSMJEREN_STDOUT", .var_id = .piped_stdout },
        .{ .name = "STABLODIREKTORIJA_SAKRIJ_BILJESKE", .var_id = .dirtree_hide_notes },
        .{ .name = "STABLODIREKTORIJA_SCM_PROMJENE_OSTAJU_SKRIVENE_ILI_ZATVORENE", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
