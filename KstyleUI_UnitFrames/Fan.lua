-- Fan.lua: seven clipped views of the engine's sorted target debuffs form a crest fan without inspecting aura data or moving restricted buttons.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, Settings = K.Widgets, K.Tokens, ns.Settings
local Fan = { KEY = "unitframes.crestDebuffs", MAX = 7 }
ns.Fan = Fan

local FILTER = "HARMFUL|PLAYER"
local SIZE, PITCH, HEIGHT, WIDTH = 28, 44, 100, 252
local TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"
local ANGLES = { 0, -18, 18, -36, 36, -54, 54 }

function Fan.Wanted(view)
	return view.kind == "target" and K.HudStyle.Current() == "medallions" and Settings.Value("target", "crestDebuffs")
end

local function Style(entry)
	entry.button:SetSize(SIZE, SIZE)
	ns.Auras.LayoutTile(entry)
	local path, size, flags = Settings.Font("target", "aura")
	for _, text in ipairs({ entry.timer, entry.count }) do
		Widgets.ApplyFont(text, path, math.min(12, math.max(10, size)), flags)
		text:SetTextColor(Tokens.Color("textEmphasis"))
	end
end

local function Dress(button, entries)
	local entry = ns.Auras.NewTile(button)
	entry.button = button
	entry.skin:SetAllPoints(button)
	entry.chrome.Restyle = function(chrome)
		if ns.Auras.Open() then
			entry.restyleChrome(chrome)
		end
	end
	local cooldown = CreateFrame("Cooldown", nil, entry.skin, "CooldownFrameTemplate")
	cooldown:SetAllPoints(entry.icon)
	cooldown:SetSwipeTexture((Tokens.Texture("iconMask")))
	cooldown:SetSwipeColor(Widgets.Rgba("black", 0.65))
	cooldown:SetReverse(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true)
	local over = CreateFrame("Frame", nil, entry.skin)
	over:SetAllPoints(entry.skin)
	over:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	entry.timer = Widgets.FontString(over, "OVERLAY")
	entry.timer:SetPoint("TOP", entry.skin, "BOTTOM", 0, -2)
	entry.count = Widgets.FontString(over, "OVERLAY")
	entry.count:SetPoint("TOPRIGHT", entry.skin, "TOPRIGHT", -1, -1)
	ns.Auras.Badge(over, entry.count)
	local cue = over:CreateTexture(nil, "OVERLAY")
	cue:SetColorTexture(Widgets.Rgba("capsGold", 0.8))
	cue:SetHeight(2)
	cue:SetPoint("BOTTOMLEFT", entry.skin, "BOTTOMLEFT", 2, 0)
	cue:SetPoint("BOTTOMRIGHT", entry.skin, "BOTTOMRIGHT", -2, 0)
	cue:Hide()
	if type(button.AddPandemicRegion) == "function" then
		button:AddPandemicRegion(cue)
	end
	Style(entry)
	button:SetIcon(entry.icon)
	button:SetDurationCooldown(cooldown)
	button:SetDurationText(entry.timer)
	button:SetApplicationCount(entry.count)
	entry.cooldown, entry.pandemic = cooldown, cue
	entries[#entries + 1] = entry
end

local function DefaultPosition()
	local layouts = K.Setup.Layouts
	local place = layouts.Aspect(K.Scale.Aspect(), "medallions", K.Layout.Setting("preset"), "actionbars.bar1")
	local _, _, _, height = layouts.MedallionsGroup(K.Scale.Aspect())
	return { anchor = "BOTTOM", x = 0, y = (place and place.y or 55) + height + 145 }
end

local function Build(view)
	local holder = CreateFrame("Frame", nil, K.Scale.Root())
	holder:SetSize(WIDTH, HEIGHT)
	holder:SetFrameStrata("LOW")
	local content = CreateFrame("Frame", nil, holder)
	content:SetAllPoints(holder)
	local fan = { holder = holder, content = content, windows = {}, containers = {}, buttons = {} }
	view.auras.fan = fan
	for rank, degrees in ipairs(ANGLES) do
		local window = CreateFrame("Frame", nil, content, TEMPLATE)
		window:SetClipsChildren(true)
		window:SetSize(PITCH, HEIGHT)
		local angle = math.rad(degrees)
		window:SetPoint("TOP", content, "TOP", Widgets.Snap(holder, 120 * math.sin(angle)), Widgets.Snap(holder, 120 * (math.cos(angle) - 1)))
		local container = CreateFrame("AuraContainer", nil, window, "CustomAuraContainerTemplate")
		fan.windows[rank], fan.containers[rank] = window, container
		container:SetUnit("target")
		container:SetEnabled(false)
		container:AddAuraGroup("debuffs", FILTER, {
			maxFrameCount = rank,
			sortMethod = AuraContainerSortMethod.ExpirationOnly,
			sortDirection = AuraContainerSortDirection.Normal,
			layout = { elementWidth = SIZE, elementHeight = SIZE, elementSpacing = PITCH - SIZE, lineSpacing = 0 },
			initializeFrame = function(button) Dress(button, fan.buttons) end,
		})
		container:SetFlowLayoutAnchorPoint("TOPLEFT")
		container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
		container:SetFlowLayoutMaximumLineSize(Fan.MAX * PITCH)
		container:SetPoint("TOPLEFT", window, "TOPLEFT", (PITCH - SIZE) / 2 - (rank - 1) * PITCH, 0)
	end
	K.Layout.Register(holder, Fan.KEY, DefaultPosition(), {
		label = K.L["Your target debuffs"], module = Settings.MODULE, scalable = true, defaultPosition = DefaultPosition,
	})
	local chip, why = ns.Overflow.New(content, "target", FILTER, Fan.MAX)
	if chip then
		fan.overflow = chip
		fan.overflowOptions = {
			enabled = true, filter = FILTER, cap = Fan.MAX, cell = SIZE, after = true,
			point = "TOP", rel = content, relPoint = "TOP", x = 0, y = -46, level = content:GetFrameLevel() + 8,
		}
		ns.Overflow.Apply(chip, fan.overflowOptions)
	else
		K.DevTest.Log(Settings.MODULE, "crest debuffs: overflow unavailable: " .. tostring(why))
	end
	return fan
end

function Fan.Restyle(view)
	local fan = view.auras and view.auras.fan
	if fan and fan.enabled and ns.Auras.Open() then
		for _, entry in ipairs(fan.buttons) do
			Style(entry)
		end
		if fan.overflow then ns.Overflow.Apply(fan.overflow, fan.overflowOptions) end
	end
end

function Fan.Apply(view, enabled)
	if view.kind ~= "target" then
		return false
	end
	local fan = view.auras.fan
	if not fan and enabled and Fan.Wanted(view) and ns.Auras.Open() then
		local ok, result = pcall(Build, view)
		fan = view.auras.fan
		if not ok then
			if fan then fan.failed = true end
			K.DevTest.Log(Settings.MODULE, "crest debuffs unavailable; keeping them on the target: " .. tostring(result))
		end
	end
	local on = enabled and Fan.Wanted(view) and fan ~= nil and not fan.failed
	if fan then
		fan.enabled = on and true or false
		for _, container in ipairs(fan.containers) do
			container:SetEnabled(on and true or false)
		end
		if fan.overflow then ns.Overflow.Enable(fan.overflow, on) end
		fan.content:SetShown(on and true or false)
		K.Layout.SetLive(Fan.KEY, on)
	end
	return on
end

function Fan.Sync(view, shown)
	local fan = view.auras and view.auras.fan
	if fan then
		fan.content:SetShown(shown and Fan.Wanted(view) and not fan.failed)
	end
end
