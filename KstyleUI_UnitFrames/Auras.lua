-- Auras.lua: frame auras on the AuraContainer engine, with aura buttons touched only while C_Secrets.ShouldAurasBeSecret says aura data is readable.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings = ns.Settings

local Auras = {}
ns.Auras = Auras

local MODULE = Settings.MODULE
local OWNER = MODULE .. ":auras"
local TEMPLATE = "CustomAuraContainerTemplate"
local ENGINE_ADDON = "Blizzard_AuraContainer"
local GROUPS = { "debuffs", "buffs" }
local FILTERS = {
	mine = { debuffs = "HARMFUL|PLAYER" },
	debuffs = { debuffs = "HARMFUL" },
	buffs = { buffs = "HELPFUL" },
	both = { debuffs = "HARMFUL", buffs = "HELPFUL" },
}
local START_FILTER = { debuffs = "HARMFUL", buffs = "HELPFUL" }
local GROWTH = {
	RIGHT_DOWN = { "TOPLEFT", "Right", "Down" },
	RIGHT_UP = { "BOTTOMLEFT", "Right", "Up" },
	LEFT_DOWN = { "TOPRIGHT", "Left", "Down" },
	LEFT_UP = { "BOTTOMRIGHT", "Left", "Up" },
}
local POSITION = {
	BELOW = { "TOPLEFT", "BOTTOMLEFT", 0, -1, true },
	ABOVE = { "BOTTOMLEFT", "TOPLEFT", 0, 1, true },
	RIGHT = { "TOPLEFT", "TOPRIGHT", 1, 0, false },
	LEFT = { "TOPRIGHT", "TOPLEFT", -1, 0, false },
}
local GAP = 2
local ICON_CROP = 0.07
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local COUNT_INSET = 1

local issecretvalue = issecretvalue or function()
	return false
end

local views = {}
local pending = {}
local waiting = false
local running = false

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

function Auras.Open()
	if InCombatLockdown() then
		return false
	end
	local secrets = C_Secrets
	if secrets and type(secrets.ShouldAurasBeSecret) == "function" then
		local ok, secret = pcall(secrets.ShouldAurasBeSecret)
		if not ok or issecretvalue(secret) then
			return false
		end
		return secret ~= true
	end
	LogOnce("gate", "frame auras: C_Secrets.ShouldAurasBeSecret is missing; aura buttons restyle only out of combat")
	return true
end

local function Value(view, key)
	return Settings.Value(view.kind, key)
end

local function StyleText(text, view)
	local path, size, flags = Settings.Font(view.kind, "aura")
	if text:SetFont(path, size, flags) == false then
		local fallback = Tokens.Font("number")
		text:SetFont(fallback, size, flags)
	end
	if flags == "" then
		text:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		text:SetShadowOffset(offset, -offset)
	else
		text:SetShadowOffset(0, 0)
	end
	pcall(text.SetTextColor, text, Tokens.Color("textEmphasis"))
end

local function StyleButton(view, entry)
	local size = Value(view, "auraSize")
	entry.button:SetSize(size, size)
	local inset = Widgets.Border(entry.skin) * 2
	entry.icon:ClearAllPoints()
	entry.icon:SetPoint("TOPLEFT", entry.skin, "TOPLEFT", inset, -inset)
	entry.icon:SetPoint("BOTTOMRIGHT", entry.skin, "BOTTOMRIGHT", -inset, inset)
	StyleText(entry.count, view)
	StyleText(entry.timer, view)
	entry.timer:SetShown(Value(view, "auraTimer"))
end

local function Dress(view, key, button)
	local skin = CreateFrame("Frame", nil, button)
	skin:SetAllPoints(button)
	local back = skin:CreateTexture(nil, "BACKGROUND")
	back:SetTexture((Tokens.Texture("iconMask")))
	back:SetAllPoints(skin)
	back:SetVertexColor(Tokens.Color("raised"))
	local border = skin:CreateTexture(nil, "BORDER")
	border:SetTexture((Tokens.Texture("iconMask")))
	border:SetAllPoints(skin)
	border:SetVertexColor(Tokens.Color("edgeOuter"))
	local icon = skin:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	local mask = skin:CreateMaskTexture()
	mask:SetTexture((Tokens.Texture("iconMask")), MASK_WRAP, MASK_WRAP)
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	local cooldown = CreateFrame("Cooldown", nil, skin, "CooldownFrameTemplate")
	cooldown:SetAllPoints(icon)
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true)
	local over = CreateFrame("Frame", nil, skin)
	over:SetAllPoints(skin)
	over:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local count = over:CreateFontString(nil, "OVERLAY")
	count:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -COUNT_INSET, -COUNT_INSET)
	local timer = over:CreateFontString(nil, "OVERLAY")
	timer:SetPoint("BOTTOM", skin, "BOTTOM", 0, COUNT_INSET)
	local entry = { button = button, skin = skin, icon = icon, count = count, timer = timer, border = border }
	StyleButton(view, entry)
	button:SetIcon(icon)
	button:SetDurationCooldown(cooldown)
	button:SetApplicationCount(count)
	button:SetDurationText(timer)
	if key == "debuffs" then
		button:AddDispelTypeTexture(border)
	end
	local a = view.auras
	a.buttons[#a.buttons + 1] = entry
end

local function Flush()
	if not Auras.Open() then
		return false
	end
	for view in pairs(pending) do
		pending[view] = nil
		for _, entry in ipairs(view.auras.buttons) do
			K.Call(StyleButton, view, entry)
		end
	end
	return true
end

local function StopWaiting()
	waiting = false
	K.Events.Unregister(OWNER, "PLAYER_REGEN_ENABLED")
	K.Events.Unregister(OWNER, "ADDON_RESTRICTION_STATE_CHANGED")
end

local function OnGate()
	if Flush() then
		StopWaiting()
	end
end

local function Wait(view)
	pending[view] = true
	if waiting then
		return
	end
	waiting = true
	K.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", OnGate)
	pcall(K.Events.Register, OWNER, "ADDON_RESTRICTION_STATE_CHANGED", OnGate)
	Log("frame auras: aura buttons are restricted now; their restyle waits until aura data is readable")
end

local function Restyle(view)
	if view.auras and #view.auras.buttons > 0 then
		pending[view] = true
		if not Flush() then
			Wait(view)
		end
	end
end

local function EngineReady()
	local addons = C_AddOns
	if addons and type(addons.IsAddOnLoaded) == "function" and not addons.IsAddOnLoaded(ENGINE_ADDON) and type(addons.LoadAddOn) == "function" then
		pcall(addons.LoadAddOn, ENGINE_ADDON)
	end
end

local function GroupLayout(view, key)
	local size, spacing = Value(view, "auraSize"), Value(view, "auraSpacing")
	return {
		elementWidth = size,
		elementHeight = size,
		elementSpacing = spacing,
		lineSpacing = spacing,
		forceNewLine = key == "buffs" and Value(view, "auraFilter") == "both",
	}
end

local function Capacity(view)
	return Value(view, "auraRows") * Value(view, "auraColumns")
end

local function MirrorHolder(view, host)
	local holder = view.uf.holder
	hooksecurefunc(holder, "SetAlpha", function(_, alpha)
		host:SetAlpha(alpha)
	end)
	hooksecurefunc(holder, "SetFrameStrata", function(_, strata)
		host:SetFrameStrata(strata)
	end)
	host:SetAlpha(holder:GetAlpha())
	local strata = holder:GetFrameStrata()
	if not issecretvalue(strata) and type(strata) == "string" and strata ~= "" then
		host:SetFrameStrata(strata)
	end
end

local function Build(view)
	local a = { buttons = {} }
	view.auras = a
	views[#views + 1] = view
	local host = CreateFrame("Frame", nil, K.Scale.Root())
	host:Hide()
	a.host = host
	EngineReady()
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, host, TEMPLATE)
	if not ok or type(container) ~= "table" or type(container.AddAuraGroup) ~= "function" then
		a.failed = true
		LogOnce("engine", "frame auras: the AuraContainer engine is not available (" .. tostring(ok and "no " .. TEMPLATE or container) .. "); frames show no auras")
		return a
	end
	a.container = container
	container:SetUnit(view.unit)
	for _, key in ipairs(GROUPS) do
		local added, err = pcall(container.AddAuraGroup, container, key, START_FILTER[key], {
			maxFrameCount = Capacity(view),
			layout = GroupLayout(view, key),
			initializeFrame = function(button)
				K.Call(Dress, view, key, button)
			end,
		})
		if not added then
			a.failed = true
			LogOnce("group", "frame auras: AuraContainer refused a group (" .. tostring(err) .. "); frames show no auras")
			host:Hide()
			return a
		end
	end
	MirrorHolder(view, host)
	LogOnce("built", "frame auras: the AuraContainer engine with " .. #a.buttons .. " buttons ready on the first frame")
	return a
end

local function Wanted(view)
	return running and view.uf.active and Settings.AURAS[view.kind] and Value(view, "auras")
end

local function Visible(frame)
	local shown = frame:IsVisible()
	return issecretvalue(shown) or shown == true
end

function Auras.Sync(view)
	local a = view.auras
	if not (a and a.container) then
		return
	end
	a.host:SetShown(Wanted(view) and Visible(view.button))
end

local function ApplyContainer(view)
	local a = view.auras
	local container = a.container
	local filter = FILTERS[Value(view, "auraFilter")] or FILTERS.mine
	for _, key in ipairs(GROUPS) do
		local on = filter[key] ~= nil
		container:SetAuraGroupEnabled(key, on)
		if on then
			container:SetAuraGroupFilterString(key, filter[key])
		end
		container:SetAuraGroupLayout(key, GroupLayout(view, key))
		container:SetAuraGroupMaxFrameCount(key, Capacity(view))
	end
	local width, height, corner, line = Auras.Footprint(view.kind)
	local growth = GROWTH[Value(view, "auraGrowth")] or GROWTH.RIGHT_DOWN
	local directions = AnchorUtil and AnchorUtil.FlowDirection
	container:SetFlowLayoutAnchorPoint(corner)
	if directions then
		container:SetFlowLayoutGrowthDirection(directions[growth[2]], directions[growth[3]])
	end
	container:SetFlowLayoutMaximumLineSize(line)
	a.host:SetSize(width, height)
	container:ClearAllPoints()
	container:SetPoint(corner, a.host, corner, 0, 0)
	Auras.Place(view)
end

function Auras.Footprint(kind)
	local size, spacing = Settings.Value(kind, "auraSize"), Settings.Value(kind, "auraSpacing")
	local columns = Settings.Value(kind, "auraColumns")
	local filter = FILTERS[Settings.Value(kind, "auraFilter")] or FILTERS.mine
	local groups = filter.debuffs and filter.buffs and 2 or 1
	local rows = Settings.Value(kind, "auraRows") * groups
	local line = columns * size + (columns - 1) * spacing
	local growth = GROWTH[Settings.Value(kind, "auraGrowth")] or GROWTH.RIGHT_DOWN
	return math.max(1, line), math.max(1, rows * size + (rows - 1) * spacing), growth[1], line, growth
end

function Auras.Anchor(host, frame, kind, panelX)
	local position = POSITION[Settings.Value(kind, "auraPosition")] or POSITION.BELOW
	local x = position[5] and panelX or 0
	host:ClearAllPoints()
	host:SetPoint(position[1], frame, position[2], x + position[3] * GAP, position[4] * GAP)
end

function Auras.Place(view)
	local a = view.auras
	if a and a.container then
		Auras.Anchor(a.host, view.button, view.kind, view.geometry and view.geometry.panel.x or 0)
	end
end

function Auras.Apply(view)
	if not Settings.AURAS[view.kind] then
		return
	end
	local want = Wanted(view)
	if not view.auras then
		if not want then
			return
		end
		Build(view)
	end
	local a = view.auras
	if a.failed then
		return
	end
	a.container:SetEnabled(want and true or false)
	if want then
		K.Call(ApplyContainer, view)
		Restyle(view)
	end
	Auras.Sync(view)
end

function Auras.Enable()
	running = true
end

function Auras.Disable()
	running = false
	for _, view in ipairs(views) do
		local a = view.auras
		if a.container then
			a.container:SetEnabled(false)
			a.host:Hide()
		end
	end
	pending = {}
	StopWaiting()
end
