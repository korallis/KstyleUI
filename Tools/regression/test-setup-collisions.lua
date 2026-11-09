-- test-setup-collisions.lua: every preset (DPS, Tank, Healer) resolves to element rects at 16:9, 16:10 and 21:9 on the 1080-unit canvas with nothing off screen and nothing overlapping, each element at the full footprint it draws: a reserve never hides part of its element (the boss stack once reserved one card of five), the tooltip anchor lies on no card (it once covered the readout and the menu you hover), the boss column's footprint covers its cards and their aura room from the live unit frames, and the live Blessings card at 0 to 40 buffs beside 12 debuffs fits the height its preset reserves.
local CoreEnv = dofile("Tools/regression/core_env.lua")

local env, K = CoreEnv.New()
CoreEnv.Boot(env)
local Layouts = K.Setup.Layouts

local HEIGHT = 1080
local ASPECTS = { { "16:9", 16 / 9 }, { "16:10", 16 / 10 }, { "21:9", 21 / 9 } }

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
			local w, h = Layouts.Footprint(name, element.key)
			local l, b, r, t = Layouts.Rect({ width = w, height = h }, layout[element.key], width, HEIGHT)
			assert(l >= -1e-6 and b >= -1e-6 and r <= width + 1e-6 and t <= HEIGHT + 1e-6,
				string.format("%s: %s is off screen (%.1f, %.1f to %.1f, %.1f on %.1f x %d)", label, element.key, l, b, r, t, width, HEIGHT))
			rects[element.key] = { l, b, r, t }
			keys[#keys + 1] = element.key
		end
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

-- The assembled right rail at the owner's aura counts: the live Blessings card, at each preset's own Auras settings,
-- holding 0, 8, 24 and 40 buffs beside 12 debuffs, stays inside the height the layouts reserve for it and overlaps
-- nothing at any aspect (round 3, Astra #1B: the card once ran 37 to 88 units into the meter or the boss column).
local blessings = 0
do
	local A = dofile("Tools/regression/auras_env.lua")
	local aenv, AK, ans = A.New({ layout = true })
	local slots = { HELPFUL = {}, HARMFUL = {} }
	aenv.C_UnitAuras = {
		GetAuraSlots = function(_, filter, maxSlots, continuation)
			local list = slots[filter] or {}
			local from = (continuation or 0) + 1
			local out, last = {}, math.min(#list, from + (maxSlots or #list) - 1)
			for i = from, last do
				out[#out + 1] = list[i]
			end
			return last < #list and last or nil, unpack(out)
		end,
	}
	AK.Modules.Enable("Auras")
	aenv.RunTimers()
	local Model, Panel = ans.Model, ans.Panel
	local helpful, harmful = A.Container(aenv, "HELPFUL"), A.Container(aenv, "HARMFUL")
	local desc, ddesc = Panel.Group("buffs"), Panel.Group("debuffs")
	local Geometry = dofile("Tools/regression/geometry.lua")
	local root = AK.Scale.Root()
	local function fill(list, n)
		for i = #list, 1, -1 do
			list[i] = nil
		end
		for i = 1, n do
			list[i] = i
		end
	end
	local function size(container, group, n)
		local shown = math.min(n, Model.Capacity(group, 0))
		local w, h = Model.ElementSize(group, Model.Timer(AK.Store.Module("Auras")))
		local columns, rows = math.min(shown, group.columns), math.ceil(shown / group.columns)
		container:SetSize(columns > 0 and columns * w + (columns - 1) * group.spacing or 0, rows * h + math.max(0, rows - 1) * group.rowSpacing)
	end
	for _, name in ipairs(Layouts.Names()) do
		for _, entry in ipairs(Layouts.Settings(name)) do
			if entry.module == "Auras" then
				AK.Options.Write("Auras", entry.key, entry.value)
			end
		end
		aenv.RunTimers()
		local settings = AK.Store.Module("Auras")
		local buffs, debuffs = Model.Group(settings, "buffs"), Model.Group(settings, "debuffs")
		local layout = Layouts.Get(name)
		local fw, fh = Layouts.Footprint(name, "auras.buffs")
		for _, n in ipairs({ 0, 8, 24, 40 }) do
			fill(slots.HELPFUL, n)
			fill(slots.HARMFUL, 12)
			size(helpful, buffs, n)
			size(harmful, debuffs, 12)
			aenv.FireEvent("UNIT_AURA", "player")
			aenv.RunTimers()
			-- The card the player sees: the holder, the glass and every row it docks, measured where they draw.
			local state = string.format("%s, %d buffs and 12 debuffs", name, n)
			local drawn = Geometry.Rect(desc.holder, root)
			for _, part in ipairs({ desc.card.edge, helpful, harmful, ddesc.dock }) do
				local r = Geometry.Rect(part, root)
				assert(r, state .. ": a card part has no rect")
				drawn = { left = math.min(drawn.left, r.left), right = math.max(drawn.right, r.right), bottom = math.min(drawn.bottom, r.bottom), top = math.max(drawn.top, r.top) }
			end
			local holder = Geometry.Rect(desc.holder, root)
			assert(math.abs(drawn.top - holder.top) < 0.5 and math.abs(drawn.right - holder.right) < 0.5, state .. ": the card hangs from its holder's top right corner")
			local cw, ch = drawn.right - drawn.left, drawn.top - drawn.bottom
			assert(desc.host:IsShown() and ch > 0, state .. ": the Blessings card shows")
			assert(cw <= fw + 0.5 and ch <= fh + 0.5, string.format("%s: the card (%.0f x %.0f) outgrows the %d x %d the layout reserves", state, cw, ch, fw, fh))
			for _, aspect in ipairs(ASPECTS) do
				local width = HEIGHT * aspect[2]
				local card = { Layouts.Rect({ width = cw, height = ch }, layout["auras.buffs"], width, HEIGHT) }
				for _, element in ipairs(Layouts.ELEMENTS) do
					local key = element.key
					if key ~= "auras.buffs" and apart(name, "auras.buffs", key) then
						local w, h = Layouts.Footprint(name, key)
						local other = { Layouts.Rect({ width = w, height = h }, layout[key], width, HEIGHT) }
						assert(not overlap(card, other), string.format("%s at %s: the Blessings card (%.0f,%.0f-%.0f,%.0f) overlaps %s (%.0f,%.0f-%.0f,%.0f)",
							state, aspect[1], card[1], card[2], card[3], card[4], key, other[1], other[2], other[3], other[4]))
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

print("setup collisions ok: " .. bars .. " action bar rects clear of the play field; " .. #Layouts.Names() .. " presets x " .. #ASPECTS .. " aspects, " .. checked .. " screens, " .. #Layouts.ELEMENTS .. " elements each, " .. blessings .. " Blessings states")
