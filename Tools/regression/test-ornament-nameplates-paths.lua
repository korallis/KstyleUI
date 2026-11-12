-- test-ornament-nameplates-paths.lua: a plate's ornament restyles only when its target state, rank, markers, name, level badge, cast or name-only mode changes; per-event updates across forty plates touch no ornament, a target change restyles exactly two plates, a recycled plate of the same kind none, a hidden plate waits for its show, and at Off the gates do nothing.
local N = dofile("Tools/regression/nameplates_env.lua")
local env, K, ns = N.New()
local Scene = dofile("Tools/render/scene.lua")
env._textWidth = function(text, fontPath, size)
	return Scene.TextWidth(Scene.PlainText(text), size, fontPath)
end
local CAST = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
local ELITE = { name = "Bloodtalon Matriarch", level = 40, classification = "elite", reaction = 2, canAttack = true }
local NORMAL = { name = "Riverglade Snapper", level = 37, reaction = 2, canAttack = true }
env.WorldFrame:SetPoint("TOPLEFT")
env.WorldFrame:SetPoint("BOTTOMRIGHT")
local SCALE = 768 / 1080
for i = 1, 40 do
	local base = N.Base(env)
	base:ClearAllPoints()
	base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", (120 + ((i - 1) % 8) * 230) * SCALE, (1080 - (120 + math.floor((i - 1) / 8) * 180)) * SCALE)
	N.Add(env, "nameplate" .. i, i % 5 == 0 and ELITE or NORMAL, { base = base })
	N.Debuffs(env, "nameplate" .. i, 8)
	if i % 4 == 0 then
		env._units["nameplate" .. i].cast = CAST
		env.FireEvent("UNIT_SPELLCAST_START", "nameplate" .. i)
	end
end
N.Target(env, "nameplate40")
env.RunTimers()
assert(K.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")

local function Fire(frame, script)
	local fn = frame._scripts and frame._scripts[script]
	if fn then fn(frame) end
end
for _, frame in ipairs(env._frames) do
	for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
		local original = frame[method]
		frame[method] = function(self, ...)
			local was = self:IsVisible()
			original(self, ...)
			local now = self:IsVisible()
			if was ~= now then Fire(self, now and "OnShow" or "OnHide") end
		end
	end
end
local function Plate(i) return ns.Plates.Get("nameplate" .. i) end
assert(Plate(5).ornament.used > 0 and Plate(1).ornament.used > 0, "the plates draw their ornaments before the checks")

local Handle = getmetatable(Plate(1).ornament)
local counts, restyled = { Restyle = 0, Place = 0, Piece = 0, Follow = 0, Swap = 0 }, {}
for name in pairs(counts) do
	local original = Handle[name]
	Handle[name] = function(self, ...)
		counts[name] = counts[name] + 1
		if name == "Restyle" then restyled[self] = (restyled[self] or 0) + 1 end
		return original(self, ...)
	end
end
local function reset()
	for name in pairs(counts) do counts[name] = 0 end
	for h in pairs(restyled) do restyled[h] = nil end
end
local function plates()
	local list = {}
	for h in pairs(restyled) do if h.kind == "plate" then list[#list + 1] = h end end
	return list
end
local function drawn(handle)
	local names = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then
			local _, _, _, x, y = texture:GetPoint(1)
			names[#names + 1] = ((texture:GetTexture() or ""):match("([%w]+)%.png$") or "Fill") .. "@" .. string.format("%.3f,%.3f", x, y)
		end
	end
	return table.concat(names, " ")
end
local function Event(event, unit)
	local list = {}
	for _, frame in ipairs(env._frames) do
		local reg = frame._events and frame._events[event]
		local wanted = reg == true
		if type(reg) == "table" then for _, u in ipairs(reg) do wanted = wanted or u == unit end end
		if wanted and frame._scripts.OnEvent then list[#list + 1] = frame end
	end
	assert(#list > 0, "a frame listens for " .. event)
	return function(...)
		for i = 1, #list do list[i]._scripts.OnEvent(list[i], event, ...) end
	end
end

env.SetCombat(true)
env.RunTimers()
reset()
local updates = {}
for _, frame in ipairs(env._frames) do
	local script = frame._scripts and frame._scripts.OnUpdate
	if script then updates[#updates + 1] = { frame, script } end
end
local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE",
	"UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FLAGS", "UNIT_FACTION", "UNIT_DISPLAYPOWER", "UNIT_SPELLCAST_DELAYED" }
local GLOBAL_EVENTS = { "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED", "QUEST_LOG_UPDATE", "SPELL_UPDATE_COOLDOWN" }
local fires = {}
for _, event in ipairs(UNIT_EVENTS) do
	for i = 1, 40 do
		local unit = "nameplate" .. i
		local ok, fire = pcall(Event, event, unit)
		if ok then fires[#fires + 1] = { fire, unit } end
	end
end
for _, event in ipairs(GLOBAL_EVENTS) do
	local ok, fire = pcall(Event, event)
	if ok then fires[#fires + 1] = { fire } end
end
assert(#fires > 400, "the burst reaches every plate: " .. #fires .. " handlers")
for round = 1, 5 do
	for i = 1, 40 do
		local u = env._units["nameplate" .. i]
		u.health = 200 + (i * 37 + round * 11) % 600
	end
	for _, entry in ipairs(fires) do entry[1](entry[2]) end
	for _, entry in ipairs(updates) do
		local frame, script = entry[1], entry[2]
		if frame._scripts.OnUpdate == script then script(frame, 0.05) end
	end
	env.RunTimers()
end
assert(#updates > 0, "the burst drives the running OnUpdate scripts")
assert(counts.Restyle == 0 and counts.Place == 0 and counts.Piece == 0 and counts.Follow == 0 and counts.Swap == 0, string.format("per-event plate updates touch no ornament: %d restyles, %d placements, %d anchored pieces, %d follows, %d swaps", counts.Restyle, counts.Place, counts.Piece, counts.Follow, counts.Swap))

reset()
N.Target(env, "nameplate1")
local list = plates()
assert(#list == 2 and restyled[Plate(1).ornament] == 1 and restyled[Plate(40).ornament] == 1, "a target change among forty restyles exactly the old and new target, once each: " .. #list)
assert(drawn(Plate(1).ornament):find("Crested"), "the new target draws its crested ends: " .. drawn(Plate(1).ornament))

reset()
env._units.nameplate3.raid = 8
env.FireEvent("RAID_TARGET_UPDATE")
list = plates()
assert(#list == 1 and restyled[Plate(3).ornament] == 1, "a raid mark on one plate restyles only that plate")

local plate39 = Plate(39)
local host = plate39.ornament.host
reset()
local base = N.Remove(env, "nameplate39")
N.Add(env, "nameplate39", NORMAL, { base = base })
assert(Plate(39) == plate39 and #plates() == 0, "a plate recycled to a unit of the same kind restyles nothing")
reset()
base = N.Remove(env, "nameplate39")
N.Add(env, "nameplate39", ELITE, { base = base })
assert(#plates() == 1 and restyled[plate39.ornament] == 1 and drawn(plate39.ornament):find("Winged"), "a rank change on recycle restyles the plate once and draws winged ends: " .. drawn(plate39.ornament))
assert(plate39.ornament.host == host, "a recycled plate keeps its ornament host and textures")

local function forced(handle)
	local before = drawn(handle)
	handle:Restyle()
	return before, drawn(handle)
end
local plate2 = Plate(2)
local idle = drawn(plate2.ornament)
reset()
env._units.nameplate2.cast = CAST
env.FireEvent("UNIT_SPELLCAST_START", "nameplate2")
local casting = drawn(plate2.ornament)
assert(plate2.cast:IsShown() and counts.Swap == 1 and counts.Restyle == 0 and counts.Place > 0 and casting ~= idle, "the first cast after a change draws the casting set once, without a restyle: " .. counts.Swap .. " swaps, " .. counts.Place .. " placements")
reset()
plate2.cast:Hide()
assert(counts.Swap == 1 and counts.Restyle == 0 and counts.Place == 0 and drawn(plate2.ornament) == idle, "a cast ending shows the kept idle set and places nothing: " .. counts.Place)
reset()
env.FireEvent("UNIT_SPELLCAST_START", "nameplate2")
assert(counts.Swap == 1 and counts.Place == 0 and drawn(plate2.ornament) == casting, "a later cast shows the kept casting set and places nothing: " .. counts.Place)
local kept, fresh = forced(plate2.ornament)
assert(kept == fresh, "the kept casting set matches a forced restyle: " .. kept .. " / " .. fresh)
reset()
plate2.cast:Hide()
assert(counts.Place > 0 and drawn(plate2.ornament) == idle, "a forced restyle while casting drops the idle set, so the cast ending places it again")

local plate38 = Plate(38)
base = N.Remove(env, "nameplate38")
assert(not plate38:IsVisible(), "a removed plate hides")
reset()
K.Options.Write("Widgets", "ornaments", "Subtle")
env.RunTimers()
assert(plate38.ornament.stale and counts.Place > 0, "a level change leaves the hidden plate stale while the shown ones place")
local placedBefore = counts.Place
N.Add(env, "nameplate38", NORMAL, { base = base })
assert(plate38:IsVisible() and not plate38.ornament.stale and counts.Place > placedBefore, "showing the plate restyles its stale ornament")
local first = drawn(plate38.ornament)
plate38.ornament:Restyle()
assert(first ~= "" and drawn(plate38.ornament) == first, "the recycled plate's first shown frame matches a fresh restyle: " .. first)

K.Options.Write("Widgets", "ornaments", "Off")
env.RunTimers()
reset()
base = N.Remove(env, "nameplate5")
N.Add(env, "nameplate5", NORMAL, { base = base })
N.Target(env, "nameplate5")
env._units.nameplate2.cast = CAST
env.FireEvent("UNIT_SPELLCAST_START", "nameplate2")
assert(Plate(2).cast:IsShown() and #plates() == 0, "at Off a recycle, a target change and a cast restyle no plate")
K.Options.Write("Widgets", "ornaments", "Full")
env.RunTimers()
local plate5 = Plate(5)
local back = drawn(plate5.ornament)
assert(not back:find("Winged") and back:find("Crested"), "after Off the plate draws its current state: " .. back)
reset()
N.Target(env, "nameplate1")
assert(restyled[plate5.ornament] == 1 and not drawn(plate5.ornament):find("Crested"), "after Off a later change still restyles the plate")
reset()
Plate(2).cast:Hide()
local kept2, fresh2 = forced(Plate(2).ornament)
assert(counts.Place > 0 and kept2 == fresh2, "a cast that showed at Off and hides at Full draws its plate's idle set, which the level change dropped: " .. kept2 .. " / " .. fresh2)
reset()
base = N.Remove(env, "nameplate5")
N.Add(env, "nameplate5", ELITE, { base = base })
assert(restyled[plate5.ornament] == 1 and drawn(plate5.ornament):find("Winged"), "after Off the plate forgets the state it saw before, so turning elite again restyles it: " .. drawn(plate5.ornament))
local plate4 = Plate(4)
plate4.cast:Hide()
env._units.nameplate4.cast = CAST
env.FireEvent("UNIT_SPELLCAST_START", "nameplate4")
assert(plate4.cast:IsShown() and plate4.ornamentSeen.cast == true, "plate 4 is casting at Full")
K.Options.Write("Widgets", "ornaments", "Off")
env.RunTimers()
base = N.Remove(env, "nameplate4")
K.Options.Write("Widgets", "ornaments", "Full")
env.RunTimers()
N.Add(env, "nameplate4", NORMAL, { base = base })
reset()
env._units.nameplate4.cast = CAST
env.FireEvent("UNIT_SPELLCAST_START", "nameplate4")
local kept4, fresh4 = forced(plate4.ornament)
assert(plate4.cast:IsShown() and counts.Swap == 1 and kept4 == fresh4, "a plate pooled while ornaments were Off forgets its old cast state, so its next cast draws the casting set: " .. kept4 .. " / " .. fresh4)
env.SetCombat(false)
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok plates restyle only on real changes, wait while hidden and do nothing at Off")
