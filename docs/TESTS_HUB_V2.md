# Hub v2 test list

Run all automated ones: `python tools/hub.py check` first, then each line below. Tests that need a window omit `--headless`. They share the PC build's user data (CLAUDE.md): the ones that write restore it.

| area | what is checked | how |
|---|---|---|
| Delete-account confirmation | Delete is a low-emphasis link in a Danger zone; the confirm button is off until the gamer tag or DELETE is typed (any case), off again when cleared | `godot --headless --path . --script res://tools/test_hub_v2.gd` |
| Friend removal | no remove button on the list; "..." -> Remove friend -> confirm names the friend; nothing removed before confirming | `godot --path . --script res://tools/test_friends_ui.gd` (window) |
| XP idempotency | same challenge twice = one award; repeatable stops at 10; rules (min/max/equals); bad ids refused; xp clamped; client remembers what was sent; another account starts clean | `godot --headless --path . --script res://tools/test_xp.gd` |
| Filter combinations | quick + original = intersection; Solo + 2 Player only in both; search + chip; Learn chip | `test_hub_v2.gd` |
| Reduced motion | Reduce motion on = no entrance animation, `anim_time` = 0; off = animates | `test_hub_v2.gd` |
| Families | each category lists a family contiguously | `godot --headless --path . --script res://tools/test_family_order.gd` |
| Avatar editor | editor opens on a picture, saves a decodable 256 px avatar under the server limit | `godot --path . --script res://tools/test_avatar_editor.gd` (window) |
| Player page | overview, compare, private state with fake server answers | `godot --path . --script res://tools/test_player_ui.gd -- <out_dir>` (window) |
| Drinking Games hidden | out of the served manifest | `test_archived.gd`; `curl` the raw manifest |

**Manual (needs a phone / two accounts / the SQL):** native photo picker on Android; presence ("Playing X" appears for a friend within a minute, "Offline" after 3); avatar visible to friends; two accounts compare achievements in a game; a `private` account's games hidden; delete an account and re-register the same email; text size 1.4 on Profile / Friends / Player.
