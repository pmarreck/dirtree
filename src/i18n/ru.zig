const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Текст справки ──────────────────────────────────────────
    .help_title = "dirtree - Деревья каталогов с состоянием для людей и LLM",
    .help_usage = "Использование: dirtree [ОПЦИИ] [ПУТЬ]",
    .help_options_header = "Опции:",
    .help_opt_help = "  -h, --help         Показать это сообщение справки",
    .help_opt_about = "  -a, --about        Показать подробное описание",
    .help_opt_depth = "  -d, --depth N      Установить максимальную глубину (по умолчанию: 4)",
    .help_opt_simple = "  --simple           Простой вывод дерева, удобный для LLM",
    .help_opt_decorated = "  --decorated        Принудительный декорированный вывод (даже при перенаправлении)",
    .help_opt_no_icons = "  --no-icons         Отключить иконки (простой режим + декорированный заголовок)",
    .help_opt_no_color = "  --no-color        Отключить ANSI-цвета и сохранить настройку",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Отключить гиперссылки OSC8 и сохранить настройку",
    .help_opt_default = "  --default X        Сохранить состояние по умолчанию: opened|closed",
    .help_opt_open = "  -o, --open КАТ...  Открыть один или несколько подкаталогов (повторяемый флаг)",
    .help_opt_close = "  -c, --close КАТ... Закрыть один или несколько подкаталогов (повторяемый флаг)",
    .help_opt_show = "  --show ПУТЬ...     Показать относительные пути; регулярные выражения как /шаблон/ или !/шаблон/",
    .help_opt_hide = "  --hide ПУТЬ...     Скрыть относительные пути; регулярные выражения как /шаблон/ или !/шаблон/ (повторяемый)",
    .help_opt_sort = "  --sort РЕЖИМ       Режим сортировки: modified|alpha (по умолчанию: modified)",
    .help_opt_asc = "  --asc              Сортировка по возрастанию",
    .help_opt_desc = "  --desc             Сортировка по убыванию (по умолчанию)",
    .help_opt_show_hidden = "  --show-hidden      Временно показать скрытые через конфигурацию пути",
    .help_opt_rewrite_settings = "  --rewrite-settings Перезаписать файл состояния текущими настройками",
    .help_opt_config = "  --config           Показать вычисленную эффективную конфигурацию",
        .help_opt_test = "  --test             Запустить связанные тесты",
    .help_opt_lang = "  --lang КОД         Установить язык отображения (напр. en, de, fr, ja)",
    .help_regex_note = "Используйте /шаблон/ или !/шаблон/ с --open/--close/--show/--hide для правил регулярных выражений; остальные аргументы обрабатываются как литералы.",
    .help_relative_note = "Пути для --show/--hide должны быть относительными (без ведущего '/').",
    .help_behavior_header = "Поведение:",
    .help_behavior_text = "По умолчанию, когда stdout не является TTY (перенаправление), цвета/иконки/гиперссылки отключаются, если не указан --decorated.",
    .help_examples_header = "Примеры:",
    .help_example_1 = "  dirtree                       # Показать дерево текущего каталога",
    .help_example_2 = "  dirtree -d 3                  # Установить глубину 3 уровня",
    .help_example_3 = "  dirtree --sort alpha --asc    # Сортировка по алфавиту по возрастанию",

    // ── Текст «О программе» ────────────────────────────────────
    .about_text = "Дерево каталогов с состоянием (иконки/цвета/ссылки); --simple для LLM; сохраняет .dirtree-state (default/open/close/show/hide); регулярные выражения через /шаблон/ или !/шаблон/; литералы должны быть относительными; переменные окружения: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Фрагменты подсчёта скрытых ─────────────────────────────
    .hidden_dir_singular = "каталог",
    .hidden_dir_plural = "каталогов",
    .hidden_file_singular = "файл",
    .hidden_file_plural = "файлов",
    .hidden_and = " и ",
    .hidden_is_hidden = " скрыт.",
    .hidden_are_hidden = " скрыты.",
    .stats_shown = " показано",
    .stats_hidden = " скрыто.",
    .stats_line_singular = "строка",
    .stats_line_plural = "строк",
    .stats_separator = "; ",

    // ── Сообщения об ошибках ────────────────────────────────────
    .err_depth_requires_number = "Ошибка: --depth требует числовой аргумент",
    .err_sort_requires_mode = "Ошибка: --sort требует 'modified' или 'alpha'",
    .err_default_requires_value = "Ошибка: --default требует хотя бы одно значение",
    .err_default_state_conflict = "Ошибка: конфликт состояния --default",
    .err_default_visibility_conflict = "Ошибка: конфликт видимости --default",
    .err_default_accepts = "Ошибка: --default принимает opened/closed/shown/hidden",
    .err_open_requires_dir = "Ошибка: --open требует хотя бы один каталог",
    .err_close_requires_dir = "Ошибка: --close требует хотя бы один каталог",
    .err_show_requires_path = "Ошибка: --show требует хотя бы один путь",
    .err_hide_requires_path = "Ошибка: --hide требует хотя бы один путь",
    .err_unknown_option = "Неизвестная опция",
    .err_not_a_directory = "Ошибка: '{s}' не является каталогом",
    .err_regex_empty = "Ошибка: шаблон регулярного выражения не должен быть пустым",
    .err_paths_must_be_relative = "Ошибка: пути {s} должны быть относительными (без ведущего '/'): {s}",
    .err_out_of_memory = "Недостаточно памяти",
    .err_regex_conflict_path = "Ошибка: путь '{s}' соответствует и шаблону открытия, и шаблону закрытия",
    .err_regex_conflict_open = "  шаблон открытия: {s}",
    .err_regex_conflict_close = "  шаблон закрытия: {s}",
    .err_unknown_lang = "Ошибка: неизвестный код языка '{s}'. Доступные: {s}",

    // ── Предупреждения ──────────────────────────────────────────
    .warn_persist_state = "Предупреждение: не удалось сохранить состояние: {}",

    // ── Режим тестирования ──────────────────────────────────────
    .test_mode_msg = "Режим тестирования: модульные тесты Zig запускаются через 'zig build test'",

    // ── Прочее ──────────────────────────────────────────────────
    .err_test_bin_run = "Ошибка: не удалось запустить DIRTREE_TEST_BIN: {s}",
    .err_test_bin_wait = "Ошибка: не удалось дождаться завершения DIRTREE_TEST_BIN",
    .err_render_tree = "Ошибка отрисовки дерева: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--pomoshch", .arg = .help },
        .{ .name = "--opisanie", .arg = .about },
        .{ .name = "--glubina", .arg = .depth },
        .{ .name = "--prostoy", .arg = .simple },
        .{ .name = "--ukrashennyy", .arg = .decorated },
        .{ .name = "--bez-ikonok", .arg = .no_icons },
        .{ .name = "--bez-tsveta", .arg = .no_color },
        .{ .name = "--bez-ssylok", .arg = .no_hyperlinks },
        .{ .name = "--po-umolchaniyu", .arg = .default },
        .{ .name = "--otkryt", .arg = .open },
        .{ .name = "--zakryt", .arg = .close },
        .{ .name = "--pokazat", .arg = .show },
        .{ .name = "--skryt", .arg = .hide },
        .{ .name = "--sortirovka", .arg = .sort },
        .{ .name = "--po-vozrastaniyu", .arg = .asc },
        .{ .name = "--po-ubyvaniyu", .arg = .desc },
        .{ .name = "--pokazat-skrytye", .arg = .show_hidden },
        .{ .name = "--perezapisat-nastroyki", .arg = .rewrite_settings },
        .{ .name = "--konfiguratsiya", .arg = .config },
                .{ .name = "--proverit", .arg = .@"test" },
        .{ .name = "--yazyk", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DEREVO_PROSTOY", .var_id = .dirtree_simple },
        .{ .name = "DEREVO_UKRASHENNYY", .var_id = .dirtree_decorated },
        .{ .name = "DEREVO_AUTO_PROSTOY", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "DEREVO_SCM_IZMENENIYA_SKRYTY_ILI_ZAKRYTY", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
