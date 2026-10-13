extends RefCounted

## Third-party software and data shipped in (or alongside) the app, shown in
## Options > Credits & licences and referred to by the Terms (EULA section B4).
## Our own art, code and sounds are in media/CREDITS.json; music credits come
## from the live music list. Keep this in step with what ships: add a line when
## a component or dataset is added (and its licence text under media/licenses/
## or beside the file).
##
## [name, what it is used for, licence, source]
const ITEMS := [
	["Godot Engine 4", "The game engine this app is built with", "MIT",
			"godotengine.org (full licence text and engine third-party notices: Options > Credits & licences)"],
	["ENABLE word list", "English word checking in Wordle, Word Hunt and Anagrams", "Public domain",
			"Enhanced North American Benchmark Lexicon"],
	["LibreOffice es_MX Hunspell dictionary", "Spanish word checking in Wordle", "MPL 1.1 (option of the MPL/GPL/LGPL tri-licence)",
			"LibreOffice dictionaries; licence text in media/licenses/wordlists/"],
	["Noto Color Emoji font", "Emoji in the browser (web) version", "SIL Open Font License 1.1",
			"Copyright 2022 Google Inc.; licence beside the font in assets/web_fonts/"],
	["DejaVu Sans font", "Symbols in the browser (web) version", "Bitstream Vera / Arev licence (free to use and redistribute)",
			"Copyright Bitstream, Inc. and Tavmjong Bah; DejaVu changes public domain; licence beside the font in assets/web_fonts/"],
]
