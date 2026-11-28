class_name LayoutHub
extends RefCounted
## THE LAST OBOL: the hub. The exit portal at the bottom of a dive throws the gunslinger
## out here, at the dead end of the Styx, where Charon gave up ferrying and opened a
## tavern on his dock. Souls who could not pay the obol linger at its tables.
## * The quay (left): the bar along the back wall (Charon behind the counter, `=`),
##   tables (`=`) with lingering souls, and the Soul Forge in the back corner between two
##   braziers.
## * The lake (right): soul-fire water (one big pit) with two rubble islets (`x`), a
##   balustrade along the front, crossed by a long pier (`B`) to the ferry landing, where
##   the portal drops you and where the ferry is moored.
## Same legend and screen directions as LayoutTemple (map left column and top row are the
## back walls). No encounters: weapons and abilities are holstered here (Player.in_hub).

const ENCLOSE := true
## Paintings laid over the hub (none yet: guide docs/paint_guides/hub_guide.png,
## --look=13.5,7.2 --zoom=0.43; prompt in docs/paint_guides/README.md).
const PAINTS := []

const MAP := [
	"OPPMPPOPPMPPOPPPMPPOPPPMPPOP",
	"Wk::::::k:*::*::::::::::::: ",
	"M:::::::::::::p        ::k: ",
	"W:======:w:::::   xx   :::: ",
	"O:::::::n:::kk:   xx   ::,: ",
	"Wn,::::::::::::        :w:: ",
	"M::::::=::w::::        :::* ",
	"W:n=:::::::::::        :::: ",
	"O::::o::::::,::BBBBBBBB:S:: ",
	"W:,:::,,:::::::        :::: ",
	"M:::::,::=n::::        :::* ",
	"W:::=::::::::w:  xx    ::o: ",
	"O::w:::::::,,::  xx    :,:: ",
	"Wk::::::::::::p        :::k ",
	"M:::::n::::::::||||||||:::: ",
	"                            ",
	"                            ",
]

## Interactive stations: kind, where its keeper/object stands (tile point), and where you
## stand to use it (tile point, reach in metres).
const STATIONS := [
	{"kind": "bar", "name": "THE LAST OBOL", "at": [4.6, 2.0], "use": [4.6, 4.3], "reach": 2.4},
	{"kind": "forge", "name": "THE SOUL FORGE", "at": [11.5, 2.4], "use": [11.5, 3.6], "reach": 2.2},
	{"kind": "ferry", "name": "THE FERRY", "at": [21.0, 11.7], "use": [23.6, 10.8], "reach": 2.4},
]

## Lingering souls: where they drift, and what they say when you talk to them (E).
const SHADES := [
	{"id": "drinker", "at": [2.5, 8.3], "lines": [
		"No coin for the ferryman. So I drink on credit. Eternity is a long tab.",
		"You've got a gun and a pulse. Down here that's practically royalty.",
		"I had a wife once. Or a horse. The gin's good at its job."]},
	{"id": "widow", "at": [7.6, 5.8], "lines": [
		"They say you sold your soul and then went to take it back. Brave. Or stupid.",
		"The deal-holders don't forget. Every soul you take, they feel it.",
		"Bring back something beautiful from the deep. I've forgotten what it looks like."]},
	{"id": "soldier", "at": [5.7, 12.5], "lines": [
		"The Legionnaires were men once. Hit them from behind. The shield only faces one way.",
		"Elites carry a gold rim. You'll want to kill those first, or last. Never in the middle.",
		"I fought the Weaver. Well. I looked at it. Then I was here."]},
	{"id": "gambler", "at": [9.6, 9.7], "lines": [
		"Bet you a soul you don't make depth five. ... Fine, I don't have one either.",
		"The Forge takes souls and gives you iron. Best deal on this whole river.",
		"Charon waters the stout. Don't tell him I said that."]},
	{"id": "watcher", "at": [14.2, 6.2], "lines": [
		"I watch the ferry come and go. It never takes me.",
		"Something else waits past the second shore. Colder. Older.",
		"The lake burns but it doesn't consume. Neither do we."]},
	{"id": "smith", "at": [12.6, 2.0], "smith": true, "lines": [
		"Souls in, iron out. That's the Forge.",
		"Your hide's thin for a man who walks through hell. Let me fix that.",
		"Every soul you bring me goes into the steel. They don't mind. Mostly."]},
]

## Charon's lines at the bar (the story, a little at a time).
const CHARON_LINES := [
	"Another one who wouldn't pay. Sit. Drinks are on the house of the dead.",
	"You're the gunslinger. The one who sold his soul for those pistols, then walked in here to take it back.",
	"Your contract was torn into pieces. Each keeper of a piece guards a shore. The Weaver held the first thread.",
	"I stopped ferrying when the souls stopped paying. Now I pour. The boat still knows the way, if you feed it souls.",
	"The deeper you go, the more they notice you. Good. Make them notice.",
	"Drink before you cross. It won't save you, but you'll die warmer.",
]
