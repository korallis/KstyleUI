-- Format.lua: what a UNIT_COMBAT event shows (damage, a heal or a word), with its colour, size and text, without comparing a secret.
local _, ns = ...

local K = KstyleUI
local L = K.L

local Format = {}
ns.Format = Format

local HEAL_FORMAT = "+%s"
local GLANCE_SCALE = 0.8
local WORD_EVENTS = {
	MISS = true, DODGE = true, PARRY = true, BLOCK = true, EVADE = true, IMMUNE = true,
	DEFLECT = true, ABSORB = true, REFLECT = true, RESIST = true, INTERRUPT = true,
}
local AVOIDED = { ABSORB = true, BLOCK = true, RESIST = true }
local EMPHASIS = { CRITICAL = "crit", CRUSHING = "crit", GLANCING = "glance" }
local FALLBACK_WORDS = {
	MISS = L["Miss"], DODGE = L["Dodge"], PARRY = L["Parry"], BLOCK = L["Block"], EVADE = L["Evade"],
	IMMUNE = L["Immune"], DEFLECT = L["Deflect"], ABSORB = L["Absorb"], REFLECT = L["Reflect"],
	RESIST = L["Resist"], INTERRUPT = L["Interrupt"],
}

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
Format.IsSecret = IsSecret

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log("CombatText", message)
	end
end

local words
local function Words()
	if not words then
		words = {
			MISS = MISS, DODGE = DODGE, PARRY = PARRY, BLOCK = BLOCK, EVADE = EVADE, IMMUNE = IMMUNE,
			DEFLECT = DEFLECT, ABSORB = ABSORB, REFLECT = REFLECT, RESIST = RESIST, INTERRUPT = INTERRUPT,
		}
		for key, fallback in pairs(FALLBACK_WORDS) do
			if IsSecret(words[key]) or type(words[key]) ~= "string" then
				words[key] = fallback
			end
		end
	end
	return words
end

local function PlainFlag(flag)
	if not IsSecret(flag) and type(flag) == "string" then
		return flag
	end
	return ""
end

function Format.Classify(event, flag, amount)
	local secretAmount = IsSecret(amount)
	if IsSecret(event) then
		if secretAmount or type(amount) == "number" then
			return "neutral", "none", nil
		end
		return nil
	end
	if type(event) ~= "string" then
		return nil
	end
	local flagText = PlainFlag(flag)
	if event == "WOUND" then
		if secretAmount then
			if AVOIDED[flagText] then
				return "miss", "none", flagText
			end
		elseif type(amount) ~= "number" then
			return nil
		elseif amount == 0 then
			return "miss", "none", AVOIDED[flagText] and flagText or "MISS"
		end
		return "damage", EMPHASIS[flagText] or "none", nil
	elseif event == "HEAL" then
		if not secretAmount and (type(amount) ~= "number" or amount == 0) then
			return nil
		end
		return "heal", flagText == "CRITICAL" and "crit" or "none", nil
	elseif WORD_EVENTS[event] then
		return "miss", "none", event
	end
	return nil
end

function Format.Text(fontString, cfg, kind, amount, word)
	if word then
		fontString:SetText(Words()[word] or word)
		return
	end
	local formatter = cfg.formatter
	if formatter then
		local ok, text = pcall(formatter, amount)
		if ok then
			if kind == "heal" then
				fontString:SetFormattedText(HEAL_FORMAT, text)
			else
				fontString:SetText(text)
			end
			return
		end
		LogOnce("formatter", "the number formatter failed (" .. tostring(text) .. "); numbers show unformatted")
	else
		LogOnce("noformatter", "AbbreviateNumbers and BreakUpLargeNumbers are missing; numbers show unformatted")
	end
	fontString:SetText(amount)
end

function Format.Color(cfg, kind, emphasis, school)
	if kind == "heal" then
		return cfg.healR, cfg.healG, cfg.healB
	elseif kind ~= "damage" then
		return cfg.missR, cfg.missG, cfg.missB
	end
	if emphasis == "crit" and cfg.critColor then
		return cfg.critR, cfg.critG, cfg.critB
	end
	if cfg.colorMode == "school" then
		local icons = K.Icons
		local schoolColor = icons and icons.SchoolColor
		if schoolColor then
			local r, g, b = schoolColor(school)
			if r then
				return r, g, b
			end
		end
	end
	return cfg.damageR, cfg.damageG, cfg.damageB
end

function Format.Scale(cfg, emphasis)
	if emphasis == "crit" then
		return cfg.critScale
	elseif emphasis == "glance" then
		return GLANCE_SCALE
	end
	return 1
end
