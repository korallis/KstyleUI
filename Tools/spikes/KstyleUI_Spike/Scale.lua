-- Scale.lua: the scale spike applies the spec's root scale, measures it, draws a pixel test card and watches for blocked actions.
local _, ns = ...

local WINDOW = 60
local MIN_USER_SCALE, MAX_USER_SCALE = 0.75, 1.5
local CARD_WIDTH, CARD_HEIGHT = 560, 330
local COMB_LINES = 40
local COMB_LENGTH = 40
local PAD = 16
local SHOT_DELAY = 1

local function Line(panel, x, y, width, height)
	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 1, 1, 1)
	line:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
	line:SetSize(width, height)
	return line
end

local function DrawCard(panel, physicalHeight, userScale)
	local key = physicalHeight .. ":" .. userScale
	if panel.drawnFor == key then
		return
	end
	panel.drawnFor = key
	if panel.lines then
		for _, line in ipairs(panel.lines) do
			line:Hide()
		end
	end
	panel.lines = {}
	local px = ns.PixelUnits(1, physicalHeight, userScale)
	local border = ns.PixelUnits(ns.BorderPixels(physicalHeight), physicalHeight, userScale)
	local width, height = math.floor(CARD_WIDTH / px) * px, math.floor(CARD_HEIGHT / px) * px
	panel:SetSize(width, height)
	local add = function(...) panel.lines[#panel.lines + 1] = Line(panel, ...) end
	add(0, 0, width, border)
	add(0, -(height - border), width, border)
	add(0, 0, border, height)
	add(width - border, 0, border, height)
	local top = -math.floor((height - COMB_LENGTH - PAD) / px) * px
	local left = math.floor(PAD / px) * px
	for i = 0, COMB_LINES - 1 do
		add(left + i * 2 * px, top, px, COMB_LENGTH)
		add(left + COMB_LINES * 2 * px + 4 * PAD + i * 2 * px, top, px, COMB_LENGTH)
	end
	for i = 0, COMB_LINES / 2 - 1 do
		add(width - left - COMB_LENGTH * 2, top + i * 2 * px, COMB_LENGTH * 2, px)
	end
end

local function Measure(run, panel)
	local width, height = GetPhysicalScreenSize()
	local root = ns.Root()
	local uiScale = UIParent:GetEffectiveScale()
	local values = {
		physicalWidth = width,
		physicalHeight = height,
		uiParentEffectiveScale = uiScale,
		uiParentWidth = UIParent:GetWidth(),
		uiParentHeight = UIParent:GetHeight(),
		userScale = ns.userScale,
		rootScale = root:GetScale(),
		rootEffectiveScale = root:GetEffectiveScale(),
		expectedRootHeight = UIParent:GetHeight() * uiScale / root:GetEffectiveScale(),
		rootWidth = root:GetWidth(),
		rootHeight = root:GetHeight(),
		pixelUnits = ns.PixelUnits(1, height, ns.userScale),
		borderPixels = ns.BorderPixels(height),
	}
	if C_CVar and C_CVar.GetCVar then
		values.cvarUseUiScale = C_CVar.GetCVar("useUiScale")
		values.cvarUiScale = C_CVar.GetCVar("uiScale")
	end
	for key, value in pairs(values) do
		run:Set(key, value)
	end
	if panel then
		DrawCard(panel, height, ns.userScale)
		panel.info:SetText(string.format(
			"Screen %dx%d px. UIParent scale %.4f. Root scale %.4f, %.1f x %.1f units.\n"
				.. "1 px = %.4f units. Border %d px. The combs below must show even, separate lines.",
			width, height, uiScale, values.rootEffectiveScale, values.rootWidth or 0, values.rootHeight or 0,
			values.pixelUnits, values.borderPixels))
	end
	return values
end

ns.Register("scale", {
	group = "basic",
	summary = "applies the root scale, records the pixel maths and watches 60 s for blocked actions. Optional: /kspike scale 1.25",
	Run = function(run, args)
		local requested = tonumber(args)
		ns.userScale = requested and math.min(MAX_USER_SCALE, math.max(MIN_USER_SCALE, requested)) or 1
		ns.Root()
		ns.ApplyRootScale()
		local panel = ns.Panel("scale", "Scale and pixels", CARD_WIDTH, CARD_HEIGHT)
		if not panel.info then
			panel.info = ns.Text(panel, "GameFontHighlight")
			panel.info:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -48)
		end
		run:Set("blocked", 0)
		run:Set("forbidden", 0)
		run:Set("windowSeconds", WINDOW)
		Measure(run, panel)
		ns.After(0, function() Measure(run, panel) end)
		local listener, failed = ns.Listen({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }, function(event, addon, fn)
			if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
				run:Count(event == "ADDON_ACTION_BLOCKED" and "blocked" or "forbidden")
				run:Add("events", { t = run:Since(), event = event, addon = ns.Describe(addon), fn = ns.Describe(fn) })
			else
				ns.ApplyRootScale()
				local values = Measure(run, panel)
				run:Add("events", { t = run:Since(), event = event, physicalHeight = values.physicalHeight, rootEffectiveScale = values.rootEffectiveScale })
				ns.After(0, function() Measure(run, panel) end)
			end
		end)
		if #failed > 0 then
			run:Set("unregisteredEvents", failed)
		end
		ns.After(WINDOW, function() ns.Stop("scale", "timeout", run) end)
		ns.Later(SHOT_DELAY, function() ns.Screenshot(run) end)
		run:Note("watching for blocked actions for " .. WINDOW .. " s. Open a few Blizzard windows meanwhile.")
		return function()
			ns.Unlisten(listener)
		end
	end,
})
