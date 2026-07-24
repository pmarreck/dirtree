const Strings = @import("strings.zig").Strings;
const CliAliasEntry = @import("cli_aliases.zig").CliAliasEntry;
const EnvAliasEntry = @import("cli_aliases.zig").EnvAliasEntry;
const LocaleAliases = @import("cli_aliases.zig").LocaleAliases;

pub const strings = Strings{
    // ── सहायता पाठ ──────────────────────────────────────────────
    .help_title = "dirtree - मनुष्यों और LLM के लिए स्थिति-संरक्षी निर्देशिका वृक्ष",
    .help_usage = "उपयोग: dirtree [विकल्प] [पथ]",
    .help_options_header = "विकल्प:",
    .help_opt_help = "  -h, --help         यह सहायता संदेश दिखाएँ",
    .help_opt_about = "  -a, --about        विस्तृत विवरण दिखाएँ",
    .help_opt_depth = "  -d, --depth N      अधिकतम गहराई निर्धारित करें (डिफ़ॉल्ट: 4)",
    .help_opt_temp = "  -t, --temp         केवल इस रन के लिए परिवर्तन लागू करें (सहेजा नहीं जाता)",
    .help_opt_persist = "  --persist, --save  इन सेटिंग्स को भी सहेजें (non-TTY और DIRTREE_TEMP को ओवरराइड करता है)",
    .help_opt_path = "  -p, --path PATH    PATH को रेंडर करें भले ही वह किसी फ़्लैग या उपकमांड जैसा दिखे",
    .help_opt_simple = "  --simple           सरल, LLM-अनुकूल स्थिति-संरक्षी वृक्ष आउटपुट करें",
    .help_opt_decorated = "  --decorated        सज्जित आउटपुट को बाध्य करें (पाइप होने पर भी)",
    .help_opt_no_icons = "  --no-icons         आइकन अक्षम करें (simple मोड + सज्जित हेडर)",
    .help_opt_no_color = "  --no-color        ANSI रंग चालू/बंद करें (सहेजा गया)",
    .help_opt_no_orphan_warning = "  --no-orphan-warning orphaned-notes चेतावनी को दबाएँ",
    .help_opt_notes = "  --no-notes/--show-notes इनलाइन टिप्पणियाँ छिपाएँ या दिखाएँ (डिफ़ॉल्ट रूप से छिपाने हेतु DIRTREE_HIDE_NOTES=1)",
    .help_opt_notes_mode = "  --notes MODE       टिप्पणी लेआउट: aligned (डिफ़ॉल्ट) या inline",
    .help_opt_notes_leader = "  --notes-leader     नामों से संरेखित टिप्पणियों तक धुँधली अग्रणी बिंदियाँ खींचें",
    .warn_orphaned_prefix = "टिप्पणी: ",
    .warn_orphaned_suffix = " एनोटेशन ऐसे पथों की ओर इंगित करते हैं जो अब मौजूद नहीं हैं। देखने हेतु 'orphaned-notes' या हटाने हेतु 'purge-orphaned-notes' चलाएँ।",
    .warn_negation_intro = "टिप्पणी: यहाँ एक निषेधित regex आपके अभिप्राय को उलट सकता है — !/PAT/ उल्टा मिलान करता है, और एक अग्रणी (?!...) lookahead भी एक निषेध है, अतः दोनों को मिलाने पर दोहरा निषेध हो जाता है:",
    .warn_negation_advice = "किसी एक पथ पर ध्यान केंद्रित करने हेतु {s} PATH को प्राथमिकता दें; धनात्मक फ़िल्टर हेतु {s} /PAT/ का उपयोग करें (show नियमों को hide पर वरीयता मिलती है)। ये नियम .dirtree-state में संरक्षित होते हैं, जो सादा पाठ है और जटिल या अतिव्यापी होने पर आप इसे हाथ से संपादित कर सकते हैं।",
    .help_opt_no_hyperlinks = "  --no-hyperlinks   OSC8 हाइपरलिंक चालू/बंद करें (सहेजा गया)",
    .help_opt_default = "  --default X        डिफ़ॉल्ट स्थिति सहेजें: opened|closed",
    .help_opt_open = "  -o, --open DIR...  एक या अधिक उपनिर्देशिकाएँ खोलें (और जोड़ने हेतु फ़्लैग दोहराएँ)",
    .help_opt_close = "  -c, --close DIR... एक या अधिक उपनिर्देशिकाएँ बंद करें (और जोड़ने हेतु फ़्लैग दोहराएँ)",
    .help_opt_show = "  --show PATH...     सापेक्ष पथ बलपूर्वक दिखाएँ; regex को /pattern/ या !/pattern/ के रूप में लपेटें",
    .help_opt_hide = "  --hide PATH...     सापेक्ष पथ छिपाएँ; regex को /pattern/ या !/pattern/ के रूप में लपेटें (दोहराने योग्य) (केवल कुछ पथ रखने हैं? --only का उपयोग करें)",
    .help_opt_sort = "  --sort MODE        क्रमबद्धन मोड: modified|alpha (डिफ़ॉल्ट: modified)",
    .help_opt_asc = "  --asc              आरोही क्रम में क्रमबद्ध करें",
    .help_opt_desc = "  --desc             अवरोही क्रम में क्रमबद्ध करें (डिफ़ॉल्ट)",
    .help_opt_show_hidden = "  --show-hidden      कॉन्फ़िग द्वारा छिपाए गए पथ अस्थायी रूप से दिखाएँ",
    .help_opt_rewrite_settings = "  --rewrite-settings वर्तमान सेटिंग्स का उपयोग करके स्थिति फ़ाइल पुनः लिखें",
    .help_opt_config = "  --config           गणना की गई प्रभावी कॉन्फ़िगरेशन दिखाएँ",
    .help_opt_test = "  --test             संबद्ध परीक्षण चलाएँ",
    .help_opt_lang = "  --lang CODE        प्रदर्शन भाषा निर्धारित करें (जैसे en, de, fr, ja)",
    .help_lang_available_label = "उपलब्ध भाषा कोड:",
    .help_regex_note = "regex नियम जोड़ने हेतु --open/--close/--show/--hide के साथ /pattern/ या !/pattern/ का उपयोग करें; अन्य तर्कों को अक्षरशः माना जाता है।",
    .help_relative_note = "--show/--hide को दिए गए पथ सापेक्ष होने चाहिए (कोई अग्रणी '/' नहीं)।",
    .help_behavior_header = "व्यवहार:",
    .help_behavior_text = "stdout एक टर्मिनल होने पर प्रस्तुति सेटिंग्स सहेजी जाती हैं; अन्यथा वे केवल वर्तमान आह्वान पर ही लागू होते हैं। डिफ़ॉल्ट रूप से, --open/--close/--show/--hide परिवर्तन हमेशा सहेजे जाते हैं। टर्मिनल आउटपुट के लिए रंग डिफ़ॉल्ट रूप से चालू है और अन्य आउटपुट के लिए बंद है। --temp या --persist/--save स्पष्ट रूप से इन बचत नियमों को ओवरराइड करता है।",
    .persistence_note_tty = "संदेश: {s}: सहेजा गया क्योंकि stdout एक टर्मिनल है; इसे केवल इस आह्वान पर लागू करने के लिए --temp का उपयोग करें।",
    .persistence_note_non_tty = "संदेश: {s}: सहेजा नहीं गया क्योंकि stdout एक टर्मिनल नहीं है; ओवरराइड करने के लिए --persist/--save का उपयोग करें।",
    .persistence_note_semantic = "संदेश: {s}: सहेजा गया क्योंकि साझा प्रोजेक्ट दृश्य में परिवर्तन डिफ़ॉल्ट रूप से सहेजे जाते हैं; उन्हें केवल इस आह्वान पर लागू करने के लिए --temp का उपयोग करें।",
    .persistence_note_env = "संदेश: {s}: सहेजा नहीं गया क्योंकि DIRTREE_TEMP=1; ओवरराइड करने के लिए --persist/--save का उपयोग करें।",
    .persistence_note_mute = "इस सूचनात्मक संदेश को दबाने के लिए DIRTREE_MUTE_PERSISTENCE_REASON=1 सेट करें।",
    .help_examples_header = "उदाहरण:",
    .help_example_1 = "  dirtree                       # वर्तमान निर्देशिका का वृक्ष दिखाएँ",
    .help_example_2 = "  dirtree -d 3                  # गहराई 3 स्तरों पर निर्धारित करें",
    .help_example_3 = "  dirtree --sort alpha --asc    # वर्णानुक्रम में आरोही क्रमबद्ध",
    .help_example_close_comment = "एक डायरेक्टरी संक्षिप्त करें (सहेजा गया)",
    .help_example_hide_comment = "रेगेक्स से मेल खाने वाली फ़ाइलें छिपाएँ",
    .help_example_only_comment = "एक सबट्री पर ध्यान दें, सहोदर छिपाएँ",
    .help_example_localized_comment = "स्थानीयकृत स्विच नाम भी काम करते हैं",

    // ── परिचय पाठ ─────────────────────────────────────────────
    .about_text = "स्थिति-संरक्षी निर्देशिका वृक्ष (आइकन/रंग/लिंक); LLM हेतु --simple; .dirtree-state सहेजता है (default/open/close/show/hide); /pattern/ या !/pattern/ के माध्यम से regex; अक्षरशः मान सापेक्ष होने चाहिए; env: DIRTREE_{SIMPLE,DECORATED,AUTO_SIMPLE}।",

    // ── गणना अंश ──────────────────────────────────
    .hidden_dir_singular = "निर्देशिका",
    .hidden_dir_plural = "निर्देशिकाएँ",
    .hidden_file_singular = "फ़ाइल",
    .hidden_file_plural = "फ़ाइलें",
    .hidden_and = " और ",
    .hidden_is_hidden = " छिपी हुई है।",
    .hidden_are_hidden = " छिपी हुई हैं।",
    .stats_shown = " दिखाई गईं",
    .stats_hidden = " छिपी हुईं।",
    .stats_line_singular = "पंक्ति",
    .stats_line_plural = "पंक्तियाँ",
    .stats_separator = "; ",

    .stats_scm_kept = " वर्तमान git/jj परिवर्तन-समुच्चय में होने के कारण छिपाया नहीं गया",
    // ── सहायता पाठ (नए फ़्लैग) ──────────────────────────────────
    .help_opt_max_lines = "  --max-lines N      बड़े आउटपुट की चेतावनी सीमा निर्धारित करें (डिफ़ॉल्ट: 500)",
    .help_opt_override_warning = "  --override-warning बड़े आउटपुट की चेतावनी को दबाएँ",
    .help_opt_only = "  --only PATH        किसी उपवृक्ष पर ध्यान केंद्रित करें, सहोदर निर्देशिकाओं को संकुचित करें (दोहराने योग्य)",
    .help_opt_html = "  --html [FILE]      स्वतंत्र HTML ट्री को FILE में लिखें (- = stdout; छोड़ें = ब्राउज़र में खोलें)",
    .help_opt_no_targets = "  --no-symlink-targets/--no-targets  सिमलिंक लक्ष्य छिपाएँ; --no-targets हाइपरलिंक भी हटाता है (पोर्टेबल आउटपुट)",

    // ── चेतावनी संदेश (बड़ा आउटपुट) ────────────────────────
    .warn_large_output_prefix = "चेतावनी: आउटपुट लगभग ~",
    .warn_large_output_mid = " पंक्तियाँ है (सीमा: ",
    .warn_large_output_suffix = ")। विचार करें: --depth N या --hide पैटर्न।",

    // ── त्रुटि संदेश ─────────────────────────────────────────
    .err_max_lines_requires_number = "त्रुटि: --max-lines को एक संख्यात्मक तर्क चाहिए (en: Error: --max-lines requires a numeric argument)",
    .err_only_requires_path = "त्रुटि: --only को एक पथ तर्क चाहिए (en: Error: --only requires a path argument)",
    .err_depth_requires_number = "त्रुटि: --depth को एक संख्यात्मक तर्क चाहिए (en: Error: --depth requires a numeric argument)",
    .err_path_requires_arg = "त्रुटि: --path को एक निर्देशिका तर्क चाहिए (en: Error: --path requires a directory argument)",
    .err_notes_requires_mode = "त्रुटि: --notes को 'aligned' या 'inline' चाहिए (en: Error: --notes requires 'aligned' or 'inline')",
    .err_sort_requires_mode = "त्रुटि: --sort को 'modified' या 'alpha' चाहिए (en: Error: --sort requires 'modified' or 'alpha')",
    .err_default_requires_value = "त्रुटि: --default को कम से कम एक मान चाहिए (en: Error: --default requires at least one value)",
    .err_default_state_conflict = "त्रुटि: --default स्थिति विरोध (en: Error: --default state conflict)",
    .err_default_accepts = "त्रुटि: --default opened/closed स्वीकार करता है (en: Error: --default accepts opened/closed)",
    .err_open_requires_dir = "त्रुटि: --open को कम से कम एक निर्देशिका चाहिए (en: Error: --open requires at least one directory)",
    .err_close_requires_dir = "त्रुटि: --close को कम से कम एक निर्देशिका चाहिए (en: Error: --close requires at least one directory)",
    .err_show_requires_path = "त्रुटि: --show को कम से कम एक पथ चाहिए (en: Error: --show requires at least one path)",
    .err_hide_requires_path = "त्रुटि: --hide को कम से कम एक पथ चाहिए (en: Error: --hide requires at least one path)",
    .err_unknown_option = "अज्ञात विकल्प (en: Unknown option)",
    .err_not_a_directory = "त्रुटि: '{s}' एक निर्देशिका नहीं है (en: Error: '{s}' is not a directory)",
    .err_regex_empty = "त्रुटि: regex पैटर्न खाली नहीं होना चाहिए (en: Error: regex pattern must not be empty)",
    .err_paths_must_be_relative = "त्रुटि: {s} पथ सापेक्ष होने चाहिए (कोई अग्रणी '/' नहीं): {s} (en: Error: {s} paths must be relative (no leading '/'): {s})",
    .err_out_of_memory = "स्मृति समाप्त (en: Out of memory)",
    .err_regex_conflict_path = "त्रुटि: पथ '{s}' open और close दोनों पैटर्न से मेल खाता है (en: Error: path '{s}' matches both open and close patterns)",
    .err_regex_conflict_open = "  open पैटर्न: {s} (en:   open pattern: {s})",
    .err_regex_conflict_close = "  close पैटर्न: {s} (en:   close pattern: {s})",
    .err_regex_invalid = "त्रुटि: अमान्य regex पैटर्न: {s} (en: Error: invalid regex pattern: {s})",
    .err_unknown_lang = "त्रुटि: अज्ञात भाषा कोड '{s}'। उपलब्ध: {s} (en: Error: unknown language code '{s}'. Available: {s})",
    .err_annotate_requires_path = "त्रुटि: annotate को एक पथ चाहिए (en: Error: annotate requires a path)",
    .err_annotate_requires_description = "त्रुटि: annotate को एक विवरण चाहिए (साफ़ करने हेतु \"\" का उपयोग करें) (en: Error: annotate requires a description (use \"\" to clear))",
    .err_annotate_multiline = "त्रुटि: एनोटेशन विवरण एक ही पंक्ति में होना चाहिए (en: Error: annotation description must be a single line)",
    .err_annotate_too_many_args = "त्रुटि: annotate ठीक दो स्थितिगत तर्क स्वीकार करता है: <path> <description> (en: Error: annotate accepts exactly two positional arguments: <path> <description>)",
    .help_opt_annotate = "  annotate PATH DESC किसी फ़ाइल या निर्देशिका के बारे में एक-पंक्ति टिप्पणी सहेजें (उपनाम: note; खाली DESC उसे साफ़ कर देता है)",
    .help_opt_orphaned_notes = "  orphaned-notes [DIR] ऐसी टिप्पणियाँ सूचीबद्ध करें जिनके लक्ष्य पथ अब मौजूद नहीं हैं",
    .help_opt_purge_orphaned_notes = "  purge-orphaned-notes [DIR] ऐसी टिप्पणियाँ हटाएँ जिनके लक्ष्य पथ अब मौजूद नहीं हैं",
    .help_subcommands =
    \\<annotate>
    \\उपयोग: dirtree annotate PATH DESC
    \\       dirtree note PATH DESC          (उपनाम)
    \\
    \\किसी फ़ाइल या निर्देशिका के बारे में एक-पंक्ति टिप्पणी सहेजें। टिप्पणी
    \\.dirtree-state में सहेजी जाती है और अगली बार वृक्ष प्रदर्शित होने पर PATH के पास दिखाई जाती है।
    \\
    \\तर्क:
    \\  PATH   फ़ाइल या निर्देशिका, वर्तमान निर्देशिका के सापेक्ष
    \\  DESC   टिप्पणी का पाठ; मौजूदा टिप्पणी साफ़ करने हेतु एक खाली स्ट्रिंग "" दें
    \\
    \\उदाहरण:
    \\  dirtree annotate src/main.zig "CLI प्रवेश बिंदु"
    \\  dirtree note docs "डिज़ाइन नोट्स यहाँ रहते हैं"
    \\  dirtree annotate README.md ""        # README.md की टिप्पणी साफ़ करें
    \\</annotate>
    \\<orphaned_notes>
    \\उपयोग: dirtree orphaned-notes [DIR]
    \\
    \\ऐसी टिप्पणियाँ सूचीबद्ध करें जिनका लक्ष्य पथ अब मौजूद नहीं है — उदाहरण के लिए किसी फ़ाइल का
    \\नाम बदलने, स्थानांतरित करने या हटाने के बाद। DIR डिफ़ॉल्ट रूप से वर्तमान निर्देशिका है।
    \\यह केवल-पठन है: कुछ भी नहीं बदला जाता। इन्हें हटाने हेतु purge-orphaned-notes का उपयोग करें।
    \\
    \\उदाहरण:
    \\  dirtree orphaned-notes
    \\  dirtree orphaned-notes src
    \\</orphaned_notes>
    \\<purge_orphaned_notes>
    \\उपयोग: dirtree purge-orphaned-notes [DIR]
    \\
    \\ऐसी टिप्पणियाँ हटाएँ जिनका लक्ष्य पथ अब मौजूद नहीं है। DIR डिफ़ॉल्ट रूप से
    \\वर्तमान निर्देशिका है। ठीक-ठीक क्या हटाया जाएगा उसका पूर्वावलोकन करने हेतु पहले
    \\orphaned-notes चलाएँ।
    \\
    \\उदाहरण:
    \\  dirtree purge-orphaned-notes
    \\  dirtree purge-orphaned-notes src
    \\</purge_orphaned_notes>
    ,
    .orphaned_header = "अनाथ टिप्पणियाँ (ऐसे पथ जो अब मौजूद नहीं हैं):",
    .orphaned_none = "कोई अनाथ टिप्पणी नहीं।",
    .purge_header = "अनाथ टिप्पणियाँ हटाई गईं:",
    .purge_none = "हटाने हेतु कोई अनाथ टिप्पणी नहीं।",
    .help_opt_version = "  --version          संस्करण दिखाएँ (ऑफ़लाइन; कैश की गई अपडेट-उपलब्ध सूचना पढ़ता है)",
    .help_opt_version_check = "  --version-check    GitHub releases API के विरुद्ध एक ताज़ा ऑनलाइन जाँच को बाध्य करें",

    // ── चेतावनियाँ ──────────────────────────────────────────────
    .warn_persist_state = "चेतावनी: स्थिति सहेजी नहीं जा सकी: {}",

    // ── परीक्षण मोड ──────────────────────────────────────────────
    .test_mode_msg = "परीक्षण मोड: zig यूनिट परीक्षण 'zig build test' के माध्यम से चलाए जाते हैं",

    // ── विविध ──────────────────────────────────────────────
    .err_test_bin_run = "त्रुटि: DIRTREE_TEST_BIN चलाया नहीं जा सका: {s} (en: Error: could not run DIRTREE_TEST_BIN: {s})",
    .err_test_bin_wait = "त्रुटि: DIRTREE_TEST_BIN की प्रतीक्षा नहीं की जा सकी (en: Error: could not wait for DIRTREE_TEST_BIN)",
    .err_render_tree = "वृक्ष रेंडर करने में त्रुटि: {} (en: Error rendering tree: {})",
};

pub const aliases = LocaleAliases{
    .cli = &[_]CliAliasEntry{
        .{ .name = "--sahayata", .arg = .help },
        .{ .name = "--bare-mein", .arg = .about },
        .{ .name = "--gehrai", .arg = .depth },
        .{ .name = "--saral", .arg = .simple },
        .{ .name = "--sajjit", .arg = .decorated },
        .{ .name = "--bina-aaikan", .arg = .no_icons },
        .{ .name = "--bina-rang", .arg = .no_color },
        .{ .name = "--rang", .arg = .color },
        .{ .name = "--bina-anaath-chetavani", .arg = .no_orphan_warning },
        .{ .name = "--bina-tippaniyan", .arg = .no_notes },
        .{ .name = "--tippaniyan-dikhayen", .arg = .show_notes },
        .{ .name = "--tippani-leaut", .arg = .notes },
        .{ .name = "--tippani-agrani", .arg = .note_leader },
        .{ .name = "--bina-hyperlink", .arg = .no_hyperlinks },
        .{ .name = "--kadi", .arg = .hyperlinks },
        .{ .name = "--default-sthiti", .arg = .default },
        .{ .name = "--kholen", .arg = .open },
        .{ .name = "--band-karen", .arg = .close },
        .{ .name = "--dikhayen", .arg = .show },
        .{ .name = "--chhipayen", .arg = .hide },
        .{ .name = "--kramabaddhan", .arg = .sort },
        .{ .name = "--aarohi", .arg = .asc },
        .{ .name = "--avarohi", .arg = .desc },
        .{ .name = "--chhipe-dikhayen", .arg = .show_hidden },
        .{ .name = "--setting-punah-likhen", .arg = .rewrite_settings },
        .{ .name = "--konfigareshan", .arg = .config },
        .{ .name = "--parikshan", .arg = .@"test" },
        .{ .name = "--bhasha", .arg = .lang },
        .{ .name = "--asthayi", .arg = .temporary },
        .{ .name = "--adhiktam-panktiyan", .arg = .max_lines },
        .{ .name = "--chetavani-andekha", .arg = .override_warning },
        .{ .name = "--keval", .arg = .only },
        .{ .name = "tippani-jodein", .arg = .annotate },
        .{ .name = "anaath-tippaniyan", .arg = .orphaned_notes },
        .{ .name = "anaath-tippaniyan-saaf-karen", .arg = .purge_orphaned_notes },
        .{ .name = "tippani", .arg = .annotate },
        .{ .name = "--sanskaran", .arg = .version },
        .{ .name = "--sanskaran-janch", .arg = .version_check },
    },
    .env = &[_]EnvAliasEntry{
        .{ .name = "DIRTREE_SARAL", .var_id = .dirtree_simple },
        .{ .name = "DIRTREE_SAJJIT", .var_id = .dirtree_decorated },
        .{ .name = "DIRTREE_SWACHALIT_SARAL", .var_id = .dirtree_auto_simple },
        .{ .name = "PAIP_STDOUT", .var_id = .piped_stdout },
        .{ .name = "DIRTREE_HIDE_NOTES_HI", .var_id = .dirtree_hide_notes },
        .{ .name = "DIRTREE_SCM_PARIVARTAN_CHHIPE_YA_BAND_RAHEN", .var_id = .dirtree_scm_changes_stay_hidden_or_closed },
    },
};
