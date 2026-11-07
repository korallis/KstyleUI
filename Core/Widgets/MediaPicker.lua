-- MediaPicker.lua: font and texture pickers listing KstyleUI's own media, then LibSharedMedia's when it is loaded.
local _, ns = ...

local Widgets = ns.Widgets
local Tokens = ns.Tokens

local LSM_MAJOR = "LibSharedMedia-3.0"
local SAMPLE_WIDTH = 64
local SAMPLE_INSET = 6

local function SharedMedia()
	local libstub = rawget(_G, "LibStub")
	if libstub == nil then
		return nil
	end
	local ok, lib = pcall(libstub, LSM_MAJOR, true)
	if ok and type(lib) == "table" and type(lib.List) == "function" and type(lib.Fetch) == "function" then
		return lib
	end
	return nil
end

local function Key(path)
	if type(path) == "string" then
		return path:lower():gsub("/", "\\")
	end
	return path
end

function Widgets.MediaOptions(kind)
	local out, seen = {}, {}
	local function add(path, label)
		local key = Key(path)
		if key ~= nil and not seen[key] then
			seen[key] = true
			out[#out + 1] = { value = path, label = label }
		end
	end
	local ok, own = pcall(Tokens.MediaList, kind)
	if ok then
		for _, item in ipairs(own) do
			add(item.path, item.label)
		end
	end
	local lib = SharedMedia()
	if lib then
		local listed, names = pcall(lib.List, lib, kind)
		if listed and type(names) == "table" then
			for _, name in ipairs(names) do
				local fetched, path = pcall(lib.Fetch, lib, kind, name)
				local usable = type(path) == "string" or (kind ~= "font" and type(path) == "number")
				if fetched and usable and type(name) == "string" then
					add(path, name)
				end
			end
		end
	end
	return out
end

local function FileName(path)
	if type(path) == "string" then
		return path:match("([^\\/]+)$") or path
	end
	return tostring(path)
end

local function Picker(parent, opts, kind, renderRow)
	local merged = {}
	for k, v in pairs(opts or {}) do
		merged[k] = v
	end
	merged.options = function()
		return Widgets.MediaOptions(kind)
	end
	merged.renderRow = renderRow
	merged.unknownLabel = FileName
	return Widgets.Dropdown(parent, merged)
end

local function FontRow(row, option)
	local _, size, flags = Tokens.Font("body")
	if row.label:SetFont(option.value, size, flags) == false then
		Widgets.StyleText(row.label, "body")
	end
end

local function TextureRow(row, option)
	local sample = row.sample
	local inset = Widgets.Snap(row, SAMPLE_INSET)
	sample:SetTexture(option.value)
	sample:ClearAllPoints()
	sample:SetPoint("TOPLEFT", row, "TOPLEFT", Widgets.Snap(row, Tokens.Size("gapMedium")), -inset)
	sample:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", Widgets.Snap(row, Tokens.Size("gapMedium")), inset)
	sample:SetWidth(Widgets.Snap(row, SAMPLE_WIDTH))
	Widgets.Tint(sample, "accent")
	sample:Show()
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", sample, "RIGHT", Widgets.Snap(row, Tokens.Size("gapMedium")), 0)
	row.label:SetPoint("RIGHT", row, "RIGHT", -Widgets.Snap(row, Tokens.Size("gapMedium")), 0)
end

function Widgets.FontPicker(parent, opts)
	return Picker(parent, opts, "font", FontRow)
end

function Widgets.TexturePicker(parent, opts)
	return Picker(parent, opts, (opts and opts.kind) or "statusbar", TextureRow)
end
