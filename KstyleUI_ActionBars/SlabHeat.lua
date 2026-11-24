-- SlabHeat.lua: Rising heat (docs/medallions-effects.md#rising-heat): each combo point or stack the crest counts warms it a step, a thin halo in the class colour on the inner edge of the rune band and the class burst in its own colours as a corona just outside the ring, masked inside 184 units, each step a one-point status bar drawn at its share of the full alpha so the engine adds them. Lua feeds the secret combo point count into crest-owned bars, skipping them while the switch is off and refreshing them when it comes back; a crown's or the storm orbs' aura feeds two more application bars per step on the same container, bound with its own feeds. The switch, a profile change and a palette change repaint every bar; bars under an aura button wait until auras are readable and combat has ended.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets = K.Tokens, K.Widgets

local Heat = {}
ns.SlabHeat = Heat

local OWNER = "ActionBars.SlabHeat"
local HALO, CORONA, MASK, LIGHT = 122, 232, 184, 0.8
local bars, combos, NONE = {}, {}, {}
Heat.bars = bars

local function On()
	return ns.Config("crestHeat") ~= false
end

local function Write(steps, points, mode)
	for _, bar in ipairs(steps) do
		bar:SetValue(points, mode)
	end
end

function Heat.Paint()
	local on, locked = On(), ns.SlabMedals.Locked()
	local r, g, b = K.Theme.ClassColor(ns.class)
	for _, bar in ipairs(bars) do
		if not (bar.fed and locked) then
			bar:SetAlpha(on and bar.share or 0)
			if bar.halo then
				bar:SetStatusBarColor(r, g, b)
			end
		end
	end
	for _, steps in ipairs(on and combos or NONE) do
		Write(steps, steps.points or 0, 0)
	end
	local listen = locked and K.Events.Register or K.Events.Unregister
	for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }) do
		listen(OWNER, event, Heat.Paint)
	end
end

local function Steps(count, make)
	local hub = ns.Slab.hub
	local level = hub:GetFrameLevel()
	local parts = {
		{ "halo", "ringLine16", HALO, 1, level + 1 },
		{ "corona", "medBurst" .. ns.class:sub(1, 1) .. ns.class:sub(2):lower(), CORONA, LIGHT, math.max(0, level - 1) },
	}
	local made = {}
	for i = 1, count do
		for _, part in ipairs(parts) do
			local bar = make(i, part[1])
			bar:SetFrameLevel(part[5])
			bar:SetPoint("CENTER", hub, "CENTER", 0, 0)
			Widgets.Size(bar, part[3], part[3])
			bar:SetOrientation("VERTICAL")
			bar:SetStatusBarTexture((Tokens.Texture(part[2])))
			bar:GetStatusBarTexture():SetBlendMode("ADD")
			bar:SetMinMaxValues(i - 1, i)
			bar:SetValue(0)
			bar.share, bar.halo = part[4] / count, part[1] == "halo"
			if not bar.halo then
				local mask = bar:CreateMaskTexture()
				mask:SetTexture((Tokens.Texture("orbMask")), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				mask:SetPoint("CENTER", hub, "CENTER", 0, 0)
				Widgets.Size(mask, MASK, MASK)
				bar:GetStatusBarTexture():AddMaskTexture(mask)
			end
			bars[#bars + 1] = bar
			made[#made + 1] = bar
		end
	end
	Heat.Paint()
	return made
end

function Heat.Combo(parent, count)
	local steps = Steps(count, function()
		return CreateFrame("StatusBar", nil, parent)
	end)
	combos[#combos + 1] = steps
	return steps
end

function Heat.Set(steps, points, moving)
	steps.points = points
	if On() then
		local modes = Enum and Enum.StatusBarInterpolation or {}
		Write(steps, points, moving and (modes.ExponentialEaseOut or 1) or (modes.Immediate or 0))
	end
end

function Heat.Fed(container, filter, options, count, feeds)
	Steps(count, function(i, key)
		local button = container:AddAuraSlot("heat" .. key .. i, filter, options)
		pcall(button.EnableMouse, button, false)
		local bar = CreateFrame("StatusBar", nil, button)
		button:SetAllPoints(bar)
		bar.fed = true
		feeds[#feeds + 1] = { button = button, bar = bar, low = i - 1, ease = true }
		return bar
	end)
end

function Heat.SetEnabled(on)
	local Callbacks = K.Callbacks
	if on then
		Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
			if module == "ActionBars" and key == "crestHeat" then
				Heat.Paint()
			end
		end)
		Callbacks.Register("ProfileChanged", OWNER, Heat.Paint)
		Callbacks.Register("ThemeChanged", OWNER, Heat.Paint)
	else
		for _, event in ipairs({ "SettingChanged", "ProfileChanged", "ThemeChanged" }) do
			Callbacks.Unregister(event, OWNER)
		end
		K.Events.UnregisterAll(OWNER)
	end
end
