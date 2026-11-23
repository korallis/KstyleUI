-- KstyleUI_ActionBars.lua: reviewed taint-scan exceptions for KstyleUI_ActionBars/. Tools/regression/README.md has the format.
return {
	["KstyleUI_ActionBars/Button.lua"] = {
		why = "GameTooltip is hidden when the pointer leaves a KstyleUI action button that showed it, and only while that button owns it, as Blizzard's own action buttons do. GameTooltip is not a layout frame.",
		calls = {
			["GameTooltip:Hide"] = 1,
		},
	},
	["KstyleUI_ActionBars/SlabStorm.lua"] = {
		why = "Read() asks C_UnitAuras.GetPlayerAuraBySpellID only after Restricted() (SlabMedals.Restricted, C_Secrets.ShouldAurasBeSecret) says auras are readable; the guard moved into the shared crest helper, so the scanner no longer sees it in this file.",
		calls = {
			["C_UnitAuras.GetPlayerAuraBySpellID"] = 1,
		},
	},
	["KstyleUI_ActionBars/Flyout.lua"] = {
		why = "GameTooltip is hidden when the pointer leaves a KstyleUI flyout button that showed it, and only while that button owns it. GameTooltip is not a layout frame.",
		calls = {
			["GameTooltip:Hide"] = 1,
		},
	},
	["KstyleUI_ActionBars/SlabVigil.lua"] = {
		why = "Inner Fire's charges are read only when Medals.Restricted() (ShouldAurasBeSecret) says auras are not secret, and the count passes Widgets.IsSecret (issecretvalue) before any comparison.",
		calls = {
			["C_UnitAuras.GetPlayerAuraBySpellID"] = 1,
		},
	},
}
