-- test-options-schema-ownership.lua: schema builders leave caching to Options.Get and own their preview.
local failures = {}
local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

for _, path in ipairs({
	"Core/Appearance.lua", "Core/Effects.lua", "Core/Layout/Layout.lua", "Core/Widgets/Base.lua",
	"KstyleUI_Bags/Settings.lua", "KstyleUI_CombatText/Settings.lua", "KstyleUI_Cooldowns/Settings.lua",
	"KstyleUI_DataBars/Settings.lua", "KstyleUI_QoL/Settings.lua",
}) do
	if read(path):match("if%s+[%w_]+%.schema%s+then%s+return%s+[%w_]+%.schema%s+end") then
		failures[#failures + 1] = path .. ": remove the dead memo guard; Options.Get caches this builder's only call"
	end
end

for _, spec in ipairs({
	{ "Bags", "Module", "Settings" }, { "CombatText", "Module", "Settings" },
	{ "Cooldowns", "Module", "Settings" }, { "DataBars", "Module", "ns" },
	{ "Meters", "Meters", "ns" }, { "Minimap", "Module", "Settings" },
	{ "Nameplates", "Module", "Settings" }, { "Tooltips", "Module", "Settings" },
}) do
	local path = "KstyleUI_" .. spec[1] .. "/" .. spec[2] .. ".lua"
	if not read(path):match("K%.Options%.Register%([^,]+,%s*" .. spec[3] .. "%.Schema%)") then
		failures[#failures + 1] = path .. ": register Schema directly and attach its preview inside the schema builder"
	end
end

assert(#failures == 0, table.concat(failures, "\n"))
for _, spec in ipairs({
	{ "Bags", "bags" }, { "CombatText", "combattext" }, { "Cooldowns", "cooldowns" }, { "DataBars", "databars" },
	{ "Meters", "meters" }, { "Minimap", "minimap" }, { "Nameplates", "nameplates" }, { "Tooltips", "tooltips" },
}) do
	local _, K, ns = dofile("Tools/regression/" .. spec[2] .. "_env.lua").New()
	local builder = type(ns.Settings) == "table" and ns.Settings.Schema or ns.Schema
	local preview = type(ns.Preview) == "table" and ns.Preview.Build or ns.Preview
	assert(builder().preview == preview, spec[1] .. ": attach the preview inside Schema before Options.Get is called")
	local schema = K.Options.Get(spec[1])
	assert(K.Options.Get(spec[1]) == schema and K.Options.Preview(spec[1]) == preview,
		spec[1] .. ": Options.Get must cache the schema and preserve its live preview")
	collectgarbage("collect")
end
print("options schema ownership ok: 10 dead memo guards and 8 preview wrappers absent")
