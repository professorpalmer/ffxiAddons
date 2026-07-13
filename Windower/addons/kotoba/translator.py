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
import unicodedata
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
HEARTBEAT_FILE = SCRIPT_DIR / "heartbeat.txt"
DB_FILE = SCRIPT_DIR / "translations.db"
LOCK_FILE = SCRIPT_DIR / "translator.lock"

# Auto-shutdown: if no heartbeat for this many seconds, exit
HEARTBEAT_TIMEOUT = 30

# Instant EN→JA greets (no LLM) — keeps casual chat snappy
FAST_PHRASES = {
    ('en', 'ja'): {
        'hey': 'おい',
        'hi': 'やあ',
        'hello': 'こんにちは',
        'hey guys': 'みんなー',
        'hey everyone': 'みんなー',
        'hey all': 'みんなー',
        "what's up": '元気？',
        "whats up": '元気？',
        "what are you up to": '今何してる？',
        "what are you up to?": '今何してる？',
        'hey what are you up to?': '今何してる？',
        'good game': 'おつ',
        'gg': 'おつ',
        'thanks': 'ありがとう',
        'ty': 'あざす',
        'np': 'いえいえ',
        'ready': '準備OK',
        'ready?': '準備できた？',
        'brb': 'ちょっと待って',
        'afk': '離席',
        'lol': 'www',
        'ok': 'おけ',
        'okay': 'おけ',
    },
}

# Defaults
LLM_API_KEY = None
LLM_BASE_URL = "https://api.deepseek.com/v1"
LLM_MODEL = "deepseek-chat"

def load_config():
    """Load LLM configuration from translator_config.txt"""
    global LLM_API_KEY, LLM_BASE_URL, LLM_MODEL

    example = SCRIPT_DIR / "translator_config.example.txt"
    if not CONFIG_FILE.exists():
        print(f"[Kotoba Translator] ERROR: Config file not found: {CONFIG_FILE}")
        if example.exists():
            print(f"[Kotoba Translator] Copy the example and add your key:")
            print(f"[Kotoba Translator]   copy {example.name} {CONFIG_FILE.name}")
        else:
            print(f"[Kotoba Translator] Create it with: LLM_API_KEY=your_key_here")
        sys.exit(1)

    placeholder_keys = {
        'your_api_key_here',
        'INSERT_YOUR_API_KEY_HERE',
        'YOUR_API_KEY_HERE',
        'sk-or-v1-REPLACE_ME',
    }

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

        if not LLM_API_KEY or LLM_API_KEY in placeholder_keys:
            print("[Kotoba Translator] ERROR: LLM_API_KEY not set in config")
            print(f"[Kotoba Translator] Edit: {CONFIG_FILE}")
            sys.exit(1)

        print(f"[Kotoba Translator] LLM configured: {LLM_MODEL} @ {LLM_BASE_URL}")

    except Exception as e:
        print(f"[Kotoba Translator] ERROR: Could not load config: {e}")
        sys.exit(1)

load_config()

# ============================================================================
# LANGUAGE NAMES + LLM SYSTEM PROMPT
# ============================================================================

LANG_NAMES = {
    'ja': 'Japanese',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ko': 'Korean',
    'zh': 'Chinese',
    'auto': 'auto-detected',
}

SYSTEM_PROMPT = """You are a machine translator for Final Fantasy XI chat.
You ONLY output the translated message text in the requested target language.

Hard rules:
- Output ONE translation only — no quotes, no options, no "or", no explanations
- Do NOT write preambles like "Here's the translation:" or "Natural English:"
- Do NOT echo the source language when a different target was requested
- Translate the FULL meaning — gil amounts, zone names, and requests must survive
- Do NOT collapse unrelated requests into "LFM WHM" / "LFM …" unless the source is actually recruiting that job
- Keep casual MMO tone in the TARGET language, but stay faithful to the content
- Preserve job abbreviations (WHM, BLM, PLD, Sortie, Odyssey, Dynamis, etc.) as players write them
- If target is English: casual EN gaming slang when it fits (wanna, ty, np, gj) — never invent LFM
- If target is Japanese: natural casual Japanese chat (です/ます optional; やる？行こ is fine)
- If target is Spanish/French/German/Korean/Chinese: casual chat tone in that language only

Examples:
JA→EN  ソーティやる？  →  Wanna do Sortie?
JA→EN  白魔募集中  →  LFM WHM
JA→EN  Dサンド突入補助50万ギルでお願いできませんか  →  Can I get Dynamis San d'Oria entry help for 500k gil?
EN→JA  hey what are you up to?  →  今何してる？
EN→JA  wanna do Sortie?  →  ソーティやる？
EN→ES  ready?  →  ¿listo?
"""

# Phrases the model sometimes prepends — strip before accepting output
_LEAK_PREFIXES = (
    r"^\s*here'?s\s+(the\s+)?(natural\s+)?(english\s+)?(mmo\s+)?(chat\s+)?translation\s*:?\s*",
    r"^\s*translation\s*:?\s*",
    r"^\s*translated\s*(text|message)?\s*:?\s*",
    r"^\s*natural\s+english\s*(mmo\s*chat)?\s*(translation)?\s*:?\s*",
    r"^\s*in\s+\w+\s*:?\s*",
)

# ============================================================================
# SQLITE CACHE
# ============================================================================

# Punctuation / whitespace variants that should share a cache entry
_PUNCT_MAP = str.maketrans({
    '！': '!',
    '？': '?',
    '。': '.',
    '、': ',',
    '｡': '.',
    '､': ',',
    '･': '・',
    '～': '~',
    '〜': '~',
    '―': '-',
    '‐': '-',
    '‑': '-',
    '–': '-',
    '—': '-',
    '　': ' ',  # ideographic space
    '\u200b': '',  # zero-width space
    '\ufeff': '',  # BOM
})


def normalize_cache_key(text):
    """Normalize text so trivial variants hit the same cache entry.

    Handles fullwidth/halfwidth (NFKC), JP/EN punctuation variants,
    and collapsed whitespace — without changing Japanese word content.
    """
    if not text:
        return ''
    text = unicodedata.normalize('NFKC', text)
    text = text.translate(_PUNCT_MAP)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


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
    migrated = migrate_normalize_cache_keys(conn)
    conn.close()
    print(f"[Kotoba Translator] SQLite cache initialized: {DB_FILE}")
    if migrated:
        print(f"[Kotoba Translator] Migrated {migrated} cache key(s) to normalized form")


def migrate_normalize_cache_keys(conn):
    """Rewrite existing rows onto normalized keys; merge collisions by usage."""
    rows = conn.execute(
        "SELECT source_text, source_lang, target_lang, translated_text, "
        "usage_count, last_used, created_at FROM translations"
    ).fetchall()

    changed = 0
    for source_text, source_lang, target_lang, translated_text, usage_count, last_used, created_at in rows:
        key = normalize_cache_key(source_text)
        if key == source_text:
            continue

        changed += 1
        conn.execute(
            "DELETE FROM translations WHERE source_text=? AND source_lang=? AND target_lang=?",
            (source_text, source_lang, target_lang)
        )
        existing = conn.execute(
            "SELECT usage_count, last_used, created_at, translated_text "
            "FROM translations WHERE source_text=? AND source_lang=? AND target_lang=?",
            (key, source_lang, target_lang)
        ).fetchone()

        if existing:
            old_usage, old_last, old_created, old_translated = existing
            created_vals = [x for x in (old_created, created_at) if x is not None]
            conn.execute(
                "UPDATE translations SET usage_count=?, last_used=?, created_at=?, translated_text=? "
                "WHERE source_text=? AND source_lang=? AND target_lang=?",
                (
                    (old_usage or 0) + (usage_count or 0),
                    max(old_last or 0, last_used or 0),
                    min(created_vals) if created_vals else None,
                    # Prefer the more-used translation
                    translated_text if (usage_count or 0) >= (old_usage or 0) else old_translated,
                    key, source_lang, target_lang,
                )
            )
        else:
            conn.execute(
                "INSERT INTO translations "
                "(source_text, source_lang, target_lang, translated_text, usage_count, last_used, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (key, source_lang, target_lang, translated_text, usage_count or 0, last_used, created_at)
            )

    if changed:
        conn.commit()
    return changed


def get_cached_translation(source_text, source_lang, target_lang):
    """Check SQLite cache for a translation. Returns (translation, hit_bool)."""
    key = normalize_cache_key(source_text)
    conn = sqlite3.connect(str(DB_FILE))
    try:
        cursor = conn.execute(
            "SELECT translated_text FROM translations WHERE source_text=? AND source_lang=? AND target_lang=?",
            (key, source_lang, target_lang)
        )
        row = cursor.fetchone()
        if row:
            conn.execute(
                "UPDATE translations SET usage_count=usage_count+1, last_used=? "
                "WHERE source_text=? AND source_lang=? AND target_lang=?",
                (time.time(), key, source_lang, target_lang)
            )
            conn.commit()
            return row[0], True
        return None, False
    finally:
        conn.close()


def store_translation(source_text, source_lang, target_lang, translated_text):
    """Store a translation in the SQLite cache without resetting usage_count."""
    key = normalize_cache_key(source_text)
    conn = sqlite3.connect(str(DB_FILE))
    try:
        now = time.time()
        conn.execute(
            """
            INSERT INTO translations
                (source_text, source_lang, target_lang, translated_text, usage_count, last_used, created_at)
            VALUES (?, ?, ?, ?, 1, ?, ?)
            ON CONFLICT(source_text, source_lang, target_lang) DO UPDATE SET
                translated_text = excluded.translated_text,
                last_used = excluded.last_used
            """,
            (key, source_lang, target_lang, translated_text, now, now)
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


def purge_poisoned_cache():
    """Remove mojibake sources and implausible LFM collapses from SQLite."""
    if not DB_FILE.exists():
        return 0
    conn = sqlite3.connect(str(DB_FILE))
    removed = 0
    try:
        rows = conn.execute(
            "SELECT source_text, source_lang, target_lang, translated_text FROM translations"
        ).fetchall()
        for source_text, source_lang, target_lang, translated_text in rows:
            if looks_mojibake(source_text) or translation_implausible(
                source_text, translated_text, source_lang, target_lang
            ):
                conn.execute(
                    "DELETE FROM translations WHERE source_text=? AND source_lang=? AND target_lang=?",
                    (source_text, source_lang, target_lang),
                )
                removed += 1
        if removed:
            conn.commit()
    finally:
        conn.close()
    return removed

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

def looks_mojibake(text):
    """True if text looks like Shift-JIS misread as UTF-8 / other encoding damage."""
    if not text:
        return False
    if '\ufffd' in text:
        return True
    cjk = sum(1 for ch in text if 0x3040 <= ord(ch) <= 0x9FFF or 0x3400 <= ord(ch) <= 0x4DBF)
    high = sum(1 for ch in text if ord(ch) > 127)
    # Non-ASCII but almost no real JP/CJK — classic mojibake for ja chat
    if high >= 3 and cjk == 0:
        return True
    # Mixed private-use / rare planes with almost no kana/kanji
    weird = sum(1 for ch in text if ord(ch) > 0xFFFF or (0x80 <= ord(ch) <= 0x9F))
    if weird >= 1 and cjk <= 1 and high >= 4:
        return True
    return False


_LFM_ONLY = re.compile(r'^\s*LFM(\s+[A-Za-z0-9]{1,6})?\s*$', re.IGNORECASE)
_RECRUIT_HINTS = ('募集', 'ＬＦＭ', 'LFM', '求む', '歓迎')
_CONTENT_HINTS = ('ギル', '突入', 'お願い', '補助', '万', 'Dynamis', 'ソート', 'オデ')


def translation_implausible(source, translation, source_lang, target_lang):
    """Catch prompt-biased collapses like Dynamis gil ask → 'LFM WHM'."""
    if not source or not translation:
        return False
    if (source_lang or '').lower() != 'ja' or (target_lang or '').lower() != 'en':
        return False
    if looks_mojibake(source):
        return True
    if _LFM_ONLY.match(translation.strip()):
        if any(h in source for h in _CONTENT_HINTS):
            return True
        if len(source) >= 18 and not any(h in source for h in _RECRUIT_HINTS):
            return True
    # Extremely short EN for long JP source
    if len(source) >= 24 and len(translation.strip()) <= 8 and not any(h in source for h in _RECRUIT_HINTS):
        return True
    return False


def _has_cjk(text):
    return bool(re.search(r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]', text or ''))


def decode_queue_bytes(raw: bytes) -> str:
    """Decode queue file bytes, preferring real UTF-8 then CP932 (FFXI)."""
    if not raw:
        return ''
    try:
        text = raw.decode('utf-8')
        if '\ufffd' not in text:
            return text
    except UnicodeDecodeError:
        pass
    for enc in ('cp932', 'shift_jis'):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode('utf-8', errors='replace')


def maybe_fix_sjis_mojibake(text: str) -> str:
    """If SJIS bytes were interpreted as Latin-1, recover real UTF-8 Japanese."""
    if not text or _has_cjk(text):
        return text
    try:
        raw = text.encode('latin-1')
    except UnicodeEncodeError:
        return text
    for enc in ('cp932', 'shift_jis'):
        try:
            fixed = raw.decode(enc)
            if _has_cjk(fixed) and not looks_mojibake(fixed):
                return fixed
        except UnicodeDecodeError:
            continue
    return text


def clean_llm_output(text, target_lang):
    """Strip prompt leakage / alternatives; keep a single chat line."""
    if not text:
        return text
    out = text.strip()
    if (out.startswith('"') and out.endswith('"')) or (out.startswith("'") and out.endswith("'")):
        out = out[1:-1].strip()
    for pat in _LEAK_PREFIXES:
        out = re.sub(pat, '', out, flags=re.IGNORECASE)
    # Model sometimes returns: "opt1" or "opt2"
    if re.search(r'\bor\b', out, flags=re.IGNORECASE) and out.count('"') >= 2:
        first = re.search(r'"([^"]+)"', out)
        if first:
            out = first.group(1).strip()
    out = out.split('\n', 1)[0].strip()
    out = out.strip(' "\'')
    return out

def output_looks_wrong_language(text, target_lang):
    """True if output is clearly not in the requested target (common DeepSeek slip)."""
    if not text or not target_lang:
        return False
    t = target_lang.lower()
    # Meta leakage in any language
    if re.search(
        r"here'?s the natural|translation:|日本語訳|翻訳結果|traducci[oó]n\s*:",
        text,
        re.IGNORECASE,
    ):
        return True
    if t in ('ja', 'zh', 'ko'):
        if not _has_cjk(text) and re.search(r'[A-Za-z]{3,}', text):
            return True
        # Entirely a meta label like 「日本語訳」 with no real message content
        if re.fullmatch(r'\s*(日本語訳|翻訳|日訳|中文翻译|번역)\s*', text):
            return True
    if t == 'en':
        if _has_cjk(text) and not re.search(r'[A-Za-z]{2,}', text):
            return True
    return False

def call_llm(text, source_lang, target_lang):
    """Call the LLM API to translate text. Returns translation string or None."""
    try:
        src_name = LANG_NAMES.get(source_lang, source_lang)
        tgt_name = LANG_NAMES.get(target_lang, target_lang)
        direction = (
            f"Translate this {src_name} FFXI chat line to {tgt_name}. "
            f"Reply with ONLY the {tgt_name} chat text — no quotes, no alternatives, no commentary.\n"
            f"{text}"
        )

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": direction}
        ]

        url = f"{LLM_BASE_URL.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {LLM_API_KEY}",
            "Content-Type": "application/json"
        }
        body = {
            "model": LLM_MODEL,
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 256
        }

        with httpx.Client(timeout=30.0) as client:
            response = client.post(url, headers=headers, json=body)
            response.raise_for_status()
            data = response.json()
            raw = data["choices"][0]["message"]["content"].strip()
            cleaned = clean_llm_output(raw, target_lang)
            if cleaned != raw:
                print(f"[Kotoba Translator] Cleaned LLM leakage: {raw[:60]} -> {cleaned[:60]}")
            return cleaned

    except httpx.HTTPStatusError as e:
        print(f"[Kotoba Translator] LLM API error {e.response.status_code}: {e.response.text[:200]}")
        return None
    except Exception as e:
        print(f"[Kotoba Translator] LLM call failed: {e}")
        return None

def translate_text(text, source_lang, target_lang):
    """Translate text using LLM with SQLite caching and gaming context"""
    text = maybe_fix_sjis_mojibake((text or '').strip())
    if not text:
        return None

    if source_lang == 'ja' and looks_mojibake(text):
        print(f"[Kotoba Translator] Rejecting mojibake source (not translating): {text[:60]}")
        return None

    # Lightning path: known short phrases (no network)
    bucket = FAST_PHRASES.get((source_lang, target_lang))
    if bucket:
        hit_fast = bucket.get(text.strip().lower())
        if hit_fast:
            print(f"[Kotoba Translator] Fast phrase: {text[:40]} -> {hit_fast}")
            store_translation(text, source_lang, target_lang, hit_fast)
            return hit_fast

    cached, hit = get_cached_translation(text, source_lang, target_lang)
    if hit:
        if (
            output_looks_wrong_language(cached, target_lang)
            or translation_implausible(text, cached, source_lang, target_lang)
            or re.search(r"here'?s the natural|translation:", cached or '', re.IGNORECASE)
        ):
            print(f"[Kotoba Translator] Ignoring bad cache entry for: {text[:40]} -> {cached[:40]}")
            # Drop poisoned cache row so the next call can recover
            try:
                key = normalize_cache_key(text)
                conn = sqlite3.connect(str(DB_FILE))
                conn.execute(
                    "DELETE FROM translations WHERE source_text=? AND source_lang=? AND target_lang=?",
                    (key, source_lang, target_lang),
                )
                conn.commit()
                conn.close()
            except Exception as e:
                print(f"[Kotoba Translator] Bad-cache delete failed: {e}")
        else:
            stats['sqlite_hits'] += 1
            print(f"[Kotoba Translator] Cache hit (SQLite): {text[:40]}")
            return cached

    stats['llm_calls'] += 1
    stats['translations'] += 1

    try:
        preprocessed = text
        if source_lang == 'ja':
            preprocessed = preprocess_japanese(text)
            if preprocessed != text:
                print(f"[Kotoba Translator] Preprocessed: {text[:40]} -> {preprocessed[:40]}")

        translation = call_llm(preprocessed, source_lang, target_lang)

        if not translation:
            return None

        if output_looks_wrong_language(translation, target_lang) or translation_implausible(
            text, translation, source_lang, target_lang
        ):
            print(f"[Kotoba Translator] Implausible/wrong output, retrying: {translation[:50]}")
            retry = call_llm(
                preprocessed
                + "\n(IMPORTANT: translate the FULL meaning into "
                + f"{LANG_NAMES.get(target_lang, target_lang)}; do not invent LFM)",
                source_lang,
                target_lang,
            )
            if (
                retry
                and not output_looks_wrong_language(retry, target_lang)
                and not translation_implausible(text, retry, source_lang, target_lang)
            ):
                translation = retry
            else:
                print(f"[Kotoba Translator] Rejecting bad translation (not storing): {translation[:50]}")
                return None

        if target_lang == 'en':
            translation = postprocess_english(translation)

        if source_lang == 'ja' and target_lang == 'en':
            detect_untranslated_terms(text, translation, preprocessed)

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
        raw = QUEUE_FILE.read_bytes()
        content = decode_queue_bytes(raw)
        lines = content.splitlines()

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
                text = maybe_fix_sjis_mojibake(text)

                if not text:
                    continue

                print(f"[Kotoba Translator] Translating ({source_lang}->{target_lang}): {text[:80]}")

                translation = translate_text(text, source_lang, target_lang)

                if translation:
                    translation = translation.replace('|', '\\|')
                    results.append(f"{translation_id}|{translation}\n")
                else:
                    # Always ack the addon — silent None left Lua stuck on "Still translating…"
                    results.append(f"{translation_id}|__ERROR__|translation_failed\n")

            except Exception as e:
                print(f"[Kotoba Translator] Error processing line: {e}")
                maybe_id = line.split('|', 1)[0] if '|' in line else None
                if maybe_id:
                    results.append(f"{maybe_id}|__ERROR__|exception\n")
                import traceback
                traceback.print_exc()
                # Best-effort id extract so Lua can unblock
                maybe_id = line.split('|', 1)[0].strip() if '|' in line else ''
                if maybe_id:
                    results.append(f"{maybe_id}|__ERROR__|exception\n")

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

def check_heartbeat():
    """Check if the game addon is still alive via heartbeat file.
    Returns True if alive, False if we should shut down."""
    if not HEARTBEAT_FILE.exists():
        return True
    try:
        mtime = HEARTBEAT_FILE.stat().st_mtime
        age = time.time() - mtime
        return age < HEARTBEAT_TIMEOUT
    except Exception:
        return True

def _pid_alive(pid):
    if not pid or pid <= 0:
        return False
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, int(pid))
        if handle:
            kernel32.CloseHandle(handle)
            return True
        return False
    except Exception:
        return False

def acquire_singleton_lock():
    """Ensure only one live translator owns the queue (kill stale sibling first)."""
    if LOCK_FILE.exists():
        try:
            old_pid = int(LOCK_FILE.read_text(encoding='utf-8').strip().split()[0])
        except Exception:
            old_pid = None
        if old_pid and old_pid != os.getpid() and _pid_alive(old_pid):
            print(f"[Kotoba Translator] Stopping stale translator pid {old_pid}")
            try:
                import ctypes
                handle = ctypes.windll.kernel32.OpenProcess(1, 0, int(old_pid))  # TERMINATE
                if handle:
                    ctypes.windll.kernel32.TerminateProcess(handle, 0)
                    ctypes.windll.kernel32.CloseHandle(handle)
                time.sleep(0.25)
            except Exception as e:
                print(f"[Kotoba Translator] Could not stop pid {old_pid}: {e}")
    try:
        LOCK_FILE.write_text(str(os.getpid()), encoding='utf-8')
    except Exception as e:
        print(f"[Kotoba Translator] Warning: could not write lock file: {e}")

def release_singleton_lock():
    try:
        if LOCK_FILE.exists():
            cur = LOCK_FILE.read_text(encoding='utf-8').strip()
            if cur == str(os.getpid()):
                LOCK_FILE.unlink()
    except Exception:
        pass

# ============================================================================
# MAIN
# ============================================================================

def main():
    """Main loop"""
    acquire_singleton_lock()
    print("\n" + "=" * 60)
    print("  KOTOBA TRANSLATOR - LLM EDITION")
    print("=" * 60)
    print(f"  Queue:         {QUEUE_FILE}")
    print(f"  Results:       {RESULTS_FILE}")
    print(f"  Community:     {COMMUNITY_GLOSSARY_FILE}")
    print(f"  Suggestions:   {SUGGESTED_TERMS_FILE}")
    print(f"  SQLite DB:     {DB_FILE}")
    print(f"  LLM:           {LLM_MODEL} @ {LLM_BASE_URL}")
    print(f"  Auto-shutdown: {HEARTBEAT_TIMEOUT}s after game disconnect")
    print("=" * 60)
    print("  Features:")
    print("    - 500+ built-in FFXI terms")
    print("    - Hot-reload community glossary")
    print("    - SQLite durable cache (sub-ms lookups)")
    print("    - Fast phrasebook for common greets")
    print("    - LLM-powered natural translation")
    print("    - Untranslated term detection")
    print("    - Casual tone post-processing")
    print("    - Auto-shutdown when game disconnects")
    print("=" * 60)
    print("\nPress Ctrl+C to stop and see stats\n")

    # Initialize SQLite
    init_db()
    purged = purge_poisoned_cache()
    if purged:
        print(f"[Kotoba Translator] Purged {purged} poisoned cache entr{'y' if purged == 1 else 'ies'}")

    # Ensure files exist
    QUEUE_FILE.touch(exist_ok=True)
    RESULTS_FILE.touch(exist_ok=True)
    create_example_glossary()

    # Load community glossary on startup
    community_terms = load_community_glossary()
    if community_terms:
        print(f"[Kotoba Translator] Loaded {len(community_terms)} community terms\n")

    last_stats_print = time.time()
    last_heartbeat_check = time.time()

    try:
        while True:
            process_queue()

            if time.time() - last_stats_print > 300:
                print_stats()
                last_stats_print = time.time()

            # Check heartbeat every 5 seconds
            if time.time() - last_heartbeat_check > 5:
                last_heartbeat_check = time.time()
                if not check_heartbeat():
                    print("\n[Kotoba Translator] Game disconnected — shutting down.")
                    print_stats()
                    try:
                        HEARTBEAT_FILE.unlink()
                    except Exception:
                        pass
                    release_singleton_lock()
                    sys.exit(0)

            time.sleep(0.15)

    except KeyboardInterrupt:
        print("\n[Kotoba Translator] Stopping...")
        print_stats()
        release_singleton_lock()
        sys.exit(0)

if __name__ == "__main__":
    main()
