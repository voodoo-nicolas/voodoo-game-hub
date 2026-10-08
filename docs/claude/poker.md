# Poker (`video_poker`, pack v4)

Texas Hold'em, Omaha, Five Card Draw, Seven Card Stud (No limit / Pot limit / Limit; Stud Limit only); vs computer (cash tables at 3 stakes, free tournaments), pass-and-play 2-6, online heads-up, Video Poker as a mode, 🎓 Training. **Id stays `video_poker`** (stats/board carry over; board "Most chips").

- Files: `_eval.gd` (hand score = one int, bigger wins; `score5` fast path for Omaha), `_table.gd` (pure engine; JSON-safe `to_dict` = save AND online state; side pots from each seat's `total`), `_ai.gd` (Monte Carlo win chance + pot odds; computer players and coach on `WorkerThreadPool`, keyed by `_decision_key()` so stale answers drop), `_view.gd` (draws table; viewer's seat always at bottom), `_machine.gd` (Video Poker screen), `_training.gd` + `_drills.gd`, `_engine.gd` (Video Poker logic + Jacks or Better hint), `_game.gd` (modes, chips, saves, online).
- Chips in `user://video_poker_chips.json` (with Home picks), shared by cash tables and Video Poker. A seated cash stack is in the table save, NOT in chips; `_discard_save()` pays it back before any New… deletes the save. Video Poker saves its hand in `user://video_poker_machine.json` (never clobbers a table save).
- Online: host = seat 0 and deals every hand (shuffled deck in state); each move sends the whole table. `_hand_over()` must not change shared state online (no elimination bookkeeping) or every hand triggers a resync. Test: `video_poker` driver in `tools/test_online_pair.gd`.
- Coach follows the Starting hands drill's Chen tiers preflop in Hold'em, win chance vs pot odds after, so advice and drills agree.
- i18n: poker's check uses key `"Check "` (trailing space, `View.CHECK`) -> "Pasar".
- Web: AIs block briefly (no threads).
