-- test-nameplates-debuff-size.lua: nameplate debuffs default to a size a player reads at a glance in a pull: big icons, outlined time and stack text, a full row inside the plate, a clear gap above the name, and a saved size left alone.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")

local MIN_ICON = 26
local MIN_TEXT = 11
local MIN_DISTANT_ICON = 20
local SLIDER_HEADROOM = 10

-- The defaults: big icons, readable outlined text, a full row inside the plate ---------------------------

do
	local _, _, ns = N.New({ enable = false })
	local d = ns.Settings.defaults.debuffs
	assert(d.size >= MIN_ICON, "debuff icons default to at least " .. MIN_ICON .. " units, not " .. d.size)
	assert(d.textSize >= MIN_TEXT, "the time left and stacks default to at least " .. MIN_TEXT .. " units, not " .. d.textSize)
	assert(d.outline ~= "NONE", "the debuff text has an outline so it reads over any icon")
	assert(d.showTime and d.showCount, "the time left and stacks show by default")
	local line = ns.Logic.AuraLineSize(d.columns, d.size, d.spacing)
	assert(line <= ns.Plate.DEFAULT_WIDTH, "a full row of " .. d.columns .. " fits the plate's width: " .. line .. " > " .. ns.Plate.DEFAULT_WIDTH)
	local distant = d.size * ns.Settings.defaults.cvars.minScale
	assert(distant >= MIN_DISTANT_ICON, "a far plate's debuffs still read at " .. MIN_DISTANT_ICON .. " units or more, not " .. distant)
	assert(ns.Settings.Get("debuffs.size") == d.size and ns.Settings.Get("debuffs.textSize") == d.textSize, "a new profile reads the defaults")
end

-- The size slider has room above the default ------------------------------------------------------------

do
	local K = select(2, N.New({ enable = false }))
	local rows = {}
	for _, row in ipairs(K.Options.Get("Nameplates")) do
		if row.key then
			rows[row.key] = row
		end
	end
	local _, _, ns = N.New({ enable = false })
	local size = ns.Settings.defaults.debuffs.size
	local slider = rows["debuffs.size"]
	assert(slider.min <= size and slider.max >= size + SLIDER_HEADROOM, "the icon size slider goes " .. SLIDER_HEADROOM .. " units past the default: max " .. slider.max)
	local text = rows["debuffs.textSize"]
	assert(text.min <= ns.Settings.defaults.debuffs.textSize and text.max > ns.Settings.defaults.debuffs.textSize, "the text size slider holds the default")
end

-- A live plate draws the debuffs at the default size, with the text at the default size and outlined ------

do
	local env, K, ns = N.New()
	N.Add(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate1")
	local d = ns.Settings.defaults.debuffs
	local button = plate.auras._groups.debuffs.frames[1]
	local w, h = button:GetSize()
	assert(w == d.size and h == d.size, "the debuff button is " .. d.size .. " units square, not " .. w .. " by " .. h)
	for _, key in ipairs({ "timer", "count" }) do
		local font = N.Last(button._aura[key], "SetFont")
		-- The stack count is a step smaller on its own corner badge, so it never runs into the timer (round 4: Fable #3).
		local want = key == "timer" and d.textSize or math.max(9, d.textSize - 3)
		assert(font and font[2] == want, "the " .. key .. " text is " .. want .. " units")
		assert(font[3] == "OUTLINE", "the " .. key .. " text is outlined")
	end

	-- The row's bottom edge clears the top of the name by a small gap, so the time text never touches it.
	local gap = K.Tokens.Size("gapSmall")
	local nameTop = K.Tokens.Size("gapTiny") + ns.Settings.Get("name.size")
	local _, _, _, _, y = plate.auras:GetPoint(1)
	assert(y - nameTop >= gap, "the debuffs sit at least " .. gap .. " units above the name: " .. (y - nameTop))
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- Each timer has its own lane under its tile ----------------------------------------------------------------
-- Round 5 (Fable #3): the timers drew on the icon art, and the row's bottom edge sat about 4 px from the next
-- plate's name. The timer now sits in a lane under its tile, as the sigil's does; the lane counts in the row's
-- line spacing and in the plate's extent, so the stacking footprint holds it.

local function intersects(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

do
	local function rect(env, object)
		if object._type == "FontString" then
			-- The page sizes a one-point text by its drawn words, as the game does.
			local path, fontSize = Scene.Font(env, object)
			object._naturalW = Scene.TextWidth(object:GetText() or "", fontSize, path)
			object._naturalH = fontSize * 1.2
			object._naturalSideW, object._naturalSideH = "center", "top"
		end
		local r = { Scene.Rect(env, object) }
		assert(r[1], "the region resolves")
		return r
	end
	-- Place(container, group, n, columns) lays the first n buttons out as the engine's flow layout does: wrapped at the
	-- columns, each row a line of elementHeight plus the layout's lineSpacing from the container's anchor corner.
	local function Place(container, group, n, columns)
		local layout, flow = group.layout, container._flow
		local size, spacing, line = layout.elementWidth, layout.elementSpacing, layout.lineSpacing
		local corner, dx, dy = flow.anchor or "TOPLEFT", flow.horizontal or 1, flow.vertical or -1
		local rows, across = math.ceil(n / columns), math.min(n, columns)
		container:SetSize(across * size + (across - 1) * spacing, rows * size + (rows - 1) * line)
		local out = {}
		for i = 1, n do
			local button = group.frames[i]
			local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
			button:ClearAllPoints()
			button:SetSize(size, size)
			button:SetPoint(corner, container, corner, dx * col * (size + spacing), dy * row * (size + line))
			out[i] = button
		end
		return out
	end
	local function Check(write, label, between)
		local env, K, ns = N.New()
		for key, value in pairs(write) do
			K.Options.Write("Nameplates", key, value)
		end
		env.WorldFrame:SetPoint("TOPLEFT")
		env.WorldFrame:SetPoint("BOTTOMRIGHT")
		local base = N.Add(env, "nameplate1")
		base:ClearAllPoints()
		base:SetPoint("BOTTOM", env.WorldFrame, "BOTTOMLEFT", 400, 300)
		local plate = ns.Plates.Get("nameplate1")
		local columns, rows = ns.Settings.Get("debuffs.columns"), ns.Settings.Get("debuffs.rows")
		local n = columns * rows
		N.Debuffs(env, "nameplate1", n)
		local buttons = Place(plate.auras, plate.auras._groups.debuffs, n, columns)
		if between then
			-- The engine keeps laying out its buttons; the stub's single row needs no new place.
			between(env, K)
		end
		local health = rect(env, plate.health)
		local above, below = ns.Auras.Extent(plate)
		local reach = { health[1] - 100, health[2] - above, health[3] + 200, above + health[4] + below }
		local tiles, timers = {}, {}
		for i, button in ipairs(buttons) do
			local timer = button._aura.timer
			timer:SetText((3 + i) .. "s")
			assert(timer:IsVisible(), label .. ": tile " .. i .. "'s timer shows")
			tiles[i], timers[i] = rect(env, button), rect(env, timer)
		end
		for i = 1, n do
			for j = 1, n do
				assert(not intersects(timers[i], tiles[j]), string.format("%s: tile %d's timer is off tile %d's art", label, i, j))
			end
			for _, part in ipairs({ "name", "health", "level" }) do
				local object = plate[part]
				if object and object:IsVisible() then
					assert(not intersects(timers[i], rect(env, object)), label .. ": tile " .. i .. "'s timer clears the plate's " .. part)
				end
			end
			local t = timers[i]
			assert(t[2] >= reach[2] - 0.01 and t[2] + t[4] <= reach[2] + reach[4] + 0.01,
				string.format("%s: tile %d's timer lane is inside the plate's extent (%.1f-%.1f in %.1f-%.1f)", label, i, t[2], t[2] + t[4], reach[2], reach[2] + reach[4]))
		end
		assert(#env._errors == 0, tostring(env._errors[1]))
		return env, plate, buttons
	end
	Check({}, "the defaults")
	Check({ ["debuffs.rows"] = 2 }, "two rows")
	Check({ ["debuffs.growthY"] = "DOWN" }, "growing down")
	Check({ ["debuffs.rows"] = 2, ["debuffs.growthY"] = "DOWN", ["debuffs.size"] = 32 }, "two rows of 32 growing down")
	-- Time left switched off while aura data is secret: the buttons keep their timers until their restyle may run,
	-- so the row keeps its lane until then, and closes it with them (round 5 codex review).
	local env, plate, buttons = Check({}, "time off while auras are secret", function(env, K)
		env._aurasSecret = true
		env.SetCombat(true)
		K.Options.Write("Nameplates", "debuffs.showTime", false)
	end)
	local held = select(5, plate.auras:GetPoint(1))
	env._aurasSecret = false
	env.SetCombat(false)
	env.RunTimers()
	assert(not buttons[1]._aura.timer:IsVisible(), "the timers hide once the buttons may restyle")
	local closed = select(5, plate.auras:GetPoint(1))
	assert(closed < held - 1, "and the row drops into the freed lane: " .. tostring(closed) .. " from " .. tostring(held))
	local _, spacing = env._addons.KstyleUI_Nameplates.Auras.Grid(plate)
	assert(plate.auras._groups.debuffs.layout.lineSpacing == spacing, "the row's line spacing loses the lane too")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- The settings preview spaces its sample plates so no plate's debuffs run into another plate ---------------

local PANE_HEIGHT = 500

local function inside(a, b)
	return a[1] >= b[1] - 0.01 and a[2] >= b[2] - 0.01 and a[1] + a[3] <= b[1] + b[3] + 0.01 and a[2] + a[4] <= b[2] + b[4] + 0.01
end

local function PreviewOverlaps(write)
	local env, K = N.New()
	for key, value in pairs(write or {}) do
		K.Options.Write("Nameplates", key, value)
	end
	local holder = env.CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(400, PANE_HEIGHT)
	holder:SetPoint("CENTER")
	local preview = K.Options.Preview("Nameplates")(holder)
	preview:SetAllPoints(holder)
	preview:Refresh()
	local pane = { Scene.Rect(env, holder) }
	local plates = preview.plates
	local shown = 0
	for i, plate in ipairs(plates) do
		if plate:IsVisible() then
			shown = shown + 1
			local h = { Scene.Rect(env, plate.health) }
			if not inside(h, pane) then
				return string.format("plate %d's health bar leaves the pane", i)
			end
		end
		for _, icon in ipairs(plate.sampleAuras) do
			if icon:IsVisible() then
				local a = { Scene.Rect(env, icon) }
				assert(a[1], "sample debuff " .. i .. " resolves")
				if not inside(a, pane) then
					return string.format("plate %d's debuffs leave the pane", i)
				end
				for j, other in ipairs(plates) do
					for _, part in ipairs({ "health", "cast", "level" }) do
						local object = other[part]
						if object and object:IsVisible() and (j ~= i or part ~= "level") then
							local b = { Scene.Rect(env, object) }
							if b[1] and intersects(a, b) then
								return string.format("plate %d's debuffs overlap plate %d's %s", i, j, part)
							end
						end
					end
				end
			end
		end
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
	return nil, shown
end

do
	local problem, shown = PreviewOverlaps()
	assert(not problem, "at the defaults, " .. tostring(problem))
	assert(shown == 3, "the defaults show all three sample plates, not " .. shown)
	problem = PreviewOverlaps({ ["debuffs.rows"] = 2, ["debuffs.size"] = 32 })
	assert(not problem, "with two rows of 32-unit icons, " .. tostring(problem))
	problem = PreviewOverlaps({ ["debuffs.growthY"] = "DOWN" })
	assert(not problem, "growing down under the cast bar, " .. tostring(problem))
	-- The largest grid the sliders allow: the pane clips its children, so it shows the plates that fit.
	problem, shown = PreviewOverlaps({ ["debuffs.rows"] = 4, ["debuffs.size"] = 40 })
	assert(not problem, "with four rows of 40-unit icons, " .. tostring(problem))
	assert(shown >= 1, "at least one sample plate shows")
end

-- A size the player saved keeps its value ----------------------------------------------------------------

do
	local saved = {
		version = 3,
		profiles = { Default = { Nameplates = { enabled = true, debuffs = { size = 18, textSize = 8 } } } },
		characters = { ["Realm-Tester"] = "Default" },
	}
	local _, _, ns = N.New({ saved = saved })
	assert(ns.Settings.Get("debuffs.size") == 18, "a saved icon size stays: " .. tostring(ns.Settings.Get("debuffs.size")))
	assert(ns.Settings.Get("debuffs.textSize") == 8, "a saved text size stays")
	assert(ns.Settings.Get("debuffs.columns") == ns.Settings.defaults.debuffs.columns, "and unsaved keys take the defaults")
end

print("nameplates debuff size ok")
