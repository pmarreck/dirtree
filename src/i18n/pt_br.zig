const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── Texto de ajuda ──────────────────────────────────────────
    .help_title = "dirtree - \xc3\x81rvores de diret\xc3\xb3rios com estado para humanos e LLMs",
    .help_usage = "Uso: dirtree [OP\xc3\x87\xc3\x95ES] [CAMINHO]",
    .help_options_header = "Op\xc3\xa7\xc3\xb5es:",
    .help_opt_help = "  -h, --help         Mostrar esta mensagem de ajuda",
    .help_opt_about = "  -a, --about        Mostrar descri\xc3\xa7\xc3\xa3o detalhada",
    .help_opt_depth = "  -d, --depth N      Definir profundidade m\xc3\xa1xima (padr\xc3\xa3o: 4)",
    .help_opt_temp = "  -t, --temp         Aplicar alterações apenas nesta execução (não salvo)",
    .help_opt_path = "  -p, --path PATH    Renderizar PATH mesmo que pareça uma opção ou subcomando",
    .help_opt_simple = "  --simple           Sa\xc3\xadda simples, amig\xc3\xa1vel para LLMs",
    .help_opt_decorated = "  --decorated        For\xc3\xa7ar sa\xc3\xadda decorada (mesmo em pipe)",
    .help_opt_no_icons = "  --no-icons         Desativar \xc3\xadcones (modo simples + cabe\xc3\xa7alho decorado)",
    .help_opt_no_color = "  --no-color        Ativar/desativar cores ANSI (persistente)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning Suprimir o aviso de notas órfãs",
    .help_opt_notes = "  --no-notes/--show-notes Ocultar ou mostrar notas em linha (DIRTREE_HIDE_NOTES=1 oculta por padrão)",
    .help_opt_notes_mode = "  --notes MODE       Layout das notas: aligned (padrão) ou inline",
    .help_opt_notes_leader = "  --notes-leader     Desenhar pontos-guia dos nomes até as notas alinhadas",
    .warn_orphaned_prefix = "Nota: ",
    .warn_orphaned_suffix = " anotação(ões) apontam para caminhos que não existem mais. Execute 'orphaned-notes' para ver ou 'purge-orphaned-notes' para remover.",
    .warn_negation_intro = "nota: uma regex negada pode inverter sua intenção — !/PAT/ corresponde ao INVERSO, e um lookahead (?!...) inicial também é uma negação; combiná-los dupla-nega:",
    .warn_negation_advice = "Para focar em um caminho, use {s} PATH; para um filtro positivo, {s} /PAT/ (regras show têm prioridade sobre hide). Essas regras são salvas em .dirtree-state, texto puro que você pode editar à mão quando ficam complexas ou se sobrepõem.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   Ativar/desativar hyperlinks OSC8 (persistente)",
    .help_opt_default = "  --default X        Persistir estado padr\xc3\xa3o: opened|closed",
    .help_opt_open = "  -o, --open DIR...  Abrir um ou mais subdiret\xc3\xb3rios",
    .help_opt_close = "  -c, --close DIR... Fechar um ou mais subdiret\xc3\xb3rios",
    .help_opt_show = "  --show CAMINHO...  For\xc3\xa7ar exibi\xc3\xa7\xc3\xa3o de caminhos relativos; regex como /padr\xc3\xa3o/ ou !/padr\xc3\xa3o/",
    .help_opt_hide = "  --hide CAMINHO...  Esconder caminhos relativos; regex como /padr\xc3\xa3o/ ou !/padr\xc3\xa3o/ (manter só alguns caminhos? use --only)",
    .help_opt_sort = "  --sort MODO        Modo de ordena\xc3\xa7\xc3\xa3o: modified|alpha (padr\xc3\xa3o: modified)",
    .help_opt_asc = "  --asc              Ordem crescente",
    .help_opt_desc = "  --desc             Ordem decrescente (padr\xc3\xa3o)",
    .help_opt_show_hidden = "  --show-hidden      Exibir temporariamente caminhos escondidos pela configura\xc3\xa7\xc3\xa3o",
    .help_opt_rewrite_settings = "  --rewrite-settings Reescrever arquivo de estado com configura\xc3\xa7\xc3\xb5es atuais",
    .help_opt_config = "  --config           Mostrar a configura\xc3\xa7\xc3\xa3o efetiva calculada",
        .help_opt_test = "  --test             Executar os testes associados",
    .help_opt_lang = "  --lang C\xc3\x93DIGO     Definir idioma de exibi\xc3\xa7\xc3\xa3o (ex. en, de, fr, ja)",
    .help_lang_available_label = "Códigos de idioma disponíveis:",
    .help_regex_note = "Use /padr\xc3\xa3o/ ou !/padr\xc3\xa3o/ com --open/--close/--show/--hide para regras regex; outros argumentos s\xc3\xa3o tratados como literais.",
    .help_relative_note = "Caminhos fornecidos a --show/--hide devem ser relativos (sem '/' inicial).",
    .help_behavior_header = "Comportamento:",
    .help_behavior_text = "Por padr\xc3\xa3o, quando stdout n\xc3\xa3o \xc3\xa9 um TTY (pipe), cores/\xc3\xadcones/hiperlinks s\xc3\xa3o desativados a menos que --decorated seja especificado.",
    .help_examples_header = "Exemplos:",
    .help_example_1 = "  dirtree                       # Mostrar \xc3\xa1rvore do diret\xc3\xb3rio atual",
    .help_example_2 = "  dirtree -d 3                  # Profundidade limitada a 3 n\xc3\xadveis",
    .help_example_3 = "  dirtree --sort alpha --asc    # Ordenado alfabeticamente de forma crescente",
    .help_example_close_comment = "Recolher um diretório (persistente)",
    .help_example_hide_comment = "Ocultar arquivos que correspondem a uma regex",
    .help_example_only_comment = "Focar em uma subárvore, ocultar irmãos",
    .help_example_localized_comment = "Nomes de opções localizados também funcionam",

    // ── Texto sobre ──────────────────────────────────────────────
    .about_text = "\xc3\x81rvore de diret\xc3\xb3rios com estado (\xc3\xadcones/cores/links); --simple para LLMs; persiste .dirtree-state (default/open/close/show/hide); regex via /padr\xc3\xa3o/ ou !/padr\xc3\xa3o/; literais devem ser relativos; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── Fragmentos de contagem oculta ───────────────────────────
    .hidden_dir_singular = "diret\xc3\xb3rio",
    .hidden_dir_plural = "diret\xc3\xb3rios",
    .hidden_file_singular = "arquivo",
    .hidden_file_plural = "arquivos",
    .hidden_and = " e ",
    .hidden_is_hidden = " est\xc3\xa1 oculto.",
    .hidden_are_hidden = " est\xc3\xa3o ocultos.",
    .stats_shown = " exibidos",
    .stats_hidden = " ocultos.",
    .stats_line_singular = "linha",
    .stats_line_plural = "linhas",
    .stats_separator = "; ",

    .stats_scm_kept = " não ocultado(s) por estar(em) no changeset atual do git/jj",
    // ── Mensagens de erro ──────────────────────────────────────
    .err_depth_requires_number = "Erro: --depth requer um argumento num\xc3\xa9rico (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "Erro: --path requer um argumento de diretório (en: Error: --path requires a directory argument)",
    .help_opt_max_lines = "  --max-lines N      Definir o limite de aviso de saída grande (padrão: 500)",
    .help_opt_override_warning = "  --override-warning Suprimir o aviso de saída grande",
    .help_opt_only = "  --only PATH        Focar em uma subárvore, recolhendo os diretórios irmãos (repetível)",
    .help_opt_html = "  --html [FILE]      Gravar uma árvore HTML autônoma em FILE (- = stdout; omitir = abrir no navegador)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  Ocultar alvos de links simbólicos; --no-targets também remove hyperlinks (saída portável)",

    .warn_large_output_prefix = "Aviso: a saída tem ~",
    .warn_large_output_mid = " linhas (limite: ",
    .warn_large_output_suffix = "). Considere: --depth N ou padrões --hide.",
    .err_only_requires_path = "Erro: --only requer um argumento de caminho (en: Error: --only requires a path argument)",
    .err_max_lines_requires_number = "Erro: --max-lines requer um argumento num\\xc3\\xa9rico (en: Error: --max-lines requires a numeric argument)",
    .err_notes_requires_mode = "Erro: --notes requer 'aligned' ou 'inline' (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "Erro: --sort requer 'modified' ou 'alpha' (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "Erro: --default requer pelo menos um valor (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "Erro: conflito de estado em --default (en: Error: --default state conflict)",
    .err_default_accepts = "Erro: --default aceita opened/closed (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "Erro: --open requer pelo menos um diret\xc3\xb3rio (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "Erro: --close requer pelo menos um diret\xc3\xb3rio (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "Erro: --show requer pelo menos um caminho (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "Erro: --hide requer pelo menos um caminho (en: Error: --hide requires at least one path)",
    .err_unknown_option = "Op\xc3\xa7\xc3\xa3o desconhecida (en: Unknown option)",
    .err_not_a_directory = "Erro: '{s}' n\xc3\xa3o \xc3\xa9 um diret\xc3\xb3rio (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "Erro: o padr\xc3\xa3o regex n\xc3\xa3o deve estar vazio (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "Erro: os caminhos {s} devem ser relativos (sem '/' inicial): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "Mem\xc3\xb3ria insuficiente (en: Out of memory)",
    .err_regex_conflict_path = "Erro: o caminho '{s}' corresponde aos padr\xc3\xb5es open e close (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  padr\xc3\xa3o open: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  padr\xc3\xa3o close: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "Erro: padrão regex inválido: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "Erro: c\xc3\xb3digo de idioma desconhecido '{s}'. Dispon\xc3\xadveis: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Error: annotate requires a path",
    .err_annotate_requires_description = "Error: annotate requires a description (use \"\" to clear)",
    .err_annotate_multiline = "Error: annotation description must be a single line",
    .err_annotate_too_many_args = "Error: annotate accepts exactly two positional arguments: <path> <description>",
    .help_opt_annotate = "  annotate PATH DESC Persist a one-line note about a file or directory (alias: note; empty DESC clears)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] Listar notas cujos caminhos não existem mais",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] Remover notas cujos caminhos não existem mais",
    .help_subcommands =
    \\<annotate>
    \\Uso: dirtree annotate PATH DESC
    \\     dirtree note PATH DESC          (alias)
    \\
    \\Salva uma nota de uma linha sobre um arquivo ou diretório. A nota é salva
    \\em .dirtree-state e mostrada ao lado de PATH na próxima vez que a árvore
    \\for renderizada.
    \\
    \\Argumentos:
    \\  PATH   arquivo ou diretório, relativo ao diretório atual
    \\  DESC   o texto da nota; passe uma string vazia "" para limpar uma nota existente
    \\
    \\Exemplos:
    \\  dirtree annotate src/main.zig "Ponto de entrada da CLI"
    \\  dirtree note docs "as notas de design ficam aqui"
    \\  dirtree annotate README.md ""        # limpa a nota de README.md
    \\</annotate>
    \\<orphaned_notes>
    \\Uso: dirtree orphaned-notes [DIR]
    \\
    \\Lista notas cujo caminho de destino não existe mais — por exemplo, depois
    \\que um arquivo foi renomeado, movido ou excluído. DIR usa o diretório atual por padrão.
    \\É somente leitura: nada é alterado. Use purge-orphaned-notes para removê-las.
    \\
    \\Exemplos:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\Uso: dirtree purge-orphaned-notes [DIR]
    \\
    \\Remove notas cujo caminho de destino não existe mais. DIR usa o diretório
    \\atual por padrão. Execute orphaned-notes primeiro para pré-visualizar
    \\exatamente o que será removido.
    \\
    \\Exemplos:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "Notas órfãs (caminhos que não existem mais):",
    .orphaned_none = "Nenhuma nota órfã.",
    .purge_header = "Notas órfãs removidas:",
    .purge_none = "Nenhuma nota órfã para remover.",
    .help_opt_version = "  --version          Show version (offline; reads cached update-available notice)",
    .help_opt_version_check = "  --version-check    Force a fresh online check against the GitHub releases API",

    // ── Avisos ──────────────────────────────────────────────────
    .warn_persist_state = "Aviso: n\xc3\xa3o foi poss\xc3\xadvel persistir o estado: {}",

    // ── Modo de teste ──────────────────────────────────────────
    .test_mode_msg = "Modo teste: os testes unit\xc3\xa1rios Zig s\xc3\xa3o executados com 'zig build test'",

    // ── Diversos ──────────────────────────────────────────────────
    .err_test_bin_run = "Erro: n\xc3\xa3o foi poss\xc3\xadvel executar DIRTREE_TEST_BIN: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "Erro: n\xc3\xa3o foi poss\xc3\xadvel aguardar DIRTREE_TEST_BIN (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "Erro ao renderizar a \xc3\xa1rvore: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--ajuda", .arg = .help },
        .{ .name = "--sobre", .arg = .about },
        .{ .name = "--profundidade", .arg = .depth },
        .{ .name = "--caminho", .arg = .path },
        .{ .name = "--simples", .arg = .simple },
        .{ .name = "--enfeitado", .arg = .decorated },
        .{ .name = "--sem-icones", .arg = .no_icons },
        .{ .name = "--sem-cor", .arg = .no_color },
        .{ .name = "--cor", .arg = .color },
        .{ .name = "--sem-aviso-orfaos", .arg = .no_orphan_warning },
        .{ .name = "--sem-notas", .arg = .no_notes },
        .{ .name = "--mostrar-notas", .arg = .show_notes },
        .{ .name = "--layout-notas", .arg = .notes },
        .{ .name = "--pontos-guia-notas", .arg = .note_leader },
        .{ .name = "--sem-hiperlinks", .arg = .no_hyperlinks },
        .{ .name = "--links", .arg = .hyperlinks },
        .{ .name = "--padrao", .arg = .default },
        .{ .name = "--expandir", .arg = .open },
        .{ .name = "--fechar", .arg = .close },
        .{ .name = "--exibir", .arg = .show },
        .{ .name = "--esconder", .arg = .hide },
        .{ .name = "--classificar", .arg = .sort },
        .{ .name = "--subindo", .arg = .asc },
        .{ .name = "--descendo", .arg = .desc },
        .{ .name = "--exibir-escondidos", .arg = .show_hidden },
        .{ .name = "--reescrever-configuracoes", .arg = .rewrite_settings },
        .{ .name = "--configuracao", .arg = .config },
                .{ .name = "--testar", .arg = .@"test" },
        .{ .name = "--linguagem", .arg = .lang },
        .{ .name = "--temporario", .arg = .temporary },
        .{ .name = "nota", .arg = .annotate },
        .{ .name = "notas-orfas", .arg = .orphaned_notes },
        .{ .name = "limpar-notas-orfas", .arg = .purge_orphaned_notes },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "ARVORE_SIMPLES", .var_id = .dirtree_simple },
        .{ .name = "ARVORE_ENFEITADO", .var_id = .dirtree_decorated },
        .{ .name = "ARVORE_AUTO_SIMPLES", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "ARVORE_SCM_MUDANCAS_OCULTAS_OU_FECHADAS", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
