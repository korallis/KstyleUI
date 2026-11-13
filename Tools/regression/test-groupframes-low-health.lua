-- test-groupframes-low-health.lua: a party member at low health turns red, the bar and its percentage both, as the KSTY-44 mock-up's 38% member does (KSTY-60 item 19); a healthy member keeps its class bar and a white percentage, and the colours come from curves so no secret is read.
local G = dofile("Tools/regression/group_env.lua")

local function last(object, method)
	for i = #object._calls, 1, -1 do
		local call = object._calls[i]
		if call.method == method then
			return call.args
		end
	end
end

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local env, K, ns = G.New()
G.SetRoster(env, "party", {
	{ name = "Ilyra", class = "PRIEST", health = 100, maxHealth = 100 },
	{ name = "Dunmar", class = "WARRIOR", health = 38, maxHealth = 100 },
	{ name = "Brannoc", class = "PALADIN", health = 64, maxHealth = 100 },
})
assert(K.Modules.Enable("GroupFrames"), "the module switches on")
env.RunTimers()

local header = ns.Headers.party
local function content(unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit and button._shown then
			return ns.Button.Content(button)
		end
		i = i + 1
	end
end

local lr, lg, lb = K.Tokens.Color("healthLow")
local wr, wg, wb = K.Tokens.Color("textEmphasis")
local function textColor(f)
	local args = assert(last(f.healthText, "SetTextColor"), "the percentage is coloured")
	return env.Reveal(args[1]), env.Reveal(args[2]), env.Reveal(args[3])
end

local low = assert(content("party2"), "the 38% member has a frame")
assert(near(env.Reveal(low.health.lowFill:GetAlpha()), 1), "the 38% member's bar shows the red low-health fill")
local r, g, b = textColor(low)
assert(near(r, lr) and near(g, lg) and near(b, lb), "and its percentage turns red")
local args = last(low.healthText, "SetTextColor")
assert(env.issecretvalue(args[1]), "the colour reaches SetTextColor as the curve's secret, never read in Lua")

for _, unit in ipairs({ "party1", "party3" }) do
	local f = assert(content(unit), unit .. " has a frame")
	assert(near(env.Reveal(f.health.lowFill:GetAlpha()), 0), unit .. " keeps its class bar")
	r, g, b = textColor(f)
	assert(near(r, wr) and near(g, wg) and near(b, wb), unit .. " keeps a white percentage")
end

env._roster.units.party2.health = 90
env.FireEvent("UNIT_HEALTH", "party2")
env.RunTimers()
r, g, b = textColor(low)
assert(near(r, wr) and near(g, wg) and near(b, wb), "healed past the line, the percentage is white again")
assert(near(env.Reveal(low.health.lowFill:GetAlpha()), 0), "and the bar its own colour")

env._roster.units.party2.health = 0
env._roster.units.party2.dead = true
env.FireEvent("UNIT_HEALTH", "party2")
env.RunTimers()
assert(low.healthText:GetText() == "Dead", "a dead member says Dead")
r, g, b = select(1, unpack(last(low.healthText, "SetTextColor")))
assert(near(r, wr) and near(g, wg) and near(b, wb), "in the plain white")
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok group frames low health")
