-- test-ornament-plate-swap.lua: a plate keeps one placed set while idle and one while casting; a cast showing or ending swaps them with region Show and Hide only, also on a protected plate in lockdown where anchoring or setting a texture raises, and every shown set matches a forced restyle on nine screens, the plate scale range, four kinds, Subtle and Full, before and after a size, level or state change.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local SCREENS = { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3440, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 3456, 2234 } }
local SCALES = { 0.5, 1.0, 1.6 }
local KINDS = {
	{ "plain", { name = "Riverglade Snapper", level = 37, reaction = 2, canAttack = true } },
	{ "elite", { name = "Bloodtalon Matriarch", level = 40, classification = "elite", reaction = 2, canAttack = true } },
	{ "selected", { name = "Riverglade Crocolisk", level = 38, reaction = 2, canAttack = true } },
	{ "boss", { name = "Onyxia", level = -1, classification = "worldboss", reaction = 2, canAttack = true } },
}
local CAST = { name = "Molten Pulse", text = "Molten Pulse", texture = 135808, notInterruptible = false }
local BLOCKED = { "ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetTexture", "SetTexCoord", "SetParent", "SetDrawLayer" }
local checked = 0
local fills, lean = {}, {}

local function run(screen, level)
	local env, K, ns = N.New({ width = screen[1], height = screen[2], uiScale = 768 / 1080, size = "default" })
	env._textWidth = function(text, fontPath, size) return Scene.TextWidth(Scene.PlainText(text), size, fontPath) end
	K.Store.Module("Widgets").cardMaterial = "ForgedBrackets"
	K.Store.Module("Widgets").ornaments = level
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	local tokens = {}
	for s, scale in ipairs(SCALES) do
		for k, kind in ipairs(KINDS) do
			local token = "nameplate" .. ((s - 1) * #KINDS + k)
			local base = N.Base(env, { scale = scale })
			base:ClearAllPoints()
			base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", screen[1] * 0.75 * (k - 0.5) / #KINDS, screen[2] * 0.7 * (s - 0.5) / #SCALES)
			N.Add(env, token, kind[2], { base = base, scale = scale })
			tokens[#tokens + 1] = { token, kind[1], scale }
		end
	end
	env.RunTimers()
	for _, frame in ipairs(env._frames) do
		for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
			local original = frame[method]
			frame[method] = function(self, ...)
				local was = self:IsVisible()
				original(self, ...)
				local now = self:IsVisible()
				if was ~= now then
					local fn = self._scripts and self._scripts[now and "OnShow" or "OnHide"]
					if fn then fn(self) end
				end
			end
		end
	end
	local Handle = getmetatable(ns.Plates.Get("nameplate1").ornament)
	local placed, place = 0, Handle.Place
	Handle.Place = function(...)
		placed = placed + 1
		return place(...)
	end
	local function drawn(handle)
		local names = {}
		for _, set in pairs(handle.sets or {}) do
			if set ~= handle.textures then
				for i = 1, #set do assert(not set[i]:IsShown(), "a kept set stays hidden while the other shows") end
			end
		end
		for i = 1, handle.used do
			local texture = handle.textures[i]
			if texture:IsShown() then
				local _, _, _, x, y = texture:GetPoint(1)
				local w, h = texture:GetSize()
				names[#names + 1] = string.format("%s@%.3f,%.3f,%.3f,%.3f", (texture:GetTexture() or ""):match("([%w]+)%.png$") or "Fill", x, y, w, h)
			end
		end
		for i = handle.used + 1, #handle.textures do assert(not handle.textures[i]:IsShown(), "a spare region stays hidden") end
		return table.concat(names, " ")
	end
	local function same(handle, label)
		local kept = drawn(handle)
		handle:Restyle()
		local fresh = drawn(handle)
		assert(kept == fresh, label .. ": the shown set matches a forced restyle\n  kept  " .. kept .. "\n  fresh " .. fresh)
		checked = checked + 1
		return fresh
	end
	local function locked(plate, fn)
		local saved, handle = {}, plate.ornament
		for _, set in pairs(handle.sets) do
			for i = 1, #set do
				for _, method in ipairs(BLOCKED) do
					saved[#saved + 1] = { set[i], method, rawget(set[i], method) }
					set[i][method] = function() error("ADDON_ACTION_BLOCKED: " .. method .. " on a protected plate's ornament in lockdown", 2) end
				end
			end
		end
		local protected = rawget(plate, "IsProtected")
		plate.IsProtected = function() return true end
		env.SetCombat(true)
		local ok, err = pcall(fn)
		for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] end
		plate.IsProtected = protected
		assert(ok, err)
		env.SetCombat(false)
		env.RunTimers()
	end
	local function cast(token, on)
		if on then
			N.Cast(env, token, CAST)
		else
			ns.Plates.Get(token).cast:Hide()
		end
		local plate = ns.Plates.Get(token)
		assert(plate.cast:IsShown() == on, "the cast bar follows the cast")
	end
	for _, entry in ipairs(tokens) do
		local token, kind, scale = entry[1], entry[2], entry[3]
		local label = string.format("%s %dx%d scale %.2f %s", level, screen[1], screen[2], scale, kind)
		local plate = ns.Plates.Get(token)
		local handle = plate.ornament
		if kind == "selected" then N.Target(env, token) end
		local idle = same(handle, label .. " idle")
		cast(token, true)
		local casting = drawn(handle)
		assert(casting ~= idle, label .. ": the first cast draws a casting set: " .. casting)
		local function ends(set) local n = 0 for _ in set:gmatch("End%a+%d+@") do n = n + 1 end return n end
		local function rails(set) local list = {} for name in set:gmatch("(Rail%d+)@") do list[#list + 1] = name end table.sort(list) return table.concat(list, " ") end
		local function top(set) local y for v in set:gmatch("Rail%d+@[-%d.]+,([-%d.]+),") do y = math.max(y or -1e9, tonumber(v)) end return y end
		assert(ends(idle) ~= 1 and ends(casting) ~= 1, label .. ": ends are symmetric, both or neither: " .. idle .. " / " .. casting)
		assert(level ~= "Full" or rails(idle) == rails(casting), label .. ": idle and casting rails have the same weight: " .. rails(idle) .. " / " .. rails(casting))
		assert(top(idle) == top(casting), label .. ": the top rail stays put when the cast starts: " .. tostring(top(idle)) .. " / " .. tostring(top(casting)))
		assert(not idle:find("Fill@"), label .. ": an idle plate draws no backing")
		assert((casting:find("Fill@") ~= nil) == (handle.scratch.wrap[1] > 0 or handle.scratch.wrap[2] > 0), label .. ": a casting plate backs the gap under its level dot, and only then: " .. casting)
		fills[kind] = (fills[kind] or 0) + (casting:find("Fill@") and 1 or 0)
		lean[#lean + 1] = ends(idle) == 0 and label or nil
		placed = 0
		cast(token, false)
		assert(placed == 0 and drawn(handle) == idle, label .. ": the cast ending shows the kept idle set without placing")
		cast(token, true)
		assert(placed == 0 and drawn(handle) == casting, label .. ": a later cast shows the kept casting set without placing")
		same(handle, label .. " casting")
		cast(token, false)
		same(handle, label .. " idle after a forced restyle")
		cast(token, true)
		cast(token, false)
		locked(plate, function()
			placed = 0
			cast(token, true)
			assert(placed == 0 and drawn(handle) == casting, label .. ": in lockdown a cast shows the kept casting set with Show and Hide only")
			cast(token, false)
			assert(placed == 0 and drawn(handle) == idle, label .. ": in lockdown a cast ending shows the kept idle set with Show and Hide only")
			plate.health:SetWidth(plate.health:GetWidth() - 2)
			cast(token, true)
			assert(placed == 0 and drawn(handle) == "", label .. ": in lockdown a size change hides the stale set and queues its placement")
		end)
		same(handle, label .. " casting after a size change in lockdown")
		cast(token, false)
		same(handle, label .. " idle after a size change in lockdown")
		plate:Restyle()
		plate:Refresh()
		cast(token, true)
		same(handle, label .. " casting after a forced restyle")
		cast(token, false)
		if kind == "plain" then
			cast(token, true)
			N.Target(env, token)
			cast(token, false)
			assert(level ~= "Full" or drawn(handle):find("Crested"), label .. ": a plate targeted while casting ends its cast with crested ends")
			same(handle, label .. " idle after a target change while casting")
			cast(token, true)
			same(handle, label .. " casting after a target change")
			cast(token, false)
			N.Target(env, "nameplate3")
		end
		cast(token, true)
		cast(token, false)
		plate.health:SetWidth(plate.health:GetWidth() - 6)
		cast(token, true)
		same(handle, label .. " casting after a size change")
		cast(token, false)
		same(handle, label .. " idle after a size change")
		plate:Restyle()
		plate:Refresh()
	end
	for _, entry in ipairs(tokens) do
		local token = entry[1]
		local label = string.format("%s %dx%d scale %.2f %s with no rect on the hidden cast bar", level, screen[1], screen[2], entry[3], entry[2])
		local plate = ns.Plates.Get(token)
		local handle, bar = plate.ornament, plate.castBar
		local bottom = bar.GetBottom
		bar.GetBottom = function(self)
			if not self:IsVisible() then return nil end
			return bottom(self)
		end
		env._units[token].cast = nil
		cast(token, false)
		handle.spanDrop = nil
		plate:Restyle()
		plate:Refresh()
		env.RunTimers()
		assert(handle.key == false and handle.textures.epoch == handle.epoch, label .. ": an idle plate draws its idle set before it has cast")
		cast(token, true)
		cast(token, false)
		cast(token, true)
		local casting = drawn(handle)
		placed = 0
		cast(token, false)
		local idle = drawn(handle)
		assert(placed == 0, label .. ": after the first cast both sets are kept")
		local function rails(set) local list = {} for name in set:gmatch("(Rail%d+)@") do list[#list + 1] = name end table.sort(list) return table.concat(list, " ") end
		assert(level ~= "Full" or rails(idle) == rails(casting), label .. ": after the first cast the rails agree: " .. rails(idle) .. " / " .. rails(casting))
		local function top(set) local y for v in set:gmatch("Rail%d+@[-%d.]+,([-%d.]+),") do y = math.max(y or -1e9, tonumber(v)) end return y end
		assert(top(idle) == top(casting), label .. ": after the first cast the top rail stays put: " .. tostring(top(idle)) .. " / " .. tostring(top(casting)))
		same(handle, label .. " idle")
		bar.GetBottom = bottom
	end
	for _, entry in ipairs(tokens) do
		local token = entry[1]
		local label = string.format("%s %dx%d scale %.2f %s with no rect when the cast bar shows", level, screen[1], screen[2], entry[3], entry[2])
		local plate = ns.Plates.Get(token)
		local handle, bar = plate.ornament, plate.castBar
		local bottom = bar.GetBottom
		env._units[token].cast = nil
		cast(token, false)
		plate:Restyle()
		plate:Refresh()
		env.RunTimers()
		bar.GetBottom = function() return nil end
		cast(token, true)
		assert(drawn(handle) == "", label .. ": a cast with no rect yet shows nothing")
		env.RunTimers()
		assert(drawn(handle) == "", label .. ": a rect that never comes stops the retries")
		cast(token, false)
		cast(token, true)
		bar.GetBottom = bottom
		env.RunTimers()
		local casting = drawn(handle)
		assert(casting ~= "", label .. ": the cast draws once its rect comes")
		same(handle, label)
		env._units[token].cast = nil
		cast(token, false)
	end
	K.Options.Write("Widgets", "ornaments", level == "Full" and "Subtle" or "Full")
	env.RunTimers()
	for _, entry in ipairs(tokens) do
		local handle = ns.Plates.Get(entry[1]).ornament
		local label = string.format("%s %dx%d scale %.2f %s after a level change", level, screen[1], screen[2], entry[3], entry[2])
		cast(entry[1], true)
		same(handle, label .. " casting")
		cast(entry[1], false)
		same(handle, label .. " idle")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
end

for _, screen in ipairs(SCREENS) do
	for _, level in ipairs({ "Subtle", "Full" }) do
		run(screen, level)
	end
end
local filled = {}
for kind, n in pairs(fills) do filled[#filled + 1] = kind .. " " .. n end
table.sort(filled)
print("plates with no ends: " .. (#lean > 0 and table.concat(lean, "; ") or "none") .. "; casting plates with a backing: " .. table.concat(filled, ", "))
print(string.format("ok %d shown plate sets match a forced restyle on nine screens, the smallest, default and largest plate scale, four kinds, Subtle and Full, at the shipped Interface size", checked))
