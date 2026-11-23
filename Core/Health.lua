-- Health.lua: each KstyleUI folder's load state, one calm notice per problem after login, and the copyable status report with no personal data.
local _, K = ...
local L = K.L
local Health = {}
K.Health = Health

local LINK = "https://www.curseforge.com/wow/addons/kstyleui"
local EXTRA = { { name = "Options", label = L["Settings window"] }, { name = "Routes", label = L["World map routes"] } }
local FIX = { disabled = "enable", reload = "reload", error = "reload", missing = "update", outdated = "update", failed = "update" }
local TEXT = {
	running = L["Running"], off = L["Off"], ondemand = L["Loads when opened"], unknown = L["Not loaded"], disabled = L["Turned off in the AddOn list"],
	reload = L["Waiting for a reload"], error = L["Hit an error while loading"], missing = L["Missing"], outdated = L["Not the same version as KstyleUI"],
	on = L["On"], absent = L["Not running"],
}
local SAY = {
	enable = L["Turn them back on and reload to finish."],
	reload = L["A reload usually loads them again."],
	update = L["Update KstyleUI from the link below so every part matches, then restart the game."],
}
local TRACKER = { kstyleui = L["Use KstyleUI's quest card"], questie = L["Use Questie's quest tracker"], both = L["Show both quest trackers"] }
local shown, checked = {}, false

local function Clean(ok, ...)
	if not ok then return end
	local out, n = { ... }, select("#", ...)
	for i = 1, n do
		if K.Widgets.IsSecret(out[i]) then out[i] = nil end
	end
	return unpack(out, 1, n)
end

local function Ask(fn, ...)
	local api = C_AddOns
	if type(api) == "table" and type(api[fn]) == "function" then return Clean(pcall(api[fn], ...)) end
end

local function State(entry, registered)
	local folder = "KstyleUI_" .. entry.name
	if Ask("DoesAddOnExist", folder) == false then return "missing" end
	if Ask("IsAddOnLoaded", folder) == true then
		local version = Ask("GetAddOnMetadata", folder, "Version")
		if type(version) == "string" and version ~= K.VERSION then return "outdated", version end
		local failed, err = K.Modules.HasFailed(entry.name)
		if failed or Ask("DoesAddOnHaveLoadError", folder) == true or entry.module and not registered[entry.name] then return "error", err end
		return entry.module and not K.Modules.IsEnabled(entry.name) and "off" or "running"
	end
	local _, _, _, loadable, reason = Ask("GetAddOnInfo", folder)
	if reason == "DISABLED" or reason == "MISSING" then return reason:lower() end
	if reason == "DEMAND_LOADED" or reason == "DEP_DEMAND_LOADED" then return "ondemand" end
	if type(reason) == "string" and reason ~= "" then return "failed", reason end
	if Ask("IsAddOnLoadOnDemand", folder) == true then return "ondemand" end
	return loadable == true and "reload" or "unknown"
end

function Health.Modules()
	local registered, rows = {}, {}
	for _, name in ipairs(K.Modules.List()) do registered[name] = true end
	local entries = {}
	for _, entry in ipairs(K.Setup.PICKER) do entries[#entries + 1] = { name = entry.name, label = entry.label, module = true } end
	for _, entry in ipairs(EXTRA) do entries[#entries + 1] = entry end
	for _, entry in ipairs(entries) do
		local state, detail = State(entry, registered)
		rows[#rows + 1] = { name = entry.name, label = entry.label, state = state, detail = detail }
	end
	return rows
end

function Health.Text(row)
	if row.state ~= "failed" then return TEXT[row.state] end
	local reason = rawget(_G, "ADDON_" .. row.detail)
	return string.format(L["Did not load: %s"], type(reason) == "string" and reason or row.detail)
end

function Health.Facts()
	local facts = {}
	local function add(key, label, code, text, addons)
		facts[#facts + 1] = { key = key, label = label, code = code, text = text or TEXT[code] or code, addons = addons }
	end
	local version, build = Clean(pcall(GetBuildInfo))
	add("game", L["Game build"], type(version) == "string" and version .. "." .. tostring(build) or "?")
	local style = K.HudStyle.Current()
	add("hud", L["HUD style"], style, style == "frames" and L["Frames"] or L["Medallions"])
	local profile = K.Store.ProfileName()
	add("profile", L["Profile"], profile == "Default" and "default" or "custom", profile)
	local scale, auto = K.Scale.AppliedUserScale() or 1, K.Scale.IsAuto()
	add("scale", L["Scale"], string.format("%.2f%s", scale, auto and " auto" or ""), string.format("%.2f", scale) .. (auto and ", " .. L["Automatic"] or ""))
	local width, height = Clean(pcall(GetPhysicalScreenSize))
	add("screen", L["Screen"], tostring(width) .. "x" .. tostring(height))
	local I, byAddon, names = K.Setup.Integrations, {}, {}
	for _, entry in ipairs(K.Setup.PICKER) do
		for _, addon in ipairs(I.Detected(entry.name)) do
			if not byAddon[addon] then byAddon[addon], names[#names + 1] = {}, addon end
			table.insert(byAddon[addon], entry)
		end
	end
	local texts, codes = {}, {}
	for i, addon in ipairs(names) do
		local labels, keys = {}, {}
		for j, entry in ipairs(byAddon[addon]) do labels[j], keys[j] = entry.label, entry.name end
		texts[i], codes[i] = addon .. " (" .. table.concat(labels, ", ") .. ")", addon .. " " .. table.concat(keys, "+")
	end
	add("overlaps", L["Overlapping addons"], #codes > 0 and table.concat(codes, ", ") or "none", #texts > 0 and table.concat(texts, ", ") or L["None"], true)
	local skinsOn = K.Modules.IsEnabled("Skins")
	for _, def in ipairs(I.Skins and I.Skins() or {}) do
		if def.addon and not def.addon:match("^Blizzard_") then
			local saved = K.Store.Module("Skins")[def.key]
			add(def.key, def.label, not I.Loaded(def.addon) and "absent" or skinsOn and not (type(saved) == "table" and saved.enabled == false) and "on" or "off", nil, true)
		end
	end
	local config = K.Store.Module("Integrations")
	if I.Loaded("Leatrix_Plus") then
		local handled = {}
		for toggle in pairs(config.leatrix) do handled[#handled + 1] = toggle end
		table.sort(handled)
		add("leatrix", "Leatrix Plus", #handled > 0 and table.concat(handled, "+") or "on", #handled > 0 and table.concat(handled, ", ") or L["On"], true)
	end
	if I.Loaded("Questie") then
		local tracker = I.QuestTracker()
		add("questTracker", L["Quest tracker"], tracker, TRACKER[tracker], true)
	end
	for _, lane in ipairs({ { "timerLane", L["Boss timer lane"] }, { "announcementLane", L["Announcement lane"] }, { "weakAuras", L["WeakAuras anchors"] } }) do
		add(lane[1], lane[2], config[lane[1]] and "on" or "off", nil, true)
	end
	return facts
end

function Health.Report()
	local modules = {}
	for _, row in ipairs(Health.Modules()) do
		local detail = row.detail and " " .. tostring(row.detail):gsub("[\r\n|]", " "):sub(1, 120) or ""
		modules[#modules + 1] = row.name .. " " .. row.state .. detail
	end
	local parts = { "KstyleUI " .. tostring(K.VERSION), "modules: " .. table.concat(modules, ", ") }
	for _, fact in ipairs(Health.Facts()) do parts[#parts + 1] = fact.key .. " " .. fact.code end
	parts[#parts + 1] = "errors " .. K.ErrorCount()
	return table.concat(parts, " | ")
end

function Health.Check()
	checked = true
	if not K.Store.IsLoaded() or K.Store.Account().healthChecks == false then return end
	local lines, fixes, disabled = {}, {}, {}
	for _, row in ipairs(Health.Modules()) do
		local fix, key = FIX[row.state], row.name .. "." .. row.state
		if fix and not shown[key] then
			shown[key], fixes[fix] = true, true
			lines[#lines + 1] = row.label .. ": " .. Health.Text(row)
			if row.state == "disabled" then disabled[#disabled + 1] = "KstyleUI_" .. row.name end
		end
	end
	if #lines == 0 then return end
	lines[#lines + 1] = ""
	for _, fix in ipairs({ "enable", "reload", "update" }) do
		if fixes[fix] then lines[#lines + 1] = SAY[fix] end
	end
	local primary = fixes.enable and L["Turn on and reload"] or fixes.reload and L["Reload now"]
	K.Widgets.Popup({
		key = "Health.Notice",
		title = L["Part of KstyleUI did not load"],
		text = table.concat(lines, "\n"),
		editBox = fixes.update and { text = LINK } or nil,
		buttons = primary and { { label = L["Later"] }, { label = primary, primary = true, reload = true, onClick = function()
			for _, folder in ipairs(disabled) do Ask("EnableAddOn", folder) end
		end } } or { { label = L["Close"], primary = true } },
	})
end

K.Events.Register("Health", "PLAYER_LOGIN", function()
	K.Events.Unregister("Health", "PLAYER_LOGIN")
	C_Timer.After(5, Health.Check)
end)

K.Callbacks.Register("ModuleChanged", "Health", function(_, name, on)
	if checked and not on and K.Modules.HasFailed(name) then Health.Check() end
end)
