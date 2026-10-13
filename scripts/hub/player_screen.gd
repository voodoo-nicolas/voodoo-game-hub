extends "res://scripts/hub/hub_screen.gd"

## A friend's page (tap a row on the Friends screen): avatar, gamer tag, Viral
## Power and what they're doing right now, with Invite and a "..." menu to
## remove them. Which friend comes from `Social.viewing` (a social_list row).
## Games played and the per-game achievement compare come with the Viral XP
## system.

const Avatar = preload("res://scripts/common/avatar.gd")
const FRIENDS_SCENE := "res://scenes/hub/friends.tscn"

func _title() -> String:
	return tr("Player")

func _ready() -> void:
	super()
	Social.friends_changed.connect(rebuild)

## Back goes to the friends list, not the hub.
func go_hub() -> void:
	get_tree().change_scene_to_file(FRIENDS_SCENE)

func _friend() -> Dictionary:
	var id := str(Social.viewing.get("user_id", ""))
	for f in Social.friends:
		if str(f.get("user_id", "")) == id and str(f.get("status", "")) == "friend":
			return f
	return {}

func _build() -> void:
	var f := _friend()
	if f.is_empty():
		var box := section("")
		box.add_child(label(tr("This player isn't on your friends list."), 26, null, true, true))
		return
	var card := section("")
	var face := CenterContainer.new()
	face.add_child(Avatar.make(str(f.get("avatar", "")), 120.0))
	card.add_child(face)
	card.add_child(label(str(f.get("display_name", "Player")), 36, pal.accent, true, true))
	if f.has("viral_power"):
		card.add_child(label(tr("%s Viral Power") % Social.format_number(int(f.viral_power)), 28, null, true, true))
	card.add_child(label(Social.activity_text(f), 24, pal.text_dim, true, true))
	var online: bool = bool(f.get("online", false))
	var inv := pill(tr("🎮 Invite"), online, 26)
	inv.disabled = not online
	inv.pressed.connect(_on_invite.bind(f))
	card.add_child(inv)
	var more := Button.new()
	more.text = tr("⋯ More")
	more.flat = true
	more.focus_mode = Control.FOCUS_NONE
	more.add_theme_font_size_override("font_size", 20)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		more.add_theme_color_override(key, pal.text_dim)
	more.pressed.connect(_on_more.bind(f))
	card.add_child(more)

func _on_invite(f: Dictionary) -> void:
	if tapped():
		pick_game_for(f)

func _on_more(f: Dictionary) -> void:
	if not tapped():
		return
	var box := dialog(str(f.get("display_name", "Player")))
	var rm := pill(tr("Remove friend"), false)
	rm.pressed.connect(_confirm_remove.bind(f))
	box.add_child(rm)
	var no := pill(tr("Cancel"), false)
	no.pressed.connect(close_dialog)
	box.add_child(no)

## Named confirmation: nobody is removed with one tap.
func _confirm_remove(f: Dictionary) -> void:
	if not tapped():
		return
	var name := str(f.get("display_name", "Player"))
	var box := dialog(tr("Remove %s?") % name)
	box.add_child(label(tr("You can add each other again later with your friend codes."), 24, pal.card_message, true, true))
	var yes := pill(tr("Remove %s") % name, true, 26)
	yes.pressed.connect(_remove.bind(str(f.user_id)))
	box.add_child(yes)
	var no := pill(tr("Cancel"), false, 26)
	no.pressed.connect(close_dialog)
	box.add_child(no)

func _remove(user_id: String) -> void:
	if tapped():
		close_dialog()
		Social.remove(user_id)
		go_hub()
