-- test-unitframes-parity-r4b-review.lua: the round 4b review's probes: the dispel retry while auras are restricted, intermediate batch crafts, the dispel icon after a resize and totems beside a portrait at four screen sizes, a Bleed and the engine's icon tint, partial dispel APIs, the idle cast preview, chained spell ID lists and one-slot totem updates.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function Boot(width, height)
	local reads = {}
	local env, K, ns = U.New({
		width = width,
		height = height,
		-- The dispel display and the totems beside a portrait are the plate's: the Medallions slab draws neither.
		saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true, player = { style = "plate" } } } }, characters = {}, layouts = {} },
		setup = function(e)
			e._recasts = 2
			e.C_TradeSkillUI = { GetRemainingRecasts = function() return e._recasts end }
			e.C_DurationUtil = { CreateDuration = function()
				local d = {}
				function d.SetTimeSpan(self, start, finish) self.start, self.finish = start, finish end
				function d.GetRemainingDuration(self) return math.max(0, self.finish - e._time) end
				function d.GetElapsedDuration(self) return math.max(0, e._time - self.start) end
				function d.GetTotalDuration(self) return self.finish - self.start end
				return d
			end }
			e.Enum.StatusBarTimerDirection = e.Enum.StatusBarTimerDirection or { ElapsedTime = 0, RemainingTime = 1 }
			local casting = e.UnitCastingInfo
			e.UnitCastingInfo = function(token)
				local r = { casting(token) }
				if e._trade and r[1] ~= nil then r[6] = true end
				return unpack(r, 1, 11)
			end
			e._totems = {}
			e.GetNumTotemSlots = function() return 4 end
			e.GetTotemInfo = function(slot)
				reads[#reads + 1] = slot
				local t = e._totems[slot]
				if not t then return false, "", 0, 0, 0 end
				return true, t.name, t.start, t.duration, t.icon
			end
		end,
	})
	local function write(key, value)
		K.Options.Write("UnitFrames", key, value)
		env.RunTimers()
	end
	local function clean(where)
		assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
	end
	return env, K, ns, write, clean, reads
end

local failed = {}
local function check(name, fn)
	local ok, err = pcall(fn)
	if not ok then failed[#failed + 1] = name .. ": " .. tostring(err) end
end

local function overlap(a, b)
	return a:GetLeft() < b:GetRight() and b:GetLeft() < a:GetRight() and a:GetBottom() < b:GetTop() and b:GetBottom() < a:GetTop()
end

-- The dispel icon follows a resize, and totems clear a portrait on their side, at every screen size.
for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do check(size[1] .. "x" .. size[2], function()
	local env, K, ns, write, clean = Boot(size[1], size[2])
	local where = size[1] .. "x" .. size[2]
	local uf = ns.Frames.Get("player")
	local view = uf.views[1]
	local w, h = uf.holder:GetSize()
	uf.holder:SetSize(w, 160)
	write("player.style", "plate")
	write("player.dispelIcon", "TOPRIGHT")
	write("player.dispelIconSize", 40)
	assert(W.LastCall(view.dispel.parts.mark, "SetSize")[1] > 39, where .. ": a tall frame takes the full icon size")
	for _, height in ipairs({ 100, 45, 30 }) do
		uf.holder:SetSize(w, height)
		ns.Frames.Relayout(uf)
		local icon = W.LastCall(view.dispel.parts.mark, "SetSize")[1]
		assert(icon <= K.Widgets.Snap(view.health, view.geometry.health.h) + 0.01, where .. ": the type icon fits the health bar at height " .. height .. ": " .. icon)
	end
	uf.holder:SetSize(w, h)
	ns.Frames.Relayout(uf)
	write("player.dispelIcon", "")
	env._totems[1] = { name = "Searing Totem", start = 1, duration = 60, icon = 135824 }
	write("player.portrait", true)
	write("player.totems", true)
	local row
	for _, child in ipairs({ uf.holder:GetChildren() }) do
		if child.buttons then row = child end
	end
	for _, side in ipairs({ "RIGHT", "LEFT" }) do
		write("player.portraitSide", side)
		write("player.totemPosition", side)
		local portrait, totem = view.portraitFrame, row.buttons[1]
		assert(portrait:IsShown() and totem:IsShown(), where .. ": portrait and totem show")
		assert(not overlap(portrait, totem), where .. ": a " .. side .. " totem clears the " .. side .. " portrait")
	end
	clean(where)
end) end

local env, K, ns, write, clean, reads = Boot(1920, 1080)
local Settings, Frames = ns.Settings, ns.Frames
local uf = Frames.Get("player")
local view = uf.views[1]

-- A capability the dispel slot needs is missing: it fails closed and logs, with no error.
check("partial APIs", function()
	local create = env.CreateFrame
	for _, strip in ipairs({ "SetUnit", "SetAuraSlotFilterString", "SetAuraSlotEnabled", "AddDispelTypeTexture" }) do
		env.CreateFrame = function(kind, ...)
			local frame = create(kind, ...)
			if kind == "AuraContainer" then
				frame[strip] = false
				local add = frame.AddAuraSlot
				function frame.AddAuraSlot(self, key, filter, options)
					local init = options.initializeFrame
					options.initializeFrame = function(button)
						button[strip] = false
						init(button)
					end
					return add(self, key, filter, options)
				end
			end
			return frame
		end
		view.dispel = nil
		write("player.dispelIcon", "TOPRIGHT")
		assert(pcall(ns.Dispel.Apply, view), "no error without " .. strip)
		assert(view.dispel == false, "without " .. strip .. " the dispel display is refused")
		write("player.dispelIcon", "")
		clean("without " .. strip)
	end
	env.CreateFrame = create
	view.dispel = nil
end)

-- Auras restricted out of combat: Apply waits for the restriction to lift instead of retrying at once.
check("restricted", function()
	local secret = true
	env.C_Secrets.ShouldAurasBeSecret = function() return secret end
	assert(not env.InCombatLockdown(), "out of combat")
	write("player.dispelOverlay", "health")
	assert(pcall(ns.Dispel.Apply, view), "a restricted Apply never recurses")
	assert(view.dispel == nil, "nothing is built while auras are restricted")
	secret = false
	env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED")
	env.RunTimers()
	assert(view.dispel and view.dispel.container._slots.dispel.enabled, "the overlay lands when auras are readable")
	write("player.dispelOverlay", "")
	clean("restricted")
end)

-- A Bleed: the engine finds no asset and clears the icon; game colours leave the icon white, as the client does.
check("bleed", function()
	write("player.dispelIcon", "TOPRIGHT")
	env._units.player.auras = { { id = 9, icon = 136207, left = 12, harmful = true, dispel = "Bleed" } }
	local fixture = dofile("Tools/regression/aura_fixture_engine.lua")
	assert(pcall(fixture.Refresh, env), "the fixture models a Bleed")
	local mark = view.dispel.parts.icon
	assert(W.LastCall(mark, "SetTexture")[1] == nil, "no Bleed asset, no icon")
	env._units.player.auras = { { id = 9, icon = 136207, left = 12, harmful = true, dispel = "Magic" } }
	fixture.Refresh(env)
	local tint = W.LastCall(mark, "SetVertexColor")
	assert(W.LastCall(mark, "SetTexture")[1] ~= nil and tint[1] == 1 and tint[2] == 1 and tint[3] == 1, "the game's colours leave the Magic icon white")
	write("edit", "player")
	write("player.style", "plate")
	local pane = ns.Preview.Build(env.UIParent)
	local sample = pane.views.player.dispelSample
	tint = W.LastCall(sample.icon, "SetVertexColor")
	assert(tint[1] == 1 and tint[2] == 1 and tint[3] == 1, "the preview icon is white in the game's colours")
	write("dispelCustom", true)
	write("dispelMagic", { r = 1, g = 0, b = 0 })
	pane:Refresh()
	tint = W.LastCall(sample.icon, "SetVertexColor")
	assert(tint[1] == 1 and tint[2] == 0 and tint[3] == 0, "own colours tint the preview icon")
	write("dispelCustom", false)
	write("player.dispelIcon", "")
	env._units.player.auras = nil
	clean("bleed")
end)

-- Hide when idle off previews the empty idle track; on previews a cast.
check("idle preview", function()
	write("edit", "player")
	local pane = ns.Preview.Build(env.UIParent)
	local cast = pane.casts.player
	write("player.castbarHideIdle", true)
	pane:Refresh()
	assert(cast.frame:IsShown() and U.Shown(env, cast.text) ~= "", "on previews a cast")
	write("player.castbarHideIdle", false)
	pane:Refresh()
	assert(cast.frame:IsShown() and U.Shown(env, cast.text) == "" and select(1, U.Bar(env, cast.bar)) == 0, "off previews the idle track")
	write("player.castbarHideIdle", true)
	pane:Refresh()
	clean("idle preview")
end)

-- One totem slot's event repaints only that slot; entering the world repaints them all.
check("totem slot", function()
	write("player.totems", true)
	for i = #reads, 1, -1 do reads[i] = nil end
	env.FireEvent("PLAYER_TOTEM_UPDATE", 2)
	assert(#reads == 1 and reads[1] == 2, "slot 2's event reads slot 2 only: " .. table.concat(reads, ","))
	for i = #reads, 1, -1 do reads[i] = nil end
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(#reads == 4, "entering the world reads every slot")
	write("player.totems", false)
	clean("totem slot")
end)

-- Chained spell ID lists resolve through each link and refresh every reader; a loop keeps each frame's own list.
check("lists", function()
	write("player.medallionsAuras", true)
	write("player.medallionsAuraFilter", "both")
	write("focus.auraHidden", "333")
	write("target.auraHidden", "222")
	write("target.auraLists", "focus")
	write("player.auraLists", "target")
	assert(Settings.Value("target", "auraHidden") == "333" and Settings.Value("player", "auraHidden") == "333", "the player reads the focus list through the target")
	write("focus.auraHidden", "444")
	local candidates = view.auras.container._groups.debuffs.candidates
	assert(candidates and candidates.excludeSpellIDs and candidates.excludeSpellIDs[444], "an edit on the focus reaches the player")
	write("player.auraLists", "")
	write("focus.auraLists", "target")
	assert(Settings.Value("focus", "auraHidden") == "444" and Settings.Value("target", "auraHidden") == "222", "a loop keeps each frame's own list")
	write("edit", "focus")
	local rows = {}
	for _, row in ipairs(Settings.Schema()) do
		if row.key then rows[row.key] = row end
	end
	assert(rows["focus.auraHidden"].showWhen(K.Store.Module("UnitFrames")), "and shows the list it uses")
	write("focus.auraLists", "")
	write("target.auraLists", "")
	clean("lists")
end)

-- A merged batch keeps running through an intermediate craft's stop, lands on the last, and runs on a native span.
check("craft batch", function()
	local pcb = ns.CastBars.Inline("player")[1]
	local function craft(start, left)
		env._recasts, env._time = left, start / 1000
		env._units.player.cast = { name = "Bolt of Linen", texture = 135846, start = start, finish = start + 3000, spellID = 116 }
		env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
	end
	local function stop()
		env._time = env._time + 3
		env._units.player.cast = nil
		env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-1", 116, 1)
	end
	write("player.style", "plate")
	write("player.castbarTimer", false)
	write("player.castbarCraftBar", true)
	env._trade = true
	craft(1000, 2)
	local span = W.LastCall(pcb.bar, "SetTimerDuration")
	assert(span and span[1].start == 1 and span[1].finish == 10, "the bar runs the batch's whole span natively")
	assert(pcb.frame:GetScript("OnUpdate") == nil, "no Lua ticker while the timer text is off")
	stop()
	assert(pcb.active and not pcb.landed, "the first craft's stop keeps the batch running")
	craft(4000, 1)
	assert(W.LastCall(pcb.bar, "SetTimerDuration")[1].start == 1, "the second craft continues the span")
	stop()
	assert(pcb.active, "and so does the second craft's stop")
	craft(7000, 0)
	stop()
	assert(not pcb.active and pcb.landed, "the last craft lands")
	env.RunTimers()
	craft(30000, 1)
	stop()
	assert(pcb.active, "a batch waits a moment for its next craft")
	env.RunTimers()
	assert(not pcb.active, "and lands when no craft follows")
	write("player.castbarCraftBar", false)
	write("player.castbarTimer", true)
	env._trade = nil
	clean("craft batch")
end)
assert(#failed == 0, table.concat(failed, "\n"))
print("test-unitframes-parity-r4b-review: ok")
