# Kickoff prompt — Viral Game Hub v2 (owner, 2026-10-06)

Saved verbatim as the owner's standing requirements for the v2 work. The
Drive copy (`files/KICKOFF_PROMPT.md`) is an earlier draft; this is the
version the owner gave Claude Code. Phase status lives in `docs/HUB_V2_PLAN.md`.

Why visible-text-only: the rename could break updates. The signing key is
`voodoo-release.keystore`. If the package ID, the key, or save paths were
renamed to "viral", Android would refuse updates and players could lose
saves, so the rebrand is limited to visible text.

---

You're continuing work on Viral Game Hub (developer: Viral; formerly "Voodoo Game Hub") — Godot 4,
Android, Supabase, EN/ES, games as downloadable .pck packs.

0. BRING IN THE NEW STANDARDS AND ART (from Google Drive)
Source: Google Drive folder "Viral Game Hub" (on this PC via Google Drive for desktop, usually
G:\My Drive\Viral Game Hub\). If you can't see it, stop and tell me — I'll download it into
_incoming/ in the repo.

Copy:
- files/hub-handoff/hub-handoff/CLAUDE.md          → MERGE into ./CLAUDE.md (do NOT overwrite)
- files/hub-handoff/hub-handoff/docs/STANDARDS.md  → docs/STANDARDS.md
- files/hub-handoff/hub-handoff/docs/HUB_V2_PLAN.md → docs/HUB_V2_PLAN.md
- files/hub-handoff/hub-handoff/docs/IP_AUDIT.md   → docs/IP_AUDIT.md
- Final Images/background.jpg                      → reference/art/brand/background.jpg
- Final Images/large skullVviral_background.png    → reference/art/brand/viral_logo_wordmark.png
- Final Images/small Vskull logo.jpg               → reference/art/brand/vskull_logo_src.jpg

- CLAUDE.md MERGE: the repo already has a CLAUDE.md (includes "App signing", maybe more). Keep every
  existing section, add the new content, and where they conflict show me both and ask. Same for any
  existing docs/ file. Show me the merged CLAUDE.md before committing.
- Don't copy the signing key or its password into the repo.
- Run /context and confirm CLAUDE.md and docs/STANDARDS.md load. From now on these docs are the
  source of truth: if my request conflicts with them, stop and say so; when a rule changes, update
  the doc in the same commit.

RENAME SAFETY (add to CLAUDE.md under Gotchas)
The rebrand changes VISIBLE TEXT ONLY. NEVER rename: Android package name/applicationId, the signing
keystore (voodoo-release.*) or VOODOO_RELEASE_KEY, Supabase project/table/column names, save-file
paths and keys, game ids in manifest.json, the GitHub repo or the packs-v1 tag. Changing these breaks
updates, wipes saves, or orphans packs. Internal identifiers may keep "voodoo".

WORK RHYTHM
After each step: hub.py check + hub.py test <id> on touched games, commit, summarize in ≤5 lines.
ASK ME BEFORE: publish-packs, release, bump-app major, deleting anything, Supabase schema changes,
store-listing text.

PHASE 0 — Brand & safety (no gameplay changes)
a. Create scripts/common/brand.gd (NAME="Viral Game Hub", DEVELOPER="Viral", EN/ES tagline keys).
   Replace hard-coded hub names in UI text, app display name and store text — within the rename-safety
   limits. "Voodoo" survives only as the skin name. List every file changed.
b. Brand assets (sources in reference/art/brand/, shipped files in res://media/hub/brand/):
   - vskull_logo_src.jpg has a FAKE checkerboard baked into the pixels (JPG = no alpha). Remove it →
     real-alpha PNG, glow kept soft. Show before/after.
   - Launcher icons per the Godot Android export preset: main 192x192; adaptive foreground 432x432
     (skull inside the ~264px safe circle); adaptive background 432x432 (dark crop of background.jpg
     or near-black); monochrome 432x432; Play Store icon 512x512 32-bit PNG. Check legibility at
     48px — if the third eye/flames turn to mush, make a simplified small variant (skull + V only).
   - viral_logo_wordmark.png is only 598x393: in-app hub header only. Build splash + Play feature
     graphic (1024x500) from the transparent logo + background.jpg + VIRAL lettering; tell me if
     anything looks soft.
   - background.jpg (1266x832) → portrait + landscape hub backgrounds, darkened for ≥4.5:1 text contrast.
   - media/CREDITS.json entries for each (owner-provided, AI-assisted; record the tool).
c. Archive Drinking Games per HUB_V2_PLAN §6. FIRST list the game ids and wait for my OK.
d. IP name audit of every game in manifest.json vs IP_AUDIT.md (include "Voodoo IQ" and its "Blitz"
   mode). Table: name → risk → proposed name. Don't rename until I approve (display names only).

PHASE 1 — Navigation core: game_router.gd, landing_kit.gd (from home_kit.gd), setup screens, pause
menu with drawer items folded in, settings_drawer.gd → no-op stub (never delete), Classic skin
default. Migrate 4 pilots (single-only, same-phone multi, online, card game) — propose them first.

PHASES 2–6: hub v2 screens → media tiers + music bus → skin system → category rollouts → join links
(no domain yet: code + QR + share text). Propose a task list at each phase start; wait for my OK.

STANDING RULES (add matching lint rules to hub.py check as you go):
- Every new/modified game meets STANDARDS "Definition of done".
- Only the Landing page links to the hub; every other screen has 🏠 Home → Landing.
- Packs keep working on older APKs. Never overwrite a mounted .pck. Never delete my comments (//, /* */, #).
- EN + ES for every string. Learning hook where natural. No alcohol references.
- Every asset: CREDITS.json + licence proof; OGG pre-encoded ~96 kbps.
- manifest.json committed last.

Start with step 0: show me what you found in the Drive folder and the CLAUDE.md merge plan before
changing anything.
