-- test-minimap-parity-r1.lua: the first EllesmereUI parity round for the minimap: each new option keeps today's default, applies switched on, refreshes on its events and restores when switched off.
local M = dofile("Tools/regression/minimap_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local W = M.W

local function clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, (what or "") .. ": " .. tostring(env._errors[1]))
end

local function point(frame)
	return frame:GetPoint(1)
end

-- A font string with one point draws at its string's size, as the game draws it; the stub gives it no extent.
local function rect(region)
	if region:GetObjectType() ~= "FontString" then
		return region:GetLeft(), region:GetRight(), region:GetBottom(), region:GetTop()
	end
	local p, rel, rp, x, y = region:GetPoint(1)
	local l, r, b, t = rect(rel)
	local w = region:GetWidth()
	w = type(w) == "number" and w > 0 and w or region:GetStringWidth()
	local h = region:GetStringHeight()
	local ax = (rp:find("LEFT") and l or rp:find("RIGHT") and r or (l + r) / 2) + x
	local ay = (rp:find("TOP") and t or rp:find("BOTTOM") and b or (b + t) / 2) + y
	local left = p:find("LEFT") and ax or p:find("RIGHT") and ax - w or ax - w / 2
	local bottom = p:find("BOTTOM") and ay or p:find("TOP") and ay - h or ay - h / 2
	return left, left + w, bottom, bottom + h
end

local function apart(a, b, what)
	local al, ar, ab, at = rect(a)
	local bl, br, bb, bt = rect(b)
	assert(al and bl, what .. ": both regions have a rect")
	assert(ar <= bl + 0.01 or br <= al + 0.01 or at <= bb + 0.01 or bt <= ab + 0.01,
		what .. string.format(": [%.1f %.1f %.1f %.1f] overlaps [%.1f %.1f %.1f %.1f]", al, ar, ab, at, bl, br, bb, bt))
end

local function lines(tip)
	local out = {}
	for _, line in ipairs(tip.used) do
		out[#out + 1] = tostring(line.left:GetText()) .. "|" .. tostring(line.right:GetText())
	end
	return table.concat(out, "\n")
end

local function cvars(env)
	env._cvarWrites = {}
	env.C_CVar = {
		GetCVar = function(name) return env._cvars[name] and "1" or "0" end,
		GetCVarInfo = function(name)
			if env._cvars[name] ~= nil then return env._cvars[name] and "1" or "0", "0", false, false, false, false, false end
		end,
		SetCVar = function(name, value)
			env._cvarWrites[#env._cvarWrites + 1] = name .. "=" .. value
			env._cvars[name] = value == "1"
			return true
		end,
	}
end

local function instance(env)
	env._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
	env._instance = { "Riverglades", "none", 0, "", 5 }
	env.GetInstanceInfo = function() return unpack(env._instance) end
	env.GetDifficultyInfo = function(id)
		return "Difficulty", "raid", id == 6, false, id == 6, id == 16
	end
	env.GetFramerate = function() return 59.6 end
	env.GetNetStats = function() return 1, 2, 42, 77 end
	env._saved = { { "Molten Core", 1, 3600 * 30, 9, true, false, 0, true, 40, "40 Player" } }
	env.GetNumSavedInstances = function() return #env._saved end
	env.GetSavedInstanceInfo = function(i) return unpack(env._saved[i]) end
	env.RequestRaidInfo = function() env._raidInfo = (env._raidInfo or 0) + 1 end
	cvars(env)
	env._lib = M.FakeLibDBIcon(env)
	env._lib:Add("BugSack")
	env._lib:Add("Details")
end

-- A v0.2.8-shaped profile loads, every new option is at today's default and nothing new shows.
local function profile()
	return { version = 42, profiles = { Default = { Minimap = { enabled = true, column = { size = 19.5 }, zone = { size = 12 } } } },
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
end
local env, K, ns = M.New({ saved = profile(), position = { 0.4532, 0.6218 }, setup = instance })
M.Settle(env)
local S, face, column = ns.Settings, ns.Map.face, ns.Map.column
local buttons, area = column.buttons, face.mapArea
for key, want in pairs({ rotate = false, ["column.offset"] = 0, ["column.tooltip"] = "auto", ["column.backgrounds"] = true,
	["column.free"] = false, ["mail.position"] = "column", ["drawer.list"] = false, ["zone.position"] = "", ["clock.position"] = "",
	["coords.position"] = "", ["clock.accent"] = false, ["clock.hover"] = "none", ["difficulty.shown"] = false, ["perf.shown"] = false }) do
	assert(S.Get(key) == want, key .. " keeps today's default")
end
assert(#env._cvarWrites == 0, "the map's rotation stays the player's own until the option is switched on")
assert(not face.difficulty:IsShown() and not face.perf:IsShown() and not face.perfHit:IsShown(), "the new readouts stay hidden by default")
assert(face.north:IsShown() and buttons.calendar.disc:IsShown(), "the N and the button discs show as before")
local zp, zrel, zrelp, zx, zy = point(face.zone)
assert(zp == "LEFT" and zrel == face.card and zrelp == "TOPLEFT", "the zone keeps its usual place")
clean(env, K, "defaults")

-- Rotate the map: the CVar on, the N hidden; off puts the game's value back and the N returns; Blizzard's own switch hides the N too.
K.Options.Write("Minimap", "rotate", true)
assert(env._cvarWrites[1] == "rotateMinimap=1" and not face.north:IsShown(), "rotating sets rotateMinimap and hides the N")
K.Options.Write("Minimap", "rotate", false)
assert(env._cvarWrites[2] == "rotateMinimap=0" and face.north:IsShown(), "switching it off turns rotation off and shows the N")
env._cvars.rotateMinimap = true
env.MinimapCluster:UpdateMinimapConfig()
assert(not face.north:IsShown(), "Blizzard's rotate setting also hides the N")
env._cvars.rotateMinimap = false
env.MinimapCluster:UpdateMinimapConfig()
assert(face.north:IsShown() and #env._cvarWrites == 2, "and the option did not write the CVar for it")

-- Button column: distance from the edge, backgrounds and tooltip direction.
env._mail.new = true
env.FireEvent("UPDATE_PENDING_MAIL")
K.Options.Write("Minimap", "column.hover", false)
local _, _, _, x0 = point(buttons.tracking)
K.Options.Write("Minimap", "column.offset", 10)
local _, _, _, x1 = point(buttons.tracking)
local function moved(sK, holder, from, to)
	local Snap, EDGE = sK.Widgets.Snap, ns.Format.EDGE
	return W.Near(to, from - (Snap(holder, EDGE + 10) - Snap(holder, EDGE)), 0.01)
end
assert(moved(K, column.holder, x0, x1), "the column moves in from the right edge: " .. tostring(x0) .. " -> " .. tostring(x1))
K.Options.Write("Minimap", "column.offset", -30)
assert(select(2, rect(buttons.tracking)) > select(2, rect(area)) + 10, "a negative distance moves the column out past the edge")
K.Options.Write("Minimap", "column.offset", 0)
assert(select(4, point(buttons.tracking)) == x0, "zero puts the column back")
K.Options.Write("Minimap", "column.backgrounds", false)
assert(not buttons.tracking.disc:IsShown() and not buttons.mail.ring:IsShown(), "backgrounds off hides each disc and rim")
K.Options.Write("Minimap", "column.backgrounds", true)
assert(buttons.tracking.disc:IsShown() and buttons.mail.ring:IsShown(), "backgrounds on brings them back")
local tip = M.FakeTooltip()
function tip.SetOwner(_, owner, anchor) tip.owner, tip.anchor = owner, anchor end
ns.Column.Tooltip("tracking", tip, buttons.tracking)
assert(tip.anchor == "ANCHOR_RIGHT", "tooltips open away from the map by default")
K.Options.Write("Minimap", "column.tooltip", "up")
ns.Column.Tooltip("tracking", tip, buttons.tracking)
assert(tip.anchor == "ANCHOR_TOP", "tooltips open upward when asked")
K.Options.Write("Minimap", "column.tooltip", "auto")

-- Mail in a corner, with offsets; at the column's starting corner the column steps down one slot so nothing overlaps.
K.Options.Write("Minimap", "mail.position", "TOPLEFT")
local mp, mrel, _, mx, my = point(buttons.mail)
assert(mp == "TOPLEFT" and mrel == area and mx > 0 and my < 0, "mail sits in the top left corner")
K.Options.Write("Minimap", "mail.x", 6)
K.Options.Write("Minimap", "mail.y", -4)
assert(W.Near(select(4, point(buttons.mail)), mx + 6, 0.01) and W.Near(select(5, point(buttons.mail)), my - 4, 0.01), "the mail offsets move it")
K.Options.Write("Minimap", "mail.position", "TOPRIGHT")
for _, name in ipairs({ "tracking", "calendar", "drawer" }) do
	if buttons[name]:IsShown() then apart(buttons.mail, buttons[name], "corner mail and the " .. name .. " button") end
end
K.Options.Write("Minimap", "mail.position", "column")
assert(select(4, point(buttons.tracking)) == x0 and point(buttons.mail) == "TOPRIGHT", "back in the column, the column is as before")

-- Free move: shift-drag saves a spot, combat refuses, off puts the button back.
K.Options.Write("Minimap", "column.free", true)
local calls = W.LastCall(buttons.tracking, "RegisterForDrag")
assert(calls and calls[1] == "LeftButton", "free move registers the buttons for drag")
env.IsShiftKeyDown = function() return true end
ns.Column.Drag(buttons.tracking, true)
assert(buttons.tracking.moving, "shift-drag starts moving the button")
buttons.tracking:ClearAllPoints()
buttons.tracking:SetPoint("CENTER", area, "CENTER", -40, 25)
ns.Column.Drag(buttons.tracking, false)
local spot = S.Get("column.spots").tracking
assert(spot and spot.x == -40 and spot.y == 25, "the drop saves the spot: " .. tostring(spot and spot.x))
local tp, trel, _, tx, ty = point(buttons.tracking)
assert(tp == "CENTER" and trel == area and tx == -40 and ty == 25, "and the button stays where it was dropped")
buttons.calendar:GetScript("OnEnter")(buttons.calendar)
local overlay = ns.SecureClick.overlay
calls = W.LastCall(overlay, "RegisterForDrag")
assert(overlay:IsShown() and calls and calls[1] == "LeftButton", "the secure overlay over the calendar takes the drag too")
overlay:GetScript("OnDragStart")(overlay)
assert(buttons.calendar.moving, "so the calendar moves under the overlay")
overlay:GetScript("OnLeave")(overlay)
assert(buttons.calendar.moving, "leaving the overlay mid-drag keeps the drag")
buttons.calendar:ClearAllPoints()
buttons.calendar:SetPoint("CENTER", area, "CENTER", 30, -20)
overlay:GetScript("OnDragStop")(overlay)
spot = S.Get("column.spots").calendar
assert(not buttons.calendar.moving and spot and spot.x == 30 and spot.y == -20 and not overlay:IsShown(), "the drop saves the calendar's spot and detaches the overlay")
env._combat = true
ns.Column.Drag(buttons.mail, true)
assert(not buttons.mail.moving, "combat refuses a drag")
env._combat = false
K.Options.Write("Minimap", "column.free", false)
assert(point(buttons.tracking) == "TOPRIGHT" and select(4, point(buttons.tracking)) == x0, "free move off puts the button back in the column")
calls = W.LastCall(buttons.tracking, "RegisterForDrag")
assert(calls and calls[1] == nil, "and stops taking drags, so a sloppy click still clicks")
K.Options.Write("Minimap", "column.hover", true)
clean(env, K, "column")

-- Captions: offsets at the usual place, then inside the map, stacked, clear of the column and the slider.
K.Options.Write("Minimap", "zone.x", 5)
K.Options.Write("Minimap", "zone.y", -3)
local _, _, _, zx2, zy2 = point(face.zone)
assert(W.Near(zx2, zx + 5, 0.01) and W.Near(zy2, zy - 3, 0.01), "zone offsets move it from its usual place")
K.Options.Write("Minimap", "zone.x", 0)
K.Options.Write("Minimap", "zone.y", 0)
K.Options.Write("Minimap", "column.hover", false)
K.Options.Write("Minimap", "zone.position", "TOPRIGHT")
assert(point(face.zone) == "TOPRIGHT" and select(2, point(face.zone)) == area, "the zone moves inside the map")
for _, name in ipairs({ "tracking", "mail", "calendar" }) do apart(face.zone, buttons[name], "the moved zone and the " .. name .. " button") end
K.Options.Write("Minimap", "clock.position", "BOTTOMRIGHT")
K.Options.Write("Minimap", "coords.position", "BOTTOMRIGHT")
assert(point(face.clock) == "BOTTOMRIGHT" and point(face.coords) == "BOTTOMRIGHT", "the clock and coordinates move inside")
apart(face.clock, face.coords, "the clock and coordinates sharing a corner")
apart(face.meridiem, face.coords, "the clock's AM or PM and the coordinates")
K.Options.Write("Minimap", "coords.position", "LEFT")
apart(face.coords, face.zoom, "coordinates at the left and the zoom slider")
local cx = select(4, point(face.clock))
K.Options.Write("Minimap", "clock.x", -4)
assert(W.Near(select(4, point(face.clock)), cx - 4, 0.01), "a moved text takes its offsets")
for _, key in ipairs({ "zone.position", "clock.position", "coords.position" }) do K.Options.Write("Minimap", key, "") end
K.Options.Write("Minimap", "clock.x", 0)
K.Options.Write("Minimap", "column.hover", true)
local zp3, zrel3, zrelp3, zx3, zy3 = point(face.zone)
assert(zp3 == zp and zrel3 == zrel and zrelp3 == zrelp and zx3 == zx and zy3 == zy, "the usual place comes back exactly")
local cp, crel, crelp = point(face.clock)
assert(cp == "RIGHT" and crel == face.card and crelp == "BOTTOMRIGHT", "and the clock returns under the card")

-- Medallions: a moved caption takes its plaque away; back home the plaque returns.
M.Settle(env)
assert(face.plaques[1].chrome.fill[5]:IsShown(), "the zone plaque shows at its usual place")
K.Options.Write("Minimap", "zone.position", "TOP")
assert(not face.plaques[1].chrome.fill[5]:IsShown(), "a zone inside the map leaves no empty plaque")
K.Options.Write("Minimap", "zone.position", "")
assert(face.plaques[1].chrome.fill[5]:IsShown(), "and the plaque comes back with it")
M.Settle(env)

-- Clock accent and lockouts in the clock tooltip.
K.Options.Write("Minimap", "clock.mode", "local12")
local er, eg, eb = face.meridiem:GetTextColor()
K.Options.Write("Minimap", "clock.accent", true)
local ar, ag, ab = ns.Style.Accent()
local mr, mg, mb = face.meridiem:GetTextColor()
assert(W.Near(mr, ar) and W.Near(mg, ag) and W.Near(mb, ab), "the AM or PM takes the accent")
K.Options.Write("Minimap", "clock.accent", false)
mr, mg, mb = face.meridiem:GetTextColor()
assert(mr == er and mg == eg and mb == eb, "and gives it back")
local kit = K.Widgets.Tooltip()
face.clockHit:GetScript("OnEnter")(face.clockHit)
assert(not lines(kit):find("Molten Core", 1, true), "the clock tooltip adds nothing by default")
K.Options.Write("Minimap", "clock.hover", "lockouts")
face.clockHit:GetScript("OnEnter")(face.clockHit)
assert(lines(kit):find("Molten Core (40 Player)", 1, true) and env._raidInfo == 1, "the clock tooltip lists saved instances and asks for fresh ones")
face.clockHit:GetScript("OnLeave")(face.clockHit)
K.Options.Write("Minimap", "clock.hover", "none")

-- Instance difficulty: shown only inside, on the instance events; secrets and missing APIs hide it.
K.Options.Write("Minimap", "difficulty.shown", true)
assert(not face.difficulty:IsShown(), "outside an instance there is no difficulty")
env._instance = { "Molten Core", "raid", 9, "40 Player", 40 }
env.FireEvent("PLAYER_DIFFICULTY_CHANGED")
assert(face.difficulty:IsShown() and face.difficulty:GetText() == "40N", "inside a raid it reads 40N: " .. tostring(face.difficulty:GetText()))
env._instance = { "Karazhan", "raid", 6, "25 Heroic", 25 }
env.FireEvent("ZONE_CHANGED_NEW_AREA")
assert(face.difficulty:GetText() == "25H", "a heroic raid reads 25H after the zone changes")
local dp = point(face.difficulty)
assert(dp == "TOPLEFT", "it sits in the map's top left by default")
K.Options.Write("Minimap", "difficulty.accent", true)
local dr, _, db = face.difficulty:GetTextColor()
assert(W.Near(dr, ar) and W.Near(db, ab), "accent colours the difficulty")
K.Options.Write("Minimap", "mail.position", "TOPLEFT")
apart(face.difficulty, buttons.mail, "the difficulty and mail sharing the top left")
K.Options.Write("Minimap", "mail.position", "column")
local issecret = env.issecretvalue
env.issecretvalue = function(v) return v == "raid" or issecret(v) end
env.FireEvent("UPDATE_INSTANCE_INFO")
assert(not face.difficulty:IsShown(), "a secret instance type hides the difficulty")
env.issecretvalue = issecret
env.GetInstanceInfo = nil
env.FireEvent("PLAYER_DIFFICULTY_CHANGED")
assert(not face.difficulty:IsShown(), "a missing GetInstanceInfo hides it")
env.GetInstanceInfo = function() return unpack(env._instance) end
env.FireEvent("PLAYER_DIFFICULTY_CHANGED")
assert(face.difficulty:IsShown(), "and it comes back")
K.Options.Write("Minimap", "difficulty.shown", false)
assert(not face.difficulty:IsShown(), "switching it off hides it")

-- Frame rate and latency: one ticker at the chosen interval, the readout and its tooltip; off stops it.
local tickers = M.LiveTickers(env)
K.Options.Write("Minimap", "perf.shown", true)
assert(M.LiveTickers(env) == tickers + 1, "the readout starts one ticker")
local live
for _, ticker in ipairs(env._tickers) do if not ticker.cancelled and ticker.fn ~= nil and ticker.interval == 3 then live = ticker end end
assert(live, "every 3 seconds by default")
assert(face.perf:IsShown() and face.perf:GetText():find("60 ", 1, true) and face.perf:GetText():find("42 ", 1, true), "it reads the frame rate and home latency: " .. face.perf:GetText())
assert(point(face.perf) == "BOTTOMLEFT", "in the map's bottom left")
K.Options.Write("Minimap", "perf.latency", "world")
assert(face.perf:GetText():find("77 ", 1, true), "world latency when asked")
K.Options.Write("Minimap", "perf.accent", false)
assert(face.perf:GetText() == "60 fps  77 ms", "accent off leaves plain labels: " .. face.perf:GetText())
K.Options.Write("Minimap", "perf.interval", 5)
local live5 = env._tickers[#env._tickers]
assert(live.cancelled and live5.interval == 5 and not live5.cancelled, "a new interval replaces the ticker")
env.GetFramerate = function() return 30 end
M.RunTickers(env)
assert(face.perf:GetText() == "30 fps  77 ms", "each tick reads again")
K.Options.Write("Minimap", "perf.hover", "lockouts")
assert(face.perfHit:IsShown(), "the readout takes the pointer only when it has a tooltip")
face.perfHit:GetScript("OnEnter")(face.perfHit)
assert(lines(kit):find("Molten Core", 1, true), "its tooltip lists saved instances")
face.perfHit:GetScript("OnLeave")(face.perfHit)
env._saved = {}
face.perfHit:GetScript("OnEnter")(face.perfHit)
assert(lines(kit):find("No saved instances", 1, true), "and says so when there are none")
face.perfHit:GetScript("OnLeave")(face.perfHit)
K.Options.Write("Minimap", "perf.position", "BOTTOMRIGHT")
K.Options.Write("Minimap", "column.hover", false)
for _, name in ipairs({ "tracking", "calendar" }) do apart(face.perf, buttons[name], "the readout and the " .. name .. " button") end
K.Options.Write("Minimap", "column.hover", true)
K.Options.Write("Minimap", "perf.shown", false)
assert(live5.cancelled and not face.perf:IsShown() and not face.perfHit:IsShown(), "off stops the ticker and hides the readout")
clean(env, K, "readouts")

-- The drawer as a list: names beside the buttons, wider panel; off restores the grid.
local lib = env._lib
local drawer = ns.Map.drawer
drawer:Open()
local gridWidth = drawer.panel:GetWidth()
K.Options.Write("Minimap", "drawer.list", true)
local bug = lib.objects.BugSack
assert(drawer.labels[bug] and drawer.labels[bug]:IsShown() and drawer.labels[bug]:GetText() == "BugSack", "the list names each addon")
assert(drawer.panel:GetWidth() > gridWidth, "and the panel widens for the names")
apart(drawer.labels[bug], bug, "a name and its button")
K.Options.Write("Minimap", "drawer.list", false)
assert(not drawer.labels[bug]:IsShown() and drawer.panel:GetWidth() == gridWidth, "off hides the names and restores the grid")
clean(env, K, "drawer")

-- The Options preview shows the new readouts when they are on.
K.Options.Write("Minimap", "perf.shown", true)
K.Options.Write("Minimap", "difficulty.shown", true)
local preview = ns.Preview.Build(env.UIParent)
assert(preview.face.perf:IsShown() and preview.face.difficulty:IsShown(), "the preview shows the readout and the difficulty")
assert(preview.face.difficulty:GetText() == "25H", "with the live or sample difficulty")
K.Options.Write("Minimap", "perf.shown", false)
K.Options.Write("Minimap", "difficulty.shown", false)
preview:Refresh()
assert(not preview.face.perf:IsShown() and not preview.face.difficulty:IsShown(), "and hides them when off")

-- Disabling the module stops the readout and restores the rotation it set.
K.Options.Write("Minimap", "rotate", true)
K.Options.Write("Minimap", "perf.shown", true)
env._cvarWrites = {}
local perfTicker = env._tickers[#env._tickers]
assert(perfTicker.interval == 5 and not perfTicker.cancelled, "the readout ticks before the module is disabled")
assert(K.Modules.Disable("Minimap"))
assert(env._cvarWrites[1] == "rotateMinimap=0", "disabling turns rotation off")
assert(perfTicker.cancelled, "and stops the readout's ticker")
clean(env, K, "disable")
-- A profile saved with every caption moved loads cleanly on each Medallions frame.
for _, frame in ipairs({ "medallion", "ring", "classic" }) do
	local fresh = { version = 42, profiles = { Default = { Minimap = { enabled = true, frame = frame,
		zone = { position = "TOP" }, clock = { position = "BOTTOMRIGHT" }, coords = { position = "BOTTOMRIGHT" } } } },
		characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local fenv, fK, fns = M.New({ saved = fresh, position = { 0.4532, 0.6218 }, setup = instance })
	M.Settle(fenv)
	clean(fenv, fK, "moved captions on the " .. frame .. " frame")
	assert(point(fns.Map.face.zone) == "TOP" and not fns.Map.face.plaques[1].chrome.fill[5]:IsShown(), "the " .. frame .. " zone loads inside the map")
	assert(not fns.Map.face.plaques[2].chrome.fill[5]:IsShown(), "and the " .. frame .. " row plaque hides with the clock and coordinates moved")
end

-- Review of a6c2c482: each probe below failed before its fix.
-- The column's distance from the edge moves it by the snapped difference at every test screen size.
for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local senv, sK, sns = M.New({ width = size[1], height = size[2], saved = profile(), position = { 0.4532, 0.6218 }, setup = instance })
	M.Settle(senv)
	local scol = sns.Map.column
	sK.Options.Write("Minimap", "column.hover", false)
	local sx0 = select(4, point(scol.buttons.tracking))
	sK.Options.Write("Minimap", "column.offset", 10)
	local sx1 = select(4, point(scol.buttons.tracking))
	assert(moved(sK, scol.holder, sx0, sx1), size[1] .. "x" .. size[2] .. ": the column moves in by the snapped distance: " .. sx0 .. " -> " .. sx1)
	clean(senv, sK, size[1] .. "x" .. size[2])
end

local renv, rK, rns = M.New({ saved = profile(), position = { 0.4532, 0.6218 }, setup = instance })
M.Settle(renv)
local function rwrite(key, value) rK.Options.Write("Minimap", key, value) end
local RS, rface, rbuttons, rdrawer = rns.Settings, rns.Map.face, rns.Map.column.buttons, rns.Map.drawer

-- Rotation keeps the player's own value: on then off leaves a native rotation on, and the memory survives a reload.
renv._cvars.rotateMinimap = true
rwrite("rotate", true)
rwrite("rotate", false)
assert(renv._cvars.rotateMinimap == true, "switching rotation off keeps the player's own rotation")
renv._cvars.rotateMinimap = false
local rsaved = profile()
local aenv, aK = M.New({ saved = rsaved, position = { 0.4532, 0.6218 }, setup = instance })
M.Settle(aenv)
aK.Options.Write("Minimap", "rotate", true)
local benv, bK = M.New({ saved = rsaved, position = { 0.4532, 0.6218 }, setup = function(e) instance(e); e._cvars.rotateMinimap = true end })
M.Settle(benv)
bK.Options.Write("Minimap", "rotate", false)
assert(benv._cvars.rotateMinimap == false, "after a reload, off still puts back the player's unrotated map")
clean(benv, bK, "rotation after a reload")

-- The open lockout tooltip redraws when the server answers, without asking again.
local rkit = rK.Widgets.Tooltip()
local rows = renv._saved
renv._saved = {}
rwrite("clock.hover", "lockouts")
rface.clockHit:GetScript("OnEnter")(rface.clockHit)
local asked = renv._raidInfo
renv._saved = rows
renv.FireEvent("UPDATE_INSTANCE_INFO")
assert(lines(rkit):find("Molten Core", 1, true) and renv._raidInfo == asked, "the open tooltip shows the server's lockouts: " .. lines(rkit))
rface.clockHit:GetScript("OnLeave")(rface.clockHit)
rwrite("clock.hover", "none")

-- Drags: switching free move off, a restricted drop, a missing modifier API and combat each end the drag without saving.
rwrite("column.free", true)
renv.IsShiftKeyDown = function() return true end
local rbtn = rbuttons.tracking
rns.Column.Drag(rbtn, true)
rwrite("column.free", false)
rns.Column.Drag(rbtn, false)
assert(not rbtn.moving and next(RS.Get("column.spots")) == nil, "switching free move off mid-drag ends the drag unsaved")
rwrite("column.free", true)
rns.Column.Drag(rbtn, true)
renv.RestrictAnchoring(rbtn)
local ok, err = pcall(rns.Column.Drag, rbtn, false)
renv.RestrictAnchoring(rbtn, false)
assert(ok and not rbtn.moving and next(RS.Get("column.spots")) == nil, "a restricted drop ends the drag unmeasured: " .. tostring(err))
renv.IsShiftKeyDown = nil
assert(pcall(rns.Column.Drag, rbtn, true) and not rbtn.moving, "a missing IsShiftKeyDown refuses the drag")
renv.IsShiftKeyDown = function() return true end
rns.Column.Drag(rbtn, true)
rbuttons.calendar:GetScript("OnEnter")(rbuttons.calendar)
local rov = rns.SecureClick.overlay
rov:GetScript("OnDragStart")(rov)
assert(rbtn.moving and rbuttons.calendar.moving, "the tracking and calendar drags start")
renv.FireEvent("PLAYER_REGEN_DISABLED")
assert(not rbtn.moving and not rbuttons.calendar.moving and next(RS.Get("column.spots")) == nil, "entering combat cancels both drags unsaved")
renv.FireEvent("PLAYER_REGEN_ENABLED")
rwrite("column.free", false)
clean(renv, rK, "drags")

-- Readouts: a hidden difficulty frees its corner, a missing frame rate hides its hover region, an unknown difficulty is not Normal.
rwrite("difficulty.shown", true)
rwrite("perf.shown", true)
rwrite("perf.position", "TOPLEFT")
renv._instance = { "Karazhan", "raid", 6, "25 Heroic", 25 }
renv.FireEvent("ZONE_CHANGED_NEW_AREA")
local below = select(5, point(rface.perf))
renv._instance = { "Riverglades", "none", 0, "", 5 }
renv.FireEvent("ZONE_CHANGED_NEW_AREA")
local alone = select(5, point(rface.perf))
rwrite("difficulty.shown", false)
assert(alone ~= below and alone == select(5, point(rface.perf)), "outside an instance the readout takes the corner: " .. below .. " / " .. alone)
rwrite("perf.hover", "lockouts")
local framerate = renv.GetFramerate
renv.GetFramerate = nil
M.RunTickers(renv)
assert(not rface.perf:IsShown() and not rface.perfHit:IsShown(), "without a frame rate the readout and its hover region hide")
renv.GetFramerate = framerate
M.RunTickers(renv)
assert(rface.perf:IsShown() and rface.perfHit:IsShown(), "and come back with it")
rwrite("perf.shown", false)
local info = renv.GetDifficultyInfo
renv.GetDifficultyInfo = nil
renv._instance = { "Karazhan", "raid", 6, "25 Heroic", 25 }
assert(rns.Data.Difficulty() == nil, "an unknown difficulty is not reported as normal: " .. tostring(rns.Data.Difficulty()))
renv.GetDifficultyInfo = info

-- No repeated work: a hidden difficulty writes nothing on its events, and a moved clock places the captions once per layout.
local writes = 0
for _, method in ipairs({ "SetText", "SetShown" }) do
	local fn = rface.difficulty[method]
	rface.difficulty[method] = function(self, ...) writes = writes + 1; return fn(self, ...) end
end
renv.FireEvent("UPDATE_INSTANCE_INFO")
renv.FireEvent("UPDATE_INSTANCE_INFO")
assert(writes == 0, "a hidden difficulty writes nothing on its events: " .. writes)
local passes, inside = 0, rface.PlaceInside
rface.PlaceInside = function(self, ...) passes = passes + 1; return inside(self, ...) end
rwrite("clock.position", "RIGHT")
passes = 0
rface.layoutWidth = nil
rface:Layout()
assert(passes == 1, "one layout places the inside captions once: " .. passes)
rface.PlaceInside = inside
rwrite("clock.position", "")

-- The drawer list: the Options preview shows sample rows, every row stays on screen, and the names follow Readable text.
rwrite("drawer.behaviour", "open")
rwrite("drawer.list", true)
local rpreview = rns.Preview.Build(renv.UIParent)
local pdrawer = rpreview.column.drawer
assert(pdrawer.open and pdrawer:Count() > 0 and pdrawer.labels[pdrawer.order[1]]:IsShown(), "the preview shows the open list with sample rows")
assert(rdrawer:Count() == 2 and rdrawer.open, "and the live drawer keeps only the live addons")
for i = 1, 40 do renv._lib:Add("TestAddon" .. i) end
rdrawer:Collect()
local rpanel = rdrawer.panel
assert(rpanel:GetBottom() >= renv.UIParent:GetBottom() - 0.01, "a long list stays on screen: bottom " .. rpanel:GetBottom())
for i, button in ipairs(rdrawer.order) do
	local nextButton = rdrawer.order[i + 1]
	if nextButton then apart(rdrawer.labels[button], nextButton, "a name and the next button") end
end
rwrite("drawer.list", false)
local hides = 0
for _, label in pairs(rdrawer.labels) do
	local fn = label.SetShown
	label.SetShown = function(self, ...) hides = hides + 1; return fn(self, ...) end
end
rdrawer:Layout()
assert(hides == 0, "a grid layout leaves the hidden names alone: " .. hides)
rwrite("drawer.list", true)
rK.Profiles.Readable("Readable")
rdrawer:Layout()
local label = rdrawer.labels[renv._lib.objects.BugSack]
local body = rK.Widgets.Text(rface.mapArea, "body", "text", "OVERLAY")
assert(select(2, label:GetFont()) == select(2, body:GetFont()), "drawer names use the body text size: " .. select(2, label:GetFont()) .. " vs " .. select(2, body:GetFont()))
clean(renv, rK, "review")
print("minimap parity r1 ok")
