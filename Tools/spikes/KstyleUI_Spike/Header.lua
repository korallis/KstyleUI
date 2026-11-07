-- Header.lua: the header spike builds a SecurePartyHeaderTemplate header and a RegisterUnitWatch target button, and logs what they show.
local _, ns = ...

local TEMPLATE = "SecurePartyHeaderTemplate"
local EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
local NEEDED = { "RegisterUnitWatch", "UnregisterUnitWatch" }
local WIDTH, HEIGHT = 160, 24
local GAP = 4
local LEFT, TOP = 40, 120
local COUNT_DELAY = 1
local CHILD_CONFIG = [[
	self:SetWidth(160)
	self:SetHeight(24)
	self:SetAttribute("*type1", "target")
]]

local built
local current

local function Dress(button, text)
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.11, 0.11, 0.11, 0.9)
	local label = ns.Text(button, "GameFontHighlightSmall")
	label:SetPoint("LEFT", button, "LEFT", 6, 0)
	label:SetText(text)
	return label
end

local function Count(run)
	if current ~= run then
		return
	end
	local children, units = 0, {}
	while true do
		local child = built.header:GetAttribute("child" .. (children + 1))
		if not child then
			break
		end
		children = children + 1
		local unit = child:GetAttribute("unit")
		units[children] = { unit = ns.Describe(unit), shown = child:IsShown() }
		if not built.dressed[child] and not ns.InCombat() then
			built.dressed[child] = Dress(child, "Header child " .. children)
		end
	end
	run:Set("children", children)
	run:Set("units", units)
	run:Add("counts", { t = run:Since(), children = children, inCombat = ns.InCombat() })
end

local function OnWatch(button)
	if current then
		current:Add("watch", { t = current:Since(), shown = button:IsShown(), targetExists = ns.Try(UnitExists, "target"), inCombat = ns.InCombat() })
	end
end

local function Build()
	local header = CreateFrame("Frame", "KstyleUISpike_PartyHeader", UIParent, TEMPLATE)
	header:SetPoint("TOPLEFT", UIParent, "LEFT", LEFT, TOP)
	header:SetAttribute("template", "SecureUnitButtonTemplate")
	header:SetAttribute("initialConfigFunction", CHILD_CONFIG)
	header:SetAttribute("showPlayer", true)
	header:SetAttribute("showSolo", true)
	header:SetAttribute("showParty", true)
	header:SetAttribute("point", "TOP")
	header:SetAttribute("yOffset", -GAP)
	local watch = CreateFrame("Button", "KstyleUISpike_TargetWatch", UIParent, "SecureUnitButtonTemplate")
	watch:SetSize(WIDTH, HEIGHT)
	watch:SetPoint("TOPLEFT", UIParent, "LEFT", LEFT, TOP + HEIGHT + GAP * 4)
	watch:SetAttribute("unit", "target")
	watch:SetAttribute("*type1", "target")
	watch:RegisterForClicks("AnyUp")
	Dress(watch, "Target watch")
	watch:HookScript("OnShow", OnWatch)
	watch:HookScript("OnHide", OnWatch)
	built = { header = header, watch = watch, dressed = {} }
end

ns.Register("header", {
	summary = "builds a party header and a target button on RegisterUnitWatch at the left of the screen. Target things and join a group.",
	Run = function(run)
		run:Set("template", TEMPLATE)
		if ns.InCombat() then
			run:Set("refused", "in combat")
			run:Note("cannot show secure frames in combat. Leave combat and type /kspike header again.")
			return
		end
		for _, name in ipairs(NEEDED) do
			if type(_G[name]) ~= "function" then
				run:Set("missing", name)
				return
			end
		end
		if not built then
			local ok, err = pcall(Build)
			if not ok then
				run:Set("buildError", tostring(err))
				run:Note("build failed: " .. tostring(err))
				return
			end
		end
		RegisterUnitWatch(built.watch)
		built.header:Show()
		current = run
		run:Set("blocked", 0)
		ns.After(COUNT_DELAY, function() Count(run) end)
		local listener = ns.Listen(EVENTS, function(event, addon, fn)
			if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
				run:Count("blocked")
				run:Add("blockedEvents", { t = run:Since(), event = event, addon = ns.Describe(addon), fn = ns.Describe(fn) })
			elseif event == "GROUP_ROSTER_UPDATE" then
				ns.After(COUNT_DELAY, function() Count(run) end)
			end
		end)
		run:Note("frames are at the left of the screen. Target and clear targets, invite someone, then /kspike stop.")
		return function()
			current = nil
			ns.Unlisten(listener)
			ns.OutOfCombat(function()
				if not current then
					UnregisterUnitWatch(built.watch)
					built.watch:Hide()
					built.header:Hide()
				end
			end)
		end
	end,
})
