-- Content.lua: the tooltip data post-calls: line colours, the title divider and the item quality edge.
local _, ns = ...

local K = KstyleUI
local Logic, Settings, Style = ns.Logic, ns.Settings, ns.Style

local Content = {}
ns.Content = Content

local registered = false

local function Readable(data)
	return type(data) == "table" and not Logic.IsSecret(data)
end

local function ItemQuality(data)
	local Item = C_Item
	if not (Item and type(Item.GetItemQualityByID) == "function") then
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
	local ok, quality = pcall(Item.GetItemQualityByID, info)
	if ok then
		return quality
	end
	return nil
end

local function OnAny(tooltip)
	if ns.active and Style.Glass(tooltip) then
		Style.Decorate(tooltip)
	end
end

local function OnItem(tooltip, data)
	if not (ns.active and Style.Glass(tooltip) and Readable(data)) then
		return
	end
	if Settings.Get("qualityEdge") then
		local quality = ItemQuality(data)
		if Logic.EdgeQuality(quality) then
			Style.SetEdge(tooltip, K.Theme.QualityColor(quality))
		end
	end
end

local function Safely(fn)
	return function(tooltip, data)
		K.Call(fn, tooltip, data)
	end
end

function Content.IsRegistered()
	return registered
end

function Content.Register()
	if registered then
		return true
	end
	local processor = TooltipDataProcessor
	if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" then
		Settings.Log("TooltipDataProcessor is missing; tooltips get the glass but no line colours, divider or quality edge")
		return false
	end
	registered = true
	if processor.AllTypes ~= nil then
		processor.AddTooltipPostCall(processor.AllTypes, Safely(OnAny))
	else
		Settings.Log("TooltipDataProcessor.AllTypes is missing; tooltips keep Blizzard's line colours and no divider")
	end
	local types = Enum and Enum.TooltipDataType
	if types and types.Item ~= nil then
		processor.AddTooltipPostCall(types.Item, Safely(OnItem))
	else
		Settings.Log("Enum.TooltipDataType.Item is missing; item tooltips keep the glass edge")
	end
	Settings.Log("tooltip post-calls added")
	return true
end
