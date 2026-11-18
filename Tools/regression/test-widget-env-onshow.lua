-- test-widget-env-onshow.lua: group-button and unit-watch helpers deliver OnShow once and preserve OnHide.
local G = dofile("Tools/regression/group_env.lua")
local U = dofile("Tools/regression/unitframes_env.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

do
	local env = G.New({ boot = false })
	local parent = env.CreateFrame("Frame", nil, env.UIParent)
	local button = env.CreateFrame("Button", nil, parent, "SecureUnitButtonTemplate")
	local shows, hides = 0, 0
	button:Hide()
	button:SetScript("OnShow", function() shows = shows + 1 end)
	button:SetScript("OnHide", function() hides = hides + 1 end)
	button:Show(); button:Show()
	assert(shows == 1, "group_env must let the stub deliver OnShow once, without invoking it again")
	button:Hide()
	assert(hides == 1, "group_env must retain its OnHide delivery")
	parent:Hide(); button:Show()
	assert(shows == 1, "a hidden group parent must defer child OnShow")
	parent:Show()
	assert(shows == 2, "showing the group parent must deliver child OnShow once")
end

do
	local env = Stubs.NewEnv()
	U.Install(env)
	local frame = env.CreateFrame("Frame", nil, env.UIParent)
	local shows, hides = 0, 0
	frame:SetAttribute("unit", "player")
	frame:Hide()
	frame:SetScript("OnShow", function() shows = shows + 1 end)
	frame:SetScript("OnHide", function() hides = hides + 1 end)
	env.RegisterUnitWatch(frame); env.RunUnitWatches()
	assert(shows == 1, "unitframes_env must let the stub deliver OnShow once per unit-watch transition")
	env._units.player = nil
	env.RunUnitWatches(); env.RunUnitWatches()
	assert(hides == 1, "unitframes_env must retain one OnHide per unit-watch transition")
end

print("widget env OnShow ok")
