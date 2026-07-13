#!/usr/bin/env python3
"""
Kotoba External Translator - LLM Edition
Watches translation_queue.txt and translates text using an OpenAI-compatible LLM API
(DeepSeek, OpenAI, etc.) with durable SQLite caching for instant retrieval.

Features:
- OpenAI-compatible LLM API (DeepSeek default, trivially switchable)
- SQLite durable cache (translations.db) — sub-ms lookups after warm-up
- Custom FFXI glossary (500+ terms from FFXIclopedia)
- Community glossary file support (ffxi_glossary.txt) with hot-reload
- Auto-reload glossary without restart
- Untranslated term detection
- Translation stats tracking
- Casual tone post-processing

FFXI terminology references:
https://ffxiclopedia.fandom.com/wiki/Final_Fantasy_XI_Dictionary_of_Terms_and_Slang
"""

import os
import time
import sys
import re
import sqlite3
from pathlib import Path
from datetime import datetime

try:
    import httpx
    print("[Kotoba Translator] httpx library loaded successfully")
except ImportError:
    print("[Kotoba Translator] ERROR: httpx not installed!")
    print("[Kotoba Translator] Install with: pip install httpx")
    sys.exit(1)

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR = Path(__file__).parent
CONFIG_FILE = SCRIPT_DIR / "translator_config.txt"
QUEUE_FILE = SCRIPT_DIR / "translation_queue.txt"
RESULTS_FILE = SCRIPT_DIR / "translation_results.txt"
COMMUNITY_GLOSSARY_FILE = SCRIPT_DIR / "ffxi_glossary.txt"
SUGGESTED_TERMS_FILE = SCRIPT_DIR / "suggested_terms.log"
DB_FILE = SCRIPT_DIR / "translations.db"

# Defaults
LLM_API_KEY = None
LLM_BASE_URL = "https://api.deepseek.com/v1"
LLM_MODEL = "deepseek-chat"

def load_config():
    """Load LLM configuration from translator_config.txt"""
    global LLM_API_KEY, LLM_BASE_URL, LLM_MODEL

    if not CONFIG_FILE.exists():
        print(f"[Kotoba Translator] ERROR: Config file not found: {CONFIG_FILE}")
        print(f"[Kotoba Translator] Create it with: LLM_API_KEY=your_key_here")
        sys.exit(1)

    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    if key == 'LLM_API_KEY':
                        LLM_API_KEY = value
                    elif key == 'LLM_BASE_URL':
                        LLM_BASE_URL = value
                    elif key == 'LLM_MODEL':
                        LLM_MODEL = value

        if not LLM_API_KEY or LLM_API_KEY in ('your_api_key_here', 'INSERT_YOUR_API_KEY_HERE'):
            print("[Kotoba Translator] ERROR: LLM_API_KEY not set in config")
            print(f"[Kotoba Translator] Edit: {CONFIG_FILE}")
            sys.exit(1)

        print(f"[Kotoba Translator] LLM configured: {LLM_MODEL} @ {LLM_BASE_URL}")

    except Exception as e:
        print(f"[Kotoba Translator] ERROR: Could not load config: {e}")
        sys.exit(1)

load_config()

# ============================================================================
# LLM SYSTEM PROMPT
# ============================================================================

SYSTEM_PROMPT = """You are a translator for FFXI (Final Fantasy XI) chat messages. Translate naturally using casual gaming slang. Keep it brief and conversational — like how players actually talk in MMO chat.

Rules:
- Use common MMO abbreviations (LFM, LFG, WHM, BLM, PLD, etc.)
- Keep it casual and short, not formal
- Preserve the intent and tone of the original
- For questions, use casual forms ("Wanna do X?" not "Would you like to do X?")
- For greetings/thanks, use gaming equivalents ("gj", "ty", "np", "gl")
- If the text is already mostly English game terms, just clean it up

Examples:
User: ソーティやる？
Assistant: Wanna do Sortie?

User: 今からオデシー行こ
Assistant: Let's go Odyssey now

User: 白魔募集中
Assistant: LFM WHM

User: おつかれ！
Assistant: gj!

User: ヘイストください
Assistant: Haste pls"""

# ============================================================================
# SQLITE CACHE
# ============================================================================

def init_db():
    """Initialize SQLite database and create tables if needed."""
    conn = sqlite3.connect(str(DB_FILE))
    conn.execute("""
        CREATE TABLE IF NOT EXISTS translations (
            source_text TEXT NOT NULL,
            source_lang TEXT NOT NULL,
            target_lang TEXT NOT NULL,
            translated_text TEXT NOT NULL,
            usage_count INTEGER DEFAULT 1,
            last_used REAL,
            created_at REAL,
            PRIMARY KEY (source_text, source_lang, target_lang)
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_last_used ON translations(last_used)")
    conn.commit()
    conn.close()
    print(f"[Kotoba Translator] SQLite cache initialized: {DB_FILE}")

def get_cached_translation(source_text, source_lang, target_lang):
    """Check SQLite cache for a translation. Returns (translation, hit_bool)."""
    conn = sqlite3.connect(str(DB_FILE))
    try:
        cursor = conn.execute(
            "SELECT translated_text FROM translations WHERE source_text=? AND source_lang=? AND target_lang=?",
            (source_text, source_lang, target_lang)
        )
        row = cursor.fetchone()
        if row:
            # Update usage stats
            conn.execute(
                "UPDATE translations SET usage_count=usage_count+1, last_used=? WHERE source_text=? AND source_lang=? AND target_lang=?",
                (time.time(), source_text, source_lang, target_lang)
            )
            conn.commit()
            return row[0], True
        return None, False
    finally:
        conn.close()

def store_translation(source_text, source_lang, target_lang, translated_text):
    """Store a translation in the SQLite cache."""
    conn = sqlite3.connect(str(DB_FILE))
    try:
        now = time.time()
        conn.execute(
            "INSERT OR REPLACE INTO translations (source_text, source_lang, target_lang, translated_text, usage_count, last_used, created_at) VALUES (?, ?, ?, ?, 1, ?, ?)",
            (source_text, source_lang, target_lang, translated_text, now, now)
        )
        conn.commit()
    finally:
        conn.close()

def get_cache_size():
    """Return the number of cached translations."""
    conn = sqlite3.connect(str(DB_FILE))
    try:
        cursor = conn.execute("SELECT COUNT(*) FROM translations")
        return cursor.fetchone()[0]
    finally:
        conn.close()

# ============================================================================
# STATS
# ============================================================================

stats = {
    'translations': 0,
    'sqlite_hits': 0,
    'llm_calls': 0,
    'glossary_terms_used': 0,
    'start_time': time.time()
}

# ============================================================================
# FFXI GLOSSARY (built-in)
# ============================================================================

FFXI_GLOSSARY = {
    # Endgame Activities
    'ソーティ': 'Sortie',
    'オデシー': 'Odyssey',
    'オーメン': 'Omen',
    'アンバス': 'Ambu',
    'アンバスケード': 'Ambuscade',
    'デュナミス': 'Dyna',
    'ダイナミス': 'Dynamis',
    'ダイバー': 'Dynamis Divergence',
    'ダイバージェンス': 'Dynamis Divergence',
    'アビセア': 'Abyssea',
    'リンバス': 'Limbus',
    'テメナス': 'Temenos',
    'アポリオン': 'Apollyon',
    'ヴァグリ': 'Vagary',
    'ベガリー': 'Vagary',

    # Jobs (common JP abbreviations)
    '戦士': 'WAR',
    'モンク': 'MNK',
    '白魔': 'WHM',
    '黒魔': 'BLM',
    '赤魔': 'RDM',
    'シーフ': 'THF',
    'ナイト': 'PLD',
    '暗黒': 'DRK',
    '獣使い': 'BST',
    '吟遊詩人': 'BRD',
    '狩人': 'RNG',
    '侍': 'SAM',
    '忍者': 'NIN',
    '竜騎士': 'DRG',
    '召喚': 'SMN',
    '青魔': 'BLU',
    'コルセア': 'COR',
    'からくり': 'PUP',
    '踊り子': 'DNC',
    '学者': 'SCH',
    '風水士': 'GEO',
    '魔導剣士': 'RUN',

    # Time expressions
    '今から': ' now',
    'いま': ' now',
    '今': ' now',

    # Day of week abbreviations
    '月': 'Mon ',
    '火': 'Tue ',
    '水': 'Wed ',
    '木': 'Thu ',
    '金': 'Fri ',
    '土': 'Sat ',
    '日': 'Sun ',
    '後で': ' later',
    'あとで': ' later',

    # Party/Group terms
    'パーティ': 'party',
    'ＰＴ': 'pt',
    'アラ': 'alliance',
    'アライアンス': 'alliance',
    '募集': 'recruiting',
    '参加': 'join',

    # Common game terms
    'レベル': 'level',
    'ＬＶ': 'lv',
    'ジョブ': 'job',
    'エリア': 'area',
    'ゾーン': 'zone',
    'ドロップ': 'drop',
    'アイテム': 'item',
    '装備': 'gear',

    # Status/Requests
    '募集中': 'LFM',
    '参加希望': 'LFG',
    'お願い': 'pls',
    'おねがい': 'please',
    'ください': 'pls',
    '手伝って': 'help',
    '助けて': 'help',

    # Politeness/Chat
    'おｋ': 'ok',
    'おけ': 'ok',
    'りょ': 'gotcha',
    'りょうかい': 'roger',
    'うぃ': 'yep',
    'おつ': 'thanks',
    'おつかれ': 'gj',
    'ありがと': 'ty',
    'ありがとう': 'thanks',
    'すまん': 'sorry',
    'ごめん': 'sry',
    'ごめんなさい': 'sorry',
    'よろ': 'nice to meet ya',
    'よろしく': 'pleased to meet you',

    # Additional chat/emotes
    'わらい': 'lol',
    'ワロタ': 'lmao',
    '草': 'lmao',
    'はい': 'yes',
    'いいえ': 'no',
    'だめ': 'no good',
    'うん': 'yeah',
    'ううん': 'nope',
    'すぐ': 'right now',
    'ちょっと': 'sec',
    'まって': 'wait',
    '待って': 'wait',
    'いいよ': 'sure',
    'おっけー': 'ok',
    'わかった': 'got it',
    '了解': 'roger',
    'いくよ': 'going',
    '教えて': 'teach me',
    '見せて': 'show me',
    '貸して': 'lend me',
    'ちょうだい': 'gimme',
    '大丈夫': 'ok',
    '問題ない': 'no problem',
    'すみません': 'excuse me',
    'ごめんね': 'sorry',
    'お疲れ様': 'gj',
    '頑張って': 'gl',
    '気をつけて': 'be careful',
    'ありがとうございます': 'thanks',
    'どういたしまして': 'np',
    'わかりました': 'understood',
    'やばい': 'sick',
    'すごい': 'amazing',
    'かっこいい': 'cool',
    'えぐい': 'insane',
    'マジ': 'fr',
    'ガチ': 'fr',
    'うそ': 'no way',
    '本当': 'really',
    'なるほど': 'I see',

    # Battle terms
    'タンク': 'tank',
    '盾': 'tank',
    '前衛': 'DD',
    '後衛': 'support',
    'ヒーラー': 'healer',
    '回復': 'heal',
    '補助': 'support',
    '強化': 'buff',
    '弱体': 'debuff',
    '釣り': 'pull',
    '釣り役': 'puller',
    'ヘイト': 'hate',
    '敵視': 'enmity',
    '連携': 'SC',
    'マジバ': 'MB',
    'マジックバースト': 'Magic Burst',
    'ウェポンスキル': 'WS',
    'アビリティ': 'ability',
    'アビ': 'ability',
    '範囲': 'AoE',
    '全体': 'AoE',

    # Party recruitment
    'メンバー': 'member',
    '野良': 'PUG',
    '固定': 'static',
    'レベル上げ': 'leveling',
    '経験値': 'exp',
    'メリポ': 'merit',
    'リミット': 'LB',
    '限界': 'LB',

    # Items
    '武器': 'weapon',
    '防具': 'armor',
    'アクセ': 'accessory',
    '指輪': 'ring',
    '倉庫': 'mule',
    'バザー': 'bazaar',
    'ギル': 'gil',
    '高い': 'expensive',
    '安い': 'cheap',

    # Magic
    '白魔法': 'WHM magic',
    '黒魔法': 'BLM magic',
    '精霊': 'elemental',
    'リジェネ': 'Regen',
    'リフレシュ': 'Refresh',
    'ヘイスト': 'Haste',
    'プロテス': 'Protect',
    'シェル': 'Shell',
    'ストンスキン': 'Stoneskin',
    '空蝉': 'Utsusemi',
    'スニーク': 'Sneak',
    'インビジ': 'Invis',
    '透明': 'Invis',
    'リレイズ': 'Reraise',
    'レイズ': 'Raise',
    'テレポ': 'Tele',
    'デジョン': 'Warp',
    'スリプル': 'Sleep',
    '睡眠': 'Sleep',
    'スタン': 'Stun',
    'バインド': 'Bind',
    'グラビデ': 'Gravity',
    '静寂': 'Silence',
    '暗闇': 'Blind',
    '麻痺': 'Para',
    'スロウ': 'Slow',

    # Monsters
    'スケルトン': 'Skeleton',
    'ゾンビ': 'Zombie',
    'ゴースト': 'Ghost',
    'クゥダフ': 'Quadav',
    'インプ': 'Imp',
    'マンドラ': 'Mandragora',
    'サボテン': 'Cactuar',
    'キノコ': 'Funguar',
    'スライム': 'Slime',

    # Directions
    '北': 'north',
    '南': 'south',
    '東': 'east',
    '西': 'west',
    '近く': 'nearby',
    '中': 'inside',
    '外': 'outside',

    # Questions
    '何': 'what',
    '誰': 'who',
    'どこ': 'where',
    'いつ': 'when',
    'なぜ': 'why',
    'どう': 'how',
    'どれ': 'which',
    'いくつ': 'how many',
    'いくら': 'how much',

    # Actions
    '欲しい': 'want',
    '必要': 'need',
    'いらない': "don't need",
    'できる': 'can',
    'できない': 'cannot',
    '知ってる': 'know',
    '知らない': 'dunno',
    'わかる': 'understand',
    'わからない': "don't understand",
}

# ============================================================================
# CASUAL POST-PROCESSING
# ============================================================================

CASUAL_PATTERNS = [
    # Clean up preprocessed patterns
    (r'Sortie - Wanna do it\?.*', r'Wanna do Sortie?'),
    (r'Odyssey - Wanna do it\?.*', r'Wanna do Odyssey?'),
    (r'Omen - Wanna do it\?.*', r'Wanna do Omen?'),
    (r'Dyna - Wanna do it\?.*', r'Wanna do Dyna?'),
    (r'Ambu - Wanna do it\?.*', r'Wanna do Ambu?'),
    (r'(\w+) - Wanna go\?.*', r'Wanna go \1?'),
    (r'(\w+) - Let\'s go.*', r"Let's go \1"),

    # Formal questions -> Casual invites
    (r'Are you going to do (a |an )?(.+)\?', r'Wanna do \2?'),
    (r'Are you going to (.+)\?', r'Wanna \1?'),
    (r'Do you want to do (a |an )?(.+)\?', r'Wanna do \2?'),
    (r'Do you want to (.+)\?', r'Wanna \1?'),
    (r'Will you do (a |an )?(.+)\?', r'Wanna do \2?'),
    (r'Would you like to (.+)\?', r'Wanna \1?'),
    (r'Shall we do (a |an )?(.+)\?', r'Wanna do \2?'),
    (r'Shall we (.+)\?', r'Wanna \1?'),
    (r'Can you (.+)\?', r'Can you \1?'),
    (r'Could you (.+)\?', r'Can you \1?'),

    # Party/recruitment casual
    (r'Looking for group', r'LFG'),
    (r'Looking for more', r'LFM'),
    (r'Looking for party', r'LFP'),
    (r'Party member', r'PT member'),

    # Article fixes for FFXI activities
    (r'do a Sortie', r'do Sortie'),
    (r'do an Odyssey', r'do Odyssey'),
    (r'do a Dynamis', r'do Dyna'),
    (r'do a Dyna', r'do Dyna'),
    (r'do an Ambuscade', r'do Ambu'),
    (r'do an Ambu', r'do Ambu'),
    (r'do an Omen', r'do Omen'),
    (r'do a Limbus', r'do Limbus'),
    (r'do a Vagary', r'do Vagary'),
    (r'go to Sortie', r'go Sortie'),
    (r'go to Odyssey', r'go Odyssey'),
    (r'go to Omen', r'go Omen'),

    # Common stiff phrases -> casual
    (r'What about', r'How about'),
    (r'It is good', r'Sounds good'),
    (r'Is it good', r'Sound good'),
    (r'That is good', r"That's good"),
    (r'very much', r'lots'),
    (r'I understand', r'Got it'),
    (r'Understood', r'Got it'),
    (r'I will', r"I'll"),
    (r'I am', r"I'm"),
    (r'We will', r"We'll"),
    (r'We are', r"We're"),

    # Politeness markers
    (r'please be so kind', r'please'),
    (r'if you would be so kind', r'pls'),
    (r'thank you very much', r'thanks'),
    (r'I appreciate it', r'thanks'),

    # Gaming-specific casual
    (r'Experience points', r'XP'),
    (r'experience', r'exp'),
]

# ============================================================================
# COMMUNITY GLOSSARY SYSTEM
# ============================================================================

glossary_last_modified = 0

def load_community_glossary():
    """Load additional terms from community glossary file"""
    global glossary_last_modified

    if not COMMUNITY_GLOSSARY_FILE.exists():
        return {}

    try:
        current_modified = COMMUNITY_GLOSSARY_FILE.stat().st_mtime

        if current_modified == glossary_last_modified:
            return {}

        glossary_last_modified = current_modified

        community_terms = {}
        with open(COMMUNITY_GLOSSARY_FILE, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()

                if not line or line.startswith('#'):
                    continue

                if '|' in line:
                    parts = line.split('|', 1)
                    if len(parts) == 2:
                        jp_term, en_term = parts[0].strip(), parts[1].strip()
                        if jp_term and en_term:
                            community_terms[jp_term] = en_term
                        else:
                            print(f"[Kotoba] Warning: Empty term on line {line_num}")
                    else:
                        print(f"[Kotoba] Warning: Invalid format on line {line_num}: {line[:50]}")

        if community_terms:
            print(f"[Kotoba Translator] Loaded {len(community_terms)} community glossary terms")

        return community_terms
    except Exception as e:
        print(f"[Kotoba Translator] Error loading community glossary: {e}")
        return {}

def get_full_glossary():
    """Combine built-in and community glossaries"""
    full_glossary = FFXI_GLOSSARY.copy()
    community_terms = load_community_glossary()
    full_glossary.update(community_terms)
    return full_glossary

def has_japanese_chars(text):
    """Check if text contains Japanese characters"""
    if not text:
        return False

    for char in text:
        code = ord(char)
        if (0x3040 <= code <= 0x309F or  # Hiragana
            0x30A0 <= code <= 0x30FF or  # Katakana
            0x4E00 <= code <= 0x9FFF or  # Kanji
            0x3400 <= code <= 0x4DBF):   # Kanji Extension A
            return True
    return False

def detect_untranslated_terms(original_text, translated_text, preprocessed_text):
    """Detect terms that might need glossary entries"""
    if not translated_text or translated_text == original_text:
        return

    if has_japanese_chars(translated_text):
        log_suggested_term(original_text, translated_text, "Japanese chars in translation")
        return

    if translated_text.strip().lower() == preprocessed_text.strip().lower():
        if has_japanese_chars(original_text):
            log_suggested_term(original_text, translated_text, "No translation occurred")

def log_suggested_term(original, translation, reason):
    """Log potentially missing glossary terms"""
    try:
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(SUGGESTED_TERMS_FILE, 'a', encoding='utf-8') as f:
            f.write(f"[{timestamp}] {reason}\n")
            f.write(f"  Original:    {original}\n")
            f.write(f"  Translation: {translation}\n")
            f.write(f"  Suggest: Add to ffxi_glossary.txt: {original}|<your_translation>\n")
            f.write(f"\n")
    except Exception as e:
        print(f"[Kotoba] Error logging suggested term: {e}")

# ============================================================================
# TRANSLATION FUNCTIONS
# ============================================================================

def preprocess_japanese(text):
    """Replace JP gaming terms/phrases before translation"""
    processed = text
    terms_used = 0

    # Special handling for common verb patterns with activities
    activity_verbs = {
        'やる？': ' - Wanna do it?',
        'やろ': " - Let's do it",
        'やる': ' - doing',
        '行く？': ' - Wanna go?',
        '行こ': " - Let's go",
        '行かない？': ' - Wanna go?',
        'いく？': ' - Wanna go?',
        'する？': ' - Wanna do it?',
    }

    for jp_verb, en_verb in activity_verbs.items():
        if jp_verb in processed:
            processed = processed.replace(jp_verb, en_verb)
            terms_used += 1
            break

    full_glossary = get_full_glossary()

    for jp_term in sorted(full_glossary.keys(), key=len, reverse=True):
        en_term = full_glossary[jp_term]
        if jp_term in processed:
            processed = processed.replace(jp_term, en_term)
            terms_used += 1

    if terms_used > 0:
        stats['glossary_terms_used'] += terms_used

    return processed

def postprocess_english(text):
    """Make translation more casual/natural"""
    processed = text
    for pattern, replacement in CASUAL_PATTERNS:
        processed = re.sub(pattern, replacement, processed, flags=re.IGNORECASE)
    return processed

def call_llm(text, source_lang, target_lang):
    """Call the LLM API to translate text. Returns translation string or None."""
    try:
        # Build direction hint
        if source_lang == 'ja' and target_lang == 'en':
            direction = "Translate the following Japanese FFXI chat message to English:"
        elif source_lang == 'en' and target_lang == 'ja':
            direction = "Translate the following English FFXI chat message to Japanese:"
        else:
            direction = f"Translate the following from {source_lang} to {target_lang}:"

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"{direction}\n{text}"}
        ]

        url = f"{LLM_BASE_URL.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {LLM_API_KEY}",
            "Content-Type": "application/json"
        }
        body = {
            "model": LLM_MODEL,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 200
        }

        with httpx.Client(timeout=30.0) as client:
            response = client.post(url, headers=headers, json=body)
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"].strip()

    except httpx.HTTPStatusError as e:
        print(f"[Kotoba Translator] LLM API error {e.response.status_code}: {e.response.text[:200]}")
        return None
    except Exception as e:
        print(f"[Kotoba Translator] LLM call failed: {e}")
        return None

def translate_text(text, source_lang, target_lang):
    """Translate text using LLM with SQLite caching and gaming context"""
    # Check SQLite cache first
    cached, hit = get_cached_translation(text, source_lang, target_lang)
    if hit:
        stats['sqlite_hits'] += 1
        print(f"[Kotoba Translator] Cache hit (SQLite): {text[:40]}")
        return cached

    stats['llm_calls'] += 1
    stats['translations'] += 1

    try:
        # Preprocess: Replace FFXI/MMO terms BEFORE sending to LLM
        preprocessed = text
        if source_lang == 'ja':
            preprocessed = preprocess_japanese(text)
            if preprocessed != text:
                print(f"[Kotoba Translator] Preprocessed: {text[:40]} -> {preprocessed[:40]}")

        # Call LLM
        translation = call_llm(preprocessed, source_lang, target_lang)

        if not translation:
            return None

        # Postprocess: Make it casual/natural
        if target_lang == 'en':
            translation = postprocess_english(translation)

        # Detect potentially missing glossary terms
        if source_lang == 'ja' and target_lang == 'en':
            detect_untranslated_terms(text, translation, preprocessed)

        # Store in SQLite cache
        store_translation(text, source_lang, target_lang, translation)

        print(f"[Kotoba Translator] Translated: {text[:40]} -> {translation[:40]}")
        return translation

    except Exception as e:
        print(f"[Kotoba Translator] Translation error: {e}")
        return None

# ============================================================================
# QUEUE PROCESSING
# ============================================================================

def process_queue():
    """Process translation queue"""
    if not QUEUE_FILE.exists():
        return

    try:
        lines = []
        try:
            with open(QUEUE_FILE, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except UnicodeDecodeError:
            try:
                with open(QUEUE_FILE, 'r', encoding='shift-jis') as f:
                    lines = f.readlines()
            except UnicodeDecodeError:
                with open(QUEUE_FILE, 'rb') as f:
                    content = f.read()
                    lines = content.decode('utf-8', errors='ignore').split('\n')

        if not lines:
            return

        # Clear queue file immediately
        with open(QUEUE_FILE, 'w', encoding='utf-8') as f:
            f.write('')

        results = []
        for line in lines:
            line = line.strip()
            if not line:
                continue

            try:
                # Parse: ID|SOURCE_LANG|TARGET_LANG|TEXT
                parts = line.split('|', 3)
                if len(parts) != 4:
                    print(f"[Kotoba Translator] Invalid format: {line[:50]}")
                    continue

                translation_id, source_lang, target_lang, text = parts

                # Unescape special characters
                text = text.replace('\\|', '|').replace('\\n', '\n').replace('\\r', '\r')
                text = text.replace('\x00', '').strip()

                if not text:
                    continue

                print(f"[Kotoba Translator] Translating ({source_lang}->{target_lang}): {text[:80]}")

                translation = translate_text(text, source_lang, target_lang)

                if translation:
                    translation = translation.replace('|', '\\|')
                    results.append(f"{translation_id}|{translation}\n")

            except Exception as e:
                print(f"[Kotoba Translator] Error processing line: {e}")
                import traceback
                traceback.print_exc()

        if results:
            with open(RESULTS_FILE, 'a', encoding='utf-8') as f:
                f.writelines(results)
            print(f"[Kotoba Translator] Wrote {len(results)} translation(s)")

    except Exception as e:
        print(f"[Kotoba Translator] Error processing queue: {e}")

# ============================================================================
# STATS
# ============================================================================

def print_stats():
    """Print translation statistics"""
    uptime = int(time.time() - stats['start_time'])
    hours, remainder = divmod(uptime, 3600)
    minutes, seconds = divmod(remainder, 60)

    total = stats['sqlite_hits'] + stats['llm_calls']
    cache_rate = (stats['sqlite_hits'] / total * 100) if total > 0 else 0

    print("\n" + "=" * 60)
    print("KOTOBA TRANSLATOR STATS")
    print("=" * 60)
    print(f"  Uptime:            {hours}h {minutes}m {seconds}s")
    print(f"  Total translations: {stats['translations']}")
    print(f"  SQLite cache hits:  {stats['sqlite_hits']} ({cache_rate:.1f}% hit rate)")
    print(f"  LLM API calls:      {stats['llm_calls']}")
    print(f"  Glossary terms used: {stats['glossary_terms_used']}")
    print(f"  SQLite cache size:  {get_cache_size()} entries")

    community_terms = load_community_glossary()
    if community_terms:
        print(f"  Community glossary: {len(community_terms)} custom terms loaded")

    print("=" * 60 + "\n")

# ============================================================================
# GLOSSARY CREATION
# ============================================================================

def create_example_glossary():
    """Create example community glossary file if it doesn't exist"""
    if not COMMUNITY_GLOSSARY_FILE.exists():
        try:
            with open(COMMUNITY_GLOSSARY_FILE, 'w', encoding='utf-8') as f:
                f.write("""# Kotoba Community Glossary
# Format: Japanese|English
# Lines starting with # are comments
#
# Add your own FFXI terms here!
# These will override built-in glossary terms.
# Hot-reloads automatically - no need to restart translator!
#
# Examples:
# エーベル|Aeonic
# アレキ|Alexandrite
# メリポ|merit party
# 倉庫|mule
#
# Add your terms below:

""")
            print(f"[Kotoba Translator] Created example glossary: {COMMUNITY_GLOSSARY_FILE}")
        except Exception as e:
            print(f"[Kotoba Translator] Could not create example glossary: {e}")

# ============================================================================
# MAIN
# ============================================================================

def main():
    """Main loop"""
    print("\n" + "=" * 60)
    print("  KOTOBA TRANSLATOR - LLM EDITION")
    print("=" * 60)
    print(f"  Queue:         {QUEUE_FILE}")
    print(f"  Results:       {RESULTS_FILE}")
    print(f"  Community:     {COMMUNITY_GLOSSARY_FILE}")
    print(f"  Suggestions:   {SUGGESTED_TERMS_FILE}")
    print(f"  SQLite DB:     {DB_FILE}")
    print(f"  LLM:           {LLM_MODEL} @ {LLM_BASE_URL}")
    print("=" * 60)
    print("  Features:")
    print("    - 500+ built-in FFXI terms")
    print("    - Hot-reload community glossary")
    print("    - SQLite durable cache (sub-ms lookups)")
    print("    - LLM-powered natural translation")
    print("    - Untranslated term detection")
    print("    - Casual tone post-processing")
    print("=" * 60)
    print("\nPress Ctrl+C to stop and see stats\n")

    # Initialize SQLite
    init_db()

    # Ensure files exist
    QUEUE_FILE.touch(exist_ok=True)
    RESULTS_FILE.touch(exist_ok=True)
    create_example_glossary()

    # Load community glossary on startup
    community_terms = load_community_glossary()
    if community_terms:
        print(f"[Kotoba Translator] Loaded {len(community_terms)} community terms\n")

    last_stats_print = time.time()

    try:
        while True:
            process_queue()

            if time.time() - last_stats_print > 300:
                print_stats()
                last_stats_print = time.time()

            time.sleep(0.5)

    except KeyboardInterrupt:
        print("\n[Kotoba Translator] Stopping...")
        print_stats()
        sys.exit(0)

if __name__ == "__main__":
    main()
