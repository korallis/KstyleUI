-- Content.lua: the tooltip data post-call: line colours, the title divider, item quality edges, unit lines, IDs and icons.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L
local Logic, Settings, Style, Units, Health = ns.Logic, ns.Settings, ns.Style, ns.Units, ns.Health

local Content = {}
ns.Content = Content

local registered = false
local kinds = {}

local function Readable(data)
	return type(data) == "table" and not Logic.IsSecret(data)
end

local function Call(api, name, ...)
	local fn = api and api[name]
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

local function ItemQuality(data)
	if not (C_Item and type(C_Item.GetItemQualityByID) == "function") then
		Settings.LogOnce("quality", "C_Item.GetItemQualityByID is missing; item tooltips keep the glass edge")
		return nil
	end
	local info = data.hyperlink
	if Logic.IsSecret(info) or info == nil then
		info = data.id
	end
	if Logic.IsSecret(info) or info == nil then
		return nil
	end
	return Call(C_Item, "GetItemQualityByID", info)
end

local function AddID(tooltip, label, id)
	local text = Logic.IDText(id)
	if text then
		local lr, lg, lb = Tokens.Color("text")
		local rr, rg, rb = Tokens.Color("textEmphasis")
		tooltip:AddDoubleLine(label, text, lr, lg, lb, rr, rg, rb)
	end
end

local function ItemLevel(data)
	local info = data.hyperlink
	if Logic.IsSecret(info) or info == nil then
		info = data.id
	end
	if Logic.IsSecret(info) or info == nil then
		return nil
	end
	return Call(C_Item, "GetDetailedItemLevelInfo", info)
end

local function Item(tooltip, data)
	local quality = ItemQuality(data)
	if Settings.Get("qualityEdge") and Logic.EdgeQuality(quality) then
		Style.SetEdge(tooltip, K.Theme.QualityColor(quality))
	end
	Style.Title(tooltip, quality, ItemLevel(data))
	local id = data.id
	if not Logic.IsNumber(id) then
		return
	end
	local icon = Call(C_Item, "GetItemIconByID", id)
	if Settings.Get("itemID") then
		AddID(tooltip, L["Item ID"], id)
	end
	if Settings.Get("iconID") then
		AddID(tooltip, L["Icon ID"], icon)
	end
	Style.Icon(tooltip, icon, quality)
end

local function Spell(tooltip, data)
	Style.Title(tooltip)
	local id = data.id
	if not Logic.IsNumber(id) then
		return
	end
	local icon = Call(C_Spell, "GetSpellTexture", id)
	if Settings.Get("spellID") then
		AddID(tooltip, L["Spell ID"], id)
	end
	if Settings.Get("iconID") then
		AddID(tooltip, L["Icon ID"], icon)
	end
	Style.Icon(tooltip, icon, nil, true)
end

local function Object(tooltip)
	if tooltip == GameTooltip then
		Health.SetColor(Units.BarColor(nil))
	end
end

local function Decorate(tooltip, data)
	if not (ns.active and Style.Glass(tooltip)) then
		return
	end
	if Settings.Get("softColors") then
		Style.Soften(tooltip)
	end
	local kind
	if Readable(data) and Logic.IsNumber(data.type) then
		kind = kinds[data.type]
		if kind then
			kind(tooltip, data)
		end
	end
	Style.Lines(tooltip, kind == Item)
end

local function OnTooltip(tooltip, data)
	K.Call(Decorate, tooltip, data)
end

function Content.IsRegistered()
	return registered
end

function Content.Register()
	if registered then
		return true
	end
	local processor = TooltipDataProcessor
	if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" or processor.AllTypes == nil then
		Settings.Log("TooltipDataProcessor is missing; tooltips get the glass but no line colours, divider, quality edge, unit lines or IDs")
		return false
	end
	local types = Enum and Enum.TooltipDataType
	if type(types) == "table" then
		for name, fn in pairs({ Item = Item, Spell = Spell, UnitAura = Spell, Unit = Units.Decorate, Object = Object }) do
			if types[name] ~= nil then
				kinds[types[name]] = fn
			else
				Settings.Log("Enum.TooltipDataType." .. name .. " is missing; those tooltips get only the glass")
			end
		end
	else
		Settings.Log("Enum.TooltipDataType is missing; tooltips get only the glass, colours and divider")
	end
	registered = true
	processor.AddTooltipPostCall(processor.AllTypes, OnTooltip)
	Settings.Log("tooltip post-call added")
	return true
end
