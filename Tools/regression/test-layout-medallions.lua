-- test-layout-medallions.lua: the Medallions HUD style's own positions: the style's preset table for every preset, defaults that follow the style and come back unchanged when it switches away, HudStyleChanged firing once with medallions, a position saved under Medallions kept under its medallions: key so the Frames position survives, and the 16:9 and 21:9 places of the one-row slab.
local W = dofile("Tools/regression/widget_env.lua")

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local BAR1, BAR2, PLAYER = "actionbars.bar1", "actionbars.bar2", "unitframes.player"

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

do
	local _, K = New()
	local Layouts = K.Setup.Layouts
	for _, name in ipairs(Layouts.Names()) do
		local keys = Layouts.StyleKeys("medallions", name)
		assert(#keys >= 11, name .. ": Medallions places the surfaces it moves, got " .. #keys)
		for _, key in ipairs(keys) do
			assert(Layouts.Element(key), name .. ": " .. key .. " is an element")
			local position = Layouts.Style("medallions", name, key)
			assert(position.anchor and position.x and position.y, name .. ": " .. key .. " has a whole position")
		end
		for _, key in ipairs({ BAR1, BAR2, PLAYER, "unitframes.target", "actionbars.pet", "actionbars.stance", "unitframes.targettarget", "unitframes.focus", "unitframes.boss" }) do
			assert(Layouts.Style("medallions", name, key), name .. ": Medallions places " .. key)
		end
		assert(Layouts.Style("medallions", name, "chat.main") == nil, name .. ": the rails keep their Frames places")
	end
	local one, two = Layouts.Style("medallions", "DPS", BAR1), Layouts.Style("medallions", "DPS", BAR2)
	assert(near(one.x, -two.x) and near(one.y, two.y), "bar 1 is the slab's left group and bar 2 its right, on one baseline")
	local mock = 1 / K.Scale.DEFAULT_USER_SCALE
	local _, _, _, groupHeight = Layouts.MedallionsGroup("16:9")
	local player, target = Layouts.Style("medallions", "DPS", PLAYER), Layouts.Style("medallions", "DPS", "unitframes.target")
	assert(near(player.width, 300 * mock) and near(player.height, 54 * mock) and near(target.width, player.width) and near(target.height, player.height), "the player and target slabs are the mock's 300 by 54")
	assert(near(player.x, -target.x) and near(player.y, target.y) and player.y >= one.y + groupHeight + 120 * mock - 1e-6, "the player and target mirror about the hub, at least 120 mock pixels over the slots' top edge")
	local wideAt = Layouts.Positions("DPS", "medallions", "21:9")
	local _, _, _, wideHeight = Layouts.MedallionsGroup("21:9")
	assert(near(wideAt[PLAYER].y, wideAt[BAR1].y + wideHeight + 120 * mock), "at 21:9 the player and target stand 120 mock pixels over the slots' top edge")
	assert(near(target.x - target.width / 2, 104 * mock), "the target's inner edge stands 104 mock pixels from the hub's centre")
	local tot = Layouts.Style("medallions", "DPS", "unitframes.targettarget")
	assert(near(tot.width, 112 * mock) and near(tot.x - tot.width / 2, target.x + target.width / 2 + 52 * mock) and near(tot.y + tot.height, target.y + target.height - 9 * mock), "the target of target stands 52 mock pixels off the target's outer edge, 9 under its top")
	local bags = Layouts.Default("databars.bags")
	local _, bagsHeight = Layouts.Footprint("DPS", "databars.bags")
	assert(tot.y >= bags.y + bagsHeight - 1e-6, "at 16:9 the one-row slab is low, so the frame row rises until the target of target clears the bag bar")
	local boss = Layouts.Style("medallions", "DPS", "unitframes.boss")
	assert(near(boss.width, 280 * mock) and near(boss.height, 324 * mock), "the boss column is 280 wide and five 60-tall rows and four 6-unit gaps tall")
	local wide = Layouts.Positions("DPS", "medallions", "21:9")
	local narrow = Layouts.Positions("DPS", "medallions", "16:9")
	assert(wide[BAR1].x < narrow[BAR1].x and wide[PLAYER].y < narrow[PLAYER].y, "the 21:9 slab is wider, and its frames sit lower than the 16:9 row that rises to clear the bag bar")
	local _, _, width = Layouts.MedallionsGroup("21:9")
	assert(near(wide[BAR2].x, Layouts.MEDALLIONS_HUB_GAP / 2 + width / 2), "at 21:9 bar 2 starts a hub gap from the centre line")
end

do
	local env, K, Element = New()
	local Layouts, Layout = K.Setup.Layouts, K.Layout
	Element(BAR1, { label = "Bar 1" })
	Element(BAR2, { label = "Bar 2" })
	Element(PLAYER)
	local frames1, frames2 = Layouts.Default(BAR1), Layouts.Default(PLAYER)
	At(K, BAR1, frames1, "Frames default")
	local fired, last = 0, nil
	K.Callbacks.Register("HudStyleChanged", "test", function(_, style)
		fired = fired + 1
		last = style
	end)
	Style(K, "medallions")
	assert(fired == 1 and last == "medallions", "HudStyleChanged fires once with medallions")
	At(K, BAR1, Layouts.Style("medallions", "DPS", BAR1), "Medallions default")
	At(K, PLAYER, Layouts.Style("medallions", "DPS", PLAYER), "Medallions default")
	assert(Layout.Set(BAR1, "x", -999), "a position under Medallions saves")
	local saved = env.KstyleUIDB.layouts.Default
	assert(near(saved["medallions:" .. BAR1].x, -999) and saved[BAR1] == nil, "it is saved under the medallions: key")
	Style(K, "frames")
	assert(fired == 2 and last == "frames", "and the way back fires once")
	At(K, BAR1, frames1, "Frames after Medallions")
	At(K, PLAYER, frames2, "Frames after Medallions")
	Style(K, "medallions")
	At(K, BAR1, { anchor = "BOTTOM", x = -999, y = Layouts.Style("medallions", "DPS", BAR1).y }, "the saved Medallions position returns")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("ok layout medallions")
