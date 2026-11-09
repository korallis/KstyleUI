-- test-widgets-duration.lua: one duration format for every timer in the kit: "24s", "8m", "2h", "3d" (long "8m 12s", tenths under three seconds), the engine's own aura formatter for secret durations, and nothing at all for a secret number.
local W = dofile("Tools/regression/widget_env.lua")
local A = dofile("Tools/regression/auras_env.lua")

local env, K = W.New({ setup = A.Engine })
local Duration = K.Widgets.Duration

for _, case in ipairs({
	{ 24, nil, "24s" }, { 24.9, "short", "24s" }, { 90, "short", "90s" }, { 91, "short", "2m" }, { 480, "short", "8m" },
	{ 7200, "short", "2h" }, { 200000, "short", "3d" }, { 492, "long", "8m 12s" }, { 2.46, "decimal", "2.4" }, { 24, "decimal", "24s" },
	{ -5, "short", "0s" }, { 24, "none", "" },
}) do
	local got = Duration.Format(case[1], case[2])
	assert(got == case[3], tostring(case[1]) .. " as " .. tostring(case[2]) .. ": " .. case[3] .. ", got " .. got)
end
assert(Duration.Format(env.Secret(24), "short") == "", "a secret number is never formatted in Lua; the engine's formatter takes it")

local engine = env.AuraContainerInbound.GetDefaultAuraDurationFormatter()
assert(Duration.Formatter("short") == engine and Duration.Formatter() == engine, "the short format is the engine's own aura formatter, so every timer reads as the aura rows do")
local long = Duration.Formatter("long")
assert(long and long ~= engine and long == Duration.Formatter("long"), "the long format is built once")
local units
for _, call in ipairs(long.calls) do
	if call.method == "SetDesiredUnitCount" then
		units = call.args[1]
	end
end
assert(units == 2, "long shows two units")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("widgets duration ok")
