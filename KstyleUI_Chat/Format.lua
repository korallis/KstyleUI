-- Format.lua: the chat's text helpers: timestamps, short channel names, URL links, plain text and class-coloured names.
local _, ns = ...

local Format = {}
ns.Format = Format

local format, floor, max, min, tonumber = string.format, math.floor, math.max, math.min, tonumber
local find, sub, gsub, match, lower = string.find, string.sub, string.gsub, string.match, string.lower
local concat = table.concat

local BYTE = 255
local MAX_OCTET = 255
local MAX_OCTET_DIGITS = 3
local COLOR_CODE_LENGTH = 9

local LINK = "addon:KstyleUI:url:"
Format.LINK = LINK

Format.TIMESTAMPS = {
	{ value = "none" },
	{ value = "%H:%M" },
	{ value = "%H:%M:%S" },
	{ value = "%I:%M %p" },
	{ value = "%I:%M:%S %p" },
	{ value = "%I:%M" },
	{ value = "%I:%M:%S" },
}
local TIMESTAMP = {}
for _, choice in ipairs(Format.TIMESTAMPS) do
	TIMESTAMP[choice.value] = true
end

function Format.IsTimestamp(fmt)
	return not Format.IsSecret(fmt) and type(fmt) == "string" and TIMESTAMP[fmt] == true
end

Format.CHANNEL_KEYS = { "guild", "officer", "party", "partyLeader", "raid", "raidLeader", "raidWarning", "instance", "instanceLeader" }

local EVENT_KEYS = {
	CHAT_MSG_GUILD = "guild",
	CHAT_MSG_OFFICER = "officer",
	CHAT_MSG_PARTY = "party",
	CHAT_MSG_PARTY_LEADER = "partyLeader",
	CHAT_MSG_RAID = "raid",
	CHAT_MSG_RAID_LEADER = "raidLeader",
	CHAT_MSG_RAID_WARNING = "raidWarning",
	CHAT_MSG_INSTANCE_CHAT = "instance",
	CHAT_MSG_INSTANCE_CHAT_LEADER = "instanceLeader",
}
local NUMBERED = { CHAT_MSG_CHANNEL = true, CHAT_MSG_COMMUNITIES_CHANNEL = true }

local TLDS = {}
for tld in ("com net org io gg tv co uk de fr eu info me app dev us ca au ru nl se no es it pl be ch at gl ly to xyz link live news wiki"):gmatch("%a+") do
	TLDS[tld] = true
end

local CLOSERS = { H = true, T = "|t", A = "|a", K = "|k" }

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end
Format.IsSecret = IsSecret

local function IsText(v)
	return not IsSecret(v) and type(v) == "string"
end

local function Byte(v)
	v = tonumber(v) or 0
	return floor(max(0, min(1, v)) * BYTE + 0.5)
end

function Format.Hex(r, g, b)
	return format("ff%02x%02x%02x", Byte(r), Byte(g), Byte(b))
end

function Format.Wrap(text, r, g, b)
	if r == nil then
		return text
	end
	return "|c" .. Format.Hex(r, g, b) .. text .. "|r"
end

function Format.Timestamp(fmt, when, r, g, b)
	if fmt == "none" or not TIMESTAMP[fmt] or type(date) ~= "function" then
		return ""
	end
	if when == nil and type(time) == "function" then
		when = time()
	end
	local ok, text = pcall(date, fmt, when)
	if not ok or not IsText(text) then
		return ""
	end
	return Format.Wrap("[" .. text .. "]", r, g, b) .. " "
end

local function CodeEnd(text, bar, len)
	local kind = sub(text, bar + 1, bar + 1)
	if kind == "H" then
		local mid = find(text, "|h", bar + 2, true)
		local close = mid and find(text, "|h", mid + 2, true)
		return close and close + 1 or len
	end
	local closer = CLOSERS[kind]
	if closer then
		local close = find(text, closer, bar + 2, true)
		return close and close + 1 or len
	end
	if kind == "c" then
		if sub(text, bar + 2, bar + 2) == "n" then
			return find(text, ":", bar + 3, true) or len
		end
		return min(bar + COLOR_CODE_LENGTH, len)
	end
	if kind == "" then
		return bar
	end
	return bar + 1
end

local function Rewrite(text, plain, code)
	local out, n, pos, len = {}, 0, 1, #text
	while pos <= len do
		local bar = find(text, "|", pos, true)
		if not bar then
			n = n + 1
			out[n] = plain(sub(text, pos))
			break
		end
		if bar > pos then
			n = n + 1
			out[n] = plain(sub(text, pos, bar - 1))
		end
		local stop = CodeEnd(text, bar, len)
		n = n + 1
		out[n] = code(sub(text, bar, stop))
		pos = stop + 1
	end
	return concat(out)
end

local function Same(text)
	return text
end

local function IsIPv4(host)
	local a, b, c, d = match(host, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	if not a then
		return false
	end
	for _, octet in ipairs({ a, b, c, d }) do
		if #octet > MAX_OCTET_DIGITS or tonumber(octet) > MAX_OCTET then
			return false
		end
	end
	return true
end

local function IsHost(host)
	if not find(host, ".", 1, true) or find(host, "..", 1, true) or sub(host, 1, 1) == "." then
		return false
	end
	local tld = match(host, "%.(%a+)$")
	return tld ~= nil and TLDS[lower(tld)] == true
end

local function IsURL(core)
	local l = lower(core)
	if match(l, "^https?://[%w%[]") or match(l, "^ftp://%w") or match(l, "^www%.[%w%-]+%.%a") then
		return true
	end
	local host, rest = match(core, "^([%w%-%.]+)(.*)$")
	if not host then
		return false
	end
	if rest ~= "" then
		local first = sub(rest, 1, 1)
		if first == ":" then
			if not match(rest, "^:%d+") then
				return false
			end
		elseif first ~= "/" and first ~= "?" and first ~= "#" then
			return false
		end
	end
	return IsIPv4(host) or IsHost(host)
end

local linkR, linkG, linkB

local function LinkWord(word)
	local lead, core, trail = match(word, "^([%(%[\"']*)(.-)([%.,!?;:%)%]\"']*)$")
	if not core or core == "" or not IsURL(core) then
		return word
	end
	return lead .. Format.Wrap("|H" .. LINK .. core .. "|h" .. core .. "|h", linkR, linkG, linkB) .. trail
end

local function LinkPlain(run)
	return (gsub(run, "%S+", LinkWord))
end

function Format.Linkify(text, r, g, b)
	if not IsText(text) or not find(text, ".", 1, true) then
		return text
	end
	linkR, linkG, linkB = r, g, b
	return Rewrite(text, LinkPlain, Same)
end

function Format.URL(link)
	if not IsText(link) or sub(link, 1, #LINK) ~= LINK then
		return nil
	end
	local url = sub(link, #LINK + 1)
	if url == "" then
		return nil
	end
	return url
end

local function StripCode(code)
	local kind = sub(code, 2, 2)
	if kind == "H" then
		local shown = match(code, "^|H.-|h(.*)|h$")
		return shown and Rewrite(shown, Same, StripCode) or ""
	elseif kind == "|" then
		return "|"
	elseif kind == "n" then
		return "\n"
	end
	return ""
end

function Format.Strip(text)
	if not IsText(text) then
		return nil
	end
	return Rewrite(text, Same, StripCode)
end

function Format.ColorName(name, r, g, b)
	if not IsText(name) or find(name, "|c", 1, true) then
		return nil
	end
	return Format.Wrap(name, r, g, b)
end

local numberOnly = false

local function ShortChannel(prefix, inner, suffix)
	local number, rest = match(inner, "^(%d+)%.%s*(.*)$")
	if not number then
		return nil
	end
	if numberOnly then
		return prefix .. "[" .. number .. "]" .. suffix
	end
	local name = match(rest, "^(.-)%s+%-%s+.+$") or rest
	return prefix .. "[" .. number .. ". " .. name .. "]" .. suffix
end

local function Drop(message, s, e)
	if sub(message, e + 1, e + 1) == " " then
		e = e + 1
	end
	return sub(message, 1, s - 1) .. sub(message, e + 1)
end

function Format.Channel(message, event, opts)
	if not IsText(message) or not IsText(event) or type(opts) ~= "table" or opts.channels ~= "short" then
		return message
	end
	if NUMBERED[event] then
		numberOnly = opts.numbers == "number"
		return (gsub(message, "(|Hchannel:channel:%d+|h)%[([^%]|]*)%](|h)", ShortChannel, 1))
	end
	local key = EVENT_KEYS[event]
	local abbr = key and type(opts.abbr) == "table" and opts.abbr[key]
	if not IsText(abbr) then
		return message
	end
	abbr = gsub(abbr, "[|%[%]]", "")
	local s, e, head, tail = find(message, "(|Hchannel:[^|]*|h)%[[^%]|]*%](|h)")
	if s then
		if abbr == "" then
			return Drop(message, s, e)
		end
		return sub(message, 1, s - 1) .. head .. "[" .. abbr .. "]" .. tail .. sub(message, e + 1)
	end
	local sender = find(message, "|Hplayer:", 1, true)
	if not sender then
		return message
	end
	local bs, be = find(sub(message, 1, sender - 1), "%[[^%]|]*%]%s*$")
	if not bs then
		return message
	end
	local close = find(message, "]", bs, true)
	if abbr == "" then
		return sub(message, 1, bs - 1) .. sub(message, be + 1)
	end
	return sub(message, 1, bs - 1) .. "[" .. abbr .. "]" .. sub(message, close + 1)
end

function Format.Decorate(message, event, opts, when)
	if not IsText(message) or type(opts) ~= "table" then
		return message
	end
	local out = Format.Channel(message, event, opts)
	local c = opts.timestampColor
	local r, g, b
	if type(c) == "table" then
		r, g, b = c.r, c.g, c.b
	end
	return Format.Timestamp(opts.timestamp, when, r, g, b) .. out
end
