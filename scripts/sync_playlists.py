#!/usr/bin/env python3
"""Fetch every Hashevaynu playlist from the SoundCloud API and write data/playlists.json.

Runs daily in GitHub Actions (.github/workflows/sync-playlists.yml). Needs two
repository secrets: SOUNDCLOUD_CLIENT_ID and SOUNDCLOUD_CLIENT_SECRET.
Uses only the Python standard library.
"""
import base64
import json
import re
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

USER_ID = "749441560"  # Hashevaynu on SoundCloud (from the RSS feed URL)
API = "https://api.soundcloud.com"
TOKEN_URL = "https://secure.soundcloud.com/oauth/token"
OUT = Path(__file__).resolve().parent.parent / "data" / "playlists.json"


def request(url, headers=None, data=None, retries=3):
    for attempt in range(retries):
        req = urllib.request.Request(url, data=data, headers={"Accept": "application/json", **(headers or {})})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:300]
            if e.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                time.sleep(5 * (attempt + 1))
                continue
            raise SystemExit(f"SoundCloud returned HTTP {e.code} for {url.split('?')[0]}: {body}")
        except urllib.error.URLError as e:
            if attempt < retries - 1:
                time.sleep(5)
                continue
            raise SystemExit(f"Could not reach SoundCloud: {e.reason}")


def get_token():
    cid = os.environ.get("SOUNDCLOUD_CLIENT_ID", "").strip()
    secret = os.environ.get("SOUNDCLOUD_CLIENT_SECRET", "").strip()
    if not cid or not secret:
        raise SystemExit("Missing SOUNDCLOUD_CLIENT_ID or SOUNDCLOUD_CLIENT_SECRET. Add them under Settings > Secrets and variables > Actions.")
    basic = base64.b64encode(f"{cid}:{secret}".encode()).decode()
    data = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode()
    tok = request(TOKEN_URL, {"Authorization": f"Basic {basic}", "Content-Type": "application/x-www-form-urlencoded"}, data)
    return tok["access_token"]


def paged(url, auth):
    """Follow SoundCloud's linked_partitioning pages."""
    while url:
        page = request(url, auth)
        if isinstance(page, list):  # endpoint without pagination
            yield from page
            return
        yield from page.get("collection", [])
        url = page.get("next_href")


def date_of(value):
    # SoundCloud dates look like "2026/11/24 13:33:03 +0000" or ISO 8601.
    for fmt in ("%Y/%m/%d %H:%M:%S %z", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            return datetime.strptime(value, fmt).strftime("%Y-%m-%d")
        except (TypeError, ValueError):
            pass
    return None


def big_artwork(url):
    """SoundCloud artwork URLs end in -large (100x100); -t500x500 is the sharp version."""
    return url.replace("-large.", "-t500x500.") if url else None


# Sections for the Series tab, in display order, with the colour used for designed tiles.
CATEGORIES = [
    ("daf", "Daf Yomi", "#1D4E89"),
    ("halacha", "Halacha", "#0F6B5C"),
    ("machshava", "Machshava & Mussar", "#4C3A8C"),
    ("gemara", "Gemara", "#1F5F8B"),
    ("yomtov", "Yomim Tovim", "#8A4B12"),
    ("more", "More", "#475569"),
]
CATEGORY_WORDS = [
    ("halacha", r"halach|mishnah berurah|basar|semicha|taaruvos"),
    ("yomtov", r"pesach|purim|chanuk|succos|sukkos|shavuos|rosh hashana|yom kippur|elul"),
    ("gemara", r"gemara|bekius"),
    ("machshava", r"machshava|moonlight|chassidus|nesivos|maharal|chovos|chovas|rav kook|mussar|chizuk|tehillim|pirkei avos|emuna"),
]
DAF = re.compile(r"^(\d+)\.\s*Daf Yomi\s*[-–:]\s*(.+)$", re.I)


def describe(title):
    """Section, short name, tile badge and colour for a playlist title."""
    m = DAF.match(title)
    if m:
        return {"category": "daf", "order": int(m.group(1)), "short": m.group(2).strip(), "badge": m.group(1)}
    low = title.lower()
    cat = next((c for c, words in CATEGORY_WORDS if re.search(words, low)), "more")
    words = [w for w in re.split(r"[^A-Za-z']+", title) if w and w.lower() not in {"of", "the", "with", "and", "r", "r'", "rabbi", "dov", "elias", "zakutinsky", "minute"} and not w.isdigit()]
    badge = (words[0][0] + (words[1][0] if len(words) > 1 else words[0][1:2])).upper() if words else "HS"
    return {"category": cat, "order": 0, "short": title, "badge": badge}


def clean_link(url):
    """Drop SoundCloud's tracking parameters (?utm_...) from share links."""
    return urllib.parse.urlsplit(url)._replace(query="", fragment="").geturl() if url else None


def track_json(t, user_permalink):
    tid = t.get("id")
    link = clean_link(t.get("permalink_url"))
    # The API often leaves out "permalink"; it is the last part of the track's web link.
    permalink = t.get("permalink") or (urllib.parse.urlsplit(link).path.rstrip("/").split("/")[-1] if link else "")
    return {
        "id": str(tid),
        "title": (t.get("title") or "").strip(),
        "link": link,
        "date": date_of(t.get("created_at")),
        "duration": round((t.get("duration") or 0) / 1000),
        # Same stream address the podcast feed uses, so the app can play older shiurim too.
        "audio": f"https://feeds.soundcloud.com/stream/{tid}-{user_permalink}-{permalink}.mp3" if permalink else None,
        "artwork": big_artwork(t.get("artwork_url")),
    }


def main():
    auth = {"Authorization": f"OAuth {get_token()}"}
    user = request(f"{API}/users/{USER_ID}", auth)
    user_permalink = user.get("permalink") or "user-964674366-190790323"
    avatar = big_artwork(user.get("avatar_url"))

    playlists = []
    for p in paged(f"{API}/users/{USER_ID}/playlists?linked_partitioning=true&limit=50&show_tracks=false", auth):
        pid = p["id"]
        try:
            tracks = list(paged(f"{API}/playlists/{pid}/tracks?linked_partitioning=true&limit=200", auth))
        except SystemExit:
            # Older API shape: tracks come embedded in the playlist itself.
            tracks = request(f"{API}/playlists/{pid}?show_tracks=true", auth).get("tracks", [])
        items = [track_json(t, user_permalink) for t in tracks if t.get("id")]
        # Only real artwork; the app draws a designed tile when there is none.
        artwork = big_artwork(p.get("artwork_url")) or next((t["artwork"] for t in items if t["artwork"]), None)
        title = (p.get("title") or "").strip()
        info = describe(title)
        playlists.append({
            "id": str(pid),
            "title": title,
            **info,
            "color": next(c for k, _, c in CATEGORIES if k == info["category"]),
            "link": clean_link(p.get("permalink_url")),
            "artwork": artwork,
            "trackCount": p.get("track_count", len(tracks)),
            "lastModified": date_of(p.get("last_modified")),
            "tracks": items,
        })
        print(f"  {p.get('title')}: {len(tracks)} tracks")

    # Daf Yomi newest masechta first; other sections by most recently updated.
    playlists.sort(key=lambda p: ([k for k, _, _ in CATEGORIES].index(p["category"]), -p["order"], "" if not p["lastModified"] else "~" + "".join(chr(255 - ord(ch)) for ch in p["lastModified"])))
    result = {"source": "SoundCloud API", "user": user.get("username"), "avatar": avatar,
              "categories": [{"id": k, "title": t, "color": c} for k, t, c in CATEGORIES], "playlists": playlists}
    old = None
    if OUT.exists():
        old = json.loads(OUT.read_text())
        old.pop("updated", None)
    if old == result:
        print(f"No changes ({len(playlists)} playlists).")
        return
    result["updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=1) + "\n")
    print(f"Wrote {len(playlists)} playlists, {sum(len(p['tracks']) for p in playlists)} tracks to {OUT.name}.")


if __name__ == "__main__":
    sys.exit(main())
