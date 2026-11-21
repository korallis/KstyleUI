-- test-groupframes-parity-r3c-review.lua: the PR #630 review's findings, each from its probe: the legacy heal absorb line, saved solo centring on reload, the missing instance API, the small raid's party card, the custom size floor, the single-column header anchor, the shield glow's clamp, lost maximum health's events and the preview.
local G = dofile("Tools/regression/group_env.lua")

local MODULE = "GroupFrames"

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { [MODULE] = own } }, characters = {}, layouts = {} }
end

local function write(env, K, key, value)
	K.Options.Write(MODULE, key, value)
	env.RunTimers()
end

local function frame(ns, unit)
	local out
	ns.Unit.ForEach(function(f) if f.unit == unit then out = f end end)
	return assert(out, "no frame for " .. unit)
end

local function near(a, b)
	return math.abs(a - b) < 1e-3
end

local function plain(env, v)
	return env.issecretvalue(v) and env.Reveal(v) or v
end

local function noErrors(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A v0.2.8 profile's heal absorb line keeps the shield line's thickness until it is given its own.
do
	local env, K, ns = G.New({ saved = saved({ prediction = { shieldLines = 6, healAbsorbLine = true } }) })
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", role = "TANK", health = 50, maxHealth = 100 } })
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	local px = K.Widgets.Border(f)
	assert(near(f.healAbsorbLine.opts.height, 6 * px), "the heal absorb line keeps the saved shield thickness: " .. f.healAbsorbLine.opts.height / px)
	write(env, K, "prediction.healAbsorbLines", 3)
	assert(near(f.healAbsorbLine.opts.height, 3 * px) and near(f.shield.opts.height, 6 * px), "given its own, it keeps it")
	noErrors(env, K)
end
collectgarbage()

-- A saved Centre when solo centres the frame on reload, not at the next roster change.
do
	local env, K, ns = G.New({ saved = saved({ party = { showSolo = true, centerSolo = true } }) })
	env.RunTimers()
	local s = ns.Settings.current.party
	local y = select(5, ns.Headers.party:GetPoint(1))
	assert(ns.AutoLayout.state.solo == true and near(y, -(4 * (s.height + s.spacing)) / 2), "a solo reload centres the frame: " .. tostring(y))
	noErrors(env, K)
end
collectgarbage()

-- Without the instance API a small raid could be a battleground, so the raid frames stay.
do
	local env, K, ns = G.New({ setup = function(e) e.IsInInstance = nil end })
	G.SetRoster(env, "raid", G.Members(6))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "party.smallRaid", true)
	assert(not ns.AutoLayout.state.smallRaid and env.Driver(ns.Headers.raid[1], "visibility") ~= "hide", "no instance API, no party frames in a raid")
	noErrors(env, K)
end
collectgarbage()

-- A small raid's party card counts group 1 only; a custom raid size keeps the frame controls' 40 by 16 floor; the secure header,
-- as SecureGroupHeaders.lua, adds the column anchor only when more than one column fills.
do
	local env, K, ns = G.New({})
	G.SetRoster(env, "raid", G.Members(6, function(i, m) m.group = i == 1 and 1 or 2 end))
	K.Modules.Enable(MODULE)
	env.RunTimers()
	write(env, K, "party.card", true)
	write(env, K, "party.smallRaid", true)
	local card = ns.Headers.cards.party
	local _, one = ns.Geometry.PartyCard(card.settings, K.Widgets.SECTION_CAP_HEIGHT, 1)
	assert(#G.Shown(ns.Headers.party) == 1 and math.abs(card.frame:GetHeight() - one) < 1, "the card fits group 1's one member: " .. card.frame:GetHeight())
	assert(card.cap.frame.count:GetText() == "1", "and counts one: " .. tostring(card.cap.frame.count:GetText()))
	write(env, K, "party.smallRaid", false)
	write(env, K, "auto.smallWidth", 1)
	write(env, K, "auto.smallHeight", 1)
	local header = ns.Headers.raid[1]
	local button = header:GetAttribute("child1")
	assert(button:GetWidth() >= 40 and button:GetHeight() >= 16, "the smallest custom frame is 40 by 16: " .. button:GetWidth() .. "x" .. button:GetHeight())
	write(env, K, "raid.merge", true)
	assert(button:GetNumPoints() == 2, "two columns: the first frame takes the column anchor too")
	write(env, K, "raid.unitsPerColumn", 10)
	assert(button:GetNumPoints() == 1, "one column: no column anchor")
	noErrors(env, K)
end
collectgarbage()

-- The shield glow compares the shield with the missing health alone, as the documented clamp modes say, whether incoming heals show
-- or not; lost maximum health reads its API on its own event, not on every health or absorb change.
do
	local env, K, ns = G.New({})
	G.SetRoster(env, "party", { { name = "Thaldren", class = "WARRIOR", health = 70, maxHealth = 100, incoming = 20, absorb = 15, maxLoss = 0.1 } })
	K.Modules.Enable(MODULE)
	env.RunTimers()
	local f = frame(ns, "party1")
	write(env, K, "prediction.glow", true)
	local function glow() return plain(env, f.shieldGlow:GetAlpha()) end
	assert(glow() == 0, "a 15 shield under 30 missing health does not glow while 20 healing comes in")
	write(env, K, "prediction.heals", false)
	assert(glow() == 0, "nor with incoming heals hidden")
	env._roster.units.party1.absorb = 35
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "party1")
	assert(glow() == 1, "a shield past the missing health glows")
	write(env, K, "prediction.heals", true)
	assert(glow() == 1, "with incoming heals shown too")
	write(env, K, "prediction.maxLoss", "SOLID")
	local calls, get = 0, env.GetUnitTotalModifiedMaxHealthPercent
	env.GetUnitTotalModifiedMaxHealthPercent = function(...) calls = calls + 1; return get(...) end
	for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED" }) do env.FireEvent(event, "party1") end
	assert(calls == 0, "health and absorb events leave lost maximum health alone: " .. calls)
	env.FireEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED", "party1")
	assert(calls == 1, "its own event reads it once: " .. calls)
	noErrors(env, K)
end
collectgarbage()

-- The preview's merged raid samples follow Frames per column, and Name format shows on the tank's two-word name.
do
	local env, K = G.New({})
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 420)
	local preview = K.Options.Preview(MODULE)(parent)
	write(env, K, "raid.merge", true)
	write(env, K, "raid.unitsPerColumn", 2)
	preview:Refresh()
	local _, _, _, x1, y1 = preview.raidFrames[1]:GetPoint(1)
	local _, _, _, x3, y3 = preview.raidFrames[3]:GetPoint(1)
	assert(near(y3, y1) and x3 > x1, "two per column, the third sample starts the second column: " .. x3 .. ", " .. y3)
	local tank = preview.partyFrames[1]
	assert(tank.name:GetText() == "Thaldren", "whole names keep the sample's own name")
	write(env, K, "party.nameFormat", "LAST")
	preview:Refresh()
	assert(tank.name:GetText() == "Ironvow", "another format shows on the tank as a follower's two-word name: " .. tostring(tank.name:GetText()))
	noErrors(env, K)
end

print("groupframes parity round 3c review ok: heal absorb line, solo reload, instance fallback, small raid card, size floor, header columns, shield glow, lost maximum health events and the preview")
