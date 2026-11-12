-- test-tooltips-card.lua: every tooltip is the quest card (KSTY-44 bible, plan row 13): no crest, one heading rule, a health bar on units only, a 0.12 s fade in played by the client, and no measurement of a world-cursor or restricted tooltip.
local T = dofile("Tools/regression/tooltips_env.lua")
local W = T.W
local Near = T.Near

local anchorType = "ANCHOR_NONE"

local function Enabled()
	local env, K, ns = T.New({
		setup = function(env)
			env.GameTooltip.GetAnchorType = function()
				return anchorType
			end
		end,
	})
	assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), "Enable ran: " .. tostring(env._errors[1]))
	env.RunTimers()
	return env, K, ns
end

-- The card: no crest on any tooltip, the quest card's rule and nothing else ---------------------------

do
	local env, K, ns = Enabled()
	for name in pairs(T.TOOLTIPS) do
		local glass = ns.Style.Glass(env[name])
		assert(glass, name .. " is restyled")
		assert(glass.chrome.ornament == nil, name .. " carries no crest: the bible allows ornament on card corners and the heading rule only")
		assert(glass.footer == nil, name .. " has no footer divider")
		assert(glass.chrome.popup == true, name .. " is opaque under every material but Glass")
	end
	local tip = env.GameTooltip
	tip:AddLine("Ranger's Long Bow", 1, 1, 1)
	tip:AddLine("Two-Hand", 1, 1, 1)
	tip:AddLine("+24 Agility", 1, 1, 1)
	tip:AddLine("Durability 96 / 100", 1, 1, 1)
	tip:AddLine("Requires Level 38", 1, 1, 1)
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 19019 })
	local glass = ns.Style.Glass(tip)
	local rules = 0
	for _, region in ipairs({ glass:GetRegions() }) do
		if region:IsObjectType("Texture") and region:IsShown() and W.LastCall(region, "SetTexture") then
			local texture = W.LastCall(region, "SetTexture")[1]
			if texture == K.Tokens.Texture("forgedRule") or texture == K.Tokens.Texture("ruleFade") or texture == K.Tokens.Texture("divider") then
				rules = rules + 1
			end
		end
	end
	assert(rules == 1, "an item with a durability line shows one rule, under its heading, got " .. rules)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The health bar shows on units only -------------------------------------------------------------------

do
	local env, _, ns = Enabled()
	local tip = env.GameTooltip
	local blizzard = tip.StatusBar
	local bar = ns.Health.Bar()
	local Unit, Object = env.Enum.TooltipDataType.Unit, env.Enum.TooltipDataType.Object

	tip:AddLine("Copper Vein", 1, 1, 1)
	tip:AddLine("Requires Mining (1)", 1, 1, 1)
	T.BlizzardShow(blizzard, true)
	T.PostCall(env, tip, { type = Object })
	assert(not bar:IsShown(), "Blizzard watches an object's health, but the card shows no bar on an object")
	assert(select(2, tip:GetPadding()) == 0, "and gives the bar's room back")

	tip:ClearLines()
	T.BlizzardShow(blizzard, true)
	tip:AddLine("Riverglade Crocolisk", 1, 1, 1)
	tip:AddLine("Level 38 (Elite) Beast", 1, 1, 1)
	T.PostCall(env, tip, { type = Unit })
	assert(bar:IsShown(), "a unit shows its health bar")
	assert(select(2, tip:GetPadding()) > 0, "with room for it")

	tip:ClearLines()
	T.BlizzardShow(blizzard, true)
	assert(not bar:IsShown(), "after a clear the bar waits for the unit's post-call, so an object never flashes one")
	T.PostCall(env, tip, { type = Unit })
	assert(bar:IsShown(), "the unit's post-call shows it")
	T.PostCall(env, tip, { type = env.Enum.TooltipDataType.Item, id = 19019 })
	assert(not bar:IsShown(), "an item that follows a unit without a hide hides it")
	T.PostCall(env, tip, { type = Unit })
	T.PostCall(env, tip, { type = Object })
	assert(not bar:IsShown(), "an object after a unit hides it again")
	T.BlizzardShow(blizzard, false)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The fade in: an alpha animation the client plays over 0.12 s, never a Lua tween ------------------------

do
	local env, K, ns = Enabled()
	for name in pairs(T.TOOLTIPS) do
		local tip = env[name]
		local fade = ns.Style.Fade(tip)
		assert(fade and fade:GetParent() == tip, name .. " has a fade on the tooltip itself")
		local alpha = fade._anims and fade._anims[1]
		assert(alpha and alpha:GetObjectType() == "Alpha", name .. ": the fade is an Alpha animation")
		assert(W.LastCall(alpha, "SetFromAlpha")[1] == 0 and W.LastCall(alpha, "SetToAlpha")[1] == 1, name .. ": from clear to whole")
		assert(Near(W.LastCall(alpha, "SetDuration")[1], 0.12) and Near(K.Tokens.Duration("hover"), 0.12), name .. ": over 0.12 s")
	end
	local tip = env.GameTooltip
	local fade = ns.Style.Fade(tip)
	local tweens = 0
	local tween = K.Motion.Tween
	K.Motion.Tween = function(...)
		tweens = tweens + 1
		return tween(...)
	end
	T.BlizzardShow(tip, false)
	T.BlizzardShow(tip, true)
	assert(fade:IsPlaying(), "showing a tooltip plays its fade")
	assert(tweens == 0, "the fade runs no Lua tween")
	assert(W.LastCall(fade, "SetToFinalAlpha")[1] == true, "a fade cut short leaves the tooltip whole")
	T.BlizzardShow(tip, false)
	assert(not fade:IsPlaying(), "hiding the tooltip stops its fade")
	K.Motion.SetReducedMotion(true)
	T.BlizzardShow(tip, true)
	assert(not fade:IsPlaying(), "with motion off the tooltip shows at once")
	K.Motion.SetReducedMotion(false)
	K.Motion.Tween = tween
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The world-cursor tooltip is never measured, nor is a restricted one ----------------------------------

local MEASURES = { "GetLeft", "GetRight", "GetTop", "GetBottom", "GetCenter", "GetRect", "GetStringHeight", "GetStringWidth", "GetUnboundedStringWidth" }

local function Watch(objects)
	local hits = {}
	for _, object in ipairs(objects) do
		for _, method in ipairs(MEASURES) do
			local original = object[method]
			if type(original) == "function" then
				object[method] = function(self, ...)
					hits[#hits + 1] = method
					return original(self, ...)
				end
			end
		end
	end
	return hits
end

local function Regions(tip, glass)
	local list = { tip, glass }
	for i = 1, 12 do
		local left, right = tip:GetLeftLine(i), tip:GetRightLine(i)
		list[#list + 1] = left
		list[#list + 1] = right
	end
	return list
end

for _, case in ipairs({ { anchor = "ANCHOR_CURSOR_RIGHT", restricted = false }, { anchor = "ANCHOR_NONE", restricted = true } }) do
	local env, K, ns = Enabled()
	local tip = env.GameTooltip
	local glass = ns.Style.Glass(tip)
	anchorType = case.anchor
	if case.restricted then
		local plate = env.CreateFrame("Frame", nil, env.UIParent)
		plate:SetSize(110, 45)
		plate:SetPoint("CENTER", K.Scale.Root(), "CENTER", 0, 0)
		env.RestrictAnchoring(plate)
		tip:ClearAllPoints()
		tip:SetPoint("BOTTOMLEFT", plate, "TOPRIGHT", 4, 4)
		assert(tip:IsAnchoringRestricted() == true, "a tooltip anchored to a nameplate is restricted")
	end
	tip:SetSize(260, 110)
	local hits = Watch(Regions(tip, glass))
	local ok, err = pcall(function()
		for _, data in ipairs({
			{ type = env.Enum.TooltipDataType.Unit },
			{ type = env.Enum.TooltipDataType.Spell, id = 133 },
			{ type = env.Enum.TooltipDataType.Item, id = 19019 },
			{ type = env.Enum.TooltipDataType.Object },
		}) do
			tip:ClearLines()
			T.BlizzardShow(tip, false)
			tip:AddLine("Bloodtalon Matriarch", 1, 1, 1)
			tip:AddLine("Level 12 Beast", 1, 1, 1)
			tip:AddLine("Target", 1, 1, 1)
			T.BlizzardShow(tip, true)
			T.PostCall(env, tip, data)
			glass._scripts.OnSizeChanged(glass, 260, 110)
			ns.Style.ApplyScale(1.1)
		end
	end)
	assert(ok, case.anchor .. ": the tooltip shows with no error: " .. tostring(err))
	assert(#hits == 0, case.anchor .. (case.restricted and " (restricted)" or "") .. ": nothing measures the tooltip or its lines, got " .. tostring(hits[1]))
	assert(not ns.Style.Measurable(tip), case.anchor .. ": Style.Measurable says no")
	anchorType = "ANCHOR_NONE"
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("ok every tooltip is the quest card: no crest, one rule, a bar on units only, a client fade, no measuring at the cursor")
