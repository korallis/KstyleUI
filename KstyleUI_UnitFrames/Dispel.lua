-- Dispel.lua: the player frame's dispel overlay, edge and type icon, tinted by the AuraContainer engine in the debuff's dispel colour.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens = K.Widgets, K.Tokens
local Settings = ns.Settings

local Dispel = {}
ns.Dispel = Dispel

local SLOT = "dispel"
local FILTERS = { PLAYER = "HARMFUL|RAID", GROUP = "HARMFUL|RAID_PLAYER_DISPELLABLE" }
local TYPES = { { "Magic", "dispelMagic" }, { "Curse", "dispelCurse" }, { "Poison", "dispelPoison" }, { "Disease", "dispelDisease" }, { "Bleed", "dispelBleed" } }

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(Settings.MODULE, message)
	end
end

local function Color(key)
	local c = Settings.Module()[key]
	if type(c) ~= "table" then c = Settings.defaults[key] end
	return c.r, c.g, c.b
end

local mapKey, map
function Dispel.Key()
	if Settings.Module().dispelCustom ~= true or type(CreateColor) ~= "function" then return "game" end
	local out = {}
	for i, kind in ipairs(TYPES) do
		out[i] = table.concat({ Color(kind[2]) }, ",")
	end
	return table.concat(out, ";")
end

function Dispel.Tinted(options)
	local key = Dispel.Key()
	if key == "game" then return options end
	if mapKey ~= key then
		map, mapKey = {}, key
		for _, kind in ipairs(TYPES) do
			map[kind[1]] = CreateColor(Color(kind[2]))
		end
	end
	options.customDispelColorMap = map
	return options
end

function Dispel.Magic()
	if Settings.Module().dispelCustom == true then return Color("dispelMagic") end
	return Tokens.Color("magic")
end

local function Wanted()
	return Settings.Form("player") ~= "slab" and (Settings.Value("player", "dispelOverlay") ~= "" or Settings.Value("player", "dispelEdge") or Settings.Value("player", "dispelIcon") ~= "")
end

local function NewParts(owner)
	local p = { health = CreateFrame("Frame", nil, owner), card = CreateFrame("Frame", nil, owner), edge = CreateFrame("Frame", nil, owner), mark = CreateFrame("Frame", nil, owner) }
	p.fill = p.health:CreateTexture(nil, "ARTWORK")
	p.fill:SetAllPoints(p.health)
	p.fill:SetColorTexture(1, 1, 1, 1)
	p.wash = Widgets.NineSlice(p.card, "chamferTile", "ARTWORK")
	p.line = Widgets.NineSlice(p.edge, "lumenOutline", "OVERLAY")
	p.icon = p.mark:CreateTexture(nil, "OVERLAY")
	p.icon:SetAllPoints(p.mark)
	p.tinted = { p.fill }
	for _, slice in ipairs({ p.wash, p.line }) do
		for _, piece in ipairs(slice) do p.tinted[#p.tinted + 1] = piece end
	end
	return p
end

local function Hide(p)
	for _, frame in ipairs({ p.health, p.card, p.edge, p.mark }) do frame:Hide() end
end

local function Layout(p, view)
	local overlay, place = Settings.Value("player", "dispelOverlay"), Settings.Value("player", "dispelIcon")
	local alpha, level = Settings.Value("player", "dispelAlpha"), view.top:GetFrameLevel() - 1
	for _, frame in ipairs({ p.health, p.card, p.edge, p.mark }) do
		frame:SetFrameLevel(level)
	end
	p.health:SetAllPoints(view.health)
	p.health:SetAlpha(alpha)
	p.health:SetShown(overlay == "health")
	p.card:SetAllPoints(view.panel)
	p.card:SetAlpha(alpha)
	Widgets.LayoutSlice(p.wash, p.card, Tokens.Size("radiusTile"), 0)
	p.card:SetShown(overlay == "frame")
	p.edge:SetAllPoints(view.panel)
	Widgets.LayoutSlice(p.line, p.edge, Tokens.Size("radiusTile"), 0)
	p.edge:SetShown(Settings.Value("player", "dispelEdge"))
	p.mark:SetShown(place ~= "")
	if place == "" then return end
	local rect = view.geometry and view.geometry.health
	local size = Widgets.Snap(view.health, math.min(Settings.Value("player", "dispelIconSize"), rect and rect.h or math.huge))
	local inset = Widgets.Snap(view.health, Tokens.Size("gapTiny"))
	p.mark:ClearAllPoints()
	p.mark:SetSize(size, size)
	p.mark:SetPoint(place, view.health, place, place:find("LEFT") and inset or place:find("RIGHT") and -inset or 0, place:find("TOP") and -inset or place:find("BOTTOM") and inset or 0)
end

local function Register(d)
	local key, slot, p = Dispel.Key(), d.slot, d.parts
	if d.tint == key then return end
	local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
	local wash = Dispel.Tinted({ style = styles.PreserveAsset, showWhenHarmful = true })
	local mark = Dispel.Tinted({ style = styles.CustomAsset, showWhenHarmful = true, customDispelAssetMap = K.ColorVision.DispelAssets() })
	for _, texture in ipairs(p.tinted) do
		if d.tint then slot:RemoveDispelTypeTexture(texture) end
		slot:AddDispelTypeTexture(texture, wash)
	end
	if d.tint then slot:RemoveDispelTypeTexture(p.icon) end
	slot:AddDispelTypeTexture(p.icon, mark)
	d.tint = key
end

local function Dress(d, slot, view)
	pcall(slot.EnableMouse, slot, false)
	slot:ClearAllPoints()
	slot:SetAllPoints(view.button)
	d.slot, d.parts = slot, NewParts(slot)
	Register(d)
	Layout(d.parts, view)
end

local function Build(view)
	local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, view.button, "CustomAuraContainerTemplate")
	if not (styles and styles.PreserveAsset and styles.CustomAsset and K.ColorVision) or not ok or type(container) ~= "table" or type(container.AddAuraSlot) ~= "function" then
		LogOnce("engine", "dispel overlay: the aura slot engine or its dispel texture styles are missing; the player frame shows no dispel overlay")
		view.dispel = false
		return nil
	end
	Widgets.KeepOut(container)
	container:SetUnit(view.unit)
	local d = { container = container, filter = FILTERS.PLAYER }
	view.dispel = d
	local added, err = pcall(container.AddAuraSlot, container, SLOT, d.filter, { initializeFrame = function(slot) K.Call(Dress, d, slot, view) end })
	if not added then
		LogOnce("slot", "dispel overlay: the aura slot was refused (" .. tostring(err) .. "); the player frame shows no dispel overlay")
		view.dispel = false
		return nil
	end
	return d
end

function Dispel.Apply(view)
	local d = view.dispel
	local on = ns.Frames.IsRunning() and view.uf.active and Wanted()
	if d == false or not (on or d) then return end
	if not ns.Auras.Open() then
		if not view.dispelQueued then
			view.dispelQueued = true
			K.Combat.Queue(function()
				view.dispelQueued = false
				Dispel.Apply(view)
			end)
		end
		return
	end
	d = d or Build(view)
	if not d then return end
	if on then
		local filter = FILTERS[Settings.Value("player", "dispelFilter")] or FILTERS.PLAYER
		if d.filter ~= filter then
			d.container:SetAuraSlotFilterString(SLOT, filter)
			d.filter = filter
		end
		if d.slot then
			Register(d)
			Layout(d.parts, view)
		end
	elseif d.slot then
		Hide(d.parts)
	end
	d.container:SetAuraSlotEnabled(SLOT, on and true or false)
end

function Dispel.Sample(view, holder, kind)
	local p = view.dispelSample
	if kind ~= "player" or not Wanted() then
		if p then Hide(p) end
		return
	end
	if not p then
		p = NewParts(holder)
		p.icon:SetTexture((Tokens.Texture("dispelM")))
		view.dispelSample = p
	end
	local r, g, b = Dispel.Magic()
	for _, texture in ipairs(p.tinted) do texture:SetVertexColor(r, g, b, 1) end
	p.icon:SetVertexColor(r, g, b, 1)
	Layout(p, view)
end
