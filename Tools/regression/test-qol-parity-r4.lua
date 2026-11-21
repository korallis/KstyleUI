-- test-qol-parity-r4.lua: the EllesmereUI parity round 4 QoL options: a v0.2.8 profile keeps today's behaviour and builds nothing new, each option works switched on and follows the events that change it, nothing depends on a switch it does not name, turning an option off puts back what it changed, missing or secret answers take the safe path, and the Quick fire snippets keep their count as the restricted environment runs them.
local Q = dofile("Tools/regression/qol_env.lua")

local GCD = 29515

local function record(env, name, result)
	return function(...)
		env._calls[name] = env._calls[name] or {}
		table.insert(env._calls[name], { ... })
		if type(result) == "function" then return result(...) end
		return result
	end
end

local function stand(env)
	env._gcd, env._markers = nil, {}
	env.C_Spell = {
		GetSpellCooldown = record(env, "GetSpellCooldown", function(id)
			if id == GCD and env._gcd then return { isActive = env._gcd ~= "done", isOnGCD = true, startTime = 1, duration = 1.5 } end
			return { isActive = false, startTime = 0, duration = 0 }
		end),
		GetSpellCooldownDuration = function(id) if id == GCD and env._gcd then return env._gcd == "secret" and env.Secret({}) or { gcd = true } end end,
	}
	env.C_PartyInfo = { DoReadyCheck = record(env, "DoReadyCheck"), DoCountdown = record(env, "DoCountdown") }
	env.InitiateRolePoll = record(env, "InitiateRolePoll")
	env.SetRaidTarget = record(env, "SetRaidTarget")
	env.GetRaidTargetIndex = function() return nil end
	env.UnitIsGroupLeader = function() return env._leader == true end
	env.UnitIsGroupAssistant = function() return false end
	env.HasLFGRestrictions = function() return false end
	env.UnitInBattleground = function() return nil end
	env.WORLD_RAID_MARKER_ORDER = { 8, 4, 1, 7, 2, 3, 6, 5 }
	env.IsRaidMarkerActive = function(i) return env._markers[i] == true end
	env.SLASH_WORLD_MARKER1, env.SLASH_CLEAR_WORLD_MARKER1 = "/wm", "/cwm"
	env._refs, env._wraps = {}, {}
	env.SecureHandlerSetFrameRef = function(frame, label, ref) env._refs[frame] = env._refs[frame] or {}; env._refs[frame][label] = ref end
	env.SecureHandlerWrapScript = function(frame, script, header, pre) env._wraps[#env._wraps + 1] = { frame = frame, script = script, header = header, pre = pre } end
end

local function boot(settings)
	local saved = { version = 42, profiles = { Default = { QoL = settings or { enabled = true } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = Q.New({ saved = saved, setup = stand })
	if not K.Modules.IsRunning("QoL") then Q.Enable(env, K) end
	env.RunTimers()
	return env, K, ns
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function last(frame, method)
	for i = #frame._calls, 1, -1 do
		if frame._calls[i].method == method then return frame._calls[i].args end
	end
end

-- Runs a wrapped OnClick pre-body as the restricted environment would: self is the button, with its frame refs; false cancels the click.
local function fire(env, button)
	local wrap
	for _, w in ipairs(env._wraps) do if w.frame == button then wrap = w end end
	local handle = setmetatable({ GetFrameRef = function(_, label) return env._refs[button][label] end }, { __index = function(_, method) return function(_, ...) return button[method](button, ...) end end })
	local body = assert(loadstring("local self, button, down = ...\n" .. wrap.pre))
	setfenv(body, { strsub = string.sub, gsub = string.gsub, tonumber = tonumber })
	local script = button:GetScript("PreClick")
	if script then script(button, "LeftButton", false) end
	return body(handle, "LeftButton", false) ~= false
end

-- Defaults: a v0.2.8 profile builds no circle or Quick fire button, reads no cooldown and keeps every raid tool and log rule as before.
do
	local env, K, ns = boot({ enabled = true, cursorRing = true, castRing = true, raidTools = "group", autoLog = true })
	for key, value in pairs({ gcdRing = false, raidToolsShow = "all", quickFire = false, autoLogWhere = "raid" }) do
		assert(ns.Get(key) == value, key .. " keeps today's behaviour by default")
	end
	assert(select(4, ns.AidFrames()) == nil and env.KstyleUI_QuickFirePlace == nil, "no global cooldown circle or Quick fire button")
	env._gcd = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(#Q.Calls(env, "GetSpellCooldown") == 0, "no cooldown read while off")
	env._group = true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	local holder = env.KstyleUI_RaidTools
	assert(holder.panel2 == nil, "one panel")
	for _, button in ipairs(holder.buttons) do assert(button:IsShown(), "every tool shows") end
	clean(env, K)
end

-- Global cooldown circle, on with the ring and the cast circle off: it follows the pointer over the global cooldown, between the ring and the cast circle in size, at the centre off the pointer, and leaves when the cooldown ends.
do
	local env, K, ns = boot()
	Q.Write(env, K, "gcdRing", true)
	local _, ring, cast, gcd = ns.AidFrames()
	assert(gcd and not cast and not gcd:IsShown() and not ring:IsShown(), "built, hidden until a global cooldown")
	env._gcd = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(gcd:IsShown() and ring:IsShown() and not ring.texture:IsShown() and ring:GetScript("OnUpdate"), "it follows the pointer without the ring")
	assert(last(gcd, "SetCooldownFromDurationObject")[1].gcd and last(gcd, "SetReverse")[1] == true, "fills from the game's duration object")
	assert(Q.Calls(env, "GetSpellCooldown")[1][1] == GCD, "reads spell 29515")
	assert(select(2, gcd:GetPoint(1)) == ring, "on the pointer")
	Q.Write(env, K, "castRing", true)
	Q.Write(env, K, "cursorRing", true)
	_, ring, cast = ns.AidFrames()
	local rw, gw, cw = ring.texture:GetWidth(), gcd:GetWidth(), cast:GetWidth()
	assert(rw < gw and gw < cw, string.format("between the ring and the cast circle: %s %s %s", rw, gw, cw))
	Q.Write(env, K, "cursorScale", 150)
	assert(math.abs(gcd:GetWidth() - gw * 1.5) < 1e-6, "Ring size sizes it")
	Q.Write(env, K, "castRing", false)
	Q.Write(env, K, "cursorRing", false)
	local sets, setScript = 0, ring.SetScript
	ring.SetScript = function(...) sets = sets + 1; return setScript(...) end
	for _ = 1, 10 do env.FireEvent("SPELL_UPDATE_COOLDOWN") end
	ring.SetScript = setScript
	assert(sets == 0 and gcd:IsShown(), "repeated cooldown events do not reconfigure the pointer frame: " .. sets)
	gcd:GetScript("OnCooldownDone")(gcd)
	assert(not gcd:IsShown() and not ring:IsShown() and not ring:GetScript("OnUpdate"), "the circle and the pointer's OnUpdate leave as the cooldown ends")
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(gcd:IsShown(), "the next global cooldown shows it again")
	env._gcd = "done"
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not gcd:IsShown() and last(gcd, "Clear") and not ring:GetScript("OnUpdate"), "an ended cooldown clears it")
	env._gcd = true
	Q.Write(env, K, "castAttach", false)
	assert(gcd:IsShown() and select(2, gcd:GetPoint(1)) == K.Scale.Root() and not ring:IsShown(), "off the pointer: the screen centre, no pointer frame")
	env._gcd = "secret"
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not gcd:IsShown(), "a secret duration shows nothing")
	env._gcd = true
	env.C_Spell.GetSpellCooldownDuration = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not gcd:IsShown(), "no duration API, no circle")
	env.C_Spell = nil
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not gcd:IsShown(), "no spell API, no circle")
	Q.Write(env, K, "gcdRing", false)
	assert(not gcd:IsShown(), "turning it off hides it")
	clean(env, K)
end

-- Raid tools Always: solo and as a plain raid member; markers only where the game lets them work.
do
	local env, K = boot()
	Q.Write(env, K, "raidTools", "always")
	local holder = env.KstyleUI_RaidTools
	assert(holder:IsShown(), "shown solo")
	for i = 1, 3 do assert(not holder.buttons[i]:IsEnabled(), "solo, action " .. i .. " is dim") end
	assert(holder.buttons[4]:IsEnabled() and holder.buttons[12]:IsEnabled(), "solo, the markers work")
	env._raid = true
	env.FireEvent("GROUP_ROSTER_UPDATE")
	assert(holder:IsShown() and not holder.buttons[4]:IsEnabled(), "a plain raid member sees dim markers")
	env._leader = true
	env.FireEvent("PARTY_LEADER_CHANGED")
	assert(holder.buttons[1]:IsEnabled() and holder.buttons[4]:IsEnabled(), "the raid leader uses everything")
	env.SetCombat(true)
	assert(not holder.buttons[4]:IsEnabled() and holder:IsShown(), "dim in combat, still shown")
	env.SetCombat(false)
	Q.Write(env, K, "raidTools", "never")
	assert(not holder:IsShown(), "Never hides it")
	clean(env, K)
end

-- Show as: the group tools or the markers alone, and two panels whose second follows the first across the way the buttons run, inside the screen at four sizes.
do
	local env, K = boot()
	env._group, env._leader = true, true
	Q.Write(env, K, "raidTools", "group")
	local holder = env.KstyleUI_RaidTools
	local full = holder.panel:GetWidth()
	Q.Write(env, K, "raidToolsShow", "group")
	for i, button in ipairs(holder.buttons) do assert(button:IsShown() == (i <= 3), "group tools only: " .. i) end
	assert(holder.panel:GetWidth() < full, "the panel shrinks to them")
	Q.Write(env, K, "raidToolsShow", "markers")
	for i, button in ipairs(holder.buttons) do assert(button:IsShown() == (i > 3), "markers only: " .. i) end
	Q.Write(env, K, "raidToolsShow", "two")
	local second = holder.panel2
	assert(second and second:IsShown() and holder.panel:IsShown(), "two panels")
	for i, button in ipairs(holder.buttons) do assert(button:IsShown() == (i <= 3), "the first holds the group tools: " .. i) end
	for i, button in ipairs(holder.buttons2) do assert(button:IsShown() == (i > 3), "the second holds the markers: " .. i) end
	assert(holder.buttons2[4]:IsEnabled() and holder.buttons2[12]:IsEnabled(), "its markers work")
	local point, anchor, relative = second:GetPoint(1)
	assert(point == "TOPLEFT" and anchor == holder.panel and relative == "BOTTOMLEFT", "a row: the markers under the group tools")
	Q.Write(env, K, "raidToolsLayout", "column")
	point, anchor, relative = second:GetPoint(1)
	assert(point == "TOPLEFT" and anchor == holder.panel and relative == "TOPRIGHT", "a column: the markers beside the group tools")
	env.SetCombat(true)
	assert(not holder.buttons2[4]:IsEnabled(), "dim in combat")
	env.SetCombat(false)
	holder:GetScript("OnClick")(holder, "LeftButton")
	assert(not holder.panel:IsShown() and not second:IsShown(), "the button closes both")
	holder:GetScript("OnClick")(holder, "LeftButton")
	local root = K.Scale.Root()
	for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		local h = 768
		local w = h * size[1] / size[2]
		root:SetSize(w, h)
		for _, layout in ipairs({ "row", "column" }) do
			for _, spot in ipairs({ { anchor = "BOTTOMRIGHT", x = -8, y = 8 }, { anchor = "TOPLEFT", x = 8, y = -8 } }) do
				for field, value in pairs(spot) do assert(K.Layout.Set("qol.raidtools", field, value)) end
				env.RunTimers()
				Q.Write(env, K, "raidToolsLayout", layout)
				for _, panel in ipairs({ holder.panel, second }) do
					local l, b, r, t = panel:GetLeft(), panel:GetBottom(), panel:GetRight(), panel:GetTop()
					assert(l >= root:GetLeft() - 0.01 and r <= root:GetRight() + 0.01 and b >= root:GetBottom() - 0.01 and t <= root:GetTop() + 0.01,
						string.format("%dx%d %s %s: a panel leaves the screen", size[1], size[2], layout, spot.anchor))
				end
			end
		end
	end
	Q.Write(env, K, "raidToolsShow", "all")
	assert(not second:IsShown(), "back to one panel, the second hides")
	for _, button in ipairs(holder.buttons) do assert(button:IsShown(), "every tool shows again") end
	clean(env, K)
end

-- Quick fire: off builds nothing; on, three named secure buttons and three bindings; Place takes the next free marker in star-to-skull order at the pointer, Undo takes away the last, Clear clears all; a change in combat waits; off makes every key do nothing.
do
	local env, K = boot()
	assert(env.KstyleUI_QuickFirePlace == nil, "nothing while off")
	env.SetCombat(true)
	Q.Write(env, K, "quickFire", true)
	assert(env.KstyleUI_QuickFirePlace == nil, "secure buttons wait for combat to end")
	env.SetCombat(false)
	local place, undo, clear = env.KstyleUI_QuickFirePlace, env.KstyleUI_QuickFireUndo, env.KstyleUI_QuickFireClear
	assert(place and undo and clear, "built after combat")
	assert(place:GetAttribute("type") == "macro" and undo:GetAttribute("type") == "macro", "Place and Undo run the game's marker commands")
	assert(clear:GetAttribute("type") == "worldmarker" and clear:GetAttribute("action") == "clear" and clear:GetAttribute("marker") == nil, "Clear clears every marker")
	assert(place:GetAttribute("order") == "84172365", "Blizzard's star-to-skull order")
	assert(#env._wraps == 3, "three wrapped clicks")
	env._markers[8], env._markers[4] = true, true
	assert(fire(env, place) and place:GetAttribute("macrotext") == "/wm [@cursor] 1", "the first free marker in order: " .. tostring(place:GetAttribute("macrotext")))
	env.SetCombat(true)
	assert(fire(env, place) and place:GetAttribute("macrotext") == "/wm [@cursor] 7", "in combat the count goes on")
	assert(fire(env, undo) and undo:GetAttribute("macrotext") == "/cwm 7", "Undo takes the last one away")
	assert(fire(env, undo) and undo:GetAttribute("macrotext") == "/cwm 1", "and the one before")
	assert(fire(env, clear) and place:GetAttribute("placed") == 0, "Clear resets the count")
	assert(not fire(env, undo), "nothing left to undo")
	for _ = 1, 9 do fire(env, place) end
	assert(place:GetAttribute("macrotext") == "/wm [@cursor] 8", "past the skull it starts again at the star")
	env._markers = {}
	env.SetCombat(false)
	assert(place:GetAttribute("placed") == 0, "combat's end reads the markers that are up")
	local file = assert(io.open("KstyleUI_QoL/Bindings.xml", "rb"))
	local xml = file:read("*a")
	file:close()
	for _, key in ipairs({ "Place", "Undo", "Clear" }) do
		local name = "CLICK KstyleUI_QuickFire" .. key .. ":LeftButton"
		assert(xml:find('<Binding name="' .. name .. '" category="BINDING_HEADER_KSTYLEUI_ACTIONBARS"/>', 1, true) and env["BINDING_NAME_" .. name], key .. " has a named binding")
	end
	Q.Write(env, K, "quickFire", false)
	assert(place:GetAttribute("order") == nil and not fire(env, place) and not fire(env, undo) and not fire(env, clear), "off, every key does nothing")
	Q.Write(env, K, "quickFire", true)
	assert(place:GetAttribute("order") == "84172365", "on again")
	clean(env, K)
	local env2, K2, ns2 = boot()
	env2.SecureHandlerWrapScript = nil
	Q.Write(env2, K2, "quickFire", true)
	assert(env2.KstyleUI_QuickFirePlace == nil and ns2.Get("quickFire"), "without the secure wrapper nothing is built")
	clean(env2, K2)
end

-- Quick fire owns only what it placed (review of 369e1fee): Undo before any Place leaves another player's markers alone, a full set and an unknown answer go on in order instead of starting again at the star, and in combat Undo walks back every placement after a wrap.
do
	local env, K = boot()
	env._markers[8], env._markers[4] = true, true
	Q.Write(env, K, "quickFire", true)
	local place, undo, clear = env.KstyleUI_QuickFirePlace, env.KstyleUI_QuickFireUndo, env.KstyleUI_QuickFireClear
	assert(not fire(env, undo), "no Place yet, so nothing of ours to undo: " .. tostring(undo:GetAttribute("macrotext")))
	for i = 1, 8 do env._markers[i] = true end
	local marks = {}
	for _ = 1, 2 do
		fire(env, place)
		marks[#marks + 1] = place:GetAttribute("macrotext")
	end
	env._markers, env.IsRaidMarkerActive = {}, nil
	for _ = 1, 2 do
		fire(env, place)
		marks[#marks + 1] = place:GetAttribute("macrotext")
	end
	assert(table.concat(marks, ",") == "/wm [@cursor] 1,/wm [@cursor] 7,/wm [@cursor] 2,/wm [@cursor] 3", "a full set and an unknown answer go on in order: " .. table.concat(marks, ","))
	fire(env, clear)
	env.SetCombat(true)
	for _ = 1, 9 do fire(env, place) end
	local undone = {}
	while fire(env, undo) and #undone < 10 do undone[#undone + 1] = undo:GetAttribute("macrotext"):sub(-1) end
	assert(table.concat(undone) == "85632714", "in combat Undo walks back all eight after a wrap: " .. table.concat(undone))
	clean(env, K)
end

-- Marker size (review of 369e1fee): the markers are as tall as the text buttons whatever the panels show, at login and after a switch.
do
	local env, K = boot({ enabled = true, raidTools = "always", raidToolsShow = "markers" })
	local holder = env.KstyleUI_RaidTools
	local function same(what)
		local want = holder.buttons[1]:GetHeight()
		for i = 4, 12 do assert(holder.buttons[i]:GetHeight() == want, string.format("%s: button %d is %s tall, not %s", what, i, holder.buttons[i]:GetHeight(), want)) end
	end
	same("markers only at login")
	for _, show in ipairs({ "all", "two", "markers", "group", "two" }) do
		Q.Write(env, K, "raidToolsShow", show)
		same(show)
	end
	Q.Write(env, K, "raidToolsLayout", "column")
	same("two in a column")
	clean(env, K)
end

-- The global cooldown circle's hot path (review of 369e1fee): an event about a spell with no start recovery category reads and sets nothing; a start, a restart, a whole update, a secret payload and the end still count.
do
	local env, K, ns = boot()
	Q.Write(env, K, "gcdRing", true)
	local gcd = select(4, ns.AidFrames())
	local function sets()
		local n = 0
		for _, call in ipairs(gcd._calls) do if call.method == "SetCooldownFromDurationObject" then n = n + 1 end end
		return n
	end
	env._gcd = true
	env.FireEvent("SPELL_UPDATE_COOLDOWN", 100, nil, nil, 133)
	assert(gcd:IsShown() and sets() == 1, "a global cooldown starts it")
	local reads = #Q.Calls(env, "GetSpellCooldown")
	for _ = 1, 10 do env.FireEvent("SPELL_UPDATE_COOLDOWN", 12345, nil, nil, nil) end
	assert(#Q.Calls(env, "GetSpellCooldown") == reads and sets() == 1, string.format("ten unrelated events: %d reads, %d sets", #Q.Calls(env, "GetSpellCooldown") - reads, sets() - 1))
	env.FireEvent("SPELL_UPDATE_COOLDOWN", 100, nil, nil, 133)
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	env.FireEvent("SPELL_UPDATE_COOLDOWN", env.Secret(12345), nil, nil, nil)
	assert(sets() == 4 and gcd:IsShown(), "a restart, a whole update and a secret payload set it again: " .. sets())
	env._gcd = "done"
	env.FireEvent("SPELL_UPDATE_COOLDOWN", 100, nil, nil, 133)
	assert(not gcd:IsShown(), "the end hides it")
	clean(env, K)
end

-- Circle spark and the help texts (review of 369e1fee): with only the global cooldown circle on, the spark row is usable and names both circles; Show raid tools says Always shows them to everyone; the README's size and Shifter claims match the code and the game's source.
do
	local env, K, ns = boot()
	Q.Write(env, K, "gcdRing", true)
	local gcd = select(4, ns.AidFrames())
	local rows = {}
	for _, row in ipairs(ns.Schema()) do if row.key then rows[row.key] = row end end
	assert(not rows.castSpark.disableWhen(K.Store.Module("QoL")), "the spark row is usable with only the global cooldown circle on")
	assert(rows.castSpark.help:find("global cooldown", 1, true), "the spark help names both circles: " .. rows.castSpark.help)
	Q.Write(env, K, "castSpark", false)
	assert(last(gcd, "SetDrawEdge")[1] == false, "and switches its edge")
	assert(rows.raidTools.help:find("Always", 1, true), "Show raid tools says Always shows them to everyone: " .. rows.raidTools.help)
	local file = assert(io.open("KstyleUI_QoL/README.md", "rb"))
	local readme = file:read("*a")
	file:close()
	assert(not readme:find("a quarter smaller than the cast circle", 1, true), "the global cooldown circle is one sixth smaller than the cast circle (40 against 48)")
	assert(not readme:find("handles only to explicitly protected frames", 1, true), "out of combat a snippet gets a handle to any frame (RestrictedInfrastructure.lua)")
	clean(env, K)
end

-- Auto logging in raids and dungeons together: both start the log, a battleground does not.
do
	local env, K = boot({ enabled = true, autoLog = true, autoLogWhere = "both" })
	env._instance = { true, "party" }
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(env._logging == true, "a dungeon logs")
	env._instance = { true, "raid" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	assert(env._logging == true, "a raid logs")
	env._instance = { true, "pvp" }
	env.FireEvent("ZONE_CHANGED_NEW_AREA")
	assert(env._logging == false, "a battleground stops it")
	clean(env, K)
end

-- The page: every new row writes, and the live preview draws the global cooldown circle inside the cast circle and the raid tools as two panels, dimmed while off, with no clickable marker.
do
	local env, K = boot()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(600, 400)
	local preview = K.Options.Preview("QoL")(parent)
	assert(last(preview.gcd, "SetSwipeColor")[4] < 0.7 * 0.5, "the global cooldown sample is dimmed while off")
	for key, value in pairs({ gcdRing = true, raidTools = "always", raidToolsShow = "two", quickFire = true, autoLogWhere = "both" }) do
		Q.Write(env, K, key, value)
		assert(K.Options.Read("QoL", key) == value, key .. " writes")
	end
	preview:Refresh()
	assert(math.abs(last(preview.gcd, "SetSwipeColor")[4] - 0.7) < 1e-6, "full opacity while on")
	assert(preview.gcd:GetWidth() > preview.ring:GetWidth() and preview.gcd:GetWidth() < preview.cast:GetWidth(), "between the ring and the cast circle")
	local _, to, _, gx, gy = preview.gcd:GetPoint(1)
	local _, _, _, cx, cy = preview.cast:GetPoint(1)
	assert(to == preview and gx == cx and gy == cy, "concentric with the cast circle")
	local raid = preview.raid
	assert(raid.panel2 and raid.panel2:IsShown(), "two panels in the preview")
	for _, button in ipairs(raid.buttons2) do assert(not button:IsMouseEnabled(), "a preview marker cannot be clicked") end
	local before = raid:GetHeight()
	Q.Write(env, K, "raidToolsShow", "markers")
	preview:Refresh()
	assert(not raid.panel2:IsShown() and raid:GetHeight() < before, "one panel again")
	clean(env, K)
end

print("qol parity round 4 ok")
