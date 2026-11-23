-- test-api-range-contract.lua: range fade requires a completed range check, combining opaque booleans only in engine setters.
local G = dofile("Tools/regression/group_env.lua")
local env, _, ns = G.New()
local function plain(value)
	if env.issecretvalue(value) then
		return env.Reveal(value)
	end
	return value
end
local last, alpha
local frame = {
	unit = "party1",
	SetAlpha = function(_, value) alpha = value end,
	SetAlphaFromBoolean = function(_, value, yes, no)
		last = value
		alpha = env.Secret(plain(value) and plain(yes) or plain(no))
	end,
	GetAlpha = function() return alpha end,
}
env.UnitIsUnit = function() return false end
ns.Settings.current.range.fade = true
for _, checked in ipairs({ false, true }) do
	for _, inRange in ipairs({ false, true }) do
		for _, secret in ipairs({ false, true }) do
			env.UnitInRange = function()
				return secret and env.Secret(inRange) or inRange, secret and env.Secret(checked) or checked
			end
			ns.Unit.Range(frame)
			local expected = checked and not inRange and ns.Settings.current.range.alpha or 1
			assert(plain(alpha) == expected, "unchecked units never fade, even with secret range results")
		end
	end
end
assert(env.issecretvalue(last), "the check reaches the engine without conversion")
print("API range contract ok")
