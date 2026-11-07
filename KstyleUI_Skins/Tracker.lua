-- Tracker.lua: the objective tracker skin: a glass panel, caption headers over accent lines, the skin font and KstyleUI progress bars.
local _, ns = ...

local K = KstyleUI
local Skin, Tokens, L = K.Skin, K.Tokens, K.L
local Style, Parts, Skins = ns.Style, ns.Parts, ns.Skins

local KEY = "tracker"
local LINE_DEFAULT, HEADER_EXTRA = 12, 2
local PANEL_OUTSET = -8
local LINE_ALPHA = 0.6

local WEAK = { __mode = "k" }
local done = setmetatable({}, WEAK)
local fonts = {}
local panel

local function Log(message)
	K.DevTest.Log("Skins", KEY .. ": " .. message)
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function PlainSize(value)
	if IsSecret(value) or type(value) ~= "number" or value <= 0 then
		return nil
	end
	return value
end

local function PaintFont(entry)
	local object = entry.object
	local path, _, flags = Style.Font(entry.role)
	object:SetFont(path, entry.size * Style.Setting("text", "size"), flags)
	if flags == "" then
		object:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		object:SetShadowOffset(offset, -offset)
	else
		object:SetShadowOffset(0, 0)
	end
end

local function PaintFonts()
	if not Skins.Setting(KEY, "font") then
		return
	end
	for _, entry in ipairs(fonts) do
		PaintFont(entry)
	end
end

local function WatchFont(name, role, fallback)
	local object = _G[name]
	if type(object) ~= "table" or type(object.SetFont) ~= "function" or type(object.GetFont) ~= "function" then
		Log(name .. " is missing on this client; the tracker keeps Blizzard's font")
		return
	end
	local _, size = object:GetFont()
	local entry = { object = object, role = role, size = PlainSize(size) or fallback }
	fonts[#fonts + 1] = entry
	if type(object.SetFontObject) == "function" then
		hooksecurefunc(object, "SetFontObject", function(_, source)
			local sourceName = source
			if type(source) == "table" and type(source.GetName) == "function" then
				sourceName = source:GetName()
			end
			local picked = type(sourceName) == "string" and tonumber(sourceName:match("(%d+)$"))
			if picked then
				entry.size = picked
			end
			if Skins.Setting(KEY, "font") then
				PaintFont(entry)
			end
		end)
	end
end

local restyler = { Restyle = PaintFonts }

local function Header(header)
	if type(header) ~= "table" or done[header] then
		return
	end
	done[header] = true
	Parts.Hush(header.Background)
	Parts.Hush(header.Shine)
	Parts.Hush(header.Glow)
	if header.Text then
		Style.Text(header.Text, "caption", "textEmphasis")
	end
	Parts.AccentLine(header, { alpha = LINE_ALPHA })
end

local function ProgressBar(holder)
	local bar = type(holder) == "table" and holder.Bar
	if type(bar) ~= "table" or done[bar] then
		return
	end
	done[bar] = true
	local keep = {}
	local fill = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
	if Parts.IsTexture(fill) then
		keep[fill] = true
	end
	Skin.Strip(bar, { keep = keep })
	Skin.Backdrop(bar, { shape = "tile", fill = "track", shadow = false })
	Style.StatusBar(bar)
	if bar.Label then
		Style.Text(bar.Label, "caption", "textEmphasis")
	end
end

local function ProgressBars(module)
	if type(module.usedProgressBars) == "table" then
		for _, holder in pairs(module.usedProgressBars) do
			ProgressBar(holder)
		end
	end
end

local function Module(module)
	if type(module) ~= "table" or done[module] then
		return
	end
	done[module] = true
	Header(module.Header)
	if type(module.GetProgressBar) == "function" then
		hooksecurefunc(module, "GetProgressBar", ProgressBars)
	end
	ProgressBars(module)
end

local function PaintPanel()
	if panel then
		panel:SetShown(Skins.Setting(KEY, "panel") == true)
	end
end

local function Apply()
	local tracker = _G.ObjectiveTrackerFrame
	Skin.Strip(tracker, { children = { "NineSlice" } })
	panel = Skin.Backdrop(tracker, { shape = "panel", fill = "surface", inset = PANEL_OUTSET })
	PaintPanel()
	Header(tracker.Header)
	if type(tracker.ForEachModule) == "function" then
		tracker:ForEachModule(Module)
	else
		Log("ForEachModule is missing; module headers keep Blizzard's look")
	end
	if type(tracker.AddModule) == "function" then
		hooksecurefunc(tracker, "AddModule", function(_, module)
			Module(module)
		end)
	end
	WatchFont("ObjectiveTrackerLineFont", "body", LINE_DEFAULT)
	WatchFont("ObjectiveTrackerHeaderFont", "heading", LINE_DEFAULT + HEADER_EXTRA)
	PaintFonts()
	Style.Track(restyler)
end

local function OnSetting(_, field)
	if field == nil or field == "panel" then
		PaintPanel()
	end
	if field == nil or field == "font" then
		PaintFonts()
	end
end

Skins.Add({
	key = KEY,
	label = L["Objective tracker"],
	help = L["Restyles the quest and objective tracker beside the minimap."],
	addon = "Blizzard_ObjectiveTracker",
	frame = "ObjectiveTrackerFrame",
	defaults = { panel = true, font = true },
	rows = {
		{
			type = "toggle", key = "panel", label = L["Glass panel"],
			help = L["Draws a KstyleUI glass panel behind the tracker."],
		},
		{
			type = "toggle", key = "font", label = L["Skin font"],
			help = L["Uses the skin's font for tracker text. Turning it off needs a reload."],
		},
	},
	Apply = Apply,
	OnSetting = OnSetting,
})
