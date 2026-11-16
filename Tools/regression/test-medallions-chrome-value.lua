-- test-medallions-chrome-value.lua: no Medallions chrome colour token is brighter than #5b626c (KSTY-110 section 4.1).
--
-- CaithUI's polish is a value hierarchy: its chrome never gets brighter than about 18 % grey, so fills, icons and numbers
-- are the brightest things on screen. Every med* colour in Core/Tokens.lua's COLORS block is chrome unless NOT_CHROME
-- lists it (text may be bright). A colour counts as it lands on black: each channel times its alpha must stay at or
-- under the ceiling's channel.

local TOKENS_FILE = "Core/Tokens.lua"
local CEILING = "5b626c"
local NOT_CHROME = { medText = true, medTextMuted = true }
local SPEC = {
	"medOutline", "medRimLit", "medRimLow", "medTopLine", "medFillTop", "medFillBottom", "medSocketRim", "medSocketTop",
	"medSocket", "medSocketLip", "medGunLit", "medGunDark", "medGunHair", "medCardFill", "medChatFill", "medCardHeaderTop",
	"medCardHeaderBottom", "medCardDivider", "medText", "medTextMuted",
}

local function channels(hex)
	return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

local function colorsBlock(text)
	local body = text:match("\nlocal COLORS = {\r?\n(.-)\r?\n}")
	assert(body, TOKENS_FILE .. " has no COLORS block")
	return body
end

local function parse(body)
	local found, lines = {}, 0
	for line in (body .. "\n"):gmatch("([^\n]*)\n") do
		if line:match("^\tmed%w+ = ") then
			lines = lines + 1
			local name, hex, alpha = line:match('^\t(med%w+) = { "(%x%x%x%x%x%x)", ([%d%.]+) },\r?$')
			assert(name, "cannot read this Medallions colour token; keep the { \"rrggbb\", alpha } form: " .. line)
			found[name] = { hex = hex:lower(), alpha = tonumber(alpha) }
		end
	end
	return found, lines
end

local function brighter(spec, ceiling)
	local c = channels(spec.hex)
	for i = 1, 3 do
		if c[i] * spec.alpha > ceiling[i] + 1e-9 then
			return true
		end
	end
	return false
end

local function check(found, ceiling)
	local over = {}
	for name, spec in pairs(found) do
		if not NOT_CHROME[name] and brighter(spec, ceiling) then
			over[#over + 1] = string.format("%s = #%s at %.2f", name, spec.hex, spec.alpha)
		end
	end
	table.sort(over)
	return over
end

local handle = assert(io.open(TOKENS_FILE, "rb"))
local text = handle:read("*a")
handle:close()

local found, lines = parse(colorsBlock(text))
local count = 0
for _ in pairs(found) do
	count = count + 1
end
assert(count == lines, "two Medallions colour tokens share a name")
for _, name in ipairs(SPEC) do
	assert(found[name], TOKENS_FILE .. " lacks the KSTY-110 chrome token " .. name)
end

local ceiling = channels(CEILING)
local over = check(found, ceiling)
assert(#over == 0, "Medallions chrome brighter than #" .. CEILING .. " (only text, fills, icons and art may be):\n  " .. table.concat(over, "\n  "))

local planted = check({ medPlanted = { hex = "5c626c", alpha = 1 }, medFaint = { hex = "ffffff", alpha = 0.4 } }, ceiling)
assert(#planted == 2, "the check must catch a channel one step over the ceiling and a bright colour at low alpha")
assert(#check({ medEdge = { hex = "6b7380", alpha = 0.4 }, medText = { hex = "ffffff", alpha = 1 } }, ceiling) == 0, "a dim hairline and a text colour pass")

print(string.format("ok: %d Medallions colour tokens, every chrome one at or under #%s", count, CEILING))
