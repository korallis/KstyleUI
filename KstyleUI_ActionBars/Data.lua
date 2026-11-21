-- Data.lua: the bar table and the pure parts of the action bars: grid maths, slots, paging drivers and the page snippet.
local _, ns = ...

local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min

ns.BUTTONS_PER_PAGE = 12
ns.FIRST_BONUS_PAGE = 6
ns.MAX_SLOT = 180

ns.BARS = {
	{ key = "bar1", kind = "action", name = "ActionBar1", binding = "ACTIONBUTTON", page = 1, paged = true, max = 12 },
	{ key = "bar2", kind = "action", name = "ActionBar2", binding = "MULTIACTIONBAR1BUTTON", page = 6, max = 12 },
	{ key = "bar3", kind = "action", name = "ActionBar3", binding = "MULTIACTIONBAR2BUTTON", page = 5, max = 12 },
	{ key = "bar4", kind = "action", name = "ActionBar4", binding = "MULTIACTIONBAR3BUTTON", page = 3, max = 12 },
	{ key = "bar5", kind = "action", name = "ActionBar5", binding = "MULTIACTIONBAR4BUTTON", page = 4, max = 12 },
	{ key = "bar6", kind = "action", name = "ActionBar6", binding = "MULTIACTIONBAR5BUTTON", page = 13, max = 12 },
	{ key = "pet", kind = "pet", name = "PetBar", binding = "BONUSACTIONBUTTON", max = 10 },
	{ key = "stance", kind = "stance", name = "StanceBar", binding = "SHAPESHIFTBUTTON", max = 10 },
}

ns.BAR = {}
for _, def in ipairs(ns.BARS) do
	def.element = "actionbars." .. def.key
	ns.BAR[def.key] = def
end

ns.BLIZZARD_BARS = {
	"MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
	"MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar",
}

function ns.GridSize(count, rows, size, spacing)
	count = max(1, count or 1)
	rows = min(count, max(1, floor(rows or 1)))
	local cols = ceil(count / rows)
	rows = ceil(count / cols)
	return cols * size + (cols - 1) * spacing, rows * size + (rows - 1) * spacing, cols, rows
end

function ns.Cell(index, count, rows, orientation, growth)
	local _, _, cols, used = ns.GridSize(count, rows, 1, 0)
	local col, row
	if orientation == "VERTICAL" then
		row, col = (index - 1) % used, floor((index - 1) / used)
	else
		col, row = (index - 1) % cols, floor((index - 1) / cols)
	end
	if growth == "LEFTDOWN" or growth == "LEFTUP" then
		col = cols - 1 - col
	end
	if growth == "RIGHTUP" or growth == "LEFTUP" then
		row = used - 1 - row
	end
	return col, row
end

function ns.Slot(id, page)
	return id + (page - 1) * ns.BUTTONS_PER_PAGE
end

local SPECIAL = "[vehicleui] vehicle; [overridebar] override; [possessbar] possess; [shapeshift] shapeshift; [bonusbar:5] possess"
local PAGE_KEYS = "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6"
local BONUS_BARS = {
	ROGUE = { "stealth", "stealth" },
	DRUID = { "form", "stealth", "form", "form" },
}
local ANY_CLASS = { "form", "form", "form", "form" }

local function Trim(text)
	if type(text) ~= "string" then
		return ""
	end
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function ns.PagingDriver(cfg, class)
	cfg = cfg or {}
	local custom = Trim(cfg.paging)
	if custom ~= "" then
		return custom
	end
	local parts = {}
	if cfg.pagePossess then
		parts[#parts + 1] = SPECIAL
	end
	if cfg.pageKeys then
		parts[#parts + 1] = PAGE_KEYS
	end
	local bonus = BONUS_BARS[class] or ANY_CLASS
	for n, rule in ipairs(bonus) do
		local wanted
		if rule == "stealth" then
			wanted = cfg.pageStealth
		else
			wanted = cfg.pageForms
		end
		if wanted then
			parts[#parts + 1] = "[bonusbar:" .. n .. "] " .. (ns.FIRST_BONUS_PAGE + n)
		end
	end
	parts[#parts + 1] = "1"
	return table.concat(parts, "; ")
end

ns.PAGE_SNIPPET = [[
	local page = newstate
	if page == "vehicle" or page == "override" or page == "possess" or page == "shapeshift" then
		if HasVehicleActionBar() then
			page = GetVehicleBarIndex()
		elseif HasOverrideActionBar() then
			page = GetOverrideBarIndex()
		elseif HasTempShapeshiftActionBar() then
			page = GetTempShapeshiftBarIndex()
		elseif HasBonusActionBar() then
			page = GetBonusBarIndex()
		else
			page = GetActionBarPage()
		end
	end
	page = tonumber(page)
	if not page or page < 1 then
		page = 1
	end
	self:SetAttribute("actionpage", page)
]]

local OUTLINES = { NONE = "", OUTLINE = "OUTLINE", THICK = "THICKOUTLINE" }

function ns.FontFlags(outline)
	return OUTLINES[outline] or ""
end
