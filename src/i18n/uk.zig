const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Текст довідки ──────────────────────────────────────────
    .help_title = "dirtree - Дерева каталогів зі станом для людей та LLM",
    .help_usage = "Використання: dirtree [ОПЦІЇ] [ШЛЯХ]",
    .help_options_header = "Опції:",
    .help_opt_help = "  -h, --help         Показати це повідомлення довідки",
    .help_opt_about = "  -a, --about        Показати детальний опис",
    .help_opt_depth = "  -d, --depth N      Встановити максимальну глибину (за замовчуванням: 4)",
    .help_opt_simple = "  --simple           Простий вивід дерева, зручний для LLM",
    .help_opt_decorated = "  --decorated        Примусовий оздоблений вивід (навіть при перенаправленні)",
    .help_opt_no_icons = "  --no-icons         Вимкнути піктограми (простий режим + оздоблений заголовок)",
    .help_opt_no_color = "  --no-color        Вимкнути ANSI-кольори та зберегти налаштування",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Вимкнути гіперпосилання OSC8 та зберегти налаштування",
    .help_opt_default = "  --default X        Зберегти стан за замовчуванням: opened|closed",
    .help_opt_open = "  -o, --open КАТ...  Відкрити один або кілька підкаталогів (повторюваний прапорець)",
    .help_opt_close = "  -c, --close КАТ... Закрити один або кілька підкаталогів (повторюваний прапорець)",
    .help_opt_show = "  --show ШЛЯХ...     Показати відносні шляхи; регулярні вирази як /шаблон/ або !/шаблон/",
    .help_opt_hide = "  --hide ШЛЯХ...     Сховати відносні шляхи; регулярні вирази як /шаблон/ або !/шаблон/ (повторюваний)",
    .help_opt_sort = "  --sort РЕЖИМ       Режим сортування: modified|alpha (за замовчуванням: modified)",
    .help_opt_asc = "  --asc              Сортування за зростанням",
    .help_opt_desc = "  --desc             Сортування за спаданням (за замовчуванням)",
    .help_opt_show_hidden = "  --show-hidden      Тимчасово показати шляхи, сховані через конфігурацію",
    .help_opt_rewrite_settings = "  --rewrite-settings Перезаписати файл стану поточними налаштуваннями",
    .help_opt_config = "  --config           Показати обчислену ефективну конфігурацію",
        .help_opt_test = "  --test             Запустити пов'язані тести",
    .help_opt_lang = "  --lang КОД         Встановити мову відображення (напр. en, de, fr, ja)",
    .help_regex_note = "Використовуйте /шаблон/ або !/шаблон/ з --open/--close/--show/--hide для правил регулярних виразів; інші аргументи обробляються як літерали.",
    .help_relative_note = "Шляхи для --show/--hide повинні бути відносними (без початкового '/').",
    .help_behavior_header = "Поведінка:",
    .help_behavior_text = "За замовчуванням, коли stdout не є TTY (перенаправлення), кольори/піктограми/гіперпосилання вимикаються, якщо не вказано --decorated.",
    .help_examples_header = "Приклади:",
    .help_example_1 = "  dirtree                       # Показати дерево поточного каталогу",
    .help_example_2 = "  dirtree -d 3                  # Встановити глибину 3 рівні",
    .help_example_3 = "  dirtree --sort alpha --asc    # Сортування за алфавітом за зростанням",

    // ── Текст «Про програму» ───────────────────────────────────
    .about_text = "Дерево каталогів зі станом (піктограми/кольори/посилання); --simple для LLM; зберігає .dirtree-state (default/open/close/show/hide); регулярні вирази через /шаблон/ або !/шаблон/; літерали повинні бути відносними; змінні середовища: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Фрагменти підрахунку схованих ──────────────────────────
    .hidden_dir_singular = "каталог",
    .hidden_dir_plural = "каталогів",
    .hidden_file_singular = "файл",
    .hidden_file_plural = "файлів",
    .hidden_and = " та ",
    .hidden_is_hidden = " сховано.",
    .hidden_are_hidden = " сховані.",
    .stats_shown = " показано",
    .stats_hidden = " приховано.",
    .stats_line_singular = "рядок",
    .stats_line_plural = "рядків",
    .stats_separator = "; ",

    // ── Повідомлення про помилки ────────────────────────────────
    .err_depth_requires_number = "Помилка: --depth потребує числовий аргумент",
    .err_sort_requires_mode = "Помилка: --sort потребує 'modified' або 'alpha'",
    .err_default_requires_value = "Помилка: --default потребує принаймні одне значення",
    .err_default_state_conflict = "Помилка: конфлікт стану --default",
    .err_default_accepts = "Помилка: --default приймає opened/closed",
    .err_open_requires_dir = "Помилка: --open потребує принаймні один каталог",
    .err_close_requires_dir = "Помилка: --close потребує принаймні один каталог",
    .err_show_requires_path = "Помилка: --show потребує принаймні один шлях",
    .err_hide_requires_path = "Помилка: --hide потребує принаймні один шлях",
    .err_unknown_option = "Невідома опція",
    .err_not_a_directory = "Помилка: '{s}' не є каталогом",
    .err_regex_empty = "Помилка: шаблон регулярного виразу не повинен бути порожнім",
    .err_paths_must_be_relative = "Помилка: шляхи {s} повинні бути відносними (без початкового '/'): {s}",
    .err_out_of_memory = "Недостатньо пам'яті",
    .err_regex_conflict_path = "Помилка: шлях '{s}' відповідає і шаблону відкриття, і шаблону закриття",
    .err_regex_conflict_open = "  шаблон відкриття: {s}",
    .err_regex_conflict_close = "  шаблон закриття: {s}",
    .err_unknown_lang = "Помилка: невідомий код мови '{s}'. Доступні: {s}",

    // ── Попередження ────────────────────────────────────────────
    .warn_persist_state = "Попередження: не вдалося зберегти стан: {}",

    // ── Режим тестування ────────────────────────────────────────
    .test_mode_msg = "Режим тестування: модульні тести Zig запускаються через 'zig build test'",

    // ── Інше ────────────────────────────────────────────────────
    .err_test_bin_run = "Помилка: не вдалося запустити DIRTREE_TEST_BIN: {s}",
    .err_test_bin_wait = "Помилка: не вдалося дочекатися завершення DIRTREE_TEST_BIN",
    .err_render_tree = "Помилка відображення дерева: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--dopomoha", .arg = .help },
        .{ .name = "--pro", .arg = .about },
        .{ .name = "--hlybyna", .arg = .depth },
        .{ .name = "--prostyy", .arg = .simple },
        .{ .name = "--ozdoblenyy", .arg = .decorated },
        .{ .name = "--bez-piktohram", .arg = .no_icons },
        .{ .name = "--bez-koloru", .arg = .no_color },
        .{ .name = "--bez-hiperposylan", .arg = .no_hyperlinks },
        .{ .name = "--za-zamovchuvannyam", .arg = .default },
        .{ .name = "--vidkryty", .arg = .open },
        .{ .name = "--zachynyty", .arg = .close },
        .{ .name = "--pokazaty", .arg = .show },
        .{ .name = "--skhovaty", .arg = .hide },
        .{ .name = "--sortuvannya", .arg = .sort },
        .{ .name = "--za-zrostannyam", .arg = .asc },
        .{ .name = "--za-spadannyam", .arg = .desc },
        .{ .name = "--pokazaty-skhovani", .arg = .show_hidden },
        .{ .name = "--perezapysaty-nalashtuvannya", .arg = .rewrite_settings },
        .{ .name = "--konfiguratsiya", .arg = .config },
                .{ .name = "--testuvaty", .arg = .@"test" },
        .{ .name = "--mova", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DEREVO_UK_PROSTYY", .var_id = .dirtree_simple },
        .{ .name = "DEREVO_UK_OZDOBLENYY", .var_id = .dirtree_decorated },
        .{ .name = "DEREVO_UK_AUTO_PROSTYY", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "DEREVO_UK_SCM_ZMINY_SKHOVANI_ABO_ZACHYNENI", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
