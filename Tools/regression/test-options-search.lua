-- test-options-search.lua: settings search reaches every row a page can show, whichever frame or bar its picker holds.
-- The unit frames and action bars pages show one frame's or bar's rows at a time, picked by their selector.
-- Search must still find the rows of every frame and bar, with the picker left as it is.
local O = dofile("Tools/regression/options_env.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local function ModuleFiles(folder)
	local out = {}
	for _, path in ipairs(TocFiles("%.lua$")) do
		if path:sub(1, #folder + 1) == folder .. "/" then
			out[#out + 1] = path
		end
	end
	assert(#out > 0, "no " .. folder .. " files found")
	return out
end

local builds = {}
local env, K, ns = O.New({
	before = function(e, kit)
		local register = kit.Options.Register
		kit.Options.Register = function(module, schema)
			assert(type(schema) == "function", module .. ": defer options rows with an Options.Register builder")
			builds[module] = 0
			register(module, function()
				builds[module] = builds[module] + 1
				return schema()
			end)
		end
		for _, module in ipairs({ "UnitFrames", "ActionBars", "GroupFrames", "Nameplates", "Skins", "DataBars", "Meters", "Minimap", "Chat", "Bags", "Tooltips", "Auras", "Cooldowns", "CombatText", "QoL" }) do
			Load(ModuleFiles("KstyleUI_" .. module), e)
		end
		for module, count in pairs(builds) do assert(count == 0, module .. ": registering settings must not build their options") end
		kit.Options.Register = register
	end,
})
local Model = ns.Model
for _, option in ipairs(K.Options.Row("ActionBars", "editBar").options) do
	K.Options.Write("ActionBars", option.value .. ".enabled", true)
end

for module, keys in pairs({ Minimap = { "frame" }, Skins = { "restyleAddons" }, Nameplates = { "name.textFormat", "healthText.textFormat", "debuffs.includePlateOnly" } }) do
	for _, key in ipairs(keys) do assert(K.Options.Row(module, key), module .. ": preserve lazily built staging row " .. key) end
end

local function Page(id)
	for _, page in ipairs(ns.Pages.List()) do
		if page.id == id then
			return page
		end
	end
	error("no settings page " .. id)
end

local function OptionValues(module, key)
	local row = assert(K.Options.Row(module, key), module .. " has no " .. key .. " row")
	local options = row.options
	if type(options) == "function" then
		options = options()
	end
	local out = {}
	for i, option in ipairs(options) do
		out[i] = option.value
	end
	assert(#out > 1, module .. "." .. key .. " picks between several values")
	return out
end

-- Reachable(page, module, selector) -> every row key the page shows for some value of the selector,
-- with the label it shows under, and the selector put back as it was.
local function Reachable(page, module, selector)
	local before = K.Options.Read(module, selector)
	local rows, order = {}, {}
	for _, value in ipairs(OptionValues(module, selector)) do
		K.Options.Write(module, selector, value)
		for _, item in ipairs(Model.Visible(Model.PageItems(page))) do
			if item.kind ~= "header" and item.key and item.module == module and not rows[item.key] then
				rows[item.key] = item.label
				order[#order + 1] = item.key
			end
		end
	end
	K.Options.Write(module, selector, before)
	return rows, order
end

local function Found(results, module, key)
	for _, item in ipairs(results or {}) do
		if item.kind ~= "header" and item.module == module and item.key == key then
			return true
		end
	end
	return false
end

local CASES = {
	{ module = "UnitFrames", selector = "edit", sample = { "target.castbarTexture", "focus.portraitStyle", "boss.healthTexture", "pet.enabled" } },
	{ module = "ActionBars", selector = "editBar", sample = { "bar2.size", "bar6.fade", "pet.hotkey", "stance.spacing" } },
}

for _, case in ipairs(CASES) do
	local module, selector = case.module, case.selector
	local page = Page(module)
	local picked = K.Options.Read(module, selector)
	local rows, order = Reachable(page, module, selector)
	for _, key in ipairs(case.sample) do
		assert(rows[key], module .. ": the page can show " .. key .. " when its picker selects it")
	end
	local pages = ns.Pages.List()
	local missing = {}
	for _, key in ipairs(order) do
		if not Found(Model.Search(pages, rows[key]), module, key) then
			missing[#missing + 1] = key
		end
	end
	assert(#missing == 0, module .. ": search for a row's label misses " .. #missing .. " rows, such as " .. table.concat(missing, ", ", 1, math.min(#missing, 5)))
	assert(K.Options.Read(module, selector) == picked, module .. ": search leaves the picker alone")
end

-- A result names its frame or bar in its section header, so equal labels stay apart.
do
	local results = Model.Search(ns.Pages.List(), "cast bar texture")
	local sections = {}
	for _, item in ipairs(results) do
		if item.kind == "header" and item.level == 2 then
			sections[#sections + 1] = item.label
		end
	end
	assert(#sections > 1, "cast bar texture is found for several frames")
	local seen = {}
	for _, label in ipairs(sections) do
		assert(not seen[label], "each frame's cast bar has its own section header, got " .. label .. " twice")
		seen[label] = true
	end
end

for module in pairs(builds) do
	local schema = K.Options.Get(module)
	local found = false
	for _, entry in ipairs(schema) do
		if entry.key and Found(Model.Search(ns.Pages.List(), entry.label), module, entry.key) then found = true; break end
	end
	assert(found, module .. ": search must find lazily built module rows")
	assert(K.Options.Get(module) == schema and builds[module] == 1, module .. ": build and validate options only once")
end

assert(#env._errors == 0, "no errors: " .. tostring(env._errors[1]))
print("options search ok")
