-- test-medallions-rune-rim.lua: generated chrome must resolve through the texture registry, and every visible unit and party rim uses the engraved high-resolution asset.
local function read(path)
	local file = assert(io.open(path, "rb"), "missing texture or source: " .. path)
	local data = file:read("*a")
	file:close()
	return data
end

local registered = {}
for name, file in read("Core/Tokens.lua"):gmatch('(med%w+) = { file = "Textures\\\\Medallions\\\\([^"]+)"') do
	registered[file] = name
end
local count = 0
for file in read("Tools/media/medallions_kit.py"):gmatch('Chrome%("([^"]+)"') do
	local name = registered[file .. ".png"]
	assert(name, "register " .. file .. ".png in Core/Tokens.lua before drawing it; missing textures must never fall back")
	count = count + 1
end
assert(count > 0, "the chrome registry check must inspect the production generator")

local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
for file, name in pairs(registered) do
	local path = K.Tokens.Texture(name)
	assert(path:sub(-#file) == file, name .. " must resolve to its registered texture")
	local png = read("Media/Textures/Medallions/" .. file)
	assert(png:sub(1, 8) == "\137PNG\13\10\26\10" and png:find("IDAT", 1, true) and png:find("IEND", 1, true), name .. " must load a complete PNG")
end
local rim = read("Media/Textures/Medallions/Ring128.png")
assert(rim:sub(17, 24) == "\0\0\1\0\0\0\1\0", "rebake the engraved medRing at 256x256 for Retina and 5120x1440")

for _, unit in ipairs({ "target", "pet", "focus" }) do
	U.SetUnit(env, unit, { name = unit, level = 60, health = 100, healthMax = 100, reaction = 2 })
end
env.SetTarget(true)
for _, kind in ipairs({ "player", "target", "pet", "focus" }) do
	local m = ns.Frames.Get(kind).views[1].medallion
	assert(m and m:IsShown() and m.ring:GetTexture() == K.Tokens.Texture("medRing"), kind .. " must draw the registered engraved rim")
end
assert(#env._errors == 0, tostring(env._errors[1]))

local G = dofile("Tools/regression/group_env.lua")
local ge, GK, group = G.New()
G.SetRoster(ge, "party", { { name = "Warlock", class = "WARLOCK", health = 100, maxHealth = 100 } })
assert(GK.Modules.Enable("GroupFrames"))
ge.RunTimers()
local party = 0
group.Unit.ForEach(function(f)
	if f.unit and f.kind == "party" then
		assert(f.medBezel and f.medBezel:IsShown() and f.medBezel:GetTexture() == GK.Tokens.Texture("medRing"), f.unit .. " must draw the same registered engraved rim")
		party = party + 1
	end
end)
assert(party > 0 and #ge._errors == 0, "party rim coverage must run without errors")
print("engraved rune rim: registered chrome and unit/party loads ok")
