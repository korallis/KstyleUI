-- SpellFamilies.lua: each class's spell families, the rank lists the crest, its rail and the cooldown medals all watch, with the crest art (a glyph or a sigil) that marks each.
local _, ns = ...

ns.SpellFamilies = {
	HUNTER = {
		hawk = { spells = { 13165, 14318, 14319, 14320, 14321, 14322, 25296, 469145 }, glyph = "glyphHawk" },
		monkey = { spells = { 13163 }, glyph = "glyphMonkey" },
		cheetah = { spells = { 5118 }, glyph = "glyphCheetah" },
		pack = { spells = { 13159 }, glyph = "glyphPack" },
		wild = { spells = { 20043, 20190 }, glyph = "glyphWild" },
		beast = { spells = { 13161, 1299445, 1299446, 1299447 }, glyph = "glyphBeast" },
		viper = { spells = { 415423 }, glyph = "glyphViper" },
		serpent = { spells = { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295 }, glyph = "glyphSerpent" },
		viperSting = { spells = { 3034, 14279, 14280 }, glyph = "glyphViperSting" },
		scorpid = { spells = { 3043, 14275, 14276, 14277 }, glyph = "glyphScorpid" },
		wyvern = { spells = { 19386, 24132, 24133, 24131, 24134, 24135 }, glyph = "glyphWyvern" },
		lacerate = { spells = { 24118, 24119, 24120, 1299332 }, glyph = "glyphLacerate" },
		blackArrow = { spells = { 3674, 14296 }, glyph = "glyphBlackArrow" },
		counter = { spells = { 20910, 20909, 19306, 1242634 }, glyph = "glyphCounter" },
		mongoose = { spells = { 14271, 14270, 14269, 1495 }, glyph = "glyphMongoose" },
		raptor = { spells = { 14266, 14265, 14264, 14263, 14262, 14261, 14260, 2973 }, glyph = "glyphRaptor" },
		mend = { spells = { 136, 3111, 3661, 3662, 13542, 13543, 13544 }, glyph = "glyphHaunch" },
		rapid = { spells = { 3045 }, sigil = "Volley" },
		wrath = { spells = { 19574 }, sigil = "Paw" },
		deter = { spells = { 19263 }, sigil = "Deflect" },
		intimidate = { spells = { 19577 }, sigil = "Intimidate" },
		trap = { spells = { 13795, 14302, 14303, 14304, 14305, 13813, 14316, 14317 }, sigil = "FireTrap" },
		sniper = { spells = { 1310786, 1310785, 1310687 }, sigil = "Sniper" },
		aimed = { spells = { 20904, 20903, 20902, 20901, 20900, 19434 }, sigil = "Aimed" },
		strider = { spells = { 1317257 }, sigil = "Strider" },
	},
}
