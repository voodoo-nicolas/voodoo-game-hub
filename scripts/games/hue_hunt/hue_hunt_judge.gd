extends RefCounted

## Camera Hunter: ObjectJudge -- decides whether a photo shows the prompt in an
## Object round ("a teacup", "something round", "a pentagon").
##
## Honest note: v1 has NO picture recognition. The phone can't tell a teacup
## from a bowl, so the other players vote (hue_hunt_room.gd "vote" phase) and
## this judge only turns their votes into a verdict. The interface is here so
## an on-device labeler (or a shape check: edge/contour count for circles,
## triangles, pentagons...) can plug in later without touching round logic:
##
##     judge(prompt_id, image, votes) -> {"valid": bool, "source": "votes" | "model",
##                                        "confidence": 0..1}
##
## A future judge returns source "model" when it is sure and falls back to the
## votes otherwise. Round logic only reads "valid".

const SOURCE_VOTES := "votes"


## v1: the players' vote. At least 50% Yes among voters passes (ties pass;
## nobody voted = pass, so a photo isn't lost when everyone else is away).
static func judge(_prompt_id: String, _image: Image, votes: Dictionary) -> Dictionary:
	var yes := 0
	var no := 0
	for v in votes.values():
		if bool(v):
			yes += 1
		else:
			no += 1
	var total := yes + no
	return {"valid": yes >= no, "source": SOURCE_VOTES, "confidence": (float(maxi(yes, no)) / total) if total > 0 else 0.0,
		"yes": yes, "no": no}
