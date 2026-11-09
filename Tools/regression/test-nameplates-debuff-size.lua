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

-- The settings preview spaces its sample plates so no plate's debuffs run into another plate ---------------

local function intersects(a, b)
	return a[1] < b[1] + b[3] and b[1] < a[1] + a[3] and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
end

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
