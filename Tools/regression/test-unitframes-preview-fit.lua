-- test-unitframes-preview-fit.lua: the unit frames live preview fits its pane: every frame kind, its cast line and its sample auras lie inside the pane at the options pane's width, and a resize fits it again (round 4: Opus #1, Astra #2; "ing Frostbolt" cut at the pane's edge).
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local PANE_W, PANE_H = 280, 560

local function inside(a, b)
	return a[1] >= b[1] - 0.5 and a[2] >= b[2] - 0.5 and a[1] + a[3] <= b[1] + b[3] + 0.5 and a[2] + a[4] <= b[2] + b[4] + 0.5
end

local function fmt(r)
	return string.format("(%.1f,%.1f %.1fx%.1f)", r[1], r[2], r[3], r[4])
end

local env, K, ns = U.New()
env._textWidth = D.TextWidth
local pane = env.CreateFrame("Frame", nil, K.Scale.Root())
pane:SetSize(PANE_W, PANE_H)
pane:SetPoint("CENTER")
local preview = K.Options.Preview("UnitFrames")(pane)

local function regions(kind)
	local out = { holder = preview.holders[kind] }
	local view = preview.views[kind]
	for _, key in ipairs({ "name", "caption", "health", "power", "marker", "healthText" }) do
		out[key] = view[key]
	end
	local cb = preview.casts[kind]
	if cb and cb.frame:IsShown() then
		for _, key in ipairs({ "frame", "label", "text", "timer", "bar" }) do
			out["cast." .. key] = cb[key]
		end
	end
	for i, icon in ipairs(preview.auraIcons[kind] or {}) do
		out["aura" .. i] = icon
	end
	return out
end

local function Check(where)
	local box = { Scene.Rect(env, pane) }
	for _, kind in ipairs(U.KINDS) do
		K.Options.Write("UnitFrames", "edit", kind)
		preview:Refresh()
		assert(preview.kind == kind, "the preview draws " .. kind)
		for key, region in pairs(regions(kind)) do
			if region:IsVisible() then
				local r = { Scene.Rect(env, region) }
				if r[1] and r[3] > 0 then
					local w = key:find("text") or key:find("label") or key:find("name") or key:find("caption")
					if w and region.GetUnboundedStringWidth then
						local text = region:GetUnboundedStringWidth()
						if type(text) == "number" and text > r[3] + 0.5 and region:GetWidth() == 0 then
							r[3] = text
						end
					end
					-- The bare pane skips the Options host's Reserve, which keeps the target and boss markers and the boss's name inside the window's pane.
					local known = key == "marker" and (kind == "target" or kind == "boss") or key == "name" and kind == "boss"
					assert(known or inside(r, box), string.format("%s: the %s preview's %s %s leaves the pane %s", where, kind, key, fmt(r), fmt(box)))
				end
			end
		end
	end
end

Check("at " .. PANE_W .. " units")
pane:SetSize(220, PANE_H)
Check("after a resize to 220 units")
pane:SetSize(PANE_W, PANE_H)

-- The target frame, in a fresh profile.
env, K = U.New()
env._textWidth = D.TextWidth
pane = env.CreateFrame("Frame", nil, K.Scale.Root())
pane:SetSize(PANE_W, PANE_H)
pane:SetPoint("CENTER")
preview = K.Options.Preview("UnitFrames")(pane)

-- The target frame is laid out at the width the Medallions HUD gives it while the pane holds it at half scale or more,
-- then scaled to fit, so its cast line is the HUD's (round 6: Opus #2, Fable #3). A narrower pane lays it out
-- narrower still.
K.Options.Write("UnitFrames", "edit", "target")
preview:Refresh()
local holder = preview.holders.target
local element = K.Layout.Get("unitframes.target")
local w, scale = holder:GetWidth(), holder:GetScale()
assert(math.abs(w - element.width) < 0.5, "the sample target is laid out at its HUD width " .. element.width .. ": " .. w)
assert(scale < 1 and scale >= 0.5 - 1e-6, "and scaled down to the pane, no smaller than half: " .. scale)

-- Round 6 (Opus #2, Fable #3): the preview fills its pane's width, and the cast bar is as wide, for the frame, as on
-- the HUD. The HUD's proportion is the target at its HUD width, as a pane wide enough to hold it draws it.
local function Width(region)
	local r = { Scene.Rect(env, region) }
	return r[3] or 0
end
local function CastShare()
	local view, cb = preview.views.target, preview.casts.target
	return Width(cb.bar) / Width(view.health)
end
local function Span()
	local view = preview.views.target
	local l, r = math.huge, -math.huge
	for _, region in ipairs({ view.health, preview.auraHosts.target }) do
		local x = { Scene.Rect(env, region) }
		if x[1] then
			l, r = math.min(l, x[1]), math.max(r, x[1] + x[3])
		end
	end
	return r - l
end
local narrowShare, span = CastShare(), Span()
assert(span >= 0.85 * PANE_W, "the sample target fills the pane's width: " .. string.format("%.0f of %d", span, PANE_W))
pane:SetSize(900, PANE_H)
preview:Refresh()
assert(math.abs(preview.holders.target:GetWidth() - element.width) < 0.5 and preview.holders.target:GetScale() >= 1, "a pane wide enough draws the target at its HUD width")
local hudShare = CastShare()
assert(narrowShare >= 0.85 * hudShare, string.format("the sample cast bar keeps the HUD's share of the health bar: %.2f against %.2f", narrowShare, hudShare))
pane:SetSize(PANE_W, PANE_H)

-- A narrow frame grows to the pane's width, no more than half again its size.
K.Options.Write("UnitFrames", "edit", "focus")
preview:Refresh()
local focusScale = preview.holders.focus:GetScale()
assert(focusScale > 1 and focusScale <= 1.5 + 1e-6, "the 200-unit focus card grows towards the pane's width, at most 1.5: " .. focusScale)

-- The Medallions target's cast sample shows under the frame, so its spell target and important outline rows show.
K.Options.Write("UnitFrames", "target.castbarTarget", true)
K.Options.Write("UnitFrames", "target.castbarImportant", true)
K.Options.Write("UnitFrames", "edit", "target")
preview:Refresh()
local tcb = preview.casts.target
assert(tcb and tcb.frame:IsShown(), "the target preview shows a cast sample")
assert(tostring(tcb.text:GetText()):find(K.L["Valerin"], 1, true), "with the spell target: " .. tostring(tcb.text:GetText()))
assert(tcb.important and tcb.important:IsShown(), "and the important cast outline")
local function Gap(bar, parent)
	local _, _, _, _, y = bar:GetPoint(1)
	return -y - parent:GetHeight()
end
local live = ns.Frames.Get("target").views[1]
local liveGap, sampleGap = Gap(live.castbar.frame, live.button), Gap(tcb.frame, preview.holders.target)
assert(math.abs(sampleGap - liveGap) < 0.5, string.format("the sample hangs at the live cast bar's gap: %.2f against %.2f", sampleGap, liveGap))
K.Options.Write("UnitFrames", "castbarOnFrame", false)
preview:Refresh()
assert(tcb.frame:IsShown(), "a detached target cast bar keeps its sample, so its spell target and outline rows still show")
K.Options.Write("UnitFrames", "castbarOnFrame", true)

assert(#env._errors == 0, tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "KstyleUI caught no errors")
print("unitframes preview fit ok")
