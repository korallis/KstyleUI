-- KstyleUI_ActionBars.lua: reviewed taint-scan exceptions for KstyleUI_ActionBars/. Tools/regression/README.md has the format.
return {
	["KstyleUI_ActionBars/Slab.lua"] = {
		why = "Parent() moves the crest hub, KstyleUI's own plain frame, between KstyleUI's root, KstyleUI's own crest gate (while the Crest element's Shown rule can hide it) and the Crest element's holder, out of combat, when bars 1 and 2 split or rejoin or that rule changes. Edit Mode never lays it out, and no protected frame anchors to it: its secure travel button and the Spirit Poles are placed over it by coordinates.",
		calls = {
			["Slab.hub:SetParent"] = 1,
		},
	},
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
	["KstyleUI_ActionBars/SlabUnleashed.lua"] = {
		why = "Readable() asks C_UnitAuras.GetUnitAuraBySpellID only after Medals.Restricted() (C_Secrets.ShouldAurasBeSecret) says auras are readable, and passes each result through Widgets.IsSecret (issecretvalue) before it uses it.",
		calls = {
			["C_UnitAuras.GetUnitAuraBySpellID"] = 1,
		},
	},
	["KstyleUI_ActionBars/SlabRail.lua"] = {
		why = "Started() asks C_UnitAuras.GetUnitAuraBySpellID only after Medals.Restricted() (C_Secrets.ShouldAurasBeSecret) says auras are readable, and passes each result and its fields through Widgets.IsSecret (issecretvalue) before it compares them.",
		calls = {
			["C_UnitAuras.GetUnitAuraBySpellID"] = 1,
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
