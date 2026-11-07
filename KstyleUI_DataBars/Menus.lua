-- Menus.lua: the micro menu and the bag bar restyled in place with the Skin helpers: Blizzard's art faded, glass and tiles on KstyleUI's own child frames.
local _, ns = ...

local K, L = ns.K, ns.L
local Skin, Widgets = K.Skin, K.Widgets

local Menus = {}
ns.Menus = Menus

local MENU_PAD = 4
local MICRO_TILE_INSET = 2
local BAG_TILE_INSET = -2
local TINTS = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }

local GROUPS = {
	micro = {
		frame = "MicroMenu",
		buttons = {
			"CharacterMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton", "SpellbookMicroButton", "TalentMicroButton",
			"AchievementMicroButton", "LegacyMicroButton", "QuestLogMicroButton", "HousingMicroButton", "GuildMicroButton",
			"LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "HelpMicroButton", "StoreMicroButton", "MainMenuMicroButton",
		},
		tileInset = MICRO_TILE_INSET,
		reload = L["Blizzard's micro menu art comes back after a reload."],
	},
	bags = {
		frame = "BagsBar",
		buttons = {
			"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
			"CharacterReagentBag0Slot", "KeyRingButton",
		},
		tileInset = BAG_TILE_INSET,
		reload = L["Blizzard's bag bar art comes back after a reload."],
	},
}
Menus.GROUPS = GROUPS

local applied = {}
local hover = setmetatable({}, { __mode = "k" })
local originalTint = setmetatable({}, { __mode = "k" })
local running = false

local function Frame(name)
	local frame = _G[name]
	if type(frame) == "table" and type(frame.GetObjectType) == "function" then
		return frame
	end
	return nil
end

local function Buttons(group)
	local out = {}
	for _, name in ipairs(group.buttons) do
		local button = Frame(name)
		if button then
			out[#out + 1] = button
		end
	end
	return out
end

local function IsTexture(region)
	return type(region) == "table" and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

local function Art(id, buttons)
	local out = {}
	for _, button in ipairs(buttons) do
		if id == "micro" then
			for _, key in ipairs({ "Background", "PushedBackground" }) do
				if IsTexture(button[key]) then
					out[#out + 1] = button[key]
				end
			end
		else
			for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
				local texture = type(button[getter]) == "function" and button[getter](button) or nil
				if IsTexture(texture) then
					out[#out + 1] = texture
				end
			end
		end
	end
	return out
end

local function PaintEdge(state)
	local parts = Skin.Parts(state.button)
	local panel = parts and parts.backdrop
	if panel and panel.chrome then
		local r, g, b = ns.Accent()
		local er, eg, eb, ea = Widgets.Rgba("edgeInner")
		panel.chrome:SetEdgeRGBA(Widgets.Mix(er, eg, eb, ea, r, g, b, 1, state.hoverT or 0))
	end
end

local function OnEnter(button)
	local state = hover[button]
	if state and running then
		Widgets.Hover(state, true)
	end
end

local function OnLeave(button)
	local state = hover[button]
	if state then
		Widgets.Hover(state, false)
	end
end

local function Watch(button)
	if hover[button] then
		return
	end
	hover[button] = { button = button, Paint = PaintEdge }
	button:HookScript("OnEnter", OnEnter)
	button:HookScript("OnLeave", OnLeave)
end

local function Apply(id)
	if applied[id] then
		return true
	end
	local group = GROUPS[id]
	local frame = Frame(group.frame)
	if not frame then
		ns.LogOnce("menus-missing:" .. id, group.frame .. " is missing; it keeps Blizzard's look")
		return false
	end
	local buttons = Buttons(group)
	Skin.Strip(frame, { watch = false, children = Art(id, buttons) })
	Skin.Backdrop(frame, { shape = "panel", fill = "surface", inset = -MENU_PAD })
	for _, button in ipairs(buttons) do
		Watch(button)
	end
	applied[id] = true
	ns.Log(group.frame .. " restyled in place: " .. #buttons .. " buttons")
	return true
end

local function SetShown(frame, shown)
	local parts = frame and Skin.Parts(frame)
	local panel = parts and parts.backdrop
	if panel then
		panel:SetShown(shown)
	end
end

local function Tint(button, tint)
	for _, getter in ipairs(TINTS) do
		local texture = type(button[getter]) == "function" and button[getter](button) or nil
		if IsTexture(texture) then
			if tint == "none" then
				local original = originalTint[texture]
				if original then
					texture:SetDesaturation(original[5])
					texture:SetVertexColor(original[1], original[2], original[3], original[4])
					originalTint[texture] = nil
				end
			else
				if not originalTint[texture] then
					local r, g, b, a = texture:GetVertexColor()
					local desaturation = texture:GetDesaturation()
					originalTint[texture] = {
						ns.IsNumber(r) and r or 1, ns.IsNumber(g) and g or 1, ns.IsNumber(b) and b or 1, ns.IsNumber(a) and a or 1,
						ns.IsNumber(desaturation) and desaturation or 0,
					}
				end
				texture:SetDesaturation(1)
				if tint == "accent" then
					texture:SetVertexColor(ns.Accent())
				else
					texture:SetVertexColor(Widgets.Rgba("white"))
				end
			end
		end
	end
end

local function Paint(id)
	if not applied[id] then
		return
	end
	local group, s = GROUPS[id], ns.Settings()[id]
	local on = running and s.skin
	SetShown(Frame(group.frame), on and s.backdrop)
	for _, button in ipairs(Buttons(group)) do
		if on and s.tiles then
			Skin.Backdrop(button, { shape = "tile", fill = "raised", shadow = false, inset = group.tileInset })
			PaintEdge(hover[button])
		end
		SetShown(button, on and s.tiles == true)
		if s.tint then
			Tint(button, on and s.tint or "none")
		end
	end
end

local function Sync(id)
	local s = ns.Settings()[id]
	if running and s.skin then
		Apply(id)
	end
	Paint(id)
end

function Menus.Enable()
	running = true
	for id in pairs(GROUPS) do
		Sync(id)
	end
end

function Menus.Disable()
	running = false
	for id in pairs(GROUPS) do
		Paint(id)
	end
end

function Menus.Setting(key)
	local id, field = key:match("^(%a+)%.(.+)$")
	if key == "accentSource" or key == "accentColor" then
		for groupId in pairs(GROUPS) do
			Paint(groupId)
		end
		return
	end
	if not GROUPS[id] then
		return
	end
	Sync(id)
	if field == "skin" and applied[id] and not ns.Settings()[id].skin then
		Widgets.ReloadPrompt(GROUPS[id].reload)
	end
end

function Menus.IsApplied(id)
	return applied[id] == true
end

ns.AddPart({
	Enable = Menus.Enable,
	Disable = Menus.Disable,
	Setting = Menus.Setting,
	Refresh = function()
		for id in pairs(GROUPS) do
			Sync(id)
		end
	end,
})
