"""Viral Music Drop: adds music to the hub's shared library from this PC.

    python tools/music_drop/music_drop.py        (or the "Viral Music Drop" desktop
                                                   shortcut: python tools/hub.py music-drop --shortcut)

Opens a small app window (Edge app mode, else the default browser) served by
this script on 127.0.0.1 only. Pick audio files, give each a title, genre and
pace, say where it came from and its licence, then "Add to hub":

  1. ffmpeg converts each file here on the PC (STANDARDS §10): OGG Vorbis
     ~96 kbps, loudness levelled to -16 LUFS (true peak -1.5 dB), tags and
     cover art dropped (one exact gain; two-pass loudnorm only when the gain
     would clip). An OGG that already meets that is kept as it is.
  2. The OGG is uploaded to the GitHub release MUSIC_RELEASE_TAG (config.gd,
     "music-v1"), a pre-release, so it never becomes the app's "latest
     release" that the update check reads.
  3. One commit on master adds the tracks to media/music/music.json and their
     licence proofs to media/licenses/music/. Files first, list last (like
     packs and manifest.json).

Phones read music.json live (the Music autoload) and download a track the
first time a game wants that genre / pace -- no APK, pack or Claude needed.
The "Where it plays" tab sets which genres each category / game uses and
which games get background music by themselves (music.json "play").

GitHub access is the GitHub CLI's login (`gh auth token`); the token is never
shown or written anywhere. Needs ffmpeg + ffprobe (%LOCALAPPDATA%\\Programs\\
ffmpeg\\bin, or on PATH). Standard library only.

    --fake DIR   test mode: "GitHub" is a folder (nothing leaves the PC)
    --no-open    don't open a window (print the address instead)
"""

from __future__ import annotations

import base64
import datetime as dt
import hashlib
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import threading
import time
import traceback
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HTML = Path(__file__).with_name("music_drop.html")
CONFIG_GD = ROOT / "scripts/common/config.gd"
LIST_PATH = "media/music/music.json"
PROOF_DIR = "media/licenses/music"
APP_DIR = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "ViralMusicDrop"
WORK = APP_DIR / "work"
INSTANCE = APP_DIR / "instance.json"
LOG = APP_DIR / "music_drop.log"
FIRST_PORT = 8765

# STANDARDS §10: OGG Vorbis, music ~96 kbps, loudness ~ -16 LUFS integrated.
TARGET_LUFS = -16.0
TRUE_PEAK = -1.5
LRA = 11.0
VORBIS_QUALITY = 2       # libvorbis -q:a 2 = ~96 kbps nominal at 44.1 kHz stereo
KEEP_MAX_KBPS = 128      # an OGG Vorbis at most this big ...
KEEP_LUFS_SLACK = 1.0    # ... and within this of the target is kept untouched
MAX_INPUT = 400 * 1024 * 1024
MAX_PROOF = 20 * 1024 * 1024
MAX_TRACK = 60 * 1024 * 1024
PROOF_EXT = {".pdf", ".png", ".jpg", ".jpeg", ".webp", ".txt", ".md", ".html", ".htm", ".eml"}

PACES = ["slow", "moderate", "fast"]
BASE_GENRES = ["Classical", "Ambient", "Lo-fi", "Jazz", "Electronic", "Synthwave", "Techno",
               "Chiptune", "Rock", "Metal", "Orchestral", "Latin", "Other"]
# STANDARDS §10: own work, CC0, CC-BY; royalty-free / bought need their written
# licence on file; never NC or ND. AI tracks: the tool's plan must allow
# commercial use (HUB_V2_PLAN §5.6).
LICENCES = {
    "own": "Own work (Viral)",
    "cc0": "CC0 1.0 (public domain)",
    "cc-by": "CC BY 4.0 (credit shown in the app)",
    "cc-by-3": "CC BY 3.0 (credit shown in the app)",
    "royalty-free": "Royalty-free licence",
    "bought": "Bought / commissioned (written licence)",
    "ai": "AI-generated",
}
CC_BY = ("cc-by", "cc-by-3")
# Freesound (freesound.org) names a download "<id>__<user>__<name>.<ext>", and
# its licence file (the "attribution" text) has one line per sound:
#   "<name> by <user> -- https://freesound.org/s/<id>/ -- License: <licence>"
# Attaching that file as the proof fills in each matching track's credit.
FREESOUND_FILE = re.compile(r"^(\d+)__(.+?)__(.+)$")
FREESOUND_LINE = re.compile(r"^(?P<title>.+?) by (?P<author>.+?) -- (?P<url>https?://freesound\.org/s/(?P<id>\d+)/?)"
                            r" -- License: (?P<lic>.+?)\s*$", re.M)
FREESOUND_LICENCES = {"Attribution 4.0": "cc-by", "Attribution 3.0": "cc-by-3", "Creative Commons 0": "cc0"}
AUDIO_EXT = re.compile(r"\.(ogg|oga|mp3|wav|flac|m4a|aac|opus|aiff?|wma)$", re.I)
LONG_TRACK_SEC = 600
# Music autoload styles <-> paces (scripts/common/music.gd).
STYLES = {"calm": "slow", "lively": "moderate", "techno": "fast"}

NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


class DropError(Exception):
    pass


def log(msg: str) -> None:
    line = f"{dt.datetime.now():%H:%M:%S}  {msg}"
    try:
        print(line, flush=True)
    except Exception:  # noqa: BLE001 -- pythonw has no console
        pass
    try:
        with LOG.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def read_config() -> dict[str, str]:
    text = CONFIG_GD.read_text(encoding="utf-8")
    cfg = dict(re.findall(r'^const (\w+) := "([^"]*)"\s*$', text, re.M))
    cfg.setdefault("MUSIC_RELEASE_TAG", "music-v1")
    return cfg


def slugify(s: str, fallback: str = "track") -> str:
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return s or fallback


def build_credit(c: dict, title: str, label: str, proof_path: str) -> dict:
    """A track's credit from the page's fields, checked like hub.py's
    lint_music (STANDARDS §10). Raises DropError naming what's missing."""
    lic = str(c.get("licence", ""))
    if lic not in LICENCES:
        raise DropError(f"{label}: pick its licence")
    author = str(c.get("author", "")).strip() or ("Viral" if lic == "own" else "")
    if not author:
        raise DropError(f"{label}: who made it? (author / artist)")
    if lic == "ai" and not (str(c.get("ai_tool", "")).strip() and str(c.get("ai_plan", "")).strip()):
        raise DropError(f"{label}: AI tracks need the tool and the plan it was made on")
    if lic in CC_BY and not str(c.get("url", "")).strip():
        raise DropError(f"{label}: CC BY needs a link to the original")
    if not c.get("commercial_ok"):
        raise DropError(f"{label}: tick that its licence allows use in a commercial app")
    if not str(proof_path).startswith("media/licenses/"):
        raise DropError(f"{label}: attach the licence proof (or pick one already on file)")
    lic_name = LICENCES[lic].split(" (")[0]
    return {
        "author": author[:120], "licence": lic, "licence_name": lic_name,
        "source": str(c.get("source", "")).strip()[:200], "url": str(c.get("url", "")).strip()[:300],
        "ai_tool": str(c.get("ai_tool", "")).strip()[:120] if lic == "ai" else "",
        "ai_plan": str(c.get("ai_plan", "")).strip()[:120] if lic == "ai" else "",
        "commercial_ok": True, "proof": proof_path,
        "text": f"“{title}” by {author} — {lic_name}",
    }


def freesound_credits(text: str) -> dict[str, dict]:
    """Freesound's licence file -> {sound id: {title, author, url, licence, licence_text}}.
    licence is "" when Freesound's licence isn't one the hub may use (NC,
    Sampling+...)."""
    out = {}
    for m in FREESOUND_LINE.finditer(text):
        lic = m["lic"].strip()
        out[m["id"]] = {"title": AUDIO_EXT.sub("", m["title"].strip()), "author": m["author"].strip(),
                        "url": f"https://freesound.org/s/{m['id']}/", "source": "Freesound",
                        "licence": FREESOUND_LICENCES.get(lic, ""), "licence_text": lic}
    return out


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def empty_list(cfg: dict[str, str]) -> dict:
    return {
        "_readme": "The hub's shared music library -- written by tools/music_drop (Viral Music Drop). "
                   "Each track's OGG lives on the GitHub release named in base_url; phones download a "
                   "track the first time a game wants its genre / pace (scripts/common/music_library.gd). "
                   "pace: slow | moderate | fast = the Music styles calm | lively | techno. "
                   "play: where music plays -- \"hub\", \"category:<English name>\", \"game:<id>\" -> "
                   "{style: \"\" (the game decides) | calm | lively | techno (plays by itself) | off, "
                   "genres: [] (any)}; field by field, a game's own entry wins over its category's.",
        "format": 1,
        "base_url": f"https://github.com/{cfg['GITHUB_OWNER']}/{cfg['GITHUB_REPO']}/releases/download/"
                    f"{cfg['MUSIC_RELEASE_TAG']}/",
        "updated": "",
        "genres": [],
        "tracks": [],
        # Games whose own sounds need the player's ears never get background
        # music: Memory Lights (the tones are the game), the IQ Test (musical
        # questions). "off" also silences a game's own Music calls, so never
        # set it on a game that plays the library itself (Neon Blast, Sky
        # Strike). The owner can change these in "Where it plays".
        "play": {"game:simon": {"style": "off", "genres": []},
                 "game:voodoo_iq": {"style": "off", "genres": []}},
    }


# ---------------------------------------------------------------- ffmpeg

def find_tool(name: str) -> str | None:
    local = Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "ffmpeg" / "bin" / f"{name}.exe"
    for c in (str(local), shutil.which(name)):
        if c and Path(c).is_file():
            return c
    return None


def run(cmd: list[str], timeout: int = 900) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                          timeout=timeout, creationflags=NO_WINDOW)


def probe(path: Path) -> dict:
    p = run([find_tool("ffprobe") or "ffprobe", "-v", "error", "-show_format", "-show_streams",
             "-of", "json", str(path)], timeout=120)
    if p.returncode != 0:
        why = (p.stderr.strip().splitlines() or ["unknown error"])[-1].replace(str(path) + ": ", "")
        raise DropError(f"not an audio file ffmpeg can read ({why})")
    data = json.loads(p.stdout or "{}")
    audio = [s for s in data.get("streams", []) if s.get("codec_type") == "audio"]
    if not audio:
        raise DropError("no audio in this file")
    a = audio[0]
    fmt = data.get("format", {})
    duration = float(a.get("duration") or fmt.get("duration") or 0)
    size = int(fmt.get("size") or path.stat().st_size)
    tags = {k.lower(): v for k, v in (fmt.get("tags") or {}).items()}
    tags.update({k.lower(): v for k, v in (a.get("tags") or {}).items()})
    return {
        "codec": a.get("codec_name", "?"),
        "rate": int(a.get("sample_rate") or 0),
        "channels": int(a.get("channels") or 0),
        "duration": duration,
        "kbps": round(size * 8 / duration / 1000) if duration > 0 else 0,
        "streams": len(data.get("streams", [])),
        "format": fmt.get("format_name", ""),
        "title": tags.get("title", ""),
        "artist": tags.get("artist", "") or tags.get("album_artist", ""),
    }


def _loudnorm_json(stderr: str) -> dict:
    blocks = re.findall(r"\{[^{}]*\}", stderr)
    if not blocks:
        raise DropError("ffmpeg didn't report the loudness")
    data = json.loads(blocks[-1])
    for k in ("input_i", "input_tp", "input_lra", "input_thresh"):
        try:
            float(data[k])
        except (KeyError, ValueError):
            raise DropError("the track is silent or too short to measure") from None
    return data


def measure(path: Path) -> tuple[float, float]:
    """(integrated loudness LUFS, true peak dBTP) -- EBU R128, ~3x faster than loudnorm."""
    p = run([find_tool("ffmpeg") or "ffmpeg", "-hide_banner", "-nostdin", "-nostats", "-i", str(path),
             "-map", "0:a:0", "-af", "ebur128=peak=true:framelog=verbose", "-f", "null", "-"])
    if p.returncode != 0:
        raise DropError("ffmpeg couldn't decode it: " + (p.stderr.strip().splitlines() or ["?"])[-1])
    summary = p.stderr[p.stderr.rfind("Summary:"):]
    i = re.search(r"I:\s+(-?[\d.]+|-inf) LUFS", summary)
    peak = re.search(r"Peak:\s+(-?[\d.]+|-inf) dBFS", summary)
    if not i or not peak or "inf" in i.group(1):
        raise DropError("the track is silent or too short to measure")
    return float(i.group(1)), (float(peak.group(1)) if "inf" not in peak.group(1) else -99.0)


def _loudnorm_args(src: Path) -> str:
    """Two-pass loudnorm (dynamic) -- only for tracks a plain gain can't
    bring up to the target without clipping."""
    p = run([find_tool("ffmpeg") or "ffmpeg", "-hide_banner", "-nostdin", "-nostats", "-i", str(src),
             "-map", "0:a:0", "-af", f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA={LRA}:print_format=json",
             "-f", "null", "-"])
    m = _loudnorm_json(p.stderr)
    return (f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA={LRA}"
            f":measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}"
            f":measured_thresh={m['input_thresh']}:offset={m.get('target_offset', '0.0')}")


def convert(src: Path, out: Path) -> dict:
    """src -> out (.ogg): kept as-is when it already meets the standard, else
    re-encoded with one exact gain (loudness to TARGET_LUFS, true peak kept
    under TRUE_PEAK). A track the gain can't lift far enough without
    clipping (quiet with big peaks) gets two-pass loudnorm instead.
    Returns the report."""
    info = probe(src)
    if info["duration"] < 5:
        raise DropError("shorter than 5 seconds -- this is for music tracks")
    lufs, tp = measure(src)
    keep = (info["codec"] == "vorbis" and src.suffix.lower() == ".ogg" and info["streams"] == 1
            and info["channels"] <= 2 and info["kbps"] <= KEEP_MAX_KBPS
            and abs(lufs - TARGET_LUFS) <= KEEP_LUFS_SLACK and tp <= TRUE_PEAK + 0.5)
    method = "kept"
    if keep:
        shutil.copyfile(src, out)
        out_lufs, out_tp = lufs, tp
    else:
        gain = min(TARGET_LUFS - lufs, TRUE_PEAK - tp)
        if TARGET_LUFS - lufs - gain > 2.0:
            af, method = _loudnorm_args(src), "loudnorm"
        else:
            af, method = f"volume={gain:.2f}dB", "gain"
        rate = info["rate"] if 0 < info["rate"] <= 48000 else 48000
        p = run([find_tool("ffmpeg") or "ffmpeg", "-hide_banner", "-nostdin", "-nostats", "-y",
                 "-i", str(src), "-map", "0:a:0", "-vn", "-sn", "-dn", "-map_metadata", "-1",
                 "-af", af, "-ar", str(rate), "-ac", str(min(max(info["channels"], 1), 2)),
                 "-c:a", "libvorbis", "-q:a", str(VORBIS_QUALITY), str(out)])
        if p.returncode != 0 or not out.is_file():
            raise DropError("ffmpeg couldn't convert it: " + (p.stderr.strip().splitlines() or ["?"])[-1])
        # A plain gain moves loudness and peak by exactly that much (the
        # encoder adds < 0.2 dB). loudnorm can fall short: measure it.
        out_lufs, out_tp = (lufs + gain, tp + gain) if method == "gain" else measure(out)
    after = probe(out)
    size = out.stat().st_size
    warns = []
    if abs(out_lufs - TARGET_LUFS) > 1.5:
        warns.append(f"ends up at {out_lufs:.1f} LUFS, not {TARGET_LUFS:.0f}: it has peaks far above its average, "
                     "so it will play quieter than the other tracks")
    if after["duration"] > LONG_TRACK_SEC:
        warns.append(f"it's {int(after['duration'] // 60)}:{int(after['duration'] % 60):02d} long, so a phone "
                     f"downloads {size / 1048576:.1f} MB the first time it plays")
    warn = "; ".join(warns)
    if size > MAX_TRACK:
        raise DropError(f"the converted file is {size / 1048576:.0f} MB -- too long for a game track")
    return {
        "kept": keep,
        "method": method,
        "warn": warn,
        "duration": round(after["duration"], 1),
        "size": size,
        "sha256": sha256_of(out),
        "in": {"codec": info["codec"], "kbps": info["kbps"], "rate": info["rate"], "channels": info["channels"],
               "lufs": round(lufs, 1), "tp": round(tp, 1)},
        "out": {"kbps": after["kbps"], "rate": after["rate"], "channels": after["channels"],
                "lufs": round(out_lufs, 1), "tp": round(out_tp, 1)},
        "title": info["title"],
        "artist": info["artist"],
    }


# ---------------------------------------------------------------- GitHub

class GitHubError(DropError):
    def __init__(self, status: int, message: str):
        super().__init__(f"GitHub {status}: {message}")
        self.status = status


def gh_exe() -> str | None:
    for c in (r"C:\Program Files\GitHub CLI\gh.exe", shutil.which("gh")):
        if c and Path(c).is_file():
            return c
    return None


def gh_token() -> str:
    exe = gh_exe()
    if not exe:
        raise DropError("GitHub CLI (gh) not found -- install it, then run `gh auth login` once")
    p = run([exe, "auth", "token"], timeout=30)
    token = p.stdout.strip()
    if p.returncode != 0 or not token:
        raise DropError("GitHub CLI isn't signed in -- run `gh auth login` in a terminal once")
    return token


class GitHub:
    """The few GitHub REST calls the tool needs (contents, git data, releases)."""

    API = "https://api.github.com"
    UPLOADS = "https://uploads.github.com"

    def __init__(self, owner: str, repo: str, branch: str):
        self.owner, self.repo, self.branch = owner, repo, branch
        self._token = gh_token()
        self.base = f"/repos/{owner}/{repo}"

    def call(self, method: str, path: str, body=None, data: bytes | None = None,
             content_type: str | None = None, accept: str = "application/vnd.github+json",
             host: str | None = None, allow404: bool = False, raw: bool = False, timeout: int = 60):
        url = (host or self.API) + path
        headers = {"Authorization": "Bearer " + self._token, "Accept": accept,
                   "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "viral-music-drop"}
        if body is not None:
            data = json.dumps(body).encode()
            content_type = "application/json"
        if content_type:
            headers["Content-Type"] = content_type
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                payload = r.read()
        except urllib.error.HTTPError as e:
            if e.code == 404 and allow404:
                return None
            try:
                msg = json.loads(e.read() or b"{}").get("message", "")
            except ValueError:
                msg = ""
            raise GitHubError(e.code, msg or e.reason) from None
        except urllib.error.URLError as e:
            raise DropError(f"can't reach GitHub ({e.reason}) -- check the internet connection") from None
        if raw:
            return payload
        return json.loads(payload) if payload else None

    # -- reading
    def whoami(self) -> str:
        return self.call("GET", "/user")["login"]

    def can_push(self) -> bool:
        info = self.call("GET", self.base)
        return bool(info.get("permissions", {}).get("push"))

    def head(self) -> str:
        return self.call("GET", f"{self.base}/git/ref/heads/{urllib.parse.quote(self.branch)}")["object"]["sha"]

    def read(self, path: str, ref: str | None = None) -> bytes | None:
        q = urllib.parse.quote(path)
        return self.call("GET", f"{self.base}/contents/{q}?ref={ref or self.branch}",
                         accept="application/vnd.github.raw+json", allow404=True, raw=True)

    def list_dir(self, path: str) -> list[str]:
        items = self.call("GET", f"{self.base}/contents/{urllib.parse.quote(path)}?ref={self.branch}",
                          allow404=True) or []
        return [i["path"] for i in items if isinstance(i, dict) and i.get("type") == "file"]

    # -- writing: one commit with several files
    def commit(self, files: dict[str, bytes], message: str, parent: str) -> str:
        base_tree = self.call("GET", f"{self.base}/git/commits/{parent}")["tree"]["sha"]
        entries = []
        for path, content in files.items():
            blob = self.call("POST", f"{self.base}/git/blobs",
                             body={"content": base64.b64encode(content).decode(), "encoding": "base64"},
                             timeout=300)
            entries.append({"path": path, "mode": "100644", "type": "blob", "sha": blob["sha"]})
        tree = self.call("POST", f"{self.base}/git/trees", body={"base_tree": base_tree, "tree": entries})
        c = self.call("POST", f"{self.base}/git/commits",
                      body={"message": message, "tree": tree["sha"], "parents": [parent]})
        # Not forced: if master moved meanwhile this fails (422) and the caller retries.
        self.call("PATCH", f"{self.base}/git/refs/heads/{urllib.parse.quote(self.branch)}",
                  body={"sha": c["sha"], "force": False})
        return c["sha"]

    def commit_url(self, sha: str) -> str:
        return f"https://github.com/{self.owner}/{self.repo}/commit/{sha}"

    # -- the music release
    def release(self, tag: str, create: bool) -> dict | None:
        rel = self.call("GET", f"{self.base}/releases/tags/{urllib.parse.quote(tag)}", allow404=True)
        if rel is None and create:
            rel = self.call("POST", f"{self.base}/releases", body={
                "tag_name": tag, "target_commitish": self.branch, "name": "Music library",
                "body": "The hub's shared music tracks (OGG), added with tools/music_drop. "
                        "The list is media/music/music.json; phones download a track when a game needs it. "
                        "Pre-release on purpose: the app's update check reads the latest release.",
                "prerelease": True, "make_latest": "false"})
        return rel

    def assets(self, rel: dict) -> dict[str, dict]:
        out, page = {}, 1
        while True:
            batch = self.call("GET", f"{self.base}/releases/{rel['id']}/assets?per_page=100&page={page}")
            for a in batch:
                out[a["name"]] = a
            if len(batch) < 100:
                return out
            page += 1

    def upload(self, rel: dict, name: str, data: bytes) -> dict:
        return self.call("POST", f"{self.base}/releases/{rel['id']}/assets?name={urllib.parse.quote(name)}",
                         data=data, content_type="audio/ogg", host=self.UPLOADS, timeout=900)


class FakeGitHub:
    """--fake DIR: the same calls against a folder, for testing the whole flow
    without touching the real repo. DIR/repo/<path> is the branch,
    DIR/release/<name> the release assets."""

    def __init__(self, folder: Path, cfg: dict[str, str]):
        self.dir = folder
        (folder / "repo").mkdir(parents=True, exist_ok=True)
        self.owner, self.repo, self.branch = cfg["GITHUB_OWNER"], cfg["GITHUB_REPO"], cfg["GITHUB_BRANCH"]
        self._n = 0
        manifest = folder / "repo" / "manifest.json"
        if not manifest.exists():
            shutil.copyfile(ROOT / "manifest.json", manifest)

    def whoami(self) -> str:
        return "fake-user"

    def can_push(self) -> bool:
        return True

    def head(self) -> str:
        f = self.dir / "head.txt"
        return f.read_text() if f.exists() else "0" * 40

    def read(self, path: str, ref: str | None = None) -> bytes | None:
        f = self.dir / "repo" / path
        return f.read_bytes() if f.is_file() else None

    def list_dir(self, path: str) -> list[str]:
        d = self.dir / "repo" / path
        return sorted(f"{path}/{f.name}" for f in d.iterdir() if f.is_file()) if d.is_dir() else []

    def commit(self, files: dict[str, bytes], message: str, parent: str) -> str:
        if parent != self.head():
            raise GitHubError(422, "Update is not a fast forward")
        for path, content in files.items():
            f = self.dir / "repo" / path
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_bytes(content)
        sha = hashlib.sha1(f"{time.time()}{message}".encode()).hexdigest()
        (self.dir / "head.txt").write_text(sha)
        with (self.dir / "commits.log").open("a", encoding="utf-8") as f:
            f.write(f"{sha} {message} {sorted(files)}\n")
        return sha

    def commit_url(self, sha: str) -> str:
        return (self.dir / "commits.log").as_uri()

    def release(self, tag: str, create: bool) -> dict | None:
        d = self.dir / "release"
        if not d.is_dir():
            if not create:
                return None
            d.mkdir()
        return {"id": 1, "tag_name": tag}

    def assets(self, rel: dict) -> dict[str, dict]:
        d = self.dir / "release"
        return {f.name: {"name": f.name, "size": f.stat().st_size} for f in d.iterdir()} if d.is_dir() else {}

    def upload(self, rel: dict, name: str, data: bytes) -> dict:
        (self.dir / "release" / name).write_bytes(data)
        return {"name": name, "size": len(data)}


# ---------------------------------------------------------------- the library

class Drop:
    def __init__(self, fake: Path | None):
        self.cfg = read_config()
        self.fake = fake
        self._gh = None
        self.work: dict[str, dict] = {}     # prepared tracks and proofs, by work id
        self.jobs: dict[str, dict] = {}
        self.publish_lock = threading.Lock()
        WORK.mkdir(parents=True, exist_ok=True)
        for f in WORK.iterdir():            # leftovers from earlier runs
            if f.is_file() and time.time() - f.stat().st_mtime > 24 * 3600:
                f.unlink(missing_ok=True)

    @property
    def gh(self):
        if self._gh is None:
            self._gh = (FakeGitHub(self.fake, self.cfg) if self.fake
                        else GitHub(self.cfg["GITHUB_OWNER"], self.cfg["GITHUB_REPO"], self.cfg["GITHUB_BRANCH"]))
        return self._gh

    def read_list(self, ref: str | None = None) -> dict:
        raw = self.gh.read(LIST_PATH, ref)
        if raw is None:
            return empty_list(self.cfg)
        try:
            data = json.loads(raw.decode("utf-8"))
        except ValueError:
            raise DropError(f"{LIST_PATH} on GitHub isn't valid JSON -- fix it there first") from None
        base = empty_list(self.cfg)
        for k, v in base.items():
            data.setdefault(k, v)
        return data

    # -- state for the page
    def state(self) -> dict:
        out = {"repo": f"{self.cfg['GITHUB_OWNER']}/{self.cfg['GITHUB_REPO']}", "branch": self.cfg["GITHUB_BRANCH"],
               "release": self.cfg["MUSIC_RELEASE_TAG"], "fake": bool(self.fake),
               "ffmpeg": bool(find_tool("ffmpeg") and find_tool("ffprobe")),
               "paces": PACES, "base_genres": [{"id": slugify(g), "name": g} for g in BASE_GENRES],
               "licences": LICENCES, "styles": STYLES,
               "target": {"lufs": TARGET_LUFS, "tp": TRUE_PEAK, "quality": VORBIS_QUALITY}}
        try:
            out["user"] = self.gh.whoami()
            out["can_push"] = self.gh.can_push()
            out["list"] = self.read_list()
            out["categories"] = self._categories()
            out["proofs"] = sorted(set(self.gh.list_dir("media/licenses") + self.gh.list_dir(PROOF_DIR)))
        except DropError as e:
            out["error"] = str(e)
        return out

    def _categories(self) -> list[dict]:
        raw = self.gh.read("manifest.json")
        if raw is None:
            return []
        m = json.loads(raw.decode("utf-8"))
        games = m.get("games", {})
        cats = []
        for c in m.get("categories", []):
            if c.get("archived"):
                continue
            items = []
            for g in c.get("games", []):
                gid = g if isinstance(g, str) else g.get("id", "")
                entry = games.get(gid, {})
                if not gid or entry.get("archived") or (isinstance(g, dict) and g.get("archived")):
                    continue
                title = (g.get("title") if isinstance(g, dict) else None) or entry.get("title") or gid
                items.append({"id": gid, "title": title})
            cats.append({"name": c.get("name", ""), "games": items})
        return cats

    # -- converting
    def prepare(self, name: str, data: bytes) -> dict:
        wid = uuid.uuid4().hex[:12]
        ext = Path(name).suffix.lower() or ".bin"
        src = WORK / f"{wid}-in{ext}"
        src.write_bytes(data)
        # Duplicates are spotted by the file as picked: every Vorbis encode
        # gets a random stream serial, so the OGG's own hash differs each time.
        src_sha = hashlib.sha256(data).hexdigest()
        out = WORK / f"{wid}.ogg"
        try:
            rep = convert(src, out)
        finally:
            src.unlink(missing_ok=True)
        stem = Path(name).stem
        fs = FREESOUND_FILE.match(stem)
        freesound = None
        if fs:
            # A Freesound download: its id says where it came from. The name
            # and user in a file name are squashed (lowercase, no dots), so the
            # licence file, once attached, gives the exact ones.
            freesound = {"id": fs[1], "user": fs[2], "url": f"https://freesound.org/s/{fs[1]}/",
                         "title": re.sub(r"[-_]+", " ", fs[3]).strip()}
        guess = rep["title"] or (freesound["title"] if freesound else
                                 re.sub(r"\s+", " ", re.sub(r"[_]+", " ", stem)).strip())
        self.work[wid] = {"kind": "track", "path": out, "name": name, "src_sha256": src_sha, **rep}
        log(f"prepared {name}: {rep['in']['codec']} {rep['in']['kbps']} kbps {rep['in']['lufs']} LUFS -> "
            f"{'kept' if rep['kept'] else 'ogg'} {rep['out']['kbps']} kbps {rep['out']['lufs']} LUFS")
        return {"work": wid, "name": name, "title": guess[:80], "freesound": freesound,
                **{k: v for k, v in rep.items() if k != "title"}}

    def add_proof(self, name: str, data: bytes) -> dict:
        ext = Path(name).suffix.lower()
        if ext not in PROOF_EXT:
            raise DropError(f"proof must be one of {', '.join(sorted(PROOF_EXT))}")
        if len(data) > MAX_PROOF:
            raise DropError("proof file over 20 MB")
        wid = uuid.uuid4().hex[:12]
        path = WORK / f"{wid}-proof{ext}"
        path.write_bytes(data)
        sha = hashlib.sha256(data).hexdigest()
        safe = slugify(Path(name).stem, "licence")[:50] + ext
        self.work[wid] = {"kind": "proof", "path": path, "name": name, "sha256": sha,
                          "repo_path": f"{PROOF_DIR}/{sha[:8]}-{safe}"}
        fs = freesound_credits(data.decode("utf-8", "replace")) if ext in (".txt", ".md", ".html", ".htm") else {}
        return {"work": wid, "name": name, "path": self.work[wid]["repo_path"], "freesound": fs}

    # -- jobs (publishing runs in the background; the page polls)
    def start_job(self, fn, *args) -> str:
        jid = uuid.uuid4().hex[:10]
        job = {"state": "running", "log": [], "result": None}
        self.jobs[jid] = job

        def say(msg):
            job["log"].append(msg)
            log(msg)

        def body():
            if not self.publish_lock.acquire(blocking=False):
                job["state"], job["error"] = "error", "another change is still being sent -- wait for it"
                return
            try:
                job["result"] = fn(say, *args)
                job["state"] = "done"
            except DropError as e:
                job["state"], job["error"] = "error", str(e)
                say("Stopped: " + str(e))
            except Exception as e:  # noqa: BLE001 -- report anything to the page
                job["state"], job["error"] = "error", f"unexpected error: {e}"
                log(traceback.format_exc())
            finally:
                self.publish_lock.release()

        threading.Thread(target=body, daemon=True).start()
        return jid

    def _change_list(self, say, mutate, message: str, files: dict[str, bytes] | None = None) -> dict:
        """Reads music.json at master's head, applies mutate(list), commits it
        (+ files) on top; retries if master moved meanwhile."""
        for attempt in range(4):
            head = self.gh.head()
            data = self.read_list(head)
            note = mutate(data)
            data["updated"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            content = (json.dumps(data, ensure_ascii=False, indent=1) + "\n").encode("utf-8")
            try:
                sha = self.gh.commit({**(files or {}), LIST_PATH: content}, message, head)
            except GitHubError as e:
                if e.status in (409, 422) and attempt < 3:
                    say("Master changed meanwhile -- trying again on top of it...")
                    continue
                raise
            say(f"Committed {sha[:7]} on {self.cfg['GITHUB_BRANCH']}.")
            return {"commit": sha, "url": self.gh.commit_url(sha), "list": data, "note": note}
        raise DropError("master kept changing -- try again in a minute")

    def publish(self, say, items: list[dict], genres: list[dict]) -> dict:
        if not items:
            raise DropError("nothing to add")
        known = {g["id"]: g["name"] for g in genres if g.get("id")}
        for g in BASE_GENRES:
            known.setdefault(slugify(g), g)
        tracks, proofs = [], {}
        for n, it in enumerate(items, 1):
            w = self.work.get(str(it.get("work")))
            if not w or w["kind"] != "track" or not Path(w["path"]).is_file():
                raise DropError(f"track {n}: the converted file is gone -- add it again")
            label = f"\"{it.get('title') or w['name']}\""
            title = str(it.get("title", "")).strip()
            genre, pace = str(it.get("genre", "")), str(it.get("pace", ""))
            if not title:
                raise DropError(f"track {n}: no title")
            if genre not in known:
                raise DropError(f"{label}: pick a genre")
            if pace not in PACES:
                raise DropError(f"{label}: pick a pace")
            pr = it.get("proof") or {}
            proof_path = str(pr.get("path", ""))
            if pr.get("work"):
                pw = self.work.get(str(pr["work"]))
                if not pw or pw["kind"] != "proof":
                    raise DropError(f"{label}: the proof file is gone -- attach it again")
                proof_path = pw["repo_path"]
            credit = build_credit(it.get("credit") or {}, title, label, proof_path)
            if pr.get("work"):
                proofs[proof_path] = Path(self.work[str(pr["work"])]["path"]).read_bytes()
            try:
                loop = max(0.0, min(float(it.get("loop_start") or 0), float(w["duration"]) - 1))
            except (TypeError, ValueError):
                loop = 0.0
            tid = f"{genre}-{pace}-{slugify(title)[:40]}-{w['sha256'][:8]}"
            tracks.append({"work": w, "entry": {
                "id": tid, "title": title[:80], "genre": genre, "pace": pace, "file": tid + ".ogg",
                "size": w["size"], "sha256": w["sha256"], "src_sha256": w["src_sha256"], "duration": w["duration"],
                "lufs": w["out"]["lufs"], "loop_start": round(loop, 2),
                "added": dt.date.today().isoformat(), "credit": credit}})

        say("Reading the library on GitHub...")
        current = self.read_list()
        have = {}
        for t in current.get("tracks", []):
            for k in ("sha256", "src_sha256"):
                if t.get(k):
                    have[t[k]] = t.get("title", "?")
        todo = []
        for t in tracks:
            e = t["entry"]
            dup = have.get(e["src_sha256"]) or have.get(e["sha256"])
            if dup:
                say(f"\"{e['title']}\" is already in the library as \"{dup}\" -- skipped.")
            else:
                have[e["src_sha256"]] = e["title"]  # the same file twice in one batch
                todo.append(t)
        if not todo:
            return {"added": [], "skipped": len(tracks)}

        rel = self.gh.release(self.cfg["MUSIC_RELEASE_TAG"], create=True)
        assets = self.gh.assets(rel)
        for t in todo:
            e = t["entry"]
            a = assets.get(e["file"])
            if a and int(a.get("size", -1)) == e["size"]:
                say(f"\"{e['title']}\" is already uploaded.")
                continue
            if a:
                raise DropError(f"release already has a different {e['file']} -- rename the track")
            say(f"Uploading \"{e['title']}\" ({e['size'] / 1048576:.1f} MB)...")
            self.gh.upload(rel, e["file"], Path(t["work"]["path"]).read_bytes())

        entries = [t["entry"] for t in todo]
        used = {e["genre"] for e in entries}

        def mutate(data):
            ids = {t.get(k) for t in data["tracks"] for k in ("sha256", "src_sha256")} - {None}
            new = [e for e in entries if e["sha256"] not in ids and e["src_sha256"] not in ids]
            data["tracks"] = sorted(data["tracks"] + new,
                                    key=lambda t: (t.get("genre", ""), PACES.index(t["pace"]) if t.get("pace") in PACES else 9,
                                                   t.get("title", "").lower()))
            have_g = {g.get("id") for g in data["genres"]}
            for gid in sorted(used - have_g):
                data["genres"].append({"id": gid, "name": known[gid]})
            return len(new)

        msg = (f"Music: add \"{entries[0]['title']}\" ({entries[0]['genre']}, {entries[0]['pace']})" if len(entries) == 1
               else f"Music: add {len(entries)} tracks")
        say("Adding to the list (media/music/music.json)...")
        res = self._change_list(say, mutate, msg, proofs)
        for t in todo:
            Path(t["work"]["path"]).unlink(missing_ok=True)
            self.work.pop(next(k for k, v in self.work.items() if v is t["work"]), None)
        res["added"] = [e["id"] for e in entries]
        res["skipped"] = len(tracks) - len(todo)
        return res

    def edit(self, say, tid: str, changes: dict, genres: list[dict]) -> dict:
        known = {g["id"]: g["name"] for g in genres if g.get("id")}
        for g in BASE_GENRES:
            known.setdefault(slugify(g), g)

        def mutate(data):
            t = next((t for t in data["tracks"] if t.get("id") == tid), None)
            if t is None:
                raise DropError("that track isn't in the library any more")
            if "title" in changes and str(changes["title"]).strip():
                t["title"] = str(changes["title"]).strip()[:80]
            # The credit: the changed fields over the stored ones, checked
            # like a new track (and its text rebuilt for a new title).
            credit = dict(t.get("credit") or {})
            credit.update(changes.get("credit") or {})
            t["credit"] = build_credit(credit, t["title"], f"\"{t['title']}\"", str(credit.get("proof", "")))
            if changes.get("genre") in known:
                t["genre"] = changes["genre"]
                if not any(g.get("id") == t["genre"] for g in data["genres"]):
                    data["genres"].append({"id": t["genre"], "name": known[t["genre"]]})
            if changes.get("pace") in PACES:
                t["pace"] = changes["pace"]
            if "loop_start" in changes:
                try:
                    t["loop_start"] = round(max(0.0, min(float(changes["loop_start"]), float(t["duration"]) - 1)), 2)
                except (TypeError, ValueError):
                    pass
            return t["title"]

        say("Saving the change...")
        return self._change_list(say, mutate, f"Music: edit \"{tid}\"")

    def remove(self, say, tid: str) -> dict:
        def mutate(data):
            before = len(data["tracks"])
            data["tracks"] = [t for t in data["tracks"] if t.get("id") != tid]
            if len(data["tracks"]) == before:
                raise DropError("that track isn't in the library any more")
            return tid

        say("Removing it from the list (the uploaded file stays on the release)...")
        return self._change_list(say, mutate, f"Music: remove \"{tid}\"")

    def set_play(self, say, play: dict) -> dict:
        clean = {}
        for key, v in (play or {}).items():
            if not re.match(r"^(hub|category:.+|game:[a-z][a-z0-9_]*)$", str(key)) or not isinstance(v, dict):
                continue
            style = str(v.get("style", ""))
            if style not in ("", "off", *STYLES):
                continue
            gs = sorted({str(g) for g in v.get("genres", []) if re.match(r"^[a-z0-9-]+$", str(g))})
            if style or gs:
                clean[key] = {"style": style, "genres": gs}

        def mutate(data):
            data["play"] = dict(sorted(clean.items()))
            return len(clean)

        say("Saving where music plays...")
        return self._change_list(say, mutate, "Music: where it plays")


# ---------------------------------------------------------------- web server

class Handler(BaseHTTPRequestHandler):
    drop: Drop = None
    key = ""
    port = 0
    last_ping = [0.0]
    server_version = "ViralMusicDrop"

    def log_message(self, fmt, *args):  # quiet: the log has what matters
        pass

    def _host_ok(self) -> bool:
        return self.headers.get("Host", "") in (f"127.0.0.1:{self.port}", f"localhost:{self.port}")

    def _send(self, code: int, body: bytes, ctype: str, extra: dict | None = None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj, code: int = 200):
        self._send(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")

    def _body(self, limit: int) -> bytes:
        n = int(self.headers.get("Content-Length") or 0)
        if n > limit:
            raise DropError(f"too big ({n / 1048576:.0f} MB)")
        return self.rfile.read(n) if n else b""

    def do_GET(self):
        if not self._host_ok():
            return self._send(403, b"forbidden", "text/plain")
        url = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(url.query)
        if url.path == "/":
            page = HTML.read_text(encoding="utf-8").replace("__DROP_KEY__", self.key)
            return self._send(200, page.encode("utf-8"), "text/html; charset=utf-8",
                              {"Content-Security-Policy": "default-src 'self'; style-src 'self' 'unsafe-inline'; "
                               "script-src 'self' 'unsafe-inline'; media-src 'self' https: blob:; img-src 'self' data:; "
                               "connect-src 'self'; frame-ancestors 'none'"})
        if url.path.startswith("/work/") and q.get("k", [""])[0] == self.key:
            w = self.drop.work.get(url.path[6:].removesuffix(".ogg"))
            if w and w["kind"] == "track" and Path(w["path"]).is_file():
                return self._send(200, Path(w["path"]).read_bytes(), "audio/ogg")
            return self._send(404, b"gone", "text/plain")
        if url.path == "/api/hello":
            return self._json({"app": "viral-music-drop", "key_ok": q.get("k", [""])[0] == self.key})
        if self.headers.get("X-Drop-Key") != self.key:
            return self._send(403, b"forbidden", "text/plain")
        try:
            if url.path == "/api/state":
                return self._json(self.drop.state())
            if url.path == "/api/job":
                job = self.drop.jobs.get(q.get("id", [""])[0])
                return self._json(job or {"state": "error", "error": "unknown job"})
        except DropError as e:
            return self._json({"error": str(e)}, 400)
        self._send(404, b"not found", "text/plain")

    def do_POST(self):
        if not self._host_ok() or self.headers.get("X-Drop-Key") != self.key:
            return self._send(403, b"forbidden", "text/plain")
        path = urllib.parse.urlparse(self.path).path
        try:
            if path == "/api/ping":
                Handler.last_ping[0] = time.time()
                return self._json({"ok": True})
            if path == "/api/quit":
                self._json({"ok": True})
                threading.Thread(target=self.server.shutdown, daemon=True).start()
                return None
            name = urllib.parse.unquote(self.headers.get("X-File-Name", "file"))
            if path == "/api/prepare":
                return self._json(self.drop.prepare(name, self._body(MAX_INPUT)))
            if path == "/api/proof":
                return self._json(self.drop.add_proof(name, self._body(MAX_PROOF)))
            req = json.loads(self._body(4 * 1024 * 1024) or b"{}")
            if path == "/api/publish":
                return self._json({"job": self.drop.start_job(self.drop.publish, req.get("items", []),
                                                               req.get("genres", []))})
            if path == "/api/edit":
                return self._json({"job": self.drop.start_job(self.drop.edit, str(req.get("id", "")),
                                                               req.get("changes", {}), req.get("genres", []))})
            if path == "/api/remove":
                return self._json({"job": self.drop.start_job(self.drop.remove, str(req.get("id", "")))})
            if path == "/api/play":
                return self._json({"job": self.drop.start_job(self.drop.set_play, req.get("play", {}))})
        except DropError as e:
            return self._json({"error": str(e)}, 400)
        except Exception as e:  # noqa: BLE001
            log(traceback.format_exc())
            return self._json({"error": f"unexpected error: {e}"}, 500)
        self._send(404, b"not found", "text/plain")


def open_window(url: str) -> None:
    for exe in (os.path.expandvars(r"%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"),
                os.path.expandvars(r"%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"),
                os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"),
                os.path.expandvars(r"%ProgramFiles%\Google\Chrome\Application\chrome.exe")):
        if Path(exe).is_file():
            subprocess.Popen([exe, f"--app={url}", "--window-size=1000,900"], creationflags=NO_WINDOW)
            return
    import webbrowser
    webbrowser.open(url)


def running_instance() -> str | None:
    """The address of a Music Drop already running, if any."""
    try:
        inst = json.loads(INSTANCE.read_text(encoding="utf-8"))
        url = f"http://127.0.0.1:{inst['port']}/"
        with urllib.request.urlopen(f"{url}api/hello?k={inst['key']}", timeout=2) as r:
            if json.loads(r.read()).get("key_ok"):
                return url
    except Exception:  # noqa: BLE001 -- no instance
        return None
    return None


def main(argv: list[str]) -> int:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    if LOG.is_file() and LOG.stat().st_size > 1024 * 1024:
        LOG.unlink()
    if sys.stdout is None:  # pythonw: no console
        sys.stdout = sys.stderr = open(os.devnull, "w")
    fake = None
    if "--fake" in argv:
        fake = Path(argv[argv.index("--fake") + 1]).resolve()
    no_open = "--no-open" in argv
    if not fake:
        url = running_instance()
        if url:
            log("already running -- opening it")
            if not no_open:
                open_window(url)
            return 0
    drop = Drop(fake)
    server = None
    for port in range(FIRST_PORT, FIRST_PORT + 20):
        try:
            server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
            break
        except OSError:
            continue
    if server is None:
        log("no free port")
        return 1
    Handler.drop, Handler.key, Handler.port = drop, secrets.token_urlsafe(24), server.server_port
    url = f"http://127.0.0.1:{Handler.port}/"
    if not fake:
        INSTANCE.write_text(json.dumps({"port": Handler.port, "key": Handler.key, "pid": os.getpid()}), encoding="utf-8")
    log(f"Viral Music Drop on {url} ({'fake GitHub: ' + str(fake) if fake else drop.cfg['GITHUB_OWNER'] + '/' + drop.cfg['GITHUB_REPO']})")

    started = time.time()

    def watchdog():
        # The window pings every 20 s; once it has been closed for 2 min (or
        # never opened within 10 min) the tool exits by itself.
        while True:
            time.sleep(10)
            last = Handler.last_ping[0]
            if (last and time.time() - last > 120) or (not last and time.time() - started > 600):
                if any(j["state"] == "running" for j in drop.jobs.values()):
                    continue
                log("window closed -- exiting")
                server.shutdown()
                return

    threading.Thread(target=watchdog, daemon=True).start()
    if no_open:
        print(url, flush=True)
    else:
        open_window(url)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        if not fake:
            INSTANCE.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
