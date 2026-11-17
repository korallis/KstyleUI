-- test-groupframes-prediction.lua: prediction amounts retain the original per-event results while ranges follow maximum health, unit reuse and full refresh, including secret values and preview samples.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local KEYS = { "heals", "absorbs", "shield", "healAbsorbs" }
local FIELDS = { heals = "incoming", absorbs = "absorb", shield = "absorb", healAbsorbs = "healAbsorb" }

local function Check(env, f, member, what, maximum)
	-- Before this optimization every enabled prediction bar received (0, UnitHealthMax) and its
	-- calculator amount on each event. The group stub returns these fixture amounts as secrets.
	for _, key in ipairs(KEYS) do
		local bar = f[key]
		local range = assert(W.LastCall(bar, "SetMinMaxValues"), what .. " " .. key .. " needs a range")
		local high, value = range[2], W.LastCall(bar, "SetValue")[1]
		if env.issecretvalue(high) then
			high = env.Reveal(high)
		end
		if env.issecretvalue(value) then
			value = env.Reveal(value)
		end
		eq(range[1], 0, what .. " " .. key .. " minimum")
		eq(high, maximum or member.maxHealth, what .. " " .. key .. " maximum")
		eq(value, (key == "shield" and maximum and member.shield) or member[FIELDS[key]] or 0, what .. " " .. key .. " amount")
	end
end

local function Ranges(f)
	local count = 0
	for _, key in ipairs(KEYS) do
		for _, call in ipairs(f[key]._calls) do
			if call.method == "SetMinMaxValues" then
				count = count + 1
			end
		end
	end
	return count
end

for _, kind in ipairs({ "party", "raid" }) do
	local env, K, ns = G.New()
	local members = {
		{ name = "Tank", class = "WARRIOR", health = 60, maxHealth = 100, incoming = 12, absorb = 9, healAbsorb = 7 },
		{ name = "Healer", class = "PRIEST", health = 220, maxHealth = 300, incoming = 28, absorb = 31, healAbsorb = 15 },
	}
	G.SetRoster(env, kind, members)
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local unit = kind .. "1"
	local header = kind == "party" and ns.Headers.party or ns.Headers.raid[1]
	local f
	for i = 1, 5 do
		local button = header:GetAttribute("child" .. i)
		if button and button:GetAttribute("unit") == unit then
			f = ns.Button.Content(button)
		end
	end
	assert(f, kind .. " has its first unit")
	Check(env, f, members[1], "initial " .. kind)
	assert(env.issecretvalue(env.UnitHealthMax(unit)), "maximum health stays secret")
	env.SetCombat(true)
	env.RunTimers()
	local count = Ranges(f)
	for i, event in ipairs({ "UNIT_HEALTH", "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEALTH" }) do
		local m = members[1]
		m.health, m.incoming, m.absorb, m.healAbsorb = 60 - i, 12 + i, 9 + i, 7 + i
		env.FireEvent(event, unit)
		Check(env, f, m, event)
		eq(Ranges(f), count, event .. ": set prediction ranges on max-health or refresh, never amount events")
	end
	members[1].maxHealth, members[1].health = 200, 90
	env.FireEvent("UNIT_MAXHEALTH", unit)
	Check(env, f, members[1], "in-combat maximum change")
	eq(Ranges(f), count + 4, "one range update per prediction bar on UNIT_MAXHEALTH")
	env.FireEvent("UNIT_HEALTH", unit)
	Check(env, f, members[1], "health after maximum change")
	eq(Ranges(f), count + 4, "health after maximum change does not reset ranges")
	-- Secure headers can reassign a token in combat without a max-health event.
	env._secure = true
	f.owner:SetAttribute("unit", kind .. "2")
	env._secure = false
	Check(env, f, members[2], "unit reassignment in combat")
	env.FireEvent("UNIT_HEALTH", kind .. "2")
	Check(env, f, members[2], "new unit health")
	env._secure = true
	f.owner:SetAttribute("unit", nil)
	f.owner:SetAttribute("unit", unit)
	env._secure = false
	Check(env, f, members[1], "frame reuse after clearing unit")
	env.SetCombat(false)
	-- A roster change can replace the member behind the same unit token.
	members[1] = { name = "Replacement", class = "DRUID", health = 310, maxHealth = 500, incoming = 61, absorb = 43, healAbsorb = 22 }
	G.SetRoster(env, kind, members)
	env.RunTimers()
	Check(env, f, members[1], "roster replacement")
	members[1].maxHealth = 600
	f.owner:Hide()
	f.owner:Show()
	Check(env, f, members[1], "reshown frame")
	members[1].maxHealth = 700
	env.FireEvent("PLAYER_ENTERING_WORLD")
	Check(env, f, members[1], "world full refresh")
	for _, key in ipairs(KEYS) do
		K.Options.Write("GroupFrames", "prediction." .. key, false)
		env.RunTimers()
		members[1].maxHealth = members[1].maxHealth + 100
		env.FireEvent("UNIT_MAXHEALTH", unit)
		K.Options.Write("GroupFrames", "prediction." .. key, true)
		env.RunTimers()
		Check(env, f, members[1], "re-enabled " .. key)
	end
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(300, 500)
	local preview = K.Options.Preview("GroupFrames")(parent)
	for _, frames in ipairs({ preview.partyFrames, preview.raidFrames }) do
		for _, sample in ipairs(frames) do
			Check(env, sample, sample.sample, "preview", 1)
		end
	end
	preview:Refresh()
	Check(env, preview.partyFrames[1], preview.partyFrames[1].sample, "refreshed preview", 1)
	eq(#env._blocked, 0, "no protected calls in combat")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("groupframes prediction amounts, ranges and refresh paths ok")
