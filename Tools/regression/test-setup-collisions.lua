-- test-setup-collisions.lua: every preset (DPS, Tank, Healer) resolves to element rects and the right rail's story slot at 16:9, 16:10, 21:9 and the owner's 2383 x 1540 on the canvas the shipped Interface size gives (Layouts.HEIGHT), every bar 1 to 6 placed, with nothing off screen and nothing overlapping, each element at the full footprint it draws: a reserve never hides part of its element (the boss stack once reserved one card of five), the tooltip anchor lies on no card (it once covered the readout and the menu you hover), the boss column's footprint covers its cards and their aura room from the live unit frames, and the live aura rows at 0 to 40 buffs beside 12 debuffs fit the footprint their preset plans and overlap nothing.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local env, K = CoreEnv.New({ fit = true })
CoreEnv.Boot(env)
local Layouts = K.Setup.Layouts

local HEIGHT = Layouts.HEIGHT
local ASPECTS = { { "16:9", 16 / 9 }, { "16:10", 16 / 10 }, { "21:9", 21 / 9 }, { "the owner's 2383 x 1540", 2383 / 1540 } }

-- Pairs that never show together or sit inside each other on purpose; everything else must stay apart.
local function apart(name, a, c)
	local pair = { [a] = true, [c] = true }
	if pair["groupframes.party"] and pair["groupframes.raid"] then
		return false
	end
	if Layouts.Dock(a) == c or Layouts.Dock(c) == a then
		return false
	end
	if pair["meters.threat"] and pair["meters.damage"] and Layouts.Shown(name, "meters.threat") == false then
		return false
	end
	return true
end

local function overlap(r, s)
	return r[1] < s[3] and s[1] < r[3] and r[2] < s[4] and s[2] < r[4]
end

-- The story slot (the quest card, under the RestedXP guide when it is loaded) is a card too: on the right rail under the
-- map and the aura rows, it overlaps no element, and the damage card and the readout stand clear under it.
local function Story(name, width)
	local slot = assert(Layouts.Slot(name), name .. " has a story slot")
	return { Layouts.Rect(slot, slot, width, HEIGHT) }
end

-- Match live Layout.Place: snap each size first, then align its anchored bottom-left to the pixel grid.
local function PhysicalRects(name, width, height, user)
	local rh = 1080 / user
	local k = height / rh
	local rw = width / k
	local positions = Layouts.Get(name, rh)
	local rects, keys = {}, {}
	local function add(key, w, h, position, offsetX)
		local fx = position.anchor:find("LEFT") and 0 or position.anchor:find("RIGHT") and 1 or 0.5
		local fy = position.anchor:find("BOTTOM") and 0 or position.anchor:find("TOP") and 1 or 0.5
		w, h = math.max(1, math.floor(w * k + 0.5)) / k, math.max(1, math.floor(h * k + 0.5)) / k
		local l, b = rw * fx + position.x + (offsetX or 0) - w * fx, rh * fy + position.y - h * fy
		l, b = math.floor(l * k + 0.5), math.floor(b * k + 0.5)
		rects[key] = { l, b, l + math.floor(w * k + 0.5), b + math.floor(h * k + 0.5) }
		keys[#keys + 1] = key
	end
	for _, element in ipairs(Layouts.ELEMENTS) do
		local w, h, offsetX = Layouts.Footprint(name, element.key)
		add(element.key, w, h, positions[element.key], offsetX)
	end
	local slot = Layouts.Slot(name, rh)
	add("story", slot.width, slot.height, slot)
	return rects, keys
end

local function PhysicalFit(name, width, height, user)
	local rects, keys = PhysicalRects(name, width, height, user)
	for i, key in ipairs(keys) do
		local r = rects[key]
		if r[1] < 0 or r[2] < 0 or r[3] > width or r[4] > height or r[3] <= r[1] or r[4] <= r[2] then
			return false, key .. " leaves the screen or has no area"
		end
		for j = i + 1, #keys do
			local other = keys[j]
			local s = rects[other]
			if apart(name, key, other) and overlap(r, s) then
				local pair = { [key] = true, [other] = true }
				local sharedDockEdge = pair["databars.micro"] and pair["databars.bags"]
				if not sharedDockEdge or math.min(r[4], s[4]) - math.max(r[2], s[2]) > 1 then
					return false, key .. " overlaps " .. other
				end
			end
		end
	end
	return true
end

local SCREENS = {
	{ 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 },
	{ 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 },
}
local REQUESTS = { 0.6, 16 / 19, 1.5 }
local capped = 0
for _, screen in ipairs(SCREENS) do
	local width, height = screen[1], screen[2]
	local record = { string.format("fit cap %dx%d:", width, height) }
	for _, name in ipairs(Layouts.Names()) do
		local cap = Layouts.ScaleLimit(width, height, name)
		local label = string.format("%s at %dx%d", name, width, height)
		assert(cap >= K.Scale.DEFAULT_USER_SCALE and cap <= K.Scale.MAX_USER_SCALE, label .. ": cap is in the supported range")
		assert(Layouts.Fits(name, width, height, K.Scale.DEFAULT_USER_SCALE), label .. ": the shipped default fits live placement")
		assert(Layouts.Fits(name, width, height, cap), label .. ": cap fits the snapped footprints")
		assert(PhysicalFit(name, width, height, cap), label .. ": independent snapped footprint measurement fits")
		if cap < K.Scale.MAX_USER_SCALE then
			assert(not Layouts.Fits(name, width, height, cap + 1e-6), label .. ": binary search reaches the fit boundary")
			for step = 1, 32 do
				local larger = cap + (K.Scale.MAX_USER_SCALE - cap) * step / 32
				assert(not PhysicalFit(name, width, height, larger), label .. ": no larger sampled scale fits")
			end
		end
		for _, requested in ipairs(REQUESTS) do
			local moved = { anchor = "BOTTOMLEFT", x = 91, y = 77, width = 401, height = 263 }
			local menv, MK = CoreEnv.New({
				width = width, height = height, fit = true,
				saved = {
					version = K.Store.DB_VERSION,
					account = { setupSeen = true },
					profiles = { Default = { Appearance = { uiScale = requested }, Layout = { preset = name } } },
					layouts = { Default = { ["chat.main"] = CoreEnv.DeepCopy(moved) } },
				},
			})
			CoreEnv.Boot(menv)
			local applied = MK.Scale.AppliedUserScale()
			local expected = math.min(requested, cap)
			local where = label .. " requested " .. requested
			assert(math.abs(MK.Scale.MaxUserScale() - cap) < 1e-9, where .. ": service uses the preset cap")
			assert(math.abs(applied - expected) < 1e-9, where .. ": service applies the capped size")
			assert(MK.Scale.UserScale() == requested and MK.Appearance.Get("uiScale") == requested, where .. ": the request remains saved and readable")
			assert(CoreEnv.DeepEqual(MK.Store.Layout()["chat.main"], moved), where .. ": moved elements are unchanged")
			assert(math.abs(MK.Scale.Root():GetEffectiveScale() * 1080 / 768 - applied) < 1e-9, where .. ": applied size drives the root")
			local fits, why = PhysicalFit(name, width, height, applied)
			assert(fits, where .. ": " .. tostring(why))
			assert(Layouts.Fits(name, width, height, applied), where .. ": predicate agrees with the independent rects")
			assert(#menv._errors == 0, tostring(menv._errors[1]))
			capped = capped + 1
		end
		record[#record + 1] = string.format("%s %.9f", name, cap)
	end
	print(table.concat(record, " "))
end

-- Only the shared micro/bags dock edge gets a one-pixel contact allowance, never a general overlap tolerance.
do
	local get = Layouts.Get
	local k = 0.6
	local overlapPixels = 1
	Layouts.Get = function(name, rh)
		local positions = get(name, rh)
		local micro = positions["databars.micro"]
		local _, height = Layouts.Footprint(name, "databars.micro")
		local top = math.floor(micro.y * k + 0.5) + math.floor(height * k + 0.5)
		positions["databars.bags"].y = (top - overlapPixels) / k
		return positions
	end
	assert(Layouts.Fits("DPS", 1920, 1080, k), "one pixel of contact at the shared dock boundary is intentional")
	assert(PhysicalFit("DPS", 1920, 1080, k), "the independent live model permits that same shared boundary")
	overlapPixels = 2
	assert(not Layouts.Fits("DPS", 1920, 1080, k), "two pixels at the shared dock boundary are refused")
	assert(not PhysicalFit("DPS", 1920, 1080, k), "the independent live model also refuses two pixels")
	Layouts.Get = get
end

-- The original owner-window failure must remain a failure before the service applies the cap.
do
	local unsafeRaid = PhysicalRects("Healer", 1920, 1080, 1.035953979)
	assert(unsafeRaid["groupframes.raid"][4] == 1081, "the old edge-only cap puts the live raid one pixel off screen")
	assert(not Layouts.Fits("Healer", 1920, 1080, 1.035953979), "live placement rejects the old edge-only false positive")
	local rects = PhysicalRects("DPS", 2383, 1540, 1.5)
	assert(overlap(rects["chat.main"], rects["unitframes.player"]), "uncapped owner-window chat overlaps the player")
	assert(not Layouts.Fits("DPS", 2383, 1540, 1.5), "uncapped owner-window defaults do not fit")
	assert(Layouts.ScaleLimit(0, 1540, "DPS") == K.Scale.DEFAULT_USER_SCALE, "unknown physical width falls back to the shipped default")
	assert(Layouts.ScaleLimit(2383, 0 / 0, "DPS") == K.Scale.DEFAULT_USER_SCALE, "invalid physical height falls back safely")
	assert(Layouts.ScaleLimit(2383, 1540, "unknown") == Layouts.ScaleLimit(2383, 1540, "DPS"), "unknown preset uses DPS")
	assert(not Layouts.Fits("unknown", 2383, 1540, 1), "unknown preset does not fit")
	assert(not Layouts.Fits("DPS", 2383, 1540, env.Secret(1)), "secret scales are refused without arithmetic")
end

-- Display changes restore as much of the saved request as the new aspect can fit, without rewriting it.
do
	local screen = { 2383, 1540 }
	local menv, MK = CoreEnv.New({
		width = screen[1], height = screen[2], fit = true,
		saved = { version = K.Store.DB_VERSION, account = { setupSeen = true }, profiles = { Default = { Appearance = { uiScale = 1.5 }, Layout = { preset = "DPS" } } } },
		setup = function(e)
			e.GetPhysicalScreenSize = function() return screen[1], screen[2] end
		end,
	})
	CoreEnv.Boot(menv)
	local narrow = MK.Scale.AppliedUserScale()
	screen[1], screen[2] = 5120, 1440
	menv.FireEvent("DISPLAY_SIZE_CHANGED")
	assert(MK.Scale.AppliedUserScale() > narrow, "a wider aspect restores more of the requested size")
	assert(math.abs(MK.Scale.AppliedUserScale() - Layouts.ScaleLimit(5120, 1440, "DPS")) < 1e-9, "restoration stops at the new fit cap")
	MK.Options.Write("Layout", "preset", "Healer")
	assert(math.abs(MK.Scale.AppliedUserScale() - Layouts.ScaleLimit(5120, 1440, "Healer")) < 1e-9, "changing preset recomputes the cap")
	assert(MK.Appearance.Get("uiScale") == 1.5 and MK.Scale.UserScale() == 1.5, "aspect and preset changes preserve the saved request")
	assert(#menv._errors == 0, tostring(menv._errors[1]))
end

-- The options control exposes the applied cap without overwriting the larger saved request.
do
	local O = dofile("Tools/regression/options_env.lua")
	local oenv, OK, ons = O.New({
		width = 2383, height = 1540, fit = true,
		saved = { version = K.Store.DB_VERSION, account = { setupSeen = true }, profiles = { Default = { Appearance = { uiScale = 1.5 } } } },
	})
	local list = { view = OK.Scale.Root(), GetViewWidth = function() return 800 end }
	local row = ons.Rows.Create(list)
	local items = ons.Model.SchemaItems("Appearance", OK.Appearance.schema, "General")
	local item
	for _, entry in ipairs(items) do
		if entry.key == "uiScale" then item = entry end
	end
	assert(item, "the interface size has a real schema row")
	ons.Rows.Update(row, item, nil, list)
	local slider = row.controls.slider
	assert(slider.max == OK.Scale.MaxUserScale(), "the slider never offers a size above the actual fit maximum")
	assert(slider:GetValue() == OK.Scale.AppliedUserScale(), "a capped request displays its actual size")
	assert(OK.Options.Read("Appearance", "uiScale") == 1.5, "filling the slider never writes the clamped display value")
	assert(OK.Options.Row("Appearance", "uiScale").max == 1.5, "the schema keeps the portable profile storage range")
	assert(#oenv._errors == 0, tostring(oenv._errors[1]))
end

-- A reserve is room kept around an element, never less than the element ------------------------------------------
for _, name in ipairs(Layouts.Names()) do
	for _, element in ipairs(Layouts.ELEMENTS) do
		local w, h = Layouts.Footprint(name, element.key)
		if not Layouts.Sizes(name)[element.key] then
			assert(w >= element.width and h >= element.height, string.format("%s: %s draws %d x %d but the layout plans only %d x %d", name, element.key, element.width, element.height, w, h))
		end
	end
end

-- Every preset at every aspect: on screen and apart --------------------------------------------------------------
local checked = 0
for _, name in ipairs(Layouts.Names()) do
	local layout = Layouts.Get(name)
	for _, aspect in ipairs(ASPECTS) do
		local width = HEIGHT * aspect[2]
		local label = name .. " at " .. aspect[1]
		local rects, keys = {}, {}
		for _, element in ipairs(Layouts.ELEMENTS) do
			local w, h, offsetX = Layouts.Footprint(name, element.key)
			local l, b, r, t = Layouts.Rect({ width = w, height = h, offsetX = offsetX }, layout[element.key], width, HEIGHT)
			assert(l >= -1e-6 and b >= -1e-6 and r <= width + 1e-6 and t <= HEIGHT + 1e-6,
				string.format("%s: %s is off screen (%.1f, %.1f to %.1f, %.1f on %.1f x %d)", label, element.key, l, b, r, t, width, HEIGHT))
			rects[element.key] = { l, b, r, t }
			keys[#keys + 1] = element.key
		end
		rects.story = Story(name, width)
		keys[#keys + 1] = "story"
		local story = rects.story
		assert(story[1] >= -1e-6 and story[2] >= -1e-6 and story[3] <= width + 1e-6 and story[4] <= HEIGHT + 1e-6, label .. ": the story slot is on screen")
		for _, key in ipairs({ "meters.damage", "databars.strip" }) do
			local r = rects[key]
			assert(r[4] <= story[2] - 16 + 1e-6, string.format("%s: %s (top %.0f) stands at least 16 under the story slot (foot %.0f)", label, key, r[4], story[2]))
		end
		-- The loot feed stands over the chat card with a card gap between, and over nothing else.
		assert(rects["qol.lootfeed"][2] - rects["chat.main"][4] >= 16 - 1e-6, label .. ": the loot feed keeps 16 units over the chat card")
		-- The tooltip anchor overlaps nothing at all: no card, no dock, no bar a player may turn on.
		local tip = rects["tooltips.anchor"]
		for _, key in ipairs(keys) do
			if key ~= "tooltips.anchor" then
				assert(not overlap(tip, rects[key]), string.format("%s: the tooltip anchor (%.0f,%.0f-%.0f,%.0f) lies on %s", label, tip[1], tip[2], tip[3], tip[4], key))
			end
		end
		for i = 1, #keys do
			for j = i + 1, #keys do
				local a, c = keys[i], keys[j]
				if apart(name, a, c) and overlap(rects[a], rects[c]) then
					local ra, rc = rects[a], rects[c]
					error(string.format("%s: %s (%.0f,%.0f-%.0f,%.0f) overlaps %s (%.0f,%.0f-%.0f,%.0f)", label, a, ra[1], ra[2], ra[3], ra[4], c, rc[1], rc[2], rc[3], rc[4]))
				end
			end
		end
		checked = checked + 1
	end
end

-- The live boss column: the unit frames build it at the element's size and its auras fit the footprint's spare width --
do
	local U = dofile("Tools/regression/unitframes_env.lua")
	local uenv, UK, ns = U.New()
	local s = ns.Settings.Snapshot("boss")
	local element = UK.Setup.Layouts.Element("unitframes.boss")
	local fw = UK.Setup.Layouts.Footprint("DPS", "unitframes.boss")
	local auraW = s.auraColumns * s.auraSize + (s.auraColumns - 1) * s.auraSpacing + 2
	assert(s.auraPosition == "LEFT" and fw - element.width >= auraW, "the boss auras hang left of the cards inside the footprint: " .. (fw - element.width) .. " < " .. auraW)
	local _, _, w, h = UK.Layout.Rect("unitframes.boss")
	assert(math.abs(w - element.width) < 1 and math.abs(h - element.height) < 1, "the boss holder is built at the element's size")
	-- Each preset's live boss column: with the preset's own unit-frame settings and at its position, every card's debuff
	-- row lies inside the footprint the preset keeps and on screen (Healer heads the left rail, where the debuffs
	-- hang towards the centre on the right of the cards; codex review: they once hung off the left edge).
	local Geometry = dofile("Tools/regression/geometry.lua")
	local root = UK.Scale.Root()
	local rw, rh = UK.Layout.RootSize()
	for i = 1, 5 do
		uenv._units["boss" .. i] = { name = "Boss " .. i, level = 62, health = 500, healthMax = 1000, reaction = 2, canAttack = true }
	end
	uenv.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	for _, name in ipairs(Layouts.Names()) do
		for _, entry in ipairs(Layouts.Settings(name)) do
			if entry.module == "UnitFrames" then
				UK.Options.Write("UnitFrames", entry.key, entry.value)
			end
		end
		local position = Layouts.Get(name)["unitframes.boss"]
		assert(UK.Layout.Update("unitframes.boss", { anchor = position.anchor, x = position.x, y = position.y }))
		uenv.RunTimers()
		local bw, bh = Layouts.Footprint(name, "unitframes.boss")
		local l, b, r, t = Layouts.Rect({ width = bw, height = bh }, position, rw, rh)
		for i, view in ipairs(UK.Layout and ns.Frames.Get("boss").views or {}) do
			local host = Geometry.Rect(view.auras.host, root)
			assert(host and host.left >= l - 0.5 and host.right <= r + 0.5 and host.bottom >= b - 0.5 and host.top <= t + 0.5,
				string.format("%s: boss%d's debuff row (%.0f-%.0f) lies inside the column's footprint (%.0f-%.0f)", name, i, host and host.left or -1, host and host.right or -1, l, r))
			local card = Geometry.Rect(view.button, root)
			assert(host.right <= card.left + 0.5 or host.left >= card.right - 0.5, name .. ": boss" .. i .. "'s debuffs sit beside its card")
		end
	end
	assert(#uenv._errors == 0, tostring(uenv._errors[1]))
end

-- The live aura rows at the owner's counts: the buff and debuff rows beside the map, at each preset's position, holding
-- 0, 2, 8, 24 and 40 buffs beside 12 debuffs, stay inside the footprint the layouts plan for them and overlap nothing at
-- any aspect (owner pass 1, 2026-11-09: plain rows that never grow past their cap; the rest reads +N).
local blessings = 0
do
	local A = dofile("Tools/regression/auras_env.lua")
	local aenv, AK, ans = A.New({ layout = true })
	AK.Modules.Enable("Auras")
	aenv.RunTimers()
	local Model, Panel = ans.Model, ans.Panel
	local helpful, harmful = A.Container(aenv, "HELPFUL"), A.Container(aenv, "HARMFUL")
	local desc, ddesc = Panel.Group("buffs"), Panel.Group("debuffs")
	local Geometry = dofile("Tools/regression/geometry.lua")
	local root = AK.Scale.Root()
	local function size(container, group, n)
		local shown = math.min(n, Model.Capacity(group, 0))
		local w, h = Model.ElementSize(group, Model.Timer(AK.Store.Module("Auras")))
		local columns, rows = math.min(shown, group.columns), math.ceil(shown / group.columns)
		container:SetSize(columns > 0 and columns * w + (columns - 1) * group.spacing or 0, rows * h + math.max(0, rows - 1) * group.rowSpacing)
	end
	local settings = AK.Store.Module("Auras")
	local buffs, debuffs = Model.Group(settings, "buffs"), Model.Group(settings, "debuffs")
	local aspects = ASPECTS
	for _, name in ipairs(Layouts.Names()) do
		local layout = Layouts.Get(name)
		for _, n in ipairs({ 0, 2, 8, 24, 40 }) do
			size(helpful, buffs, n)
			size(harmful, debuffs, 12)
			A.Counters(ans, { n, 0, 12 })
			aenv.RunTimers()
			local state = string.format("%s, %d buffs and 12 debuffs", name, n)
			for _, item in ipairs({ { "auras.buffs", desc, helpful }, { "auras.debuffs", ddesc, harmful } }) do
				local key, group, container = item[1], item[2], item[3]
				local holder = Geometry.Rect(group.holder, root)
				local rows = Geometry.Rect(container, root)
				assert(holder and rows and group.host:IsShown(), state .. ": " .. key .. " shows")
				assert(math.abs(rows.top - holder.top) < 0.5 and math.abs(rows.right - holder.right) < 0.5, state .. ": " .. key .. " grows from its element's top right corner")
				local fw, fh = Layouts.Footprint(name, key)
				local cw, ch = holder.right - holder.left, holder.top - holder.bottom
				assert(rows.left >= holder.left - 0.5 and rows.bottom >= holder.bottom - 0.5, string.format("%s: %s's rows (%.0f x %.0f) run past the element (%.0f x %.0f)", state, key, rows.right - rows.left, rows.top - rows.bottom, cw, ch))
				assert(cw <= fw + 0.5 and ch <= fh + 0.5, string.format("%s: %s (%.0f x %.0f) outgrows the %d x %d the layout plans", state, key, cw, ch, fw, fh))
				for _, aspect in ipairs(aspects) do
					local width = HEIGHT * aspect[2]
					local own = { Layouts.Rect({ width = cw, height = ch }, layout[key], width, HEIGHT) }
					local story = Story(name, width)
					assert(not overlap(own, story), string.format("%s at %s: %s (%.0f,%.0f-%.0f,%.0f) overlaps the story slot (%.0f,%.0f-%.0f,%.0f)",
						state, aspect[1], key, own[1], own[2], own[3], own[4], story[1], story[2], story[3], story[4]))
					for _, element in ipairs(Layouts.ELEMENTS) do
						local other = element.key
						if other ~= key and apart(name, key, other) then
							local w, h, offsetX = Layouts.Footprint(name, other)
							local r = { Layouts.Rect({ width = w, height = h, offsetX = offsetX }, layout[other], width, HEIGHT) }
							assert(not overlap(own, r), string.format("%s at %s: %s (%.0f,%.0f-%.0f,%.0f) overlaps %s (%.0f,%.0f-%.0f,%.0f)",
								state, aspect[1], key, own[1], own[2], own[3], own[4], other, r[1], r[2], r[3], r[4]))
						end
					end
				end
			end
			blessings = blessings + 1
		end
	end
	assert(#aenv._errors == 0, tostring(aenv._errors[1]))
end

-- The play field stays clear of action bars (round 5, Opus #2: bar 2, on by default, stood above the sigil across the
-- screen's centre, over the character). Every action bar a player may turn on, in every preset at 16:9 and 21:9,
-- stays out of the centre column above the sigil's top and out of the screen's central 40% band.
local bars = 0
for _, name in ipairs(Layouts.Names()) do
	local layout = Layouts.Get(name)
	for _, aspect in ipairs({ { "16:9", 16 / 9 }, { "21:9", 21 / 9 } }) do
		local width = HEIGHT * aspect[2]
		local column = { width * 0.3, 0, width * 0.7, HEIGHT }
		local band = { width * 0.3, HEIGHT * 0.3, width * 0.7, HEIGHT * 0.7 }
		local tw, th = Layouts.Footprint(name, "unitframes.target")
		local _, _, _, sigilTop = Layouts.Rect({ width = tw, height = th }, layout["unitframes.target"], width, HEIGHT)
		for _, element in ipairs(Layouts.ELEMENTS) do
			if element.key:find("^actionbars%.") then
				local w, h = Layouts.Footprint(name, element.key)
				local r = { Layouts.Rect({ width = w, height = h }, layout[element.key], width, HEIGHT) }
				local where = string.format("%s at %s: %s (%.0f,%.0f-%.0f,%.0f)", name, aspect[1], element.key, r[1], r[2], r[3], r[4])
				assert(not (overlap(r, column) and r[4] > sigilTop), where .. " stands in the centre column above the sigil's top " .. sigilTop)
				assert(not overlap(r, band), where .. " lies in the screen's central 40% band")
				bars = bars + 1
			end
		end
	end
end

-- An action bar's footprint is the grid its preset writes (round 5, Fable #2: the pet bar was planned as two rows of
-- five while the bar drew one row of ten, so its first button sat on the chat card). Each bar the layouts place, at
-- the rows and buttons Apply writes and the action bars' own defaults, is exactly its element's size.
do
	local A = dofile("Tools/regression/actionbars_env.lua")
	local aenv, AK, ans = A.New()
	A.Enable(aenv, AK)
	local written = {}
	for _, entry in ipairs(Layouts.Settings("DPS")) do
		if entry.module == "ActionBars" then
			written[entry.key] = entry.value
		end
	end
	for _, def in ipairs(ans.BARS) do
		local element = Layouts.Element(def.element)
		local cfg = ans.defaults[def.key]
		assert(written[def.key .. ".rows"] == cfg.rows, def.key .. ": Apply writes the rows the bar has by default (" .. tostring(written[def.key .. ".rows"]) .. " against " .. tostring(cfg.rows) .. ")")
		local w, h = ans.GridSize(math.min(cfg.buttons, def.max), cfg.rows, cfg.size, cfg.spacing)
		assert(math.abs(w - element.width) < 0.5 and math.abs(h - element.height) < 0.5,
			string.format("%s draws %.0f x %.0f in %d rows, but its element is %d x %d", def.key, w, h, cfg.rows, element.width, element.height))
	end
	assert(#aenv._errors == 0, tostring(aenv._errors[1]))
end

print("setup collisions ok: " .. capped .. " capped screen/preset/request cases; " .. bars .. " action bar rects clear of the play field; " .. #Layouts.Names() .. " presets x " .. #ASPECTS .. " aspects, " .. checked .. " screens, " .. #Layouts.ELEMENTS .. " elements each, " .. blessings .. " aura row states")
