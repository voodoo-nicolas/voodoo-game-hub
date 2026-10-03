# Voodoo IQ — Build spec for Godot + Supabase

The playable web prototype (`claude/voodoo-iq-prototype.html` in this project) is the **reference implementation**. The generators, scoring math, gates, and text are final. Port them as they are, don't redesign them. Section names in code: `LOG SPA LIN MUS NAT KIN INT SELF EXI`.

## 1. Architecture

- **Godot 4 client:** rendering, input and timers only. It never receives answer keys or computes official scores.
- **Supabase (region `sa-east-1`, São Paulo):** Auth (Google + email), Postgres, Edge Functions (TypeScript/Deno). This is the referee.
- **Generators:** written **once in TypeScript**, in `supabase/functions/_shared/gens/`, ported from the JS prototype files `20–27`. The server sends render params only, e.g. `{gid, d, display:{...}}`, and keeps `answer` server-side.
- **Release:** Google Play. Set `FLAG_SECURE` on the Android window to block screenshots. Pausing or backgrounding the app during an item = that item is void (scored wrong), and `hidden` is counted.

## 2. Modes

| Mode | Scope | Time | Scoring |
|---|---|---|---|
| IQ Test | ALL (mixed, 8 sections) or one section | 5 / 15 / 30 / 60 min | Adaptive 3PL IRT, EAP |
| Blitz | ALL or one section (SELF excluded) | 1 / 2 / 3 / 5 min | Points = Σ weight(correct) − Σ weight/(k−1) for wrong MC. Skip costs 2 s |
| Daily Brain | Blitz ALL, 3 min | seed = hash("voodoo-daily-" + UTC date) | first attempt only |
| Duel | Blitz with a shared seed | code of 6 chars | 1 attempt per player |

- **Ranked IQ:** 1 attempt per scope per UTC day. Quitting still uses it. Practice is unlimited and never saved.
- **Instructions:** the clock pauses while they show, and there is an optional untimed example before the first item of each type.

## 3. Scoring (see `10-irt.js`)

- `b = −2.5 + (d−1)·5.5/9` for difficulty d = 1..10.
- `c = 1/options` (0 for typed or performance items).
- `a` comes from the gen definition (1.1–1.6).
- **EAP:** grid −4..4 step 0.05, N(0,1) prior.
- **Next item:** first item d = 4, then `d = dOf(θ̂ + N(0, 0.3))`. Never the same generator 3 times in a row.
- **Mixed scope:** pick the section with the highest SE, never the same section twice in a row.
- **Rapid correct** (`ms < gen.minMs`) is scored wrong and counted as rapid.
- **Session flagged** if hidden > 2 or rapid > 3.
- **Section misfit** if lz < −2.5 with n ≥ 15.
- **Combining sessions:** last 3 unflagged ranked sessions within 90 days. Remove the prior before combining: Λᵢ = 1/seᵢ² − 1; θ = Σθᵢ/seᵢ² ÷ (1 + ΣΛᵢ); se = 1/√(1 + ΣΛᵢ).
- **Rank score** = IQ(θ − 2·se), where IQ = 100 + 15θ. Display is clamped to 55–145.
- **Gates:**
  - Section board: n ≥ 15 and se ≤ 0.45.
  - Genius (130+): se ≤ 0.30 and ≥ 3 correct items at d ≥ 8 (for SELF: n ≥ 40). Without it, the score is capped at 129.
  - **Voodoo IQ** = composite of LOG, SPA, LIN (r = 0.5): each se ≤ 0.40 and n ≥ 15, sessions on ≥ 2 distinct days, and every pair of sessions within a section has |Δθ| / √(se₁² + se₂²) ≤ 2.5.
  - **9-Mind** = composite of all 9 sections (r = 0.3), with every section on its board.
- **SELF (Intrapersonal):**
  - Items come from `matrix, rotation, topview, natodd, face, syll`, targeted at θ − 0.6.
  - After each answer the player rates confidence 25 / 50 / 75 / 100 %.
  - θ = (AUC₂ − 0.68)/0.08, se = Hanley–McNeil SE / 0.08.
  - Valid only if accuracy ≥ 0.35 with ≥ 3 right and ≥ 3 wrong.

## 4. Database (SQL)

```sql
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  nick text not null check (char_length(nick) between 2 and 18),
  age_band text, minor boolean default false,
  country text, province text, lang text default 'es',
  created_at timestamptz default now()
);
create table sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id),
  mode text not null check (mode in ('iq','blitz')),
  kind text not null default 'normal' check (kind in ('normal','daily','duel')),
  scope text not null, dur_s int not null, ranked boolean not null,
  seed bigint not null, lang text not null,
  started_at timestamptz not null default now(),
  deadline timestamptz not null,
  status text not null default 'live' check (status in ('live','done','abandoned')),
  flags jsonb default '{}'::jsonb, result jsonb
);
create table responses (
  session_id uuid references sessions(id) on delete cascade,
  seq int, sec text, gid text, d int, a real, b real, c real,
  u smallint, ms int, conf real,
  served_at timestamptz, answered_at timestamptz,
  answer_key jsonb,        -- server only, never exposed
  primary key (session_id, seq)
);
create table section_scores (     -- one row per ranked session per section
  session_id uuid references sessions(id), user_id uuid references profiles(id),
  sec text, day date, theta real, se real, n int, hard int, lang text, flagged boolean,
  auc real, bias real, created_at timestamptz default now(),
  primary key (session_id, sec)
);
create table blitz_best (user_id uuid, scope text, dur_s int, season text, pts real, correct int, at timestamptz,
  primary key (user_id, scope, dur_s, season));      -- season = 'all' or 'YYYY-MM'
create table daily (user_id uuid, day date, pts real, correct int, primary key (user_id, day));
create table duels (code text primary key, seed bigint, scope text, dur_s int, created_by uuid, created_at timestamptz default now());
create table duel_results (code text references duels, user_id uuid, pts real, correct int, primary key (code, user_id));
create table certificates (token text primary key, user_id uuid, score int, theta real, se real, issued_at timestamptz default now());
```

- **RLS:** enable on every table.
  - `select` is open to authenticated users on `profiles` (nick/age/country only, via a view), `section_scores`, `blitz_best`, `daily`, `duel_results` and `certificates`.
  - **No insert/update policies for clients.** Only Edge Functions using the service role write.
  - `responses.answer_key` is never selectable.
- **Leaderboards:** SQL views or RPCs implementing §3 (combine → gates → rank score), filterable by age_band, country, province and LIN language.

## 5. Edge Functions

| Function | In | Out / effect |
|---|---|---|
| `session-start` | mode, kind, scope, dur, ranked, duel? | checks ranked eligibility (1/day per scope, daily once, 16+), creates the session, returns `{session_id, deadline, first_item}` |
| `item-answer` | session_id, seq, value, client_ms | validates order and the server deadline, scores, applies the rapid rule, picks the next item, returns `{next_item}` or `{done}` |
| `blitz-submit` | session_id, answers[] with timestamps | server regenerates items from the seed, scores them, checks plausibility (min ms per item, total ≤ dur + 2 s) |
| `session-finish` | session_id, reason | computes results (§3), writes `section_scores` / `blitz_best` / `daily` / `duel_results` |
| `cron-abandon` | (every 10 min) | `live` sessions past the deadline get scored from their stored responses and marked `abandoned` |
| `cert-issue` / `cert-verify` | token | issues a certificate only if Voodoo IQ is verified; the verify page is public |

**Blitz latency:** the server sends a pre-generated batch of about 200 items (no keys). The client posts answers once at the end.

## 6. Generators (port 1:1 from the prototype)

| Section | Gens (IQ weight) | Blitz gen (weight) |
|---|---|---|
| LOG | matrix .45 (8 opts, balanced factorial distractors), series .35 (typed), digits .2 (fwd/back span) | arith (1) |
| SPA | topview .4 (iso stack, marked front edge, visibility-checked distractors), rotation .35 (chiral polyomino), corsi .25 | rotquick (2) |
| LIN | analogy .34 (curated, ES/EN), oddword .36 (category bank + tricks), anagram .3 (tiles, no-alt-anagram lists) | oddquick (2) |
| MUS | pitch .35 (3-AFC oddball, 200→7 cents), melody .4 (changed note), chord .25 (count notes) | pitchhl (2) |
| NAT | natclass .55 (3 families, rule verified unique), natodd .45 (4 vs 1, unique) | natquick (3) |
| KIN | tap .5 (window 1300→450 ms), timing .5 (coincidence anticipation, occlusion at d ≥ 6) | tap (1) |
| INT | face .6 (AU-param faces, intensity scaling, eyes-only at d ≥ 8), faceodd .4 | facequick (1.5) |
| EXI | syll .65 (brute-force Venn validity; only conclusions valid under both modern logic and existential import), fallacy .35 (17 curated, ES/EN) | syllquick (4) |

**Godot rendering notes:**

- Top-view stacks: use real 3D (orthographic camera, fixed iso angle).
- Matrix, creature and face drawings: port the SVG drawing math to `Control._draw()`.

## 7. Accessibility (must keep)

- Dark background `#07070C`. Text contrast ≥ 7:1, shape contrast ≥ 3:1.
- Atkinson Hyperlegible for body text, Big Shoulders Display for headings and numbers.
- Every color is paired with a symbol or number. The Okabe-Ito-derived section palette is in `SEC_COLOR`.
- Touch targets ≥ 48 dp. Text size options 1× / 1.15× / 1.3×.
- Instructions are untimed. A headphone check runs before the first MUS item.
- Ranked play is blocked under a minimum screen width.

## 8. Calibration roadmap

1. Launch with provisional `b` (from d) and the `a` values from the gen definitions.
2. At ≥ 300 responses per gen × d cell, refit 2PL/3PL per gen and d using marginal MLE (e.g. the R package `mirt` offline). Store the parameters in an `item_params` table, which overrides the defaults.
3. Anchor the norms to ICAR public-domain items (matrix reasoning, 3D rotation, letter-number series), and check the ICAR license for commercial use first.
4. Norm by age band once each band has n ≥ 200.
5. Model the practice effect using session count as a covariate.

## 9. Open decisions

- Monetization: cosmetic only. Never sell retries or hints.
- Under-16 players: practice only (Play Families policy).
