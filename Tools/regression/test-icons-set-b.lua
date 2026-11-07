-- test-icons-set-b.lua: KstyleUI_IconsColour defines set B's data when loaded, every texture it names exists, and the Icons service shows it untinted.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local ADDON = "KstyleUI_IconsColour"
local PREFIX = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\"

local files = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if path:match("^" .. ADDON .. "/") then
		files[#files + 1] = path
	end
end
assert(#files > 0, ADDON .. " has Lua files")

local function exists(path)
	local handle = io.open(path, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

-- A C_AddOns stand-in that runs the real addon files, as the game would. The saved profile turns
-- custom icons on with set B, so login loads the addon before any module builds its frames.
local function New()
	local saved = { version = 1, profiles = { Default = { Icons = { enabled = true, set = "B" } } } }
	return W.New({
		saved = saved,
		setup = function(env)
			env._loads = {}
			env.C_AddOns = {
				LoadAddOn = function(name)
					env._loads[#env._loads + 1] = name
					if name ~= ADDON then
						return false, "MISSING"
					end
					Load(files, env)
					return true
				end,
			}
		end,
	})
end

-- The data table: the documented shape, and a PNG on disk for every path ----------------------------

local env, K = New()
assert(env._loads[1] == ADDON, "a saved set B loads " .. ADDON .. " at login: " .. tostring(env._loads[1]))
assert(K.Icons.ActiveSet() == "B", "set B loaded: " .. tostring(env.KstyleUIIconData))

local data = env.KstyleUIIconData
assert(type(data) == "table" and data.set == "B", ADDON .. " sets KstyleUIIconData for set B")
assert(type(data.icons) == "table" and type(data.schools) == "table")

local count, first = 0, nil
for id, path in pairs(data.icons) do
	count = count + 1
	assert(type(id) == "number" and id > 0 and id % 1 == 0, "icon keys are file IDs: " .. tostring(id))
	assert(path == PREFIX .. id .. ".png", "the path names the icon's own PNG: " .. tostring(path))
	assert(exists(ADDON .. "/Icons/" .. id .. ".png"), "Icons/" .. id .. ".png exists")
	first = first and math.min(first, id) or id
end
assert(count > 0, "set B has icons")
for id, mask in pairs(data.schools) do
	assert(data.icons[id], "a school belongs to an icon in the set: " .. tostring(id))
	assert(type(mask) == "number" and mask >= 1 and mask <= 127 and mask % 1 == 0, "a school is a bit mask: " .. tostring(mask))
end

-- The service shows the real art untinted, and keeps the game's icon for a file ID the set lacks -------

assert(K.Icons.Resolve(first) == PREFIX .. first .. ".png", "Resolve maps a file ID to set B's art")
local texture = K.Scale.Root():CreateTexture(nil, "ARTWORK", nil, 1)
assert(K.Icons.Apply(texture, first) == true, "Apply shows the custom icon")
assert(W.LastCall(texture, "SetTexture")[1] == PREFIX .. first .. ".png")
assert(W.SameRGB(texture, 1, 1, 1), "set B is never tinted")

local missing = 1
while data.icons[missing] do
	missing = missing + 1
end
assert(K.Icons.Apply(texture, missing) == false, "a file ID with no set B art is not custom")
assert(W.LastCall(texture, "SetTexture")[1] == missing, "the game's icon stays for a file ID the set lacks")
assert(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))

print("icon set B ok: " .. count .. " icons")
