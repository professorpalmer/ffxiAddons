#!/usr/bin/env python3
"""
Kotoba Seed Database Builder
Pre-loads translations.db with common *full chat phrases* for a warm cache.

Glossary terms (ffxi_glossary.txt) are intentionally NOT seeded here — they are
word/phrase fragments used during preprocess, not complete chat messages. Seeding
them as full-message translations caused odd hits when someone typed just a term.
"""

import re
import sqlite3
import time
import unicodedata
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
DB_FILE = SCRIPT_DIR / "translations.db"

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
    '　': ' ',
    '\u200b': '',
    '\ufeff': '',
})


def normalize_cache_key(text):
    """Same normalization as translator.py so seeds hit at runtime."""
    if not text:
        return ''
    text = unicodedata.normalize('NFKC', text)
    text = text.translate(_PUNCT_MAP)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


# Pre-baked common FFXI phrases (JP -> EN) — full messages only
SEED_PHRASES = {
    # Greetings
    "こんにちは": "hi",
    "こんばんは": "good evening",
    "おはよう": "morning",
    "お疲れ様でした": "gj",
    "お疲れ": "gj",
    "おつ": "gj",
    "おつかれ": "gj",
    "よろしくお願いします": "nice to meet you",
    "よろしく": "pleased to meet you",

    # Activity invites
    "ソーティやる？": "Wanna do Sortie?",
    "ソーティ行きませんか？": "Wanna do Sortie?",
    "ソーティ行こう": "Let's do Sortie",
    "オデシー行く？": "Wanna do Odyssey?",
    "今からオデシー行こ": "Let's go Odyssey now",
    "オーメンやる？": "Wanna do Omen?",
    "アンバス行く？": "Wanna do Ambu?",
    "ダイナミス行く？": "Wanna do Dyna?",
    "メリポ行く？": "Wanna go merit?",
    "メリポやろう": "Let's do merits",
    "アビセア行く？": "Wanna do Abyssea?",
    "リンバス行く？": "Wanna do Limbus?",

    # Party recruitment
    "PT募集": "LFM",
    "パーティ募集中": "LFM",
    "白魔募集中": "LFM WHM",
    "黒魔募集中": "LFM BLM",
    "赤魔募集中": "LFM RDM",
    "ナイト募集中": "LFM PLD",
    "吟遊詩人募集中": "LFM BRD",
    "コルセア募集中": "LFM COR",
    "参加希望": "LFG",
    "参加したい": "I want to join",
    "野良PT": "PUG party",
    "固定PT": "static party",

    # Requests
    "ヘイストお願いします": "Haste pls",
    "ヘイストください": "Haste pls",
    "リフレシュお願いします": "Refresh pls",
    "リレイズお願いします": "Reraise pls",
    "レイズお願いします": "Raise pls",
    "プロテスお願いします": "Protect pls",
    "シェルお願いします": "Shell pls",
    "手伝ってください": "Help pls",
    "助けてください": "Help pls",
    "教えてください": "Tell me pls",
    "見せてください": "Show me pls",

    # Responses
    "はい": "yes",
    "いいえ": "no",
    "うん": "yeah",
    "ううん": "nope",
    "わかった": "got it",
    "了解": "roger",
    "りょうかい": "roger",
    "大丈夫": "ok",
    "問題ない": "no problem",
    "いいよ": "sure",
    "だめ": "no good",
    "無理": "can't",
    "ちょっと待って": "wait a sec",
    "待って": "wait",
    "すぐ行く": "coming now",
    "今行く": "coming now",

    # Thanks/Apology
    "ありがとうございます": "thanks",
    "ありがとう": "thanks",
    "ありがと": "ty",
    "ごめんなさい": "sorry",
    "ごめん": "sry",
    "すみません": "excuse me",
    "すまん": "sorry",
    "どういたしまして": "np",

    # Battle
    "連携お願いします": "SC pls",
    "マジックバーストお願いします": "MB pls",
    "WSお願いします": "WS pls",
    "釣りお願いします": "pull pls",
    "タンクお願いします": "need tank",
    "ヒーラーお願いします": "need healer",
    "前衛募集": "LFM DD",
    "後衛募集": "LFM support",

    # Common chat
    "やばい": "sick",
    "すごい": "amazing",
    "えぐい": "insane",
    "マジ？": "fr?",
    "ガチ？": "fr?",
    "うそ": "no way",
    "なるほど": "I see",
    "おｋ": "ok",
    "おけ": "ok",
    "りょ": "gotcha",
    "うぃ": "yep",
    "わらい": "lol",
    "ワロタ": "lmao",
    "草": "lmao",
    "頑張って": "gl",
    "気をつけて": "be careful",
    "お疲れ様": "gj",

    # Items/Economy
    "ギルください": "gil pls",
    "アイテムください": "item pls",
    "高い": "expensive",
    "安い": "cheap",
    "バザー": "bazaar",
    "倉庫": "mule",

    # Directions
    "どこ？": "where?",
    "ここ": "here",
    "そこ": "there",
    "あそこ": "over there",
    "近く": "nearby",
    "北へ": "go north",
    "南へ": "go south",
    "東へ": "go east",
    "西へ": "go west",

    # Misc common
    "何？": "what?",
    "誰？": "who?",
    "いつ？": "when?",
    "なぜ？": "why?",
    "どう？": "how?",
    "いくつ？": "how many?",
    "いくら？": "how much?",
    "欲しい": "want",
    "いらない": "don't need",
    "できる？": "can you?",
    "できない": "can't",
    "知ってる": "I know",
    "知らない": "dunno",
    "わかる？": "understand?",
    "わからない": "don't understand",
}


def init_db(conn):
    """Create the translations table if it doesn't exist."""
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


def main():
    print("\n" + "=" * 60)
    print("  KOTOBA SEED DATABASE BUILDER")
    print("=" * 60)
    print("[Seed DB] Glossary terms are NOT seeded as full-message cache")
    print("[Seed DB] entries (they stay in preprocess via ffxi_glossary.txt).")

    conn = sqlite3.connect(str(DB_FILE))
    init_db(conn)

    now = time.time()

    # Insert pre-baked full-message seed phrases (normalized keys)
    print(f"[Seed DB] Inserting {len(SEED_PHRASES)} pre-baked common phrases")
    phrase_added = 0
    seen_keys = set()

    for jp, en in SEED_PHRASES.items():
        key = normalize_cache_key(jp)
        if not key or key in seen_keys:
            continue
        seen_keys.add(key)
        cursor = conn.execute(
            "INSERT OR IGNORE INTO translations "
            "(source_text, source_lang, target_lang, translated_text, usage_count, last_used, created_at) "
            "VALUES (?, 'ja', 'en', ?, 0, ?, ?)",
            (key, en, now, now)
        )
        if cursor.rowcount > 0:
            phrase_added += 1

    conn.commit()
    print(f"[Seed DB] Added {phrase_added} pre-baked phrases")

    total = conn.execute("SELECT COUNT(*) FROM translations").fetchone()[0]
    conn.close()

    print(f"[Seed DB] Total entries in translations.db: {total}")
    print("=" * 60)
    print("  Seed database complete!")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
