-- KstyleUI_QoL.lua: reviewed taint-scan exceptions for KstyleUI_QoL/. Tools/regression/README.md has the format.
return {
	["KstyleUI_QoL/Chores.lua"] = {
		why = "Hide screenshot notice unregisters SCREENSHOT_SUCCEEDED on ActionStatus, a plain unprotected notice frame (Blizzard_ActionStatus/Mainline), only while the switch is on, and registers it again only when it was the one that removed it. No secure code reads ActionStatus. Hide toasts does the same for the loot and achievement toast events on AlertFrame (Blizzard_FrameXML/Mainline/AlertFrames.lua), an unprotected frame whose OnEvent only queues toasts: it unregisters only events AlertFrame had and registers again only those it removed.",
		calls = {
			["ActionStatus:UnregisterEvent"] = 1,
			["ActionStatus:RegisterEvent"] = 1,
			["AlertFrame:UnregisterEvent"] = 1,
			["AlertFrame:RegisterEvent"] = 1,
		},
	},
}
