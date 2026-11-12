-- test-ornament-restricted-tooltip.lua: the world-cursor tooltip's crest skips a card on a frame the game restricts for measurement, as a nameplate's level badge is, and still draws, with no error; Off draws no crest.
local T = dofile("Tools/regression/tooltips_env.lua")
local env, K, ns = T.New({
	setup = function(env)
		env.GameTooltip.GetAnchorType = function()
			return "ANCHOR_NONE"
		end
	end,
})
if not K.Modules.IsRunning("Tooltips") then
	assert(K.Modules.Enable("Tooltips"))
end
env.RunTimers()
local Widgets, Scale = K.Widgets, K.Scale
assert(Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")

local MEASURE = "Action[FrameMeasurement] failed because[Can't measure restricted regions]"

local plate = env.CreateFrame("Frame", nil, env.UIParent)
plate:SetSize(110, 45)
plate:SetPoint("CENTER", Scale.Root(), "CENTER", 0, 0)
env.RestrictAnchoring(plate)
local badge = env.CreateFrame("Frame", nil, plate)
badge:SetSize(22, 22)
badge:SetPoint("RIGHT", plate, "LEFT", -4, 0)
local ok, err = pcall(Widgets.Chrome, badge, { shape = "panel", fill = "surface", shadow = false, grain = false })
assert(ok, "a card on a restricted frame builds: " .. tostring(err))
assert(badge:IsAnchoringRestricted() == true, "a badge anchored to a restricted frame is restricted")
ok, err = pcall(badge.GetLeft, badge)
assert(not ok and err == "Frame:GetLeft(): " .. MEASURE .. ": attempted from: Frame:GetLeft().",
	"the stub raises the game's error when a restricted region is measured, got " .. tostring(err))

local tip = env.GameTooltip
local glass = ns.Style.Glass(tip)
local crest = glass.chrome.ornament
assert(crest and crest.kind == "crest", "GameTooltip's glass carries a crest handle")

local function drawn()
	local count = 0
	for i = 1, crest.used do
		if crest.textures[i]:IsShown() then count = count + 1 end
	end
	return count
end

local function worldCursor(width, height)
	return pcall(function()
		T.BlizzardShow(tip, false)
		tip:ClearAllPoints()
		tip:SetPoint("BOTTOMRIGHT", Scale.Root(), "BOTTOMRIGHT", -120, 240)
		tip:SetSize(width, height)
		tip.TextLeft1:SetText("Bloodtalon Matriarch")
		tip.TextLeft1:ClearAllPoints()
		tip.TextLeft1:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -10)
		tip.TextLeft1:SetSize(width - 20, 14)
		T.BlizzardShow(tip, true)
		glass._scripts.OnSizeChanged(glass, width, height)
	end)
end

ok, err = worldCursor(260, 110)
assert(ok, "the world-cursor tooltip shows beside a restricted card with no error: " .. tostring(err))
assert(drawn() == 1, "the world-cursor tooltip keeps its crest, got " .. drawn())
ok, err = worldCursor(380, 160)
assert(ok, "a wider world-cursor tooltip shows with no error: " .. tostring(err))
assert(drawn() == 1, "a wider world-cursor tooltip keeps its crest, got " .. drawn())

K.Store.Module("Widgets").ornaments = "Off"
K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
ok, err = worldCursor(260, 110)
assert(ok, "Off: " .. tostring(err))
assert(drawn() == 0, "Off draws no crest")

assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok the world-cursor tooltip's crest skips a restricted card and still draws, with no error")
