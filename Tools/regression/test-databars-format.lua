-- test-databars-format.lua: the data bars' text formats: grouped and short numbers, percentages, bar texts, money and clock times.
local D = dofile("Tools/regression/databars_env.lua")

local _, _, ns = D.New({ enable = false })
local Format = ns.Format
assert(type(Format) == "table", "KstyleUI_DataBars exposes its formats as ns.Format")

local function eq(got, want, what)
	assert(got == want, string.format("%s: expected %q, got %q", what, tostring(want), tostring(got)))
end

-- Numbers ----------------------------------------------------------------------------------------

eq(Format.Number(0), "0", "zero")
eq(Format.Number(999), "999", "three digits")
eq(Format.Number(1000), "1,000", "thousands")
eq(Format.Number(12345), "12,345", "XP-sized number")
eq(Format.Number(1234567), "1,234,567", "millions")
eq(Format.Number(-4500), "-4,500", "a negative number keeps its sign")
eq(Format.Number(12.9), "12", "fractions are cut, not rounded")

eq(Format.Short(999), "999", "below a thousand stays whole")
eq(Format.Short(12345), "12.3K", "thousands with one decimal")
eq(Format.Short(50000), "50K", "no trailing .0")
eq(Format.Short(49990), "49.9K", "cut, never rounded up to the next step")
eq(Format.Short(123456), "123K", "three digits drop the decimal")
eq(Format.Short(2500000), "2.5M", "millions")
eq(Format.Short(-12345), "-12.3K", "a negative short number keeps its sign")

-- The client's own grouping wins when it has one, so separators follow the player's locale.
do
	local env, _, ns2 = D.New({ enable = false, setup = function(e)
		e.BreakUpLargeNumbers = function(n)
			return "<" .. n .. ">"
		end
	end })
	assert(env.BreakUpLargeNumbers, "the stub client has BreakUpLargeNumbers")
	eq(ns2.Format.Number(12345), "<12345>", "BreakUpLargeNumbers is used when present")
end

-- Percentages --------------------------------------------------------------------------------------

eq(Format.Percent(12345, 50000), 24, "a percentage is cut to a whole number")
eq(Format.Percent(50000, 50000), 100, "full")
eq(Format.Percent(60000, 50000), 100, "clamped at 100")
eq(Format.Percent(-5, 50000), 0, "clamped at 0")
eq(Format.Percent(10, 0), 0, "an empty range is 0%")

-- Bar texts ------------------------------------------------------------------------------------------

eq(Format.BarText("none", 12345, 50000, "Level 38"), nil, "none shows nothing")
eq(Format.BarText("percent", 12345, 50000, "Level 38"), "24%", "percent")
eq(Format.BarText("value", 12345, 50000, "Level 38"), "12,345 / 50,000", "value")
eq(Format.BarText("valuePercent", 12345, 50000, "Level 38"), "12,345 / 50,000 (24%)", "value and percent")
eq(Format.BarText("short", 12345, 50000, "Level 38"), "12.3K / 50K", "short value")
eq(Format.BarText("remaining", 12345, 50000, "Level 38"), "37,655 to go", "remaining")
eq(Format.BarText("label", 12345, 50000, "Level 38"), "Level 38", "label")
eq(Format.BarText("labelPercent", 12345, 50000, "Stormwind"), "Stormwind 24%", "label and percent")
eq(Format.BarText("labelValue", 12345, 50000, "Stormwind"), "Stormwind 12,345 / 50,000", "label and value")
eq(Format.BarText("labelPercent", 12345, 50000, nil), "24%", "a missing label leaves the percent")
-- The Lumen XP caption: "Level 8 \194\183 74% \194\183 rested 10%", the rested part only while there is rested XP.
local DOT = " \194\183 "
eq(Format.BarText("levelRested", 37000, 50000, "Level 8", "XP", 5000), "Level 8" .. DOT .. "74%" .. DOT .. "rested 10%", "level, percent and rested")
eq(Format.BarText("levelRested", 37000, 50000, "Level 8", "XP", 0), "Level 8" .. DOT .. "74%", "no rested part without rested XP")
eq(Format.BarText("levelRested", 37000, 50000, "Level 8"), "Level 8" .. DOT .. "74%", "or when the source has none")
local listed = false
for _, option in ipairs(Format.BAR_TEXTS) do
	listed = listed or option.value == "levelRested"
end
eq(listed, true, "the caption is a text choice")
eq(Format.BarText("shortPercent", 12345, 50000, "Level 38", "XP"), "XP 24%", "short name and percent: the mockup's XP 32% caption")
eq(Format.BarText("shortPercent", 12345, 50000, "Stormwind"), "Stormwind 24%", "a bar without a short name uses its label")
eq(Format.BarText("bogus", 12345, 50000, "x"), nil, "an unknown style shows nothing")

local styles = {}
for _, option in ipairs(Format.BAR_TEXTS) do
	styles[#styles + 1] = option.value
	assert(type(option.label) == "string" and option.label ~= "", option.value .. " has a label for the settings window")
end
eq(table.concat(styles, ","), "none,percent,value,valuePercent,short,remaining,label,labelPercent,labelValue,shortPercent,levelRested", "every bar text style is offered")

-- Money ---------------------------------------------------------------------------------------------

eq(Format.Money(1438217, "full"), "143g 82s 17c", "the mockup's gold")
eq(Format.Money(124837621, "full"), "12,483g 76s 21c", "gold is grouped")
eq(Format.Money(8217, "full"), "82s 17c", "no gold part below a gold")
eq(Format.Money(17, "full"), "17c", "copper only")
eq(Format.Money(0, "full"), "0c", "nothing")
eq(Format.Money(1400005, "full"), "140g 0s 5c", "inner zeros stay once gold shows")
eq(Format.Money(-50500, "full"), "-5g 5s 0c", "a loss keeps its sign")
eq(Format.Money(1438217, "gold"), "143g", "gold only")
eq(Format.Money(8217, "gold"), "82s 17c", "gold only falls back below a gold")
eq(Format.Money(1438217, "icons"), "143g 82s 17c", "coin icons fall back to letters without the client function")
do
	local _, _, ns2 = D.New({ enable = false, setup = function(e)
		e.C_CurrencyInfo = { GetCoinTextureString = function(copper)
			return "coins:" .. copper
		end }
	end })
	eq(ns2.Format.Money(1438217, "icons"), "coins:1438217", "coin icons come from the client")
end

-- Clock times ---------------------------------------------------------------------------------------

eq(Format.Clock(14, 32, true), "14:32", "24-hour clock")
eq(Format.Clock(9, 5, true), "09:05", "24-hour clock pads")
eq(Format.Clock(14, 32, false), "2:32 PM", "12-hour afternoon")
eq(Format.Clock(0, 7, false), "12:07 AM", "midnight is 12 AM")
eq(Format.Clock(12, 0, false), "12:00 PM", "noon is 12 PM")

print("databars format ok")
