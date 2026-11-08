-- Icons.lua: maps a game icon file ID to a custom texture and tint for the active icon set.
local _, ns = ...

local Icons = {}
ns.Icons = Icons

local L = ns.L
local floor, min, max = math.floor, math.min, math.max

local MODULE = "Icons"
local ADDONS = { A = "KstyleUI_Icons", B = "KstyleUI_IconsColour" }
local TINTS = { class = true, school = true, white = true }
local HIGHLIGHT_MAX = 0.6
local HIGHLIGHT_STEP = 0.05
local MAX_SUBLEVEL = 7
local SCHOOL_ORDER = {
	{ mask = 2, token = "schoolHoly" },
	{ mask = 4, token = "schoolFire" },
	{ mask = 8, token = "schoolNature" },
	{ mask = 16, token = "schoolFrost" },
	{ mask = 32, token = "schoolShadow" },
	{ mask = 64, token = "schoolArcane" },
	{ mask = 1, token = "schoolPhysical" },
}

local defaults = { enabled = false, set = "B", tint = "class", highlight = 0.25 }

local cache = {}
local active, activeSet, lastProblem
local state = setmetatable({}, { __mode = "k" })
local own = false

local function isSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function isNumber(value)
	return not isSecret(value) and type(value) == "number"
end

local function log(message)
	ns.DevTest.Log(MODULE, message)
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

local function setting(key)
	local Store = ns.Store
	local value = Store.IsLoaded() and Store.Module(MODULE)[key]
	if key == "set" then
		return ADDONS[value] and value or defaults.set
	elseif key == "tint" then
		return TINTS[value] and value or defaults.tint
	end
	if type(value) ~= "number" or value ~= value then
		return defaults.highlight
	end
	return max(0, min(HIGHLIGHT_MAX, value))
end

local function readData(set)
	local data = _G.KstyleUIIconData
	if type(data) ~= "table" or data.set ~= set or type(data.icons) ~= "table" then
		return nil
	end
	cache[set] = data
	return data
end

local function load(set)
	local data = cache[set] or readData(set)
	if data then
		return data
	end
	local AddOns = C_AddOns
	if not (AddOns and type(AddOns.LoadAddOn) == "function") then
		return nil, "C_AddOns.LoadAddOn is missing"
	end
	local addon = ADDONS[set]
	local ok, loaded, reason = pcall(AddOns.LoadAddOn, addon)
	if not ok or not loaded then
		return nil, "LoadAddOn(" .. addon .. ") failed: " .. tostring(ok and reason or loaded)
	end
	data = readData(set)
	if not data then
		return nil, addon .. " loaded but its KstyleUIIconData is missing or not set " .. set
	end
	log("set " .. set .. ": loaded " .. addon .. " with " .. count(data.icons) .. " icons")
	return data
end

local function activate()
	local set = setting("set")
	local data, problem = load(set)
	active, activeSet, lastProblem = data, data and set or nil, problem
	if problem then
		log("set " .. set .. ": " .. problem .. "; Blizzard icons stay")
	end
end

local function schoolToken(mask)
	if isSecret(mask) or type(mask) ~= "number" or mask ~= mask or mask <= 0 then
		return nil
	end
	for _, school in ipairs(SCHOOL_ORDER) do
		if floor(mask / school.mask) % 2 == 1 then
			return school.token
		end
	end
end

local function tintColor(school)
	local mode = setting("tint")
	local token = mode == "white" and "white" or (mode == "school" and schoolToken(school))
	if token then
		local r, g, b = ns.Tokens.Color(token)
		return r, g, b
	end
	return ns.Theme.Accent()
end

local function syncCopy(texture)
	local st = state[texture]
	local copy = st and st.copy
	if not copy then
		return
	end
	if st.glow > 0 then
		local shown = texture:IsShown()
		if isSecret(shown) then
			copy:Show()
		else
			copy:SetShown(shown == true)
		end
	else
		copy:Hide()
	end
end

local function syncGlow(texture)
	local st = state[texture]
	if st.glow > 0 then
		local alpha = texture:GetAlpha()
		st.copy:SetVertexColor(st.dimR, st.dimG, st.dimB, st.glow * (isNumber(alpha) and alpha or 1))
	end
end

local function syncCrop(texture)
	state[texture].copy:SetTexCoord(texture:GetTexCoord())
end

local function addMask(texture, mask)
	state[texture].copy:AddMaskTexture(mask)
end

local function removeMask(texture, mask)
	local copy = state[texture].copy
	pcall(copy.RemoveMaskTexture, copy, mask)
end

local function makeCopy(texture, st)
	local parent = texture:GetParent()
	if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
		return nil
	end
	local layer, sublevel = texture:GetDrawLayer()
	if isSecret(layer) or type(layer) ~= "string" then
		layer = "ARTWORK"
	end
	if isSecret(sublevel) or type(sublevel) ~= "number" then
		sublevel = 0
	end
	local copy = parent:CreateTexture(nil, layer, nil, min(sublevel + 1, MAX_SUBLEVEL))
	copy:SetAllPoints(texture)
	copy:SetBlendMode("ADD")
	local masks = texture:GetNumMaskTextures()
	if not isSecret(masks) and type(masks) == "number" then
		for i = 1, masks do
			local mask = texture:GetMaskTexture(i)
			if mask then
				copy:AddMaskTexture(mask)
			end
		end
	end
	st.copy = copy
	syncCrop(texture)
	if type(hooksecurefunc) == "function" then
		hooksecurefunc(texture, "Show", syncCopy)
		hooksecurefunc(texture, "Hide", syncCopy)
		hooksecurefunc(texture, "SetShown", syncCopy)
		hooksecurefunc(texture, "SetAlpha", syncGlow)
		hooksecurefunc(texture, "SetTexCoord", syncCrop)
		hooksecurefunc(texture, "AddMaskTexture", addMask)
		hooksecurefunc(texture, "RemoveMaskTexture", removeMask)
	end
	return copy
end

local function entry(texture)
	local st = state[texture]
	if not st then
		st = { dimR = 1, dimG = 1, dimB = 1, glow = 0 }
		state[texture] = st
	end
	return st
end

local function draw(texture, st)
	local tr, tg, tb, glow = 1, 1, 1, 0
	if st.custom and st.set == "A" then
		tr, tg, tb = tintColor(st.school)
		glow = setting("highlight")
	end
	own = true
	if st.desat ~= nil then
		texture:SetDesaturated(st.desat)
	end
	texture:SetVertexColor(tr * st.dimR, tg * st.dimG, tb * st.dimB, select(4, texture:GetVertexColor()))
	own = false
	st.glow = glow
	local copy = st.copy
	if glow > 0 and not copy then
		copy = makeCopy(texture, st)
	end
	if not copy then
		return
	end
	if glow > 0 then
		if st.copyPath ~= st.path then
			copy:SetTexture(st.path)
			st.copyPath = st.path
		end
		copy:SetDesaturated(st.desat == true)
		syncGlow(texture)
	end
	syncCopy(texture)
end

local function repaint()
	for texture, st in pairs(state) do
		if st.custom then
			draw(texture, st)
		end
	end
end

function Icons.Resolve(fileID)
	if active == nil or isSecret(fileID) or type(fileID) ~= "number" then
		return nil
	end
	local path = active.icons[fileID]
	if type(path) == "string" then
		return path
	end
	return nil
end

function Icons.Apply(texture, fileID, school)
	if texture == nil then
		return false
	end
	local st = entry(texture)
	local path = Icons.Resolve(fileID)
	own = true
	if path then
		texture:SetTexture(path)
		if isSecret(school) or type(school) ~= "number" then
			local schools = active.schools
			school = type(schools) == "table" and schools[fileID] or nil
		end
		st.custom, st.set, st.path, st.school = true, activeSet, path, school
	else
		texture:SetTexture(fileID)
		st.custom, st.set, st.path, st.school = false, nil, nil, nil
	end
	own = false
	draw(texture, st)
	return path ~= nil
end

function Icons.Shade(texture, r, g, b, desaturated)
	if texture == nil then
		return
	end
	local st = entry(texture)
	st.dimR, st.dimG, st.dimB = r or 1, g or r or 1, b or r or 1
	if desaturated ~= nil then
		st.desat = desaturated == true
	end
	draw(texture, st)
end

function Icons.Reset(texture)
	local st = texture and state[texture]
	if st and st.custom then
		st.custom, st.set, st.path, st.school = false, nil, nil, nil
		draw(texture, st)
	end
end

local function follow(texture, fileID)
	local st = state[texture]
	st.file = fileID
	if st.custom or Icons.Resolve(fileID) then
		Icons.Apply(texture, fileID)
	end
end

local function onSetTexture(texture, fileID)
	if not own then
		follow(texture, fileID)
	end
end

local function onVertexColor(texture, r, g, b)
	if own or not (isNumber(r) and isNumber(g) and isNumber(b)) then
		return
	end
	local st = state[texture]
	st.dimR, st.dimG, st.dimB = r, g, b
	if st.custom then
		draw(texture, st)
	end
end

local function onAtlas(texture)
	if not own then
		state[texture].file = nil
		Icons.Reset(texture)
	end
end

function Icons.Watch(texture)
	if type(texture) ~= "table" or type(texture.GetTextureFileID) ~= "function" or type(hooksecurefunc) ~= "function" then
		return false
	end
	local st = entry(texture)
	if not st.watched then
		st.watched = true
		onVertexColor(texture, texture:GetVertexColor())
		hooksecurefunc(texture, "SetTexture", onSetTexture)
		hooksecurefunc(texture, "SetVertexColor", onVertexColor)
		hooksecurefunc(texture, "SetAtlas", onAtlas)
		follow(texture, texture:GetTextureFileID())
	end
	return true
end

local function changed()
	for texture, st in pairs(state) do
		if st.watched then
			follow(texture, st.file)
		end
	end
	ns.Callbacks.Fire("IconsChanged")
end

function Icons.SchoolColor(mask)
	local token = schoolToken(mask)
	if token then
		local r, g, b = ns.Tokens.Color(token)
		return r, g, b
	end
end

function Icons.ActiveSet()
	return activeSet
end

local function onSetting(_, module, key)
	if module ~= MODULE then
		return
	end
	if key == "set" then
		activate()
	elseif key ~= "tint" and key ~= "highlight" then
		return
	end
	repaint()
	changed()
end

local function onTheme()
	if setting("tint") ~= "white" then
		repaint()
	end
end

local function onProfile()
	activate()
	repaint()
	changed()
end

local function Enable()
	activate()
	ns.Callbacks.Register("SettingChanged", MODULE, onSetting)
	ns.Callbacks.Register("ThemeChanged", MODULE, onTheme)
	ns.Callbacks.Register("ProfileChanged", MODULE, onProfile)
	changed()
end

local function Disable()
	active, activeSet = nil, nil
	changed()
end

local function isOff(settings)
	return not settings.enabled
end

local function setA(settings)
	return settings.set == "A"
end

local schema = {
	{ type = "header", label = L["Custom icons"] },
	{ type = "toggle", key = "enabled", label = L["Custom icons"], help = L["Show KstyleUI's own ability icons instead of Blizzard's."] },
	{
		type = "dropdown", key = "set", label = L["Icon set"], help = L["Light art tinted in game, or full-colour painted art."], disableWhen = isOff,
		options = { { value = "A", label = L["Light art, tinted"] }, { value = "B", label = L["Full colour"] } },
	},
	{
		type = "dropdown", key = "tint", label = L["Tint"], help = L["The colour that tints the light icons."], showWhen = setA, disableWhen = isOff,
		options = { { value = "class", label = L["Class colour"] }, { value = "school", label = L["Spell school colour"] }, { value = "white", label = L["White"] } },
	},
	{
		type = "slider", key = "highlight", label = L["Highlight glow"], help = L["How brightly the highlights of the light icons glow."],
		min = 0, max = HIGHLIGHT_MAX, step = HIGHLIGHT_STEP, showWhen = setA, disableWhen = isOff,
	},
}

Icons.defaults, Icons.schema = defaults, schema

ns.Modules.Register({ name = MODULE, defaults = defaults, Enable = Enable, Disable = Disable })
ns.Options.Register(MODULE, schema)

ns.DevTest.AddCheck("icons", function()
	if not ns.Modules.IsRunning(MODULE) then
		return true, "off: Blizzard icons"
	end
	if not active then
		return false, "set " .. setting("set") .. " did not load: " .. tostring(lastProblem)
	end
	return true, "set " .. activeSet .. ": " .. count(active.icons) .. " icons, tint " .. setting("tint")
end)
