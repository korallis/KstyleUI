-- test-chat-format.lua: KstyleUI_Chat's text helpers: timestamps, short channel names, URL links, plain text for copying and class-coloured names.
local Load = dofile("Tools/regression/load_files.lua")
local Stubs = dofile("Tools/regression/stubs/wow.lua")

local env = Stubs.NewEnv()
env.date = os.date
Load({ "KstyleUI_Chat/Init.lua", "KstyleUI_Chat/Format.lua" }, env)
local F = env._addons.KstyleUI_Chat.Format
assert(type(F) == "table", "KstyleUI_Chat must expose its Format helpers")

local function eq(got, want, what)
	assert(got == want, what .. ":\n  got  " .. tostring(got) .. "\n  want " .. tostring(want))
end

-- Colours become |cffrrggbb escapes, rounded and clamped.
eq(F.Hex(1, 0.5, 0), "ffff8000", "hex rounds to the nearest byte")
eq(F.Hex(2, -1, 0.2), "ffff0033", "hex clamps each channel")
eq(F.Wrap("x", 1, 1, 1), "|cffffffffx|r", "wrap colours text")
eq(F.Wrap("x"), "x", "wrap without a colour leaves the text alone")

-- Timestamps: a whitelisted format, in brackets, coloured, with one space after.
local when = os.time({ year = 2026, month = 11, day = 7, hour = 14, min = 31, sec = 5 })
eq(F.Timestamp("%H:%M", when), "[14:31] ", "hours and minutes")
eq(F.Timestamp("%H:%M:%S", when), "[14:31:05] ", "with seconds")
eq(F.Timestamp("%I:%M %p", when), "[02:31 PM] ", "12-hour clock")
eq(F.Timestamp("%H:%M", when, 1, 0, 0), "|cffff0000[14:31]|r ", "coloured")
eq(F.Timestamp("none", when), "", "none adds nothing")
eq(F.Timestamp("%Y %x", when), "", "a format outside the list adds nothing")
eq(F.Timestamp(nil, when), "", "no format adds nothing")
assert(#F.TIMESTAMPS >= 4 and F.TIMESTAMPS[1].value == "none", "the dropdown's choices start with none")

-- Short channel names.
local short = {
	channels = "short",
	numbers = "name",
	abbr = {
		guild = "G", officer = "O", party = "P", partyLeader = "PL", raid = "R", raidLeader = "RL",
		raidWarning = "RW", instance = "I", instanceLeader = "IL",
	},
}
local player = "|Hplayer:Thargor-Realm:42:CHANNEL:1|h[Thargor]|h"
local general = "|Hchannel:channel:1|h[1. General - Riverglades]|h " .. player .. ": LFM tank"
eq(F.Channel(general, "CHAT_MSG_CHANNEL", short), "|Hchannel:channel:1|h[1. General]|h " .. player .. ": LFM tank", "a numbered channel loses its zone")
short.numbers = "number"
eq(F.Channel(general, "CHAT_MSG_CHANNEL", short), "|Hchannel:channel:1|h[1]|h " .. player .. ": LFM tank", "number only")
short.numbers = "name"
local trade = "|Hchannel:channel:2|h[2. Trade]|h " .. player .. ": WTS"
eq(F.Channel(trade, "CHAT_MSG_CHANNEL", short), trade, "a channel without a zone keeps its name")

local guild = "|Hchannel:GUILD|h[Guild]|h " .. player .. ": hi"
eq(F.Channel(guild, "CHAT_MSG_GUILD", short), "|Hchannel:GUILD|h[G]|h " .. player .. ": hi", "guild")
local leader = "|Hchannel:PARTY|h[Party Leader]|h " .. player .. ": go"
eq(F.Channel(leader, "CHAT_MSG_PARTY_LEADER", short), "|Hchannel:PARTY|h[PL]|h " .. player .. ": go", "the event picks the abbreviation, not the link")
local gilde = "|Hchannel:GUILD|h[Gilde]|h " .. player .. ": hallo"
eq(F.Channel(gilde, "CHAT_MSG_GUILD", short), "|Hchannel:GUILD|h[G]|h " .. player .. ": hallo", "any language's channel name")
local warning = "[Raid Warning] " .. player .. ": stack"
eq(F.Channel(warning, "CHAT_MSG_RAID_WARNING", short), "[RW] " .. player .. ": stack", "a raid warning has no channel link")
local stamped = "[14:31] [Raid Warning] " .. player .. ": stack"
eq(F.Channel(stamped, "CHAT_MSG_RAID_WARNING", short), "[14:31] [RW] " .. player .. ": stack", "the bracket next to the name, not the game's own timestamp")

short.abbr.guild = ""
eq(F.Channel(guild, "CHAT_MSG_GUILD", short), player .. ": hi", "an empty abbreviation drops the channel")
short.abbr.guild = "G|cff"
eq(F.Channel(guild, "CHAT_MSG_GUILD", short), "|Hchannel:GUILD|h[Gcff]|h " .. player .. ": hi", "a typed | cannot start an escape code")
short.abbr.guild = "G"

eq(F.Channel(guild, "CHAT_MSG_SAY", short), guild, "an event without a channel is untouched")
eq(F.Channel(guild, nil, short), guild, "a line without an event is untouched")
short.channels = "full"
eq(F.Channel(guild, "CHAT_MSG_GUILD", short), guild, "full names leave the line alone")
short.channels = "short"

-- URL links: plain text only, never inside an escape sequence.
local function link(url)
	return "|H" .. F.LINK .. url .. "|h" .. url .. "|h"
end
eq(F.Linkify("see https://example.com/a?b=1 now"), "see " .. link("https://example.com/a?b=1") .. " now", "an https URL")
eq(F.Linkify("www.wowhead.com/forever"), link("www.wowhead.com/forever"), "a www address")
eq(F.Linkify("go to example.com."), "go to " .. link("example.com") .. ".", "a bare domain keeps the full stop outside")
eq(F.Linkify("(https://a.io/x)"), "(" .. link("https://a.io/x") .. ")", "brackets stay outside")
eq(F.Linkify("server 192.168.1.20:3724 up"), "server " .. link("192.168.1.20:3724") .. " up", "an IPv4 address with a port")
eq(F.Linkify("bad 300.1.1.1"), "bad 300.1.1.1", "an address over 255 is not a link")
eq(F.Linkify("e.g. this, i.e. that"), "e.g. this, i.e. that", "abbreviations are not links")
eq(F.Linkify("v1.2.3 and addon.lua"), "v1.2.3 and addon.lua", "versions and file names are not links")
eq(F.Linkify("no links here"), "no links here", "plain text is untouched")
local item = "|cffa335ee|Hitem:19019::::::::60|h[www.fake.com]|h|r"
eq(F.Linkify(item .. " http://x.com"), item .. " " .. link("http://x.com"), "an item link's text is left alone")
eq(F.Linkify("|TInterface\\Icons\\a.com:14|t x"), "|TInterface\\Icons\\a.com:14|t x", "a texture path is left alone")
eq(F.Linkify("a||b.com"), "a||" .. link("b.com"), "an escaped bar is copied as is")
eq(F.Linkify("x https://a.com", 0, 1, 0), "x |cff00ff00" .. link("https://a.com") .. "|r", "coloured links")
eq(F.Linkify("50%.com"), "50%.com", "a percent sign never reaches a pattern")
eq(F.Linkify("https://a.com/%20x"), link("https://a.com/%20x"), "percent signs in a URL survive")

-- The URL back out of a clicked link.
eq(F.URL(F.LINK .. "https://a.com/x:1"), "https://a.com/x:1", "the URL after the prefix, colons and all")
eq(F.URL("item:19019"), nil, "another link is not ours")
eq(F.URL(nil), nil, "nothing is not ours")

-- Plain text for the copy window.
eq(F.Strip("|cffff0000[14:31]|r " .. player .. ": |cff00ff00hi|r"), "[14:31] [Thargor]: hi", "colours and links go, link text stays")
eq(F.Strip("a |TInterface\\x:14|t b |A:atlas:14:14|a c"), "a  b  c", "textures and atlases go")
eq(F.Strip("x || y"), "x | y", "an escaped bar becomes one bar")
eq(F.Strip("|cnNORMAL_FONT_COLOR:named|r"), "named", "named colours go")
eq(F.Strip(link("https://a.com")), "https://a.com", "our own links become their URL")

-- Class-coloured names.
eq(F.ColorName("Thargor", 1, 0, 0), "|cffff0000Thargor|r", "a plain name")
eq(F.ColorName("|cff00ff00Thargor|r", 1, 0, 0), nil, "an already coloured name is left alone")
eq(F.ColorName(nil, 1, 0, 0), nil, "no name")

-- Decorate: the short channel, then the timestamp in front.
local opts = { channels = "short", numbers = "name", abbr = short.abbr, timestamp = "%H:%M" }
eq(F.Decorate(guild, "CHAT_MSG_GUILD", opts, when), "[14:31] |Hchannel:GUILD|h[G]|h " .. player .. ": hi", "both")
opts.timestamp = "none"
eq(F.Decorate("You receive loot.", nil, opts, when), "You receive loot.", "nothing to add")

-- Secret values pass through untouched: no pattern, no comparison, no length.
local secret = env.Secret("hidden")
eq(F.Linkify(secret), secret, "a secret line is not linkified")
eq(F.Channel(secret, "CHAT_MSG_GUILD", short), secret, "a secret line keeps its channel")
eq(F.Decorate(secret, "CHAT_MSG_GUILD", { channels = "short", numbers = "name", abbr = short.abbr, timestamp = "%H:%M" }, when), secret, "a secret line gets no timestamp")
eq(F.Strip(secret), nil, "a secret line has no plain text")
eq(F.ColorName(secret, 1, 0, 0), nil, "a secret name is left alone")
eq(F.URL(secret), nil, "a secret link is not ours")

print("chat format ok")
