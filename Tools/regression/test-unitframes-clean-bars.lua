-- test-unitframes-clean-bars.lua: acceptance pass 1 (KSTY-60 items 1, 3, 4, 14, 22, 25 and 28): no card, brackets or gems round a unit-frame bar, target health from the left, cast bars two thirds of the health bar with a lit top edge, the portrait ring after a live switch, a stronger sub-label grey, a rage orb that is not red, and a percentage that never straddles the loss band.
local U = dofile("Tools/regression/unitframes_env.lua")

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.01)
end

local function withEnum(env)
	env.Enum = env.Enum or {}
	env.Enum.StatusBarInterpolation = { Immediate = 0, ExponentialEaseOut = 1 }
end

local function saved(style, frames)
	local profile = { UnitFrames = frames or { enabled = true }, HudStyle = { style = style } }
	return { version = 32, profiles = { Default = profile }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end

local function noErrors(env, K, where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function luminance(r, g, b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local TARGET = { name = "Shadowgale Poacher", level = 12, health = 118, healthMax = 236, reaction = 2, canAttack = true, creature = "Humanoid", power = 10, powerMax = 100 }

-- Items 3 and 4, Frames: the target fills from the left; both cast bars are the clean caption bar, 14 units (two thirds
-- of the 21.5-unit health bar), with the lit top edge inside the dark edge.
do
	local env, K, ns = U.New({ saved = saved("frames"), setup = withEnum })
	U.SetUnit(env, "target", TARGET)
	env.SetTarget(true)
	local Geometry = ns.Geometry
	assert(ns.Settings.Value("target", "healthOrientation") == "RIGHT", "the target's health fills from the left, as both mock-ups draw it")
	local target = ns.Frames.Get("target").views[1]
	assert(target.health:GetReverseFill() ~= true, "the target's health bar is not reversed")
	assert(near(Geometry.COLUMN.castBar, 14) and math.abs(Geometry.COLUMN.castBar - Geometry.COLUMN.health * 2 / 3) < 0.5, "the attached cast bar is two thirds of the health bar")
	local tg = target.geometry
	assert(tg.cast and tg.name and tg.name.y >= 0, "the taller cast fits under the target's bar with its name on the frame")
	local casts = { player = ns.CastBars.Get("player")[1], target = ns.CastBars.Inline("target")[1] }
	for kind, cb in pairs(casts) do
		ns.CastBars.Restyle(cb)
		assert(cb.mode, kind .. " cast bar is a caption bar")
		assert(near(select(2, cb.bar:GetSize()), 14, 0.6), kind .. " cast bar is 14 units tall, got " .. tostring(select(2, cb.bar:GetSize())))
		assert(cb.bar.lit:IsShown() and cb.bar.shade:IsShown(), kind .. " cast fill keeps its lit top edge and shade")
		local edge = cb.bar.innerEdgeOn and cb.bar:EdgeLine() or 0
		local _, _, _, _, y = cb.bar.lit:GetPoint(1)
		assert(edge == 0 or (type(y) == "number" and y < 0), kind .. " lit edge sits inside the dark edge, not under it")
		assert(cb.bar:EdgeLine() == 1, kind .. " cast keeps a one-pixel dark edge, as the mock-up draws it")
		assert(not cb.chrome.visible, kind .. " cast bar has no card")
	end
	noErrors(env, K, "frames")
end

-- Items 1, 3 and 28, Orbs: the target's own cast bar has no forged card; the wide bar fills from the left and its
-- percentage stands at the fill's start, never across the loss band.
do
	local env, K, ns = U.New({ saved = saved("orbs"), setup = withEnum })
	U.SetUnit(env, "target", TARGET)
	env.SetTarget(true)
	assert(ns.Settings.Form("target") == "bar", "Orbs takes the wide target bar")
	local view = ns.Frames.Get("target").views[1]
	assert(view.health:GetReverseFill() ~= true, "the wide target bar fills from the left")
	local cb = ns.CastBars.Get("target")[1]
	ns.CastBars.LayoutElement("target")
	assert(cb.mode == "above", "the Orbs target cast is the caption bar, got " .. tostring(cb.mode))
	assert(not cb.chrome.visible, "no forged card round the Orbs target cast")
	assert(cb.ornament.bare, "and no brackets round its bar")
	assert(near(select(2, cb.bar:GetSize()), 14, 0.6), "the Orbs target cast is 14 units, got " .. tostring(select(2, cb.bar:GetSize())))
	local g = view.geometry
	assert(g.healthText and g.healthText.x > g.health.x and g.healthText.x + g.healthText.w <= g.health.x + g.health.w, "the percentage sits inside the bar")
	assert(view.healthText:GetJustifyH() == "LEFT", "the percentage stands at the fill's start: " .. tostring(view.healthText:GetJustifyH()))
	noErrors(env, K, "orbs")
end

-- Item 1: the sigil target has no gems; focus and boss lay out no glass card, and the folded boss chip wears none.
do
	local env, K, ns = U.New({ saved = saved("frames", { enabled = true, target = { style = "lumen" } }), setup = withEnum })
	for i = 1, 2 do
		U.SetUnit(env, "boss" .. i, { name = "Boss " .. i, level = 62, classification = "elite", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
	end
	env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	env.RunTimers()
	env._units.target = env._units.boss1
	env.FireEvent("PLAYER_TARGET_CHANGED")
	env.RunTimers()
	local Settings, Geometry = ns.Settings, ns.Geometry
	assert(Settings.Form("target") == "sigil", "the Lumen target is the sigil")
	local s = Geometry.Frame(Settings.Snapshot("target"), 640, 90, 1)
	assert(s.gemLeft == nil and s.gemRight == nil, "no gems close the sigil's bar")
	assert(near(s.health.x, 0) and near(s.health.w, 640), "the bar runs the sigil's whole width")
	assert(ns.Frames.Get("target").views[1].gemLeft == nil, "the sigil makes no gem textures")
	for _, kind in ipairs({ "focus", "boss" }) do
		local g = Geometry.Frame(Settings.Snapshot(kind), 222, 60, 1)
		assert(g.form == "card" and g.chrome == false, kind .. " lays out no glass card")
	end
	for i, view in ipairs(ns.Frames.Get("boss").views) do
		if i <= 2 then
			assert(not view.chrome.visible and view.chrome.ornament.enabled == false, "boss " .. i .. " shows no card and no corner brackets")
			assert(view.scrim:IsShown(), "boss " .. i .. " reads on the world over the soft scrim")
			local _, sh = view.scrim:GetSize()
			local _, bh = view.button:GetSize()
			assert(sh - bh <= 2 * 3 + 0.01, "boss " .. i .. "'s scrim stays inside the 6-unit gap to the next boss, not over it: " .. sh .. " for " .. bh)
		end
	end
	local chip = ns.Frames.Get("boss").views[1].chip
	assert(not chip.chrome.visible and chip.chrome.ornament.enabled == false, "the Targeted chip has no card or brackets")
	noErrors(env, K, "lumen")
end

-- Item 14: a profile that logs in to Orbs and switches to Frames lays the player out on a shown frame, so the portrait
-- ring draws without waiting for an OnShow the switch may never fire: a restyle from the module's own layout, not only
-- the ornament's OnShow wake, must find the ring visible.
do
	local env, K, ns = U.New({ saved = saved("orbs"), setup = withEnum })
	local view = ns.Frames.Get("player").views[1]
	assert(not view.button:IsShown(), "Orbs hides the player frame")
	local ring = view.portraitOrnament
	local restyle, seen = ring.Restyle, {}
	ring.Restyle = function(self, ...)
		local caller = debug.getinfo(2, "S").short_src
		if not caller:find("Ornaments.lua", 1, true) then
			seen[#seen + 1] = view.portraitFrame:IsVisible() and true or false
		end
		return restyle(self, ...)
	end
	K.Options.Write("HudStyle", "style", "frames")
	env.RunTimers()
	ring.Restyle = restyle
	assert(view.button:IsShown() and view.portraitFrame:IsVisible(), "Frames shows the player frame")
	assert(#seen > 0 and seen[#seen] == true, "the module's last restyle of the ring in the switch ran on a visible frame")
	assert(ring.stale == nil, "the ring is not left stale")
	noErrors(env, K, "switch")
end

-- Item 22: the type word and the dimmed value are a stronger, warmer grey than the old muted token.
do
	local env, K, ns = U.New({ saved = saved("frames"), setup = withEnum })
	U.SetUnit(env, "target", TARGET)
	env.SetTarget(true)
	local view = ns.Frames.Get("target").views[1]
	local sr, sg, sb = ns.Lumen.Color("subLabel")
	for _, key in ipairs({ "caption", "healthSub" }) do
		local r, g, b = view[key]:GetTextColor()
		assert(near(r, sr, 1e-6) and near(g, sg, 1e-6) and near(b, sb, 1e-6), key .. " takes the sub-label colour")
	end
	assert(luminance(sr, sg, sb) > luminance(K.Tokens.Color("muted")) + 0.05, "it reads stronger than the old muted grey")
	assert(sr >= sb, "and it is warm, not blue-grey, as the mock-up's")
	noErrors(env, K, "sub-label")
end

-- Item 25: a warrior's rage orb is not a second red health orb.
do
	local env, K, ns = U.New({
		saved = saved("orbs"),
		setup = function(env)
			withEnum(env)
			env.UnitPowerType = function()
				return 1, "RAGE"
			end
		end,
	})
	local power = ns.Orbs.Get("power")
	assert(power, "Orbs builds the resource orb")
	local r, g = power.bar:GetStatusBarColor()
	local qr, qg = K.Tokens.Color("orbRage")
	assert(near(g / r, qg / qr, 1e-6), "rage fills the orb with the orbRage hue")
	local hr, hg = ns.Orbs.Get("health").bar:GetStatusBarColor()
	assert(g - hg > 0.25 and g / r > 0.35, "rage reads amber beside the red health orb: " .. r .. ", " .. g .. " against " .. hr .. ", " .. hg)
	noErrors(env, K, "rage")
end

-- Item 4 for the cast elements: a saved layout that kept the old default height lets the new one through.
do
	local env, K = U.New({ saved = saved("frames"), setup = withEnum })
	local data = {
		version = 30, profiles = {}, layouts = {
			Default = {
				["unitframes.castbar.player"] = { height = 30 },
				["unitframes.castbar.target"] = { height = 24 },
				["unitframes.resource"] = { anchor = "BOTTOM", x = 0, y = 420 + K.Setup.Layouts.TRAY_LIFT },
				["orbs:unitframes.castbar.target"] = { height = 24, x = 4 },
			},
		},
	}
	K.Store.migrations[32](data)
	local layout = data.layouts.Default
	assert(layout["unitframes.castbar.target"] == nil, "the target cast bar's old default height goes")
	assert(layout["orbs:unitframes.castbar.target"].height == nil and layout["orbs:unitframes.castbar.target"].x == 4, "a style's old default height goes, its place stays")
	assert(layout["unitframes.castbar.player"].height == 30, "the player cast bar keeps its 30-unit element")
	assert(layout["unitframes.resource"] == nil, "a class resource saved at its old default follows the new one, clear of the cast label")
	local now = K.Setup.Layouts.Get("DPS")["unitframes.resource"]
	assert(near(now.y, 421 + K.Setup.Layouts.TRAY_LIFT), "the new default stands one unit higher")
	noErrors(env, K, "migration")
end

-- Item 4 for the damage card: its full-height rows keep the fill's lit top edge and shade.
do
	local M = dofile("Tools/regression/meters_env.lua")
	local env, K, ns = M.New({ game = function(e) e._group = { raid = false, size = 2 } end })
	env._session = { combatSources = { { name = "Kragar", classFilename = "WARRIOR", totalAmount = 2840, amountPerSecond = 28.4, sourceDisplayType = 1, isLocalPlayer = false, deathRecapID = 0, deathTimeSeconds = 0 } }, maxAmount = 2840, totalAmount = 2840, durationSeconds = 30 }
	M.Enable(env, K)
	local row = ns.Damage.list.rows[1]
	assert(row and row.bar.lit and row.bar.lit:IsShown(), "a damage row's fill keeps its lit top edge")
	assert(row.bar.shade:IsShown() or type(env.CreateColor) ~= "function", "and its shade, where the client can draw it")
	noErrors(env, K, "meters")
end

print("ok unit frames clean bars")
