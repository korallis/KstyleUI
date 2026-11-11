-- test-ornament-corners.lua: the focus, boss and Targeted-chip corners are placed by the game's own events and the card chrome, with no render pass restyling them, and they follow the level setting.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
U.SetUnit(env, "focus", { name = "Elunara Frostweaver", level = 39, health = 2530, healthMax = 4010, power = 2900, powerMax = 4400, powerType = 0, powerToken = "MANA", reaction = 2, canAttack = true })
for i = 1, 5 do
	U.SetUnit(env, "boss" .. i, { name = "Boss " .. i, level = 62, classification = "elite", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
end
env.FireEvent("PLAYER_FOCUS_CHANGED")
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
env.RunTimers()
env._units.target = env._units.boss1
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()
assert(K.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")

local handles = { focus = ns.Frames.Get("focus").views[1].chrome.ornament }
for i, view in ipairs(ns.Frames.Get("boss").views) do
	handles["boss" .. i] = view.chrome.ornament
end
handles.chip = ns.Frames.Get("boss").views[1].chip.chrome.ornament

local function drawn(handle)
	local names = {}
	for i = 1, handle.used do
		local texture = handle.textures[i]
		if texture:IsShown() then names[#names + 1] = texture:GetTexture() end
	end
	return names
end
local live = {}
for name, handle in pairs(handles) do
	live[name] = table.concat(drawn(handle), " ")
	handle:Restyle()
	assert(table.concat(drawn(handle), " ") == live[name], name .. ": the game's own events place the corners a restyle would place")
end
for _, name in ipairs({ "boss1", "boss2", "chip" }) do
	local pieces = drawn(handles[name])
	assert(#pieces == 4, name .. " draws four corners at Full, got " .. #pieces)
	for _, path in ipairs(pieces) do
		assert(path:find("ForgedOrnaments\\Corner%d+%.png$"), name .. ": a corner piece, got " .. path)
	end
end

for _, level in ipairs({ "Subtle", "Off" }) do
	K.Options.Write("Widgets", "ornaments", level)
	env.RunTimers()
	for name, handle in pairs(handles) do
		assert(#drawn(handle) == 0, name .. " draws no corners at " .. level)
	end
end
K.Options.Write("Widgets", "ornaments", "Full")
env.RunTimers()
for name, handle in pairs(handles) do
	assert(table.concat(drawn(handle), " ") == live[name], name .. " draws its corners again at Full")
end

local chrome = ns.Frames.Get("boss").views[2].chrome
chrome:SetShown(false)
env.RunTimers()
assert(#drawn(handles.boss2) == 0, "a hidden card chrome hides its corners")
chrome:SetShown(true)
env.RunTimers()
assert(#drawn(handles.boss2) == 4, "the corners return with the chrome")
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok ornament corners follow the game's events and the level")
