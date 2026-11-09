-- ClickCast.lua: the settings page's click casting panel: the game's Click Casting bindings listed, removed and added through C_ClickBindings, out of combat.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Unit, Style = ns.Unit, ns.Style

local ClickCast = {}
ns.ClickCast = ClickCast

local ROWS = 3
local CAP = 20
local HELP = 44
local MORE = 16
local ROW_HEIGHT = 20
local ICON = 16
local BUTTON_HEIGHT = 24
local PLUS = " + "
local BUTTON_NAMES = {
	LeftButton = "LEFT_BUTTON_STRING", RightButton = "RIGHT_BUTTON_STRING", MiddleButton = "MIDDLE_BUTTON_STRING",
	Button4 = "BUTTON_4_STRING", Button5 = "BUTTON_5_STRING",
}
local INTERACT_ICONS = { [1] = 132212, [2] = 134331 }

local function Api()
	local api = C_ClickBindings
	local kinds = Enum and Enum.ClickBindingType
	if type(api) == "table" and type(api.GetProfileInfo) == "function" and type(api.SetProfileByInfo) == "function" and kinds then
		return api, kinds
	end
end

function ClickCast.Available()
	return Api() ~= nil
end

local function Plain(v)
	return not Unit.IsSecret(v)
end

function ClickCast.Profile()
	local api = Api()
	if not api then
		return nil
	end
	local ok, list = pcall(api.GetProfileInfo)
	if not ok or type(list) ~= "table" then
		return nil
	end
	local out = {}
	for _, info in ipairs(list) do
		if type(info) == "table" and Plain(info.type) and Plain(info.actionID) and Plain(info.button) and Plain(info.modifiers) then
			out[#out + 1] = { type = info.type, actionID = info.actionID, button = info.button, modifiers = info.modifiers }
		end
	end
	return out
end

local function ButtonText(button)
	local global = BUTTON_NAMES[button]
	local text = global and _G[global]
	if type(text) == "string" then
		return text
	end
	return tostring(button)
end

function ClickCast.KeyText(info)
	local mods = ""
	if type(GetStringFromModifiers) == "function" and type(info.modifiers) == "number" then
		local ok, text = pcall(GetStringFromModifiers, info.modifiers)
		if ok and type(text) == "string" then
			mods = text
		end
	end
	if mods ~= "" then
		return mods .. PLUS .. ButtonText(info.button)
	end
	return ButtonText(info.button)
end

function ClickCast.Describe(info)
	local _, kinds = Api()
	if not kinds then
		return "", nil
	end
	if info.type == kinds.Spell or info.type == kinds.PetAction then
		local spell = C_Spell
		local name = spell and spell.GetSpellName and spell.GetSpellName(info.actionID)
		local icon = spell and spell.GetSpellTexture and spell.GetSpellTexture(info.actionID)
		return type(name) == "string" and name or tostring(info.actionID), icon
	elseif info.type == kinds.Macro and type(GetMacroInfo) == "function" then
		local name, icon = GetMacroInfo(info.actionID)
		return type(name) == "string" and name or L["Macro"], icon
	elseif info.type == kinds.Interaction then
		local interaction = Enum.ClickBindingInteraction
		local target = interaction and interaction.Target or 1
		return info.actionID == target and L["Target the member"] or L["Open the member's menu"], INTERACT_ICONS[info.actionID]
	end
	return "", nil
end

local function Save(profile)
	if InCombatLockdown() then
		return false, L["Change click casting after combat."]
	end
	local api = Api()
	if not api then
		return false, L["This client has no Click Casting."]
	end
	local ok, err = pcall(api.SetProfileByInfo, profile)
	if not ok then
		Style.LogOnce("clickSave", "C_ClickBindings.SetProfileByInfo refused the profile: " .. tostring(err))
		return false, L["The game refused the binding."]
	end
	return true
end

function ClickCast.Remove(index)
	local profile = ClickCast.Profile()
	if not profile or not profile[index] then
		return false
	end
	table.remove(profile, index)
	return Save(profile)
end

function ClickCast.Add(kind, actionID, button, modifiers)
	local profile = ClickCast.Profile()
	if not profile then
		return false, L["This client has no Click Casting."]
	end
	local kept = {}
	for _, info in ipairs(profile) do
		if not (info.button == button and info.modifiers == modifiers) then
			kept[#kept + 1] = info
		end
	end
	kept[#kept + 1] = { type = kind, actionID = actionID, button = button, modifiers = modifiers }
	return Save(kept)
end

function ClickCast.FromCursor()
	local api, kinds = Api()
	if not api or type(GetCursorInfo) ~= "function" then
		return nil
	end
	local cursor, info1, _, info3 = GetCursorInfo()
	if cursor == "spell" or cursor == "petaction" then
		local spellID = cursor == "spell" and info3 or info1
		local can = type(api.CanSpellBeClickBound) ~= "function" or api.CanSpellBeClickBound(spellID)
		if Plain(can) and can and Plain(spellID) then
			return cursor == "spell" and kinds.Spell or kinds.PetAction, spellID
		end
	elseif cursor == "macro" and Plain(info1) then
		return kinds.Macro, info1
	end
	return nil
end

function ClickCast.Open()
	if InCombatLockdown() then
		return false
	end
	if type(ToggleClickBindingFrame) == "function" then
		ToggleClickBindingFrame()
		return true
	end
	Style.LogOnce("clickFrame", "ToggleClickBindingFrame is missing; the game's Click Casting window cannot open from here")
	return false
end

local function Modifiers()
	if type(MakeModifiers) == "function" then
		local ok, mods = pcall(MakeModifiers)
		if ok and type(mods) == "number" then
			return mods
		end
	end
	return 0
end

local function Row(panel)
	local row = CreateFrame("Frame", nil, panel)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON, ICON)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.key = Widgets.Text(row, "caption", "textEmphasis")
	row.key:SetPoint("LEFT", row.icon, "RIGHT", Tokens.Size("gapSmall"), 0)
	row.name = Widgets.Text(row, "caption", "text")
	row.name:SetWordWrap(false)
	row.remove = Widgets.CloseButton(row, function()
		local ok, err = ClickCast.Remove(row.index)
		panel:Report(ok, err)
	end)
	row.remove:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.name:SetPoint("LEFT", row.key, "RIGHT", Tokens.Size("gapSmall"), 0)
	row.name:SetPoint("RIGHT", row.remove, "LEFT", -Tokens.Size("gapSmall"), 0)
	return row
end

local function Refresh(panel)
	local api = Api()
	local profile = api and ClickCast.Profile() or {}
	local custom = {}
	local _, kinds = Api()
	for index, info in ipairs(profile) do
		if not kinds or info.type ~= kinds.Interaction then
			custom[#custom + 1] = { index = index, info = info }
		end
	end
	for i, row in ipairs(panel.rows) do
		local entry = custom[i]
		row:SetShown(entry ~= nil)
		if entry then
			local name, icon = ClickCast.Describe(entry.info)
			row.index = entry.index
			Widgets.SetText(row.key, ClickCast.KeyText(entry.info))
			Widgets.SetText(row.name, name)
			row.icon:SetTexture(icon)
		end
	end
	local more = #custom - #panel.rows
	Widgets.SetText(panel.more, more > 0 and string.format(L["and %d more in the game's window"], more) or (#custom == 0 and L["No spells bound yet."] or ""))
	local fight = InCombatLockdown()
	panel.drop:SetEnabled(api ~= nil and not fight)
	panel.open:SetEnabled(not fight)
	if panel.pending then
		panel.drop:SetText(L["Now click here with your binding"])
	else
		panel.drop:SetText(L["Drop a spell or macro here"])
	end
end

function ClickCast.Panel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel.cap = Widgets.SectionCap(panel, { text = L["Click casting"] })
	panel.cap:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	panel.cap:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
	panel.help = Widgets.Text(panel, "caption", "text")
	panel.help:SetJustifyH("LEFT")
	panel.help:SetPoint("TOPLEFT", panel.cap, "BOTTOMLEFT", 0, -Tokens.Size("gapSmall"))
	panel.help:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	Widgets.SetText(panel.help, L["Drop a spell below, then click it with the keys and button that should cast it on a member. These are the game's Click Casting bindings."])
	panel.rows = {}
	local above = panel.help
	for i = 1, ROWS do
		local row = Row(panel)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, i == 1 and -Tokens.Size("gapSmall") or 0)
		row:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
		panel.rows[i] = row
		above = row
	end
	panel.more = Widgets.Text(panel, "caption", "textDisabled")
	panel.more:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 2 * BUTTON_HEIGHT + 2 * Tokens.Size("gapSmall"))
	panel.drop = Widgets.Button(panel, {
		text = L["Drop a spell or macro here"],
		onClick = function(_, mouse)
			if panel.pending then
				local kind, id = panel.pending.kind, panel.pending.id
				panel.pending = nil
				panel:Report(ClickCast.Add(kind, id, mouse or "LeftButton", Modifiers()))
				return
			end
			local kind, id = ClickCast.FromCursor()
			if kind then
				panel.pending = { kind = kind, id = id }
				if type(ClearCursor) == "function" then
					ClearCursor()
				end
				Refresh(panel)
			end
		end,
	})
	panel.drop:RegisterForClicks("AnyUp")
	panel.drop:SetScript("OnReceiveDrag", function()
		local kind, id = ClickCast.FromCursor()
		if kind then
			panel.pending = { kind = kind, id = id }
			if type(ClearCursor) == "function" then
				ClearCursor()
			end
			Refresh(panel)
		end
	end)
	panel.drop:SetHeight(BUTTON_HEIGHT)
	panel.drop:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, BUTTON_HEIGHT + Tokens.Size("gapSmall"))
	panel.drop:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	panel.open = Widgets.Button(panel, {
		text = L["Open the game's Click Casting"],
		onClick = function()
			ClickCast.Open()
		end,
	})
	panel.open:SetHeight(BUTTON_HEIGHT)
	panel.open:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
	panel.open:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	function panel.Report(_, ok, err)
		if not ok and err then
			Widgets.SetText(panel.more, err)
			return
		end
		Refresh(panel)
	end
	panel.Refresh = Refresh
	panel:SetScript("OnShow", Refresh)
	Refresh(panel)
	return panel
end

ClickCast.HEIGHT = CAP + HELP + ROWS * ROW_HEIGHT + MORE + 2 * BUTTON_HEIGHT + 3 * Tokens.Size("gapSmall")
