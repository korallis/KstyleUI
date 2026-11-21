-- Stats.lua: character stats as text at the top left, a Layout element: the stats the player picks in their order, ratings as a percentage, the rating or both, and the frame rate and latency. Each value comes from one game call and goes straight to the font string, never compared, so a value the game makes secret in combat still shows, except spell power: the lowest of the magic schools, as the character sheet shows it, blank while any school is secret; ratings are read only when shown; fonts and formats change on settings, values on the events that change stats, and the frame rate and latency on a ticker that runs only while one of them shows.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets, Tokens = K.Widgets, K.Tokens

local OWNER, KEY = "QoL.stats", "qol.stats"
local WIDTH, GAP = 170, 2
local SHOWN = { crit = true, spellCrit = true, haste = true, spellPower = true, armour = true }
local EVENTS = { "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" }
local UNIT_EVENTS = { "UNIT_STATS", "UNIT_RESISTANCES", "UNIT_ATTACK_SPEED", "UNIT_AURA" }

local function SpellPower()
	local low
	for school = 2, ns.Number(MAX_SPELL_SCHOOLS) or 7 do
		local value = ns.Number(GetSpellBonusDamage(school))
		if not value then return nil end
		low = math.min(low or value, value)
	end
	return low
end

local STATS = {
	{ "strength", L["Strength"], L["Str"], "UnitStat", { "player", 1 }, 2 },
	{ "agility", L["Agility"], L["Agi"], "UnitStat", { "player", 2 }, 2 },
	{ "stamina", L["Stamina"], L["Sta"], "UnitStat", { "player", 3 }, 2 },
	{ "intellect", L["Intellect"], L["Int"], "UnitStat", { "player", 4 }, 2 },
	{ "spirit", L["Spirit"], L["Spi"], "UnitStat", { "player", 5 }, 2 },
	{ "crit", L["Critical strike"], L["Crit"], "GetCritChance", {}, 1, "CR_CRIT_MELEE" },
	{ "spellCrit", L["Spell critical strike"], L["Spell crit"], "GetSpellCritChance", {}, 1, "CR_CRIT_SPELL" },
	{ "haste", L["Haste"], L["Haste"], "GetMeleeHaste", {}, 1, "CR_HASTE_MELEE" },
	{ "spellPower", L["Spell power"], L["SP"], "GetSpellBonusDamage", {}, 1, read = SpellPower },
	{ "healing", L["Healing"], L["Heal"], "GetSpellBonusHealing", {}, 1 },
	{ "dodge", L["Dodge"], L["Dodge"], "GetDodgeChance", {}, 1, "CR_DODGE" },
	{ "parry", L["Parry"], L["Parry"], "GetParryChance", {}, 1, "CR_PARRY" },
	{ "block", L["Block"], L["Block"], "GetBlockChance", {}, 1, "CR_BLOCK" },
	{ "armour", L["Armour"], L["Arm"], "UnitArmor", { "player" }, 2 },
	{ "fps", L["Frame rate"], L["FPS"], "GetFramerate", {}, 1, fmt = "%d", sample = 60 },
	{ "home", L["Home latency"], L["Home"], "GetNetStats", {}, 3, fmt = "%d ms", net = true, sample = 42 },
	{ "world", L["World latency"], L["World"], "GetNetStats", {}, 4, fmt = "%d ms", net = true, sample = 58 },
}
local BY = {}
ns.defaults.statsList = {}
for i, stat in ipairs(STATS) do
	BY[stat[1]] = stat
	ns.defaults.statsList[i] = { id = stat[1], shown = SHOWN[stat[1]] == true, zone = "left" }
end

local holder, ticker

function ns.StatOptions()
	local options = { zones = false }
	for i, stat in ipairs(STATS) do options[i] = { value = stat[1], label = stat[2], rows = {} } end
	return options
end

function ns.StatList()
	local saved, out, seen = K.Store.Module(ns.MODULE).statsList, {}, {}
	if type(saved) ~= "table" or ns.IsSecret(saved) then saved = ns.defaults.statsList end
	for _, list in ipairs({ saved, ns.defaults.statsList }) do
		for _, entry in ipairs(list) do
			local id = type(entry) == "table" and entry.id
			if BY[id] and not seen[id] then
				seen[id] = true
				out[#out + 1] = { id = id, shown = list == saved and entry.shown == true }
			end
		end
	end
	return out
end

function ns.ReadStat(stat, which)
	local fn = stat.read or _G[stat[4]]
	if type(fn) ~= "function" then return nil end
	return select(stat[6], fn(unpack(stat[5]))), which ~= "percent" and stat[7] and GetCombatRating(_G[stat[7]])
end

local function Hex(name)
	local r, g, b = Tokens.Color(name)
	return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function ns.StyleStats(frame, read)
	local size = Tokens.Size("lootText") * ns.Get("statsScale") / 100
	local path = Tokens.Font("body")
	local mode, short = ns.Get("statsValue"), ns.Get("statsShort")
	local label, value = Hex("text"), Hex(ns.Get("statsColored") and "accent" or "textEmphasis")
	local count, height = 0, 0
	frame.read = read
	for _, entry in ipairs(ns.StatList()) do
		local stat = entry.shown and BY[entry.id]
		if stat and type(_G[stat[4]]) == "function" then
			count = count + 1
			local text = frame.lines[count] or Widgets.FontString(frame, "OVERLAY")
			frame.lines[count] = text
			Widgets.ApplyFont(text, path, size, "OUTLINE")
			local rated = stat[7] and type(_G[stat[7]]) == "number" and type(GetCombatRating) == "function"
			text.stat, text.which = stat, stat[7] and (rated and mode or "percent")
			local shown = text.which == "rating" and "%d" or text.which == "both" and "%.2f%% (%d)" or text.which == "percent" and "%.2f%%" or "%d"
			local name = (short and stat[3] or stat[2]):gsub("%%", "%%%%")
			text.format = (stat.net and not ns.Get("statsNetLabels") and "" or "|cff" .. label .. name .. "|r  ") .. "|cff" .. value .. (stat.fmt or shown) .. "|r"
			height = Widgets.LineHeight(text)
			text:ClearAllPoints()
			Widgets.Point(text, "TOPLEFT", frame, "TOPLEFT", 0, -(count - 1) * (height + GAP))
			text:Show()
		end
	end
	frame.count = count
	for i = count + 1, #frame.lines do frame.lines[i]:Hide() end
	Widgets.Size(frame, WIDTH * ns.Get("statsScale") / 100, math.max(height, count * (height + GAP) - GAP))
end

function ns.FillStats(frame)
	for i = 1, frame.count or 0 do
		local text = frame.lines[i]
		local amount, rating = frame.read(text.stat, text.which)
		if text.which == "rating" then amount = rating end
		if not ns.IsSecret(amount) and amount == nil or text.which == "both" and not ns.IsSecret(rating) and rating == nil then
			text:SetText("")
		else
			text:SetFormattedText(text.format, amount, rating)
		end
	end
end

local function Fill()
	if holder and holder:IsShown() then ns.FillStats(holder) end
end

local function Sync()
	local on = ns.running and ns.Get("stats")
	for _, event in ipairs(EVENTS) do
		if on then K.Events.Register(OWNER, event, Fill) else K.Events.Unregister(OWNER, event) end
	end
	for _, event in ipairs(UNIT_EVENTS) do
		if on then K.Events.RegisterUnit(OWNER, event, Fill, "player") else K.Events.Unregister(OWNER, event) end
	end
	if on and not holder then
		holder = CreateFrame("Frame", nil, K.Scale.Root())
		holder:SetFrameStrata("BACKGROUND")
		holder.lines = {}
		holder.Restyle = function(self)
			ns.StyleStats(self, ns.ReadStat)
			Fill()
		end
		Widgets.Size(holder, WIDTH, 1)
		Widgets.Track(holder)
		Widgets.Place(holder, KEY, { anchor = "TOPLEFT", x = 16, y = -40 }, { label = L["Character stats"], module = ns.MODULE })
	end
	if ticker then ticker:Cancel() end
	ticker = nil
	if on and C_Timer and type(C_Timer.NewTicker) == "function" then
		for _, entry in ipairs(ns.StatList()) do
			if entry.shown and BY[entry.id].fmt then
				ticker = C_Timer.NewTicker(ns.Get("statsInterval"), Fill)
				break
			end
		end
	end
	if not holder then return end
	holder:SetShown(on)
	if K.Layout and K.Layout.SetLive then K.Layout.SetLive(KEY, on) end
	if on then holder:Restyle() end
end

function ns.StatsFrame() return holder end

ns.AddPart({
	name = "stats",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or type(key) == "string" and key:find("^stats") then Sync() end
	end,
})
