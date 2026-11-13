-- test-layout-orbs.lua: the Orbs HUD style's own positions: the style's preset table, defaults that follow the style, a position saved under Orbs kept under its orbs: key so the Frames position survives a switch, Reset and undo per style, and Setup.Apply writing the Frames positions and clearing the Orbs ones.
local W = dofile("Tools/regression/widget_env.lua")

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local CAST, CHAT, BAR2 = "unitframes.castbar.player", "chat.main", "actionbars.bar2"

local function New()
	local env, K = W.New()
	local function Element(key, opts)
		local frame = env.CreateFrame("Frame", nil, K.Scale.Root())
		frame:SetSize(200, 30)
		K.Layout.Register(frame, key, K.Setup.Layouts.Default(key), opts or { label = key })
		return frame
	end
	return env, K, Element
end

local function Style(K, style)
	K.Options.Write("HudStyle", "style", style)
	assert(K.HudStyle.Current() == style, "the HUD style is now " .. style)
end

local function At(K, key, position, label)
	local s = K.Layout.Get(key)
	assert(s.anchor == position.anchor and near(s.x, position.x) and near(s.y, position.y),
		string.format("%s: %s is at %s %s %s, wants %s %s %s", label, key, s.anchor, s.x, s.y, position.anchor, position.x, position.y))
end

-- The preset table: Orbs moves the centre cluster, the target, the bars beside the orbs and party for DPS and Tank;
-- Healer keeps its party beside the cluster; Frames has no table.
do
	local _, K = New()
	local Layouts = K.Setup.Layouts
	for _, name in ipairs(Layouts.Names()) do
		local keys = Layouts.StyleKeys("orbs", name)
		assert(#keys >= 15, name .. ": Orbs places the surfaces it moves, got " .. #keys)
		for _, key in ipairs(keys) do
			assert(Layouts.Element(key), name .. ": " .. key .. " is an element")
			local position = Layouts.Style("orbs", name, key)
			assert(position.anchor and position.x and position.y, name .. ": " .. key .. " has a whole position")
		end
		for _, key in ipairs({ "actionbars.bar1", BAR2, CAST, "unitframes.target", "auras.buffs", "auras.debuffs",
			"cooldowns.buffs", "actionbars.pet", "actionbars.stance", "databars.rep", "databars.honor" }) do
			assert(Layouts.Style("orbs", name, key), name .. ": Orbs places " .. key)
		end
		assert(Layouts.Style("frames", name, CAST) == nil, name .. ": Frames has no style table")
		assert(Layouts.Style("orbs", name, CHAT) == nil, name .. ": chat stays where Frames puts it")
	end
	assert(Layouts.Style("orbs", "DPS", "groupframes.party").anchor == "TOPLEFT", "DPS party sits at the left edge under Orbs")
	assert(Layouts.Style("orbs", "Healer", "groupframes.party") == nil, "Healer party keeps its Frames place beside the cluster")
	assert(Layouts.Style("orbs", "DPS", "unitframes.target").anchor == "TOP", "the target is a top-centre bar under Orbs")
	assert(Layouts.Style("orbs", "DPS", BAR2).scale < 0.85, "bar 2 is the smaller second row under Orbs")
	local positions = Layouts.Positions("DPS", "orbs")
	assert(positions[CAST].y == Layouts.Style("orbs", "DPS", CAST).y and positions[CHAT].y == Layouts.Get("DPS")[CHAT].y,
		"Positions merges the Orbs table over the Frames preset")
end

-- Defaults follow the style; a position saved under Orbs goes to orbs:<key>, and the Frames position survives.
do
	local env, K, Element = New()
	local Layouts, Layout = K.Setup.Layouts, K.Layout
	Element(CAST)
	Element(CHAT)
	Element(BAR2, { label = "Bar 2", scalable = true })
	local frames = Layouts.Default(CAST)
	local orbs = Layouts.Style("orbs", "DPS", CAST)
	At(K, CAST, frames, "Frames default")
	assert(Layout.Set(CAST, "x", 40), "a Frames position saves")
	local saved = env.KstyleUIDB.layouts.Default
	assert(near(saved[CAST].x, 40) and saved["orbs:" .. CAST] == nil, "a Frames position is saved under the plain key")
	local fired = {}
	K.Callbacks.Register("LayoutChanged", "test", function(_, key)
		fired[key] = true
	end)
	Style(K, "orbs")
	assert(fired[CAST] and fired[CHAT], "a switch re-places every element")
	At(K, CAST, orbs, "Orbs default")
	assert(near(Layout.Get(BAR2).scale, Layouts.Style("orbs", "DPS", BAR2).scale), "bar 2 takes the Orbs scale")
	At(K, CHAT, Layouts.Default(CHAT), "unmoved under Orbs")
	assert(Layout.Set(CAST, "y", orbs.y + 30), "an Orbs position saves")
	assert(near(saved["orbs:" .. CAST].y, orbs.y + 30), "an Orbs position is saved under orbs:")
	assert(near(saved[CAST].x, 40) and saved[CAST].y == nil, "the Frames position is untouched")
	assert(Layout.Set(CAST, "alphaIdle", 0.5), "a non-position field saves")
	assert(saved[CAST].alphaIdle == 0.5 and saved["orbs:" .. CAST].alphaIdle == nil, "opacity is shared by both styles")
	Style(K, "frames")
	At(K, CAST, { anchor = frames.anchor, x = 40, y = frames.y }, "Frames again")
	assert(near(Layout.Get(BAR2).scale, 1), "bar 2 is back to its own scale")
	assert(Layout.Get(CAST).alphaIdle == 0.5, "the shared opacity holds under Frames")
	Style(K, "orbs")
	At(K, CAST, { anchor = orbs.anchor, x = orbs.x, y = orbs.y + 30 }, "Orbs again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
end

-- Reset under Orbs clears only the Orbs position; undo and redo in Layout Mode work on the orbs: key.
do
	local env, K, Element = New()
	local Layouts, Layout = K.Setup.Layouts, K.Layout
	Element(CAST)
	Style(K, "orbs")
	local saved = env.KstyleUIDB.layouts.Default
	local orbs = Layouts.Style("orbs", "DPS", CAST)
	Style(K, "frames")
	Layout.Set(CAST, "x", 25)
	Style(K, "orbs")
	assert(Layout.Enter(), "Layout Mode opens")
	Layout.Set(CAST, "x", -60)
	assert(near(saved["orbs:" .. CAST].x, -60), "the drag saves under orbs:")
	assert(Layout.Undo(), "undo")
	assert(saved["orbs:" .. CAST] == nil, "undo clears the Orbs entry")
	At(K, CAST, orbs, "after undo")
	assert(Layout.Redo(), "redo")
	At(K, CAST, { anchor = orbs.anchor, x = -60, y = orbs.y }, "after redo")
	Layout.Exit(false)
	assert(saved["orbs:" .. CAST] == nil, "leaving without saving restores the Orbs entry")
	Layout.Set(CAST, "x", -60)
	Layout.Reset(CAST)
	At(K, CAST, orbs, "after Reset")
	assert(saved["orbs:" .. CAST] == nil and near(saved[CAST].x, 25), "Reset under Orbs keeps the Frames position")
	Layout.Set(CAST, "x", -60)
	Layout.ResetAll()
	assert(saved["orbs:" .. CAST] == nil and near(saved[CAST].x, 25), "Reset all under Orbs keeps the Frames positions")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
end

-- Setup.Apply under Orbs writes the preset's Frames positions to the plain keys and clears the Orbs entries.
do
	local env, K, Element = New()
	local Layouts, Layout = K.Setup.Layouts, K.Layout
	Element(CAST)
	Style(K, "orbs")
	Layout.Set(CAST, "x", -60)
	local saved = env.KstyleUIDB.layouts.Default
	assert(saved["orbs:" .. CAST], "an Orbs position is saved")
	assert(K.Setup.Apply({ layout = "Healer", modules = {} }), "Apply runs")
	assert(saved["orbs:" .. CAST] == nil, "Apply clears the Orbs position")
	At(K, CAST, Layouts.Style("orbs", "Healer", CAST), "Orbs after Apply")
	Style(K, "frames")
	At(K, CAST, Layouts.Get("Healer")[CAST], "Frames after Apply")
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
end

print("ok layout orbs")
