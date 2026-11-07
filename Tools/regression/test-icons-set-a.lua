-- test-icons-set-a.lua: KstyleUI_Icons defines set A's data when loaded, every texture it names exists, and the Icons service shows it.
local W = dofile("Tools/regression/widget_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local PREFIX = "Interface\\AddOns\\KstyleUI_Icons\\Icons\\"

local files = {}
for _, path in ipairs(TocFiles("%.lua$")) do
	if path:match("^KstyleUI_Icons/") then
		files[#files + 1] = path
	end
end
assert(#files > 0, "KstyleUI_Icons has Lua files")

local function exists(path)
	local handle = io.open(path, "rb")
	if handle then
		handle:close()
		return true
	end
	return false
end

-- A C_AddOns stand-in that runs the real addon files, as the game would.
local function New()
	return W.New({
		setup = function(env)
			env._loads = {}
			env.C_AddOns = {
				LoadAddOn = function(name)
					env._loads[#env._loads + 1] = name
					if name ~= "KstyleUI_Icons" then
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
assert(env.KstyleUIIconData == nil, "nothing loads while custom icons are off")
K.Options.Write("Icons", "enabled", true)
assert(env._loads[1] == "KstyleUI_Icons", "turning icons on loads set A")
assert(K.Icons.ActiveSet() == "A", "set A loaded: " .. tostring(env.KstyleUIIconData))

local data = env.KstyleUIIconData
assert(type(data) == "table" and data.set == "A", "KstyleUI_Icons sets KstyleUIIconData for set A")
assert(type(data.icons) == "table" and type(data.schools) == "table")

local count, first = 0, nil
for id, path in pairs(data.icons) do
	count = count + 1
	assert(type(id) == "number" and id > 0 and id % 1 == 0, "icon keys are file IDs: " .. tostring(id))
	assert(path == PREFIX .. id .. ".png", "the path names the icon's own PNG: " .. tostring(path))
	assert(exists("KstyleUI_Icons/Icons/" .. id .. ".png"), "Icons/" .. id .. ".png exists")
	first = first and math.min(first, id) or id
end
assert(count > 0, "set A has icons")
for id, mask in pairs(data.schools) do
	assert(data.icons[id], "a school belongs to an icon in the set: " .. tostring(id))
	assert(type(mask) == "number" and mask >= 1 and mask <= 127 and mask % 1 == 0, "a school is a bit mask: " .. tostring(mask))
end

-- The service resolves and tints the real art ---------------------------------------------------------

assert(K.Icons.Resolve(first) == PREFIX .. first .. ".png", "Resolve maps a file ID to set A's art")
local texture = K.Scale.Root():CreateTexture(nil, "ARTWORK", nil, 1)
assert(K.Icons.Apply(texture, first) == true, "Apply shows the custom icon")
assert(W.LastCall(texture, "SetTexture")[1] == PREFIX .. first .. ".png")
local ar, ag, ab = K.Theme.Accent()
assert(W.SameRGB(texture, ar, ag, ab), "set A is tinted in the class colour")
assert(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))

print("icon set A ok: " .. count .. " icons")
