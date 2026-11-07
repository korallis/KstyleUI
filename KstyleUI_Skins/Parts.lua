-- Parts.lua: the pieces skins draw on KstyleUI's own child frames: quality rims behind icons and accent lines.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets = K.Tokens, K.Widgets

local Parts = {}
ns.Parts = Parts

local RIM_UNITS = 2
local RIM_SUBLEVEL = -7
local LEVEL_BELOW = 1
local LINE_UNITS = 2

local function LayoutRim(holder)
	local frame = holder.target
	local outset = Widgets.Snap(holder, holder.outset)
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", frame, "TOPLEFT", -outset, outset)
	holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", outset, -outset)
	local _, _, corner = Tokens.Texture("chamferTile")
	Widgets.LayoutSlice(holder.rim, holder, corner, RIM_UNITS)
end

local function PaintRim(holder)
	local color = holder.color
	if color then
		Widgets.ShowSlice(holder.rim, true)
		Widgets.ColorSlice(holder.rim, color[1], color[2], color[3], color[4] or 1)
		holder.chrome:SetEdgeRGBA(color[1], color[2], color[3], color[4] or 1)
	else
		Widgets.ShowSlice(holder.rim, false)
		holder.chrome:SetEdge("edgeInner")
	end
end

local function RestyleRim(holder)
	if Widgets.MayMove(holder) then
		LayoutRim(holder)
	end
	holder.chrome:Restyle()
	PaintRim(holder)
end

local function SetRimColor(holder, r, g, b, a)
	if r == nil then
		holder.color = nil
	else
		holder.color = { r, g, b, a or 1 }
	end
	PaintRim(holder)
end

function Parts.Rim(frame, opts)
	opts = opts or {}
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetFrameLevel(math.max(0, frame:GetFrameLevel() - LEVEL_BELOW))
	holder.target = frame
	holder.outset = opts.outset or 0
	holder.chrome = Widgets.Chrome(holder, { shape = "tile", fill = opts.fill or "raised", shadow = false })
	holder.rim = Widgets.NineSlice(holder, "chamferTile", "BACKGROUND", RIM_SUBLEVEL)
	holder.Restyle = RestyleRim
	holder.SetRimColor = SetRimColor
	RestyleRim(holder)
	return Widgets.Track(holder)
end

local function RestyleLine(line)
	local owner = line.owner
	local inset = Widgets.Snap(owner, line.inset)
	line:ClearAllPoints()
	if line.edge == "TOP" then
		line:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, 0)
		line:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -inset, 0)
	else
		line:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", inset, 0)
		line:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, 0)
	end
	line:SetHeight(Widgets.Snap(owner, line.units))
	ns.Style.TintAccent(line, line.alpha)
end

function Parts.AccentLine(owner, opts)
	opts = opts or {}
	local layer = CreateFrame("Frame", nil, owner)
	layer:SetAllPoints(owner)
	layer:SetFrameLevel(owner:GetFrameLevel() + LEVEL_BELOW)
	local line = layer:CreateTexture(nil, "OVERLAY")
	line:SetTexture((Tokens.Texture("divider")))
	line.owner = owner
	line.edge = opts.edge or "BOTTOM"
	line.inset = opts.inset or 0
	line.units = opts.units or LINE_UNITS
	line.alpha = opts.alpha or 1
	line.Restyle = RestyleLine
	RestyleLine(line)
	ns.Style.Track(line)
	return Widgets.Track(line)
end
