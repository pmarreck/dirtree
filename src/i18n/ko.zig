const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── 도움말 텍스트 ──────────────────────────────────────────
    .help_title = "dirtree - 사람과 LLM을 위한 상태 기반 디렉토리 트리",
    .help_usage = "사용법: dirtree [옵션] [경로]",
    .help_options_header = "옵션:",
    .help_opt_help = "  -h, --help         이 도움말 메시지 표시",
    .help_opt_about = "  -a, --about        자세한 설명 표시",
    .help_opt_depth = "  -d, --depth N      최대 깊이 설정 (기본값: 4)",
    .help_opt_temp = "  -t, --temp         이번 실행에만 변경 적용 (저장 안 함)",
    .help_opt_persist = "  --persist, --save  이 설정도 저장합니다(non-TTY 및 DIRTREE_TEMP 재정의).",
    .help_opt_path = "  -p, --path PATH    플래그나 하위 명령처럼 보여도 PATH를 렌더링",
    .help_opt_simple = "  --simple           간단한 LLM 친화적 상태 트리 출력",
    .help_opt_decorated = "  --decorated        꾸며진 출력 강제 (파이프 시에도 유효)",
    .help_opt_no_icons = "  --no-icons         아이콘 비활성화 (간단 모드 + 꾸며진 헤더)",
    .help_opt_no_color = "  --no-color        ANSI 색상 켜기/끄기 (저장됨)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning 고아 주석 경고 숨기기",
    .help_opt_notes = "  --no-notes/--show-notes 인라인 주석 표시/숨김 (DIRTREE_HIDE_NOTES=1이면 기본 숨김)",
    .help_opt_notes_mode = "  --notes MODE       주석 레이아웃: aligned (기본값) 또는 inline",
    .help_opt_notes_leader = "  --notes-leader     이름에서 정렬된 주석까지 점선 안내선 표시",
    .warn_orphaned_prefix = "참고: ",
    .warn_orphaned_suffix = " 개의 주석이 존재하지 않는 경로를 가리킵니다. 'orphaned-notes'로 보거나 'purge-orphaned-notes'로 제거하세요.",
    .warn_negation_intro = "참고: 부정 정규식은 의도를 뒤집을 수 있습니다 — !/PAT/는 반대로 일치하고, 앞쪽 (?!...) 룩어헤드도 부정이므로 함께 쓰면 이중 부정이 됩니다:",
    .warn_negation_advice = "하나의 경로에 집중하려면 {s} PATH를, 긍정 필터에는 {s} /PAT/를 사용하세요(show 규칙이 hide보다 우선). 이 규칙들은 .dirtree-state에 저장되며, 복잡하거나 겹칠 때 직접 편집할 수 있는 일반 텍스트입니다.",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   OSC8 하이퍼링크 켜기/끄기 (저장됨)",
    .help_opt_default = "  --default X        기본 상태 저장: opened|closed",
    .help_opt_open = "  -o, --open DIR...  하나 이상의 하위 디렉토리 열기 (반복 지정 가능)",
    .help_opt_close = "  -c, --close DIR... 하나 이상의 하위 디렉토리 닫기 (반복 지정 가능)",
    .help_opt_show = "  --show PATH...     상대 경로 강제 표시; 정규식은 /pattern/ 또는 !/pattern/",
    .help_opt_hide = "  --hide PATH...     상대 경로 숨기기; 정규식은 /pattern/ 또는 !/pattern/ (반복 가능) (일부 경로만 유지? --only 사용)",
    .help_opt_sort = "  --sort MODE        정렬 모드: modified|alpha (기본값: modified)",
    .help_opt_asc = "  --asc              오름차순 정렬",
    .help_opt_desc = "  --desc             내림차순 정렬 (기본값)",
    .help_opt_show_hidden = "  --show-hidden      설정으로 숨겨진 경로를 임시로 표시",
    .help_opt_rewrite_settings = "  --rewrite-settings 현재 설정으로 상태 파일 다시 쓰기",
    .help_opt_config = "  --config           계산된 유효 구성 표시",
    .help_opt_test = "  --test             관련 테스트 실행",
    .help_opt_lang = "  --lang CODE        표시 언어 설정 (예: en, de, fr, ja)",
    .help_lang_available_label = "사용 가능한 언어 코드:",
    .help_regex_note = "--open/--close/--show/--hide와 함께 /pattern/ 또는 !/pattern/을 사용하여 정규식 규칙을 추가할 수 있습니다. 그 외의 인수는 리터럴로 처리됩니다.",
    .help_relative_note = "--show/--hide에 전달하는 경로는 상대 경로여야 합니다 (선행 '/' 불가).",
    .help_behavior_header = "동작:",
    .help_behavior_text = "프리젠테이션 설정은 stdout가 터미널일 때 저장됩니다. 그렇지 않으면 현재 호출에만 적용됩니다. 기본적으로 --open/--close/--show/--hide 변경 사항은 항상 저장됩니다. 색상은 기본적으로 터미널 출력에 대해 켜져 있고 다른 출력에 대해서는 꺼져 있습니다. --temp 또는 --persist/--save는 이러한 저장 규칙을 명시적으로 재정의합니다.",
    .persistence_note_tty = "메시지: {s}: stdout가 터미널이기 때문에 저장되었습니다. 이 호출에만 적용하려면 --temp를 사용하세요.",
    .persistence_note_non_tty = "메시지: {s}: stdout가 터미널이 아니기 때문에 저장되지 않았습니다. 재정의하려면 --persist/--save를 사용하세요.",
    .persistence_note_semantic = "메시지: {s}: 공유 프로젝트 보기에 대한 변경 사항이 기본적으로 저장되므로 저장되었습니다. 이 호출에만 적용하려면 --temp를 사용하세요.",
    .persistence_note_env = "메시지: {s}: DIRTREE_TEMP=1 때문에 저장되지 않았습니다. 재정의하려면 --persist/--save를 사용하세요.",
    .persistence_note_mute = "이 정보 메시지를 표시하지 않으려면 DIRTREE_MUTE_PERSISTENCE_REASON=1를 설정하십시오.",
    .help_examples_header = "사용 예:",
    .help_example_1 = "  dirtree                       # 현재 디렉토리의 트리 표시",
    .help_example_2 = "  dirtree -d 3                  # 깊이를 3단계로 설정",
    .help_example_3 = "  dirtree --sort alpha --asc    # 알파벳 오름차순 정렬",
    .help_example_close_comment = "디렉터리 접기 (저장됨)",
    .help_example_hide_comment = "정규식과 일치하는 파일 숨기기",
    .help_example_only_comment = "하나의 하위 트리에 집중하고 형제 숨기기",
    .help_example_localized_comment = "현지화된 옵션 이름도 작동합니다",

    // ── 소개 텍스트 ────────────────────────────────────────────
    .about_text = "상태 기반 디렉토리 트리 (아이콘/색상/링크); --simple로 LLM 친화적 출력; .dirtree-state에 영구 저장 (default/open/close/show/hide); 정규식은 /pattern/ 또는 !/pattern/; 리터럴은 상대 경로 필수; 환경변수: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}.",

    // ── 숨김 카운트 조각 ───────────────────────────────────────
    .hidden_dir_singular = "디렉토리",
    .hidden_dir_plural = "디렉토리",
    .hidden_file_singular = "파일",
    .hidden_file_plural = "파일",
    .hidden_and = "과 ",
    .hidden_is_hidden = "이 숨겨져 있습니다.",
    .hidden_are_hidden = "이 숨겨져 있습니다.",
    .stats_shown = " 표시됨",
    .stats_hidden = " 숨김.",
    .stats_line_singular = "줄",
    .stats_line_plural = "줄",
    .stats_separator = "; ",

    .stats_scm_kept = " 현재 git/jj 변경 집합에 포함되어 숨기지 않음",
    // ── 오류 메시지 ────────────────────────────────────────────
    .err_depth_requires_number = "오류: --depth에는 숫자 인수가 필요합니다 (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "오류: --path에는 디렉터리 인수가 필요합니다 (en: Error: --path requires a directory argument)",
    .help_opt_max_lines = "  --max-lines N      큰 출력 경고 임계값 설정 (기본값: 500)",
    .help_opt_override_warning = "  --override-warning 큰 출력 경고 숨기기",
    .help_opt_only = "  --only PATH        하위 트리에 집중하고 형제 디렉터리를 접기 (반복 가능)",
    .help_opt_html = "  --html [FILE]      독립적인 HTML 트리를 FILE에 저장 (- = stdout, 생략 = 브라우저에서 열기)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  심볼릭 링크 대상 숨기기; --no-targets는 하이퍼링크도 제거 (이식 가능한 출력)",

    .warn_large_output_prefix = "경고: 출력이 약 ~",
    .warn_large_output_mid = "줄 (임계값: ",
    .warn_large_output_suffix = "). 고려하세요: --depth N 또는 --hide 패턴.",
    .err_only_requires_path = "오류: --only에는 경로 인수가 필요합니다 (en: Error: --only requires a path argument)",
    .err_max_lines_requires_number = "오류: --max-lines에는 숫자 인수가 필요합니다 (en: Error: --max-lines requires a numeric argument)",
    .err_notes_requires_mode = "오류: --notes에는 'aligned' 또는 'inline'이 필요합니다 (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "오류: --sort에는 'modified' 또는 'alpha'가 필요합니다 (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "오류: --default에는 최소 하나의 값이 필요합니다 (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "오류: --default 상태 충돌 (en: Error: --default state conflict)",
    .err_default_accepts = "오류: --default는 opened/closed을 받습니다 (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "오류: --open에는 최소 하나의 디렉토리가 필요합니다 (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "오류: --close에는 최소 하나의 디렉토리가 필요합니다 (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "오류: --show에는 최소 하나의 경로가 필요합니다 (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "오류: --hide에는 최소 하나의 경로가 필요합니다 (en: Error: --hide requires at least one path)",
    .err_unknown_option = "알 수 없는 옵션 (en: Unknown option)",
    .err_not_a_directory = "오류: '{s}'은(는) 디렉토리가 아닙니다 (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "오류: 정규식 패턴은 비어 있을 수 없습니다 (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "오류: {s} 경로는 상대 경로여야 합니다 (선행 '/' 불가): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "메모리 부족 (en: Out of memory)",
    .err_regex_conflict_path = "오류: 경로 '{s}'이(가) open 패턴과 close 패턴 모두에 일치합니다 (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  open 패턴: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  close 패턴: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "오류: 잘못된 정규식 패턴: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "오류: 알 수 없는 언어 코드 '{s}'. 사용 가능: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "Error: annotate requires a path",
    .err_annotate_requires_description = "Error: annotate requires a description (use \"\" to clear)",
    .err_annotate_multiline = "Error: annotation description must be a single line",
    .err_annotate_too_many_args = "Error: annotate accepts exactly two positional arguments: <path> <description>",
    .help_opt_annotate = "  annotate PATH DESC 파일이나 디렉토리에 대한 한 줄 주석을 저장 (alias: note; 빈 DESC는 지웁니다)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] 존재하지 않는 경로의 주석 나열",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] 존재하지 않는 경로의 주석 제거",
    .help_subcommands =
    \\<annotate>
    \\사용법: dirtree annotate PATH DESC
    \\       dirtree note PATH DESC          (별칭)
    \\
    \\파일이나 디렉토리에 대한 한 줄 주석을 저장합니다. 주석은 .dirtree-state에
    \\저장되며, 다음번에 트리를 렌더링할 때 PATH 옆에 표시됩니다.
    \\
    \\인수:
    \\  PATH   현재 디렉토리를 기준으로 한 파일 또는 디렉토리
    \\  DESC   주석 텍스트; 기존 주석을 지우려면 빈 문자열 ""을 전달하세요
    \\
    \\사용 예:
    \\  dirtree annotate src/main.zig "CLI 진입점"
    \\  dirtree note docs "설계 노트는 여기에 있습니다"
    \\  dirtree annotate README.md ""        # README.md의 주석 지우기
    \\</annotate>
    \\<orphaned_notes>
    \\사용법: dirtree orphaned-notes [DIR]
    \\
    \\대상 경로가 더 이상 존재하지 않는 주석을 나열합니다 — 예를 들어 파일의
    \\이름을 바꾸거나, 옮기거나, 삭제한 후입니다. DIR의 기본값은 현재 디렉토리입니다.
    \\이 작업은 읽기 전용으로 아무것도 변경하지 않습니다. 제거하려면 purge-orphaned-notes를 사용하세요.
    \\
    \\사용 예:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\사용법: dirtree purge-orphaned-notes [DIR]
    \\
    \\대상 경로가 더 이상 존재하지 않는 주석을 제거합니다. DIR의 기본값은
    \\현재 디렉토리입니다. 무엇이 제거될지 정확히 미리 보려면 먼저
    \\orphaned-notes를 실행하세요.
    \\
    \\사용 예:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "고아 주석 (존재하지 않는 경로):",
    .orphaned_none = "고아 주석이 없습니다.",
    .purge_header = "고아 주석을 제거했습니다:",
    .purge_none = "제거할 고아 주석이 없습니다.",
    .help_opt_version = "  --version          Show version (offline; reads cached update-available notice)",
    .help_opt_version_check = "  --version-check    Force a fresh online check against the GitHub releases API",

    // ── 경고 메시지 ────────────────────────────────────────────
    .warn_persist_state = "경고: 상태를 저장할 수 없습니다: {}",

    // ── 테스트 모드 ────────────────────────────────────────────
    .test_mode_msg = "테스트 모드: Zig 유닛 테스트는 'zig build test'로 실행합니다",

    // ── 기타 ───────────────────────────────────────────────────
    .err_test_bin_run = "오류: DIRTREE_TEST_BIN을 실행할 수 없습니다: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "오류: DIRTREE_TEST_BIN 대기에 실패했습니다 (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "트리 렌더링 오류: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--dowum", .arg = .help },
        .{ .name = "--jeonbo", .arg = .about },
        .{ .name = "--gipgi", .arg = .depth },
        .{ .name = "--gyeongno", .arg = .path },
        .{ .name = "--gandanhan", .arg = .simple },
        .{ .name = "--jangsikin", .arg = .decorated },
        .{ .name = "--aikon-eopsi", .arg = .no_icons },
        .{ .name = "--saek-eopsi", .arg = .no_color },
        .{ .name = "--saek", .arg = .color },
        .{ .name = "--gou-gyeonggo-eopsi", .arg = .no_orphan_warning },
        .{ .name = "--juseok-eopsi", .arg = .no_notes },
        .{ .name = "--juseok-bogi", .arg = .show_notes },
        .{ .name = "--juseok-baechi", .arg = .notes },
        .{ .name = "--juseok-anseseon", .arg = .note_leader },
        .{ .name = "--link-eopsi", .arg = .no_hyperlinks },
        .{ .name = "--lingkeu", .arg = .hyperlinks },
        .{ .name = "--gichon", .arg = .default },
        .{ .name = "--yeolgi", .arg = .open },
        .{ .name = "--datgi", .arg = .close },
        .{ .name = "--bogi", .arg = .show },
        .{ .name = "--sumgigi", .arg = .hide },
        .{ .name = "--jeongnyeol", .arg = .sort },
        .{ .name = "--olimchason", .arg = .asc },
        .{ .name = "--naerimchason", .arg = .desc },
        .{ .name = "--sumgin-geo-bogi", .arg = .show_hidden },
        .{ .name = "--seoljeong-dasi-sseugi", .arg = .rewrite_settings },
        .{ .name = "--guseong", .arg = .config },
        .{ .name = "--teseuteu", .arg = .@"test" },
        .{ .name = "--eoneo", .arg = .lang },
        .{ .name = "--imsi", .arg = .temporary },
        .{ .name = "juseok", .arg = .annotate },
        .{ .name = "goa-juseok", .arg = .orphaned_notes },
        .{ .name = "goa-juseok-jeonggi", .arg = .purge_orphaned_notes },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DIRTREE_KO_SIMPLE", .var_id = .dirtree_simple },
        .{ .name = "DIRTREE_KO_DECORATED", .var_id = .dirtree_decorated },
        .{ .name = "DIRTREE_KO_AUTO_SIMPLE", .var_id = .dirtree_auto_simple },
        .{ .name = "PIPED_STDOUT", .var_id = .piped_stdout },
        .{ .name = "DIRTREE_KO_SCM_CHANGES_STAY_HIDDEN_OR_CLOSED", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
