-- SlabHeat.lua: Rising heat (docs/medallions-effects.md#rising-heat): each combo point or stack the crest counts warms it a step, a thin halo in the class colour on the inner edge of the rune band and the class burst as a faint corona just outside the ring, each step a one-point status bar drawn at its share of the full alpha so the engine adds them. Lua feeds the secret combo point count into crest-owned bars; a crown's or the storm orbs' aura feeds two more application bars per step on the same container, bound with its own feeds. The switch hides the bars, and waits while auras are secret for the ones under an aura button.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets = K.Tokens, K.Widgets

local Heat = {}
ns.SlabHeat = Heat

local OWNER = "ActionBars.SlabHeat"
local HALO, CORONA, FAINT = 122, 1.3, 0.5
local bars = {}
Heat.bars = bars

local function Steps(count, make)
	local hub = ns.Slab.hub
	local r, g, b = K.Theme.ClassColor(ns.class)
	local level = hub:GetFrameLevel()
	local parts = {
		{ "halo", "ringLine16", HALO, 1, level + 1 },
		{ "corona", "medBurst" .. ns.class:sub(1, 1) .. ns.class:sub(2):lower(), ns.Slab.RING * CORONA, FAINT, math.max(0, level - 1) },
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
			bar:SetStatusBarColor(r, g, b)
			bar:SetMinMaxValues(i - 1, i)
			bar:SetValue(0)
			bar.share = part[4] / count
			bar:SetAlpha(ns.Config("crestHeat") ~= false and bar.share or 0)
			bars[#bars + 1] = bar
			made[#made + 1] = bar
		end
	end
	return made
end

function Heat.Combo(parent, count)
	return Steps(count, function()
		return CreateFrame("StatusBar", nil, parent)
	end)
end

function Heat.Set(steps, points, moving)
	if not steps then
		return
	end
	local modes = Enum and Enum.StatusBarInterpolation or {}
	local mode = moving and (modes.ExponentialEaseOut or 1) or (modes.Immediate or 0)
	for _, bar in ipairs(steps) do
		bar:SetValue(points, mode)
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

function Heat.Paint()
	local on, waiting = ns.Config("crestHeat") ~= false, ns.SlabMedals.Restricted()
	for _, bar in ipairs(bars) do
		if not (bar.fed and waiting) then
			bar:SetAlpha(on and bar.share or 0)
		end
	end
	local listen = waiting and K.Events.Register or K.Events.Unregister
	for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED" }) do
		listen(OWNER, event, Heat.Paint)
	end
end

function Heat.SetEnabled(on)
	if on then
		K.Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
			if module == "ActionBars" and key == "crestHeat" then
				Heat.Paint()
			end
		end)
	else
		K.Callbacks.Unregister("SettingChanged", OWNER)
		K.Events.UnregisterAll(OWNER)
	end
end
