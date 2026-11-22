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
			local position = Layouts.Style(name, key)
			assert(position.anchor and position.x and position.y, name .. ": " .. key .. " has a whole position")
		end
		for _, key in ipairs({ BAR1, BAR2, PLAYER, "unitframes.target", "actionbars.pet", "actionbars.stance", "unitframes.targettarget", "unitframes.focus", "unitframes.boss" }) do
			assert(Layouts.Style(name, key), name .. ": Medallions places " .. key)
		end
		assert(Layouts.Style(name, "chat.main") == nil, name .. ": the rails keep their Frames places")
	end
	local one, two = Layouts.Style("DPS", BAR1), Layouts.Style("DPS", BAR2)
	assert(near(one.x, -two.x) and near(one.y, two.y), "bar 1 is the slab's left group and bar 2 its right, on one baseline")
	local mock = 1 / K.Scale.DEFAULT_USER_SCALE
	local ring, pad = Layouts.MEDALLIONS_RING, Layouts.MEDALLIONS_SLAB.pad
	for _, class in ipairs(Layouts.ASPECTS) do
		local at = Layouts.Positions("DPS", "medallions", class)
		local _, _, _, groupHeight = Layouts.MedallionsGroup(class)
		local top, label = at[BAR1].y + groupHeight, "DPS " .. class
		local function Place(key)
			local place, styled = at[key], Layouts.Style("DPS", key)
			return { x = place.x, y = place.y, width = place.width or styled.width, height = place.height or styled.height }
		end
		local player, target = Place(PLAYER), Place("unitframes.target")
		local pet, tot = Place("unitframes.pet"), Place("unitframes.targettarget")
		assert(near(player.width, 300) and near(player.height, 58) and near(target.width, 300) and near(target.height, 58), label .. ": the player and target slabs are 300 by 58")
		assert(near(player.x, -target.x) and near(player.y, target.y), label .. ": the player and target mirror about the hub")
		assert(near(player.y, top + pad + 26), label .. ": the unit slabs leave their power reserves clear of the action slab")
		assert(near(target.x - target.width / 2, ring / 2 + 12), label .. ": the target's inner edge stands 12 clear of the hub ring")
		assert(near(pet.width, 170) and near(pet.height, 34) and near(tot.width, 170) and near(tot.height, 34), label .. ": the pet and target of target are 170 by 34")
		assert(near(pet.x, -tot.x) and near(pet.y, tot.y), label .. ": the pet and target of target mirror")
		if class == Layouts.ASPECTS[1] then
			assert(tot.x + tot.width / 2 <= target.x + target.width / 2 and near(tot.y, target.y + target.height + 46 + 96), label .. ": under 21:9 the target of target stands over the target, clear of its debuff row")
		else
			assert(pet.x - pet.width / 2 - Layouts.MEDALLIONS_MEDALS["unitframes.pet"].d / 2 >= at["actionbars.stance"].x + select(2, Layouts.MedallionsSide(class, "actionbars.stance")) / 2 + Layouts.MEDALLIONS_SIDE.pad and near(tot.y + tot.height / 2, target.y + target.height / 2 + 8), label .. ": at 21:9 and wider the mini frames clear the full medallion and the pet bar's plaque")
		end
		local cast, targetCast = Place("unitframes.castbar.player"), Place("unitframes.castbar.target")
		assert(cast.x == 0 and near(cast.width, 300) and near(cast.height, 20) and near(cast.y, top + ring / 2 + 27), label .. ": the player's cast bar is 300 by 20 and clears the raised unit slabs")
		assert(targetCast.x == 0 and near(targetCast.width, 300) and near(targetCast.height, 20) and near(targetCast.y - (cast.y + cast.height), 9), label .. ": the target cast must be 300 by 20 with a nine-unit gap above the player cast")
	end
	local boss = Layouts.Style("DPS", "unitframes.boss")
	assert(near(boss.width, 280 * mock) and near(boss.height, 324 * mock), "the boss column is 280 wide and five 60-tall rows and four 6-unit gaps tall")
	local wide = Layouts.Positions("DPS", "medallions", "21:9")
	local narrow = Layouts.Positions("DPS", "medallions", "16:9")
	assert(wide[BAR1].x < narrow[BAR1].x, "the 21:9 slab is no narrower than the 16:9 one")
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
	At(K, BAR1, Layouts.Style("DPS", BAR1), "Medallions default")
	At(K, PLAYER, Layouts.Style("DPS", PLAYER), "Medallions default")
	assert(Layout.Set(BAR1, "x", -999), "a position under Medallions saves")
	local saved = env.KstyleUIDB.layouts.Default
	assert(near(saved["medallions:" .. BAR1].x, -999) and saved[BAR1] == nil, "it is saved under the medallions: key")
	Style(K, "frames")
	assert(fired == 2 and last == "frames", "and the way back fires once")
	At(K, BAR1, frames1, "Frames after Medallions")
	At(K, PLAYER, frames2, "Frames after Medallions")
	Style(K, "medallions")
	At(K, BAR1, { anchor = "BOTTOM", x = -999, y = Layouts.Style("DPS", BAR1).y }, "the saved Medallions position returns")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

do
	local _, K = New()
	local Layouts = K.Setup.Layouts
	local OFFSETS = { BOTTOM = { 0.5, 0 }, BOTTOMLEFT = { 0, 0 }, BOTTOMRIGHT = { 1, 0 }, TOP = { 0.5, 1 }, TOPLEFT = { 0, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, RIGHT = { 1, 0.5 }, CENTER = { 0.5, 0.5 } }
	local pad = Layouts.MEDALLIONS_SIDE.pad
	for _, screen in ipairs({ { 1920, 1080, 0.9375 }, { 3456, 2234, 0.8158 }, { 2383, 1540, 0.789 }, { 1280, 720, 0.9375 } }) do
		local cw, ch = screen[1] / screen[2] * 1080 / screen[3], 1080 / screen[3]
		for _, name in ipairs(Layouts.Names()) do
			local at = Layouts.Positions(name, "medallions", "16:9")
			local function Box(key, grow)
				local p = at[key]
				local w, h = Layouts.StyleSize("16:9", key)
				if not w then
					w, h = Layouts.Footprint(name, key)
				end
				local o = OFFSETS[p.anchor]
				local l, b = cw * o[1] + p.x - w * o[1], ch * o[2] + p.y - h * o[2]
				return { l - grow, b - grow, l + w + grow, b + h + grow }
			end
			local stance = Box("actionbars.stance", pad)
			for _, key in ipairs({ "databars.micro", "databars.strip", "databars.bags", "meters.damage", "actionbars.pet" }) do
				if at[key] then
					local o = Box(key, key == "actionbars.pet" and pad or 0)
					local clear = stance[3] <= o[1] + 1e-6 or o[3] <= stance[1] + 1e-6 or stance[4] <= o[2] + 1e-6 or o[4] <= stance[2] + 1e-6
					assert(clear, string.format("%s %dx%d: the stance slab %.1f %.1f %.1f %.1f overlaps %s %.1f %.1f %.1f %.1f", name, screen[1], screen[2], stance[1], stance[2], stance[3], stance[4], key, o[1], o[2], o[3], o[4]))
				end
			end
		end
	end
end

do
	local AB = dofile("Tools/regression/actionbars_env.lua")
	for _, screen in ipairs({ {1280,720,0.9375}, {1366,768,0.9375}, {1920,1080,0.9375}, {2383,1540,0.789}, {2560,1440,0.9375}, {3456,2234,0.8158} }) do
		local width, height = screen[1], screen[2]
		local env, K, ns = AB.New({ width = width, height = height, uiScale = 768 / 1080, size = screen[3], fit = true, class = "WARLOCK" })
		env._game.petExists = true
		env._game.pet[1] = { name = "Firebolt", texture = 135809, spellID = 8001 }
		for i = 1, 10 do
			env._game.forms[i] = { texture = 135036, spellID = 15473 + i }
		end
		AB.Enable(env, K)
		env.RunTimers()
		local pet, stance = ns.Slab.sides.pet, ns.Slab.sides.stance
		assert(pet and stance and pet:IsVisible() and stance:IsVisible(), "the pet and stance plates must both show")
		assert(pet:GetTop() * pet:GetEffectiveScale() <= stance:GetBottom() * stance:GetEffectiveScale() + 1e-6,
			width .. "x" .. height .. ": snapped pet and stance plates overlap; reserve their pixel padding")
		assert(#env._errors == 0 and #env._blocked == 0, "side plates must stay error-free and combat-safe")
	end
end
print("ok layout medallions")
