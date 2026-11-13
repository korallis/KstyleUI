-- test-old-style-names.lua: no string a player reads names the retired styles. The HUD styles are Frames and Orbs
-- (design bible 3.11); KSTY-60 item 27 found "Lumen" and "Classic" still in the unit frames' Style choices, the
-- nameplate and font presets and the setup's DPS note. The English base (Tools/locale/enUS.json) holds every L[...] key
-- the addons load, so a retired name there reaches the settings window or the setup; a translation carrying "Lumen"
-- reaches it in that language. Saved values such as "lumen" stay valid: only what a player reads is checked.
local RETIRED = { "Lumen", "Classic" }

local function read(path)
	local file = assert(io.open(path, "rb"), "cannot open " .. path)
	local text = file:read("*a")
	file:close()
	return text
end

local function names(text)
	local found = {}
	for _, name in ipairs(RETIRED) do
		if text:find("%f[%w]" .. name .. "%f[%W]") then
			found[#found + 1] = name
		end
	end
	return found
end

local problems = {}
local strings = 0
for line in read("Tools/locale/enUS.json"):gmatch("[^\n]+") do
	local key = line:match('^%s*"(.*)",?%s*$')
	if key then
		strings = strings + 1
		local found = names(key)
		if #found > 0 then
			problems[#problems + 1] = "enUS: " .. key .. " (" .. table.concat(found, ", ") .. ")"
		end
	end
end
assert(strings > 1000, "the English base lists every string, got " .. strings)

for _, code in ipairs({ "deDE", "frFR", "esES", "zhCN" }) do
	for line in read("Core/Locales/" .. code .. ".lua"):gmatch("[^\r\n]+") do
		local value = line:match('^%s*%[".-"%]%s*=%s*"(.*)",%s*$')
		if value and value:find("%f[%w]Lumen%f[%W]") then
			problems[#problems + 1] = code .. ": " .. value
		end
	end
end

assert(#problems == 0, "player-facing strings name a retired style (use Frames and Orbs, or describe the look):\n" .. table.concat(problems, "\n"))
print("old style names ok")
