-- KstyleUI_QoL.lua: reviewed taint-scan exceptions for KstyleUI_QoL/. Tools/regression/README.md has the format.
return {
	["KstyleUI_QoL/Chores.lua"] = {
		why = "Hide screenshot notice unregisters SCREENSHOT_SUCCEEDED on ActionStatus, a plain unprotected notice frame (Blizzard_ActionStatus/Mainline), only while the switch is on, and registers it again only when it was the one that removed it. No secure code reads ActionStatus.",
		calls = {
			["ActionStatus:UnregisterEvent"] = 1,
			["ActionStatus:RegisterEvent"] = 1,
		},
	},
}
