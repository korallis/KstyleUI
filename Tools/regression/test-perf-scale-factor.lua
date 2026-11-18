-- test-perf-scale-factor.lua: cached factors equal live factors after display, UI scale, parent scale and ancestry changes.
local W = dofile("Tools/regression/widget_env.lua")
local env, K = W.New()
local root = K.Scale.Root()
local parent = env.CreateFrame("Frame", nil, root)
local frame = env.CreateFrame("Frame", nil, parent)
local text = K.Widgets.FontString(frame, "OVERLAY")
local function same(why)
	for _, region in ipairs({ parent, frame, text }) do
		local live = region:GetEffectiveScale() / root:GetEffectiveScale()
		assert(K.Widgets.ScaleFactor(region) == live, "P4: invalidate cached scale factors after " .. why)
	end
end
same("initial layout")
local reads, real = 0, frame.GetEffectiveScale
frame.GetEffectiveScale = function(self) reads = reads + 1; return real(self) end
K.Widgets.ScaleFactor(frame)
K.Widgets.ScaleFactor(frame)
assert(reads == 0, "P4: reuse a frame factor until scale inputs change")
for _, scale in ipairs({ 0.65, 1.25, 0.9, 1 }) do
	parent:SetScale(scale)
	same("parent SetScale")
	frame:SetScale(scale)
	same("frame SetScale")
	frame:SetIgnoreParentScale(true)
	same("SetIgnoreParentScale true")
	frame:SetIgnoreParentScale(false)
	same("SetIgnoreParentScale false")
end
for _, screen in ipairs({ { 5120, 1440 }, { 3456, 2234 }, { 1920, 1080 } }) do
	env.GetPhysicalScreenSize = function() return unpack(screen) end
	env.FireEvent("DISPLAY_SIZE_CHANGED")
	env.RunTimers()
	same("DISPLAY_SIZE_CHANGED and late recheck")
	env.UIParent:SetScale(0.8)
	env.FireEvent("UI_SCALE_CHANGED")
	env.RunTimers()
	same("UI_SCALE_CHANGED")
	K.Scale.SetUserScale(0.8)
	same("user scale change")
	K.Callbacks.Fire("ScaleChanged")
	same("ScaleChanged")
end
frame:SetParent(root)
same("SetParent to root")
frame:SetParent(env.UIParent)
same("SetParent outside the managed root")
frame._scale = 0.7
same("engine-driven scale outside the managed root")
frame:SetParent(parent)
same("SetParent back into the managed root")
root:SetScale(root:GetScale() * 1.1)
same("direct root SetScale")
local engine = env.CreateFrame("AuraButton", nil, root)
local art = env.CreateFrame("Frame", nil, engine)
K.Widgets.ScaleFactor(art)
engine._scale = 0.75
assert(K.Widgets.ScaleFactor(art) == art:GetEffectiveScale() / root:GetEffectiveScale(), "P4: keep live scale reads for engine-scaled aura descendants")
do
	local fight, kit = W.New()
	fight.RunTimers()
	local fightRoot = kit.Scale.Root()
	local existing = fight.CreateFrame("Frame", nil, fightRoot)
	local start = fight.UIParent:GetScale()
	local function check(region, why)
		assert(kit.Widgets.ScaleFactor(region) == region:GetEffectiveScale() / fightRoot:GetEffectiveScale(), "P4: invalidate both scale caches during combat after " .. why)
	end
	check(existing, "initial layout")
	for _, event in ipairs({ "UI_SCALE_CHANGED", "CVAR_UPDATE", "DISPLAY_SIZE_CHANGED" }) do
		fight.SetCombat(true)
		fight.UIParent._scale = start * 1.25
		fight.FireEvent(event, "uiScale")
		check(existing, event)
		local midFight = fight.CreateFrame("Frame", nil, fightRoot)
		midFight:SetSize(100, 20)
		check(midFight, event .. " on a new frame")
		fight.RunTimers()
		check(midFight, "the late scale recheck")
		fight.UIParent._scale = start
		fight.FireEvent(event, "uiScale")
		check(midFight, event .. " returning to the old scale")
		fight.RunTimers()
		fight.SetCombat(false)
		check(existing, "combat with unchanged Apply inputs")
		check(midFight, "combat ending after the UI-scale round trip")
		local chrome = kit.Widgets.Chrome(midFight, { shape = "tile" })
		assert(math.abs(chrome.line[1]:GetWidth() - 3 * kit.Scale.Border()) < 1e-9, "P4: UI-scale round trips in combat must retain one-pixel slice lines")
	end
	fight.UIParent:SetScale(start * 0.8)
	check(existing, "UIParent:SetScale without an event")
	assert(#fight._errors == 0, table.concat(fight._errors, "\n"))
end
assert(#env._errors == 0, table.concat(env._errors, "\n"))
print("perf scale factor ok")
