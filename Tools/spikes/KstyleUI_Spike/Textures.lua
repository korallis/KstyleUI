-- Textures.lua: the textures spike shows the spike PNGs as textures and as masks, and records whether each loaded.
local _, ns = ...

local MEDIA = "Interface\\AddOns\\KstyleUI_Spike\\Media\\"
local TILE = 256
local GAP = 24
local TOP = 56
local CAPTION_HEIGHT = 72
local SHOT_DELAY = 1
local TILES = {
	{ key = "mask", file = "mask_2048.png", caption = "mask_2048.png\nas a texture" },
	{ key = "alpha", file = "alpha_test.png", caption = "alpha_test.png\nas a texture" },
	{ key = "maskedByAlpha", mask = "alpha_test.png", caption = "Solid colour masked\nby alpha_test.png" },
	{ key = "maskedByMask", mask = "mask_2048.png", caption = "Solid colour masked\nby mask_2048.png" },
}
local HINT = "Tile 3 fading left to right means masks read alpha. Fading top to bottom means they read colour."

local function Inspect(target, setReturn)
	return {
		setReturn = tostring(setReturn),
		texture = ns.Describe(target:GetTexture()),
		path = ns.Describe(target:GetTextureFilePath()),
		fileID = ns.Describe(target:GetTextureFileID()),
		loaded = ns.Describe(target:IsObjectLoaded()),
	}
end

local function Build(panel)
	panel.tiles = {}
	for i, tile in ipairs(TILES) do
		local x = GAP + (i - 1) * (TILE + GAP)
		local texture = panel:CreateTexture(nil, "ARTWORK")
		texture:SetSize(TILE, TILE)
		texture:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -TOP)
		local caption = ns.Text(panel, "GameFontHighlightSmall")
		caption:SetPoint("TOPLEFT", texture, "BOTTOMLEFT", 0, -8)
		caption:SetText(tile.caption)
		local entry = { tile = tile, texture = texture }
		if tile.file then
			entry.setReturn = texture:SetTexture(MEDIA .. tile.file)
			entry.target = texture
		else
			texture:SetColorTexture(0.31, 0.76, 1, 1)
			local mask = panel:CreateMaskTexture()
			mask:SetAllPoints(texture)
			entry.setReturn = mask:SetTexture(MEDIA .. tile.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			texture:AddMaskTexture(mask)
			entry.target = mask
		end
		panel.tiles[#panel.tiles + 1] = entry
	end
	local hint = ns.Text(panel, "GameFontNormal")
	hint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", GAP, 14)
	hint:SetText(HINT)
end

ns.Register("textures", {
	group = "basic",
	summary = "shows a 2048x2048 PNG and an alpha test PNG as textures and as masks, and takes a screenshot.",
	Run = function(run)
		local width = GAP + #TILES * (TILE + GAP)
		local panel = ns.Panel("textures", "Textures and masks", width, TOP + TILE + CAPTION_HEIGHT + 40)
		if not panel.tiles then
			Build(panel)
		end
		local textures = {}
		run:Set("textures", textures)
		ns.After(0, function()
			for _, entry in ipairs(panel.tiles) do
				textures[entry.tile.key] = Inspect(entry.target, entry.setReturn)
			end
			run:Set("measured", true)
		end)
		ns.Later(SHOT_DELAY, function() ns.Screenshot(run) end)
		run:Note("panel open. It takes a screenshot in " .. SHOT_DELAY .. " s. Then type /kspike hide.")
	end,
})
