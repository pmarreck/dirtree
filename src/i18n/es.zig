const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Texto de ayuda ──────────────────────────────────────────
    .help_title = "dirtree - \xc3\x81rboles de directorios con estado para humanos y LLMs",
    .help_usage = "Uso: dirtree [OPCIONES] [RUTA]",
    .help_options_header = "Opciones:",
    .help_opt_help = "  -h, --help         Mostrar este mensaje de ayuda",
    .help_opt_about = "  -a, --about        Mostrar descripci\xc3\xb3n detallada",
    .help_opt_depth = "  -d, --depth N      Establecer profundidad m\xc3\xa1xima (por defecto: 4)",
    .help_opt_simple = "  --simple           Salida simple, amigable para LLMs",
    .help_opt_decorated = "  --decorated        Forzar salida decorada (incluso en pipe)",
    .help_opt_no_icons = "  --no-icons         Desactivar iconos (modo simple + cabecera decorada)",
    .help_opt_no_color = "  --no-color        Desactivar colores ANSI y persistir preferencia",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Desactivar hiperenlaces OSC8 y persistir preferencia",
    .help_opt_default = "  --default X        Persistir estado por defecto: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Abrir uno o m\xc3\xa1s subdirectorios",
    .help_opt_close = "  -c, --close DIR... Cerrar uno o m\xc3\xa1s subdirectorios",
    .help_opt_show = "  --show RUTA...     Forzar mostrar rutas relativas; regex como /patr\xc3\xb3n/ o !/patr\xc3\xb3n/",
    .help_opt_hide = "  --hide RUTA...     Ocultar rutas relativas; regex como /patr\xc3\xb3n/ o !/patr\xc3\xb3n/",
    .help_opt_sort = "  --sort MODO        Modo de ordenaci\xc3\xb3n: modified|alpha (por defecto: modified)",
    .help_opt_asc = "  --asc              Orden ascendente",
    .help_opt_desc = "  --desc             Orden descendente (por defecto)",
    .help_opt_show_hidden = "  --show-hidden      Mostrar temporalmente rutas ocultas por configuraci\xc3\xb3n",
    .help_opt_rewrite_settings = "  --rewrite-settings Reescribir archivo de estado con ajustes actuales",
    .help_opt_config = "  --config           Mostrar la configuraci\xc3\xb3n efectiva calculada",
        .help_opt_test = "  --test             Ejecutar las pruebas asociadas",
    .help_opt_lang = "  --lang C\xc3\x93DIGO     Establecer idioma de visualizaci\xc3\xb3n (ej. en, de, fr, ja)",
    .help_regex_note = "Use /patr\xc3\xb3n/ o !/patr\xc3\xb3n/ con --open/--close/--show/--hide para reglas regex; otros argumentos se tratan como literales.",
    .help_relative_note = "Las rutas para --show/--hide deben ser relativas (sin '/' inicial).",
    .help_behavior_header = "Comportamiento:",
    .help_behavior_text = "Por defecto, cuando stdout no es un TTY (pipe), colores/iconos/hiperenlaces se desactivan salvo que se indique --decorated.",
    .help_examples_header = "Ejemplos:",
    .help_example_1 = "  dirtree                       # Mostrar \xc3\xa1rbol del directorio actual",
    .help_example_2 = "  dirtree -d 3                  # Profundidad limitada a 3 niveles",
    .help_example_3 = "  dirtree --sort alpha --asc    # Ordenado alfab\xc3\xa9ticamente ascendente",

    // ── Texto acerca de ──────────────────────────────────────────
    .about_text = "\xc3\x81rbol de directorios con estado (iconos/colores/enlaces); --simple para LLMs; persiste .dirtree-state (default/open/close/show/hide); regex v\xc3\xada /patr\xc3\xb3n/ o !/patr\xc3\xb3n/; los literales deben ser relativos; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Fragmentos de conteo oculto ─────────────────────────────
    .hidden_dir_singular = "directorio",
    .hidden_dir_plural = "directorios",
    .hidden_file_singular = "archivo",
    .hidden_file_plural = "archivos",
    .hidden_and = " y ",
    .hidden_is_hidden = " est\xc3\xa1 oculto.",
    .hidden_are_hidden = " est\xc3\xa1n ocultos.",
    .stats_shown = " mostrados",
    .stats_hidden = " ocultos.",
    .stats_line_singular = "línea",
    .stats_line_plural = "líneas",
    .stats_separator = "; ",

    // ── Mensajes de error ──────────────────────────────────────
    .err_depth_requires_number = "Error: --depth requiere un argumento num\xc3\xa9rico",
    .err_sort_requires_mode = "Error: --sort requiere 'modified' o 'alpha'",
    .err_default_requires_value = "Error: --default requiere al menos un valor",
    .err_default_state_conflict = "Error: conflicto de estado en --default",
    .err_default_accepts = "Error: --default acepta opened/closed",
    .err_open_requires_dir = "Error: --open requiere al menos un directorio",
    .err_close_requires_dir = "Error: --close requiere al menos un directorio",
    .err_show_requires_path = "Error: --show requiere al menos una ruta",
    .err_hide_requires_path = "Error: --hide requiere al menos una ruta",
    .err_unknown_option = "Opci\xc3\xb3n desconocida",
    .err_not_a_directory = "Error: '{s}' no es un directorio",
    .err_regex_empty = "Error: el patr\xc3\xb3n regex no debe estar vac\xc3\xado",
    .err_paths_must_be_relative = "Error: las rutas {s} deben ser relativas (sin '/' inicial): {s}",
    .err_out_of_memory = "Memoria insuficiente",
    .err_regex_conflict_path = "Error: la ruta '{s}' coincide con patrones open y close",
    .err_regex_conflict_open = "  patr\xc3\xb3n open: {s}",
    .err_regex_conflict_close = "  patr\xc3\xb3n close: {s}",
    .err_unknown_lang = "Error: c\xc3\xb3digo de idioma desconocido '{s}'. Disponibles: {s}",

    // ── Advertencias ──────────────────────────────────────────
    .warn_persist_state = "Advertencia: no se pudo persistir el estado: {}",

    // ── Modo de prueba ──────────────────────────────────────────
    .test_mode_msg = "Modo prueba: las pruebas unitarias de Zig se ejecutan con 'zig build test'",

    // ── Varios ──────────────────────────────────────────────────
    .err_test_bin_run = "Error: no se pudo ejecutar DIRTREE_TEST_BIN: {s}",
    .err_test_bin_wait = "Error: no se pudo esperar a DIRTREE_TEST_BIN",
    .err_render_tree = "Error al renderizar el \xc3\xa1rbol: {}",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--ayuda", .arg = .help },
        .{ .name = "--acerca", .arg = .about },
        .{ .name = "--profundidad", .arg = .depth },
        .{ .name = "--sencillo", .arg = .simple },
        .{ .name = "--decorado", .arg = .decorated },
        .{ .name = "--sin-iconos", .arg = .no_icons },
        .{ .name = "--sin-color", .arg = .no_color },
        .{ .name = "--sin-hiperenlaces", .arg = .no_hyperlinks },
        .{ .name = "--predeterminado", .arg = .default },
        .{ .name = "--abrir", .arg = .open },
        .{ .name = "--cerrar", .arg = .close },
        .{ .name = "--mostrar", .arg = .show },
        .{ .name = "--ocultar", .arg = .hide },
        .{ .name = "--ordenar", .arg = .sort },
        .{ .name = "--ascendente", .arg = .asc },
        .{ .name = "--descendente", .arg = .desc },
        .{ .name = "--mostrar-ocultos", .arg = .show_hidden },
        .{ .name = "--reescribir-ajustes", .arg = .rewrite_settings },
        .{ .name = "--configuracion", .arg = .config },
                .{ .name = "--probar", .arg = .@"test" },
        .{ .name = "--idioma", .arg = .lang },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "ARBOL_SIMPLE", .var_id = .dirtree_simple },
        .{ .name = "ARBOL_DECORADO", .var_id = .dirtree_decorated },
        .{ .name = "ARBOL_AUTO_SIMPLE", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "ARBOL_SCM_CAMBIOS_OCULTOS_O_CERRADOS", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
