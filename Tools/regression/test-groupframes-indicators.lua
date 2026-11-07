-- test-groupframes-indicators.lua: role, leader, raid marker and ready-check icons, the threat border, incoming heals and absorbs on the group frames, with their settings and fallbacks.
local G = dofile("Tools/regression/group_env.lua")

local function eq(got, want, what)
	assert(got == want, what .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function last(object, method)
	for i = #object._calls, 1, -1 do
		local call = object._calls[i]
		if call.method == method then
			return call.args
		end
	end
end

local function setup(opts)
	local env, K, ns = G.New(opts)
	local party = {
		{ name = "Thaldren", class = "WARRIOR", role = "TANK", leader = true, threat = 3, incoming = 30, absorb = 12 },
		{ name = "Sylaen", class = "DRUID", role = "HEALER", marker = 8, ready = "waiting" },
		{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", threat = 0, secretThreat = true },
	}
	G.SetRoster(env, "party", party)
	K.Modules.Enable("GroupFrames")
	env.RunTimers()
	local function content(unit)
		local i = 1
		while ns.Headers.party._attributes["child" .. i] do
			local button = ns.Headers.party._attributes["child" .. i]
			if button._attributes.unit == unit and button._shown then
				return ns.Button.Content(button)
			end
			i = i + 1
		end
	end
	return env, K, ns, party, content
end

local env, K, _, party, content = setup()
local tank, healer, dps = content("party1"), content("party2"), content("party3")

-- Role icons: Blizzard's secret-safe role helper is missing here, so the fallback reads the role.
eq(tank.role:IsShown(), true, "the tank shows a role icon")
eq(last(tank.role, "SetAtlas")[1], "micro-TANK", "the tank's role icon")
eq(last(healer.role, "SetAtlas")[1], "micro-HEALER", "the healer's role icon")

-- Leader: alpha from the secret boolean.
local leader = last(tank.leader, "SetAlphaFromBoolean")
assert(leader and env.issecretvalue(leader[1]), "the leader icon follows the secret leader flag")
eq(env.Reveal(leader[1]), true, "party1 leads")
eq(env.Reveal(last(healer.leader, "SetAlphaFromBoolean")[1]), false, "party2 does not lead")

-- Raid marker: the secret index reaches the sprite sheet; no marker hides the icon.
local cell = last(healer.marker, "SetSpriteSheetCell")
assert(cell and env.Reveal(cell[1]) == 8, "party2's skull marker")
eq(cell[2], 4, "the marker sheet has 4 rows")
eq(healer.marker:IsShown(), true, "a marked member shows the marker")
eq(tank.marker:IsShown(), false, "an unmarked member hides the marker")
party[1].marker = 1
env.FireEvent("RAID_TARGET_UPDATE")
eq(tank.marker:IsShown(), true, "RAID_TARGET_UPDATE shows a new marker")

-- Ready check: waiting, then confirmed, then hidden a moment after it ends. A member still waiting
-- when it ends shows as not ready.
eq(healer.ready:IsShown(), false, "no ready-check icon before a check")
party[3].ready = "waiting"
env.FireEvent("READY_CHECK", "Thaldren", 30)
eq(healer.ready:IsShown(), true, "a ready check shows the icon")
eq(last(healer.ready, "SetAtlas")[1], env.READY_CHECK_WAITING_TEXTURE, "waiting")
party[2].ready = "ready"
env.FireEvent("READY_CHECK_CONFIRM", "party2", true)
eq(last(healer.ready, "SetAtlas")[1], env.READY_CHECK_READY_TEXTURE, "ready")
env.FireEvent("READY_CHECK_FINISHED")
eq(healer.ready:IsShown(), true, "the result stays for a moment")
eq(last(dps.ready, "SetAtlas")[1], env.READY_CHECK_NOT_READY_TEXTURE, "a member still waiting at the end shows as not ready")
eq(last(healer.ready, "SetAtlas")[1], env.READY_CHECK_READY_TEXTURE, "a ready member stays ready")
env.RunTimers()
eq(healer.ready:IsShown(), false, "then hides")

-- Threat: a plain threat status draws the glow in the game's threat colour; a secret one hides it.
eq(tank.threat:IsShown(), true, "the tank with aggro shows the threat glow")
local glow = last(tank.threatGlow.slice[1], "SetVertexColor")
local r, g, b = glow[1], glow[2], glow[3]
assert(near(r, 1) and near(g, 0) and near(b, 0), "status 3 is the game's red")
eq(dps.threat:IsShown(), false, "a secret threat status hides the border")
party[1].threat = 0
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "party1")
eq(tank.threat:IsShown(), false, "no aggro hides the border")

-- Incoming heals and absorbs through the heal prediction calculator.
local heals = last(tank.heals, "SetValue")
assert(heals and env.issecretvalue(heals[1]), "incoming heals reach the bar as a secret")
eq(env.Reveal(heals[1]), 30, "party1's incoming heals")
eq(env.Reveal(last(tank.absorbs, "SetValue")[1]), 12, "party1's absorbs")
eq(env.Reveal(last(tank.heals, "SetMinMaxValues")[2]), 100, "the heal bar spans the health maximum")
party[1].incoming = 45
env.FireEvent("UNIT_HEAL_PREDICTION", "party1")
eq(env.Reveal(last(tank.heals, "SetValue")[1]), 45, "UNIT_HEAL_PREDICTION updates the heals")
party[1].absorb = 20
env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "party1")
eq(env.Reveal(last(tank.absorbs, "SetValue")[1]), 20, "UNIT_ABSORB_AMOUNT_CHANGED updates the absorbs")
eq(tank.heals:GetParent():GetParent(), tank, "the prediction bars sit in a clip frame on the content")
party[1].absorb = 25
env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "party1")
eq(env.Reveal(last(tank.absorbs, "SetValue")[1]), 25, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED refreshes the prediction")
local calculators = env._calculators
env.FireEvent("UNIT_HEAL_PREDICTION", "party1")
eq(env._calculators, calculators, "the calculator is made once per frame, not per update")

-- Settings switch each part off.
K.Options.Write("GroupFrames", "icons.role", false)
K.Options.Write("GroupFrames", "icons.marker", false)
K.Options.Write("GroupFrames", "threat.enabled", false)
K.Options.Write("GroupFrames", "prediction.heals", false)
eq(tank.role:IsShown(), false, "role icons switch off")
eq(healer.marker:IsShown(), false, "markers switch off")
party[1].threat = 3
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "party1")
eq(tank.threat:IsShown(), false, "the threat border switches off")
eq(tank.heals:IsShown(), false, "incoming heals switch off")
eq(last(tank.heals, "SetValue")[1], 0, "hidden heals drop to zero, so absorbs start at the health fill")
eq(tank.calc.modes.absorb, env.Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals, "absorbs clamp without heals while heals are off")
eq(tank.absorbs:IsShown(), true, "absorbs stay on")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

-- Blizzard's secret-safe role helper is used when the client has it.
local seen
env, _, _, _, content = setup({
	setup = function(e)
		e.UnitFrameUtil = {
			UpdateUnitFrameRoleIcon = function(elements)
				seen = elements.unit
				elements.roleIcon:SetAtlas("blizzard-role")
			end,
		}
	end,
})
eq(last(content("party1").role, "SetAtlas")[1], "blizzard-role", "UnitFrameUtil draws the role icon")
assert(seen ~= nil, "UnitFrameUtil gets the unit")
eq(#env._errors, 0, "no errors with UnitFrameUtil: " .. tostring(env._errors[1]))

-- Without the calculator, the plain secret APIs fill the bars.
env, _, _, _, content = setup({
	setup = function(e)
		e.CreateUnitHealPredictionCalculator = nil
	end,
})
eq(env.Reveal(last(content("party1").heals, "SetValue")[1]), 30, "UnitGetIncomingHeals fills the bar without the calculator")
eq(env.Reveal(last(content("party1").absorbs, "SetValue")[1]), 12, "UnitGetTotalAbsorbs fills the bar without the calculator")
eq(#env._errors, 0, "no errors: " .. tostring(env._errors[1]))

print("groupframes indicators ok")
