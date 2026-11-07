-- Logic.lua: the Meters module's pure rules: readable numbers, percentages, swing progress, threat sorting and threat warnings.
local _, ns = ...

local Logic = {}
ns.Logic = Logic

local floor, max, format = math.floor, math.max, string.format
local HUGE = math.huge
local THREAT_UNITS = 100
local NO_WARNING, WARNING, DANGER = 0, 1, 2

Logic.NO_WARNING, Logic.WARNING, Logic.DANGER = NO_WARNING, WARNING, DANGER

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end
Logic.IsSecret = IsSecret

function Logic.Plain(value)
	if IsSecret(value) or type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == HUGE or value == -HUGE then
		return nil
	end
	return value
end
local Plain = Logic.Plain

function Logic.Percent(part, total)
	part, total = Plain(part), Plain(total)
	if not part or not total or total <= 0 then
		return nil
	end
	return floor(part / total * 100 + 0.5)
end

function Logic.FormatPercent(percent)
	if not Plain(percent) then
		return ""
	end
	return format("%d%%", percent)
end

function Logic.FormatSeconds(seconds)
	if not Plain(seconds) then
		return ""
	end
	return format("%.1f", seconds)
end

function Logic.Abbreviate(value)
	if IsSecret(value) then
		if type(AbbreviateNumbers) == "function" then
			return AbbreviateNumbers(value)
		end
		return ""
	end
	value = Plain(value)
	if not value then
		return ""
	end
	if type(AbbreviateNumbers) == "function" then
		return AbbreviateNumbers(value)
	end
	return format("%d", floor(value + 0.5))
end

function Logic.SwingProgress(start, duration, now)
	start, duration, now = Plain(start), Plain(duration), Plain(now)
	if not start or not duration or not now or duration <= 0 then
		return nil
	end
	local elapsed = now - start
	if elapsed < 0 then
		elapsed = 0
	end
	if elapsed >= duration then
		return 1, 0, true
	end
	return elapsed / duration, duration - elapsed, false
end

function Logic.FitRows(available, rowHeight, spacing)
	local step = rowHeight + spacing
	if step <= 0 or available < rowHeight then
		return 0
	end
	return floor((available + spacing) / step)
end

function Logic.Split(total, count, gap)
	if count <= 0 then
		return 0
	end
	return max(0, (total - (count - 1) * gap) / count)
end

function Logic.ThreatAmount(raw)
	raw = Plain(raw)
	if not raw then
		return nil
	end
	return raw / THREAT_UNITS
end

local function Before(a, b)
	a, b = Plain(a), Plain(b)
	if not a then
		return false
	end
	if not b then
		return true
	end
	return a > b
end

function Logic.SortRows(rows, order, count, field)
	for i = 1, count do
		if IsSecret(rows[order[i]][field]) then
			return false
		end
	end
	for i = 2, count do
		local index = order[i]
		local value = rows[index][field]
		local j = i - 1
		while j >= 1 and Before(value, rows[order[j]][field]) do
			order[j + 1] = order[j]
			j = j - 1
		end
		order[j + 1] = index
	end
	return true
end

local function Level(percent, warnAt, dangerAt)
	if percent >= dangerAt then
		return DANGER
	elseif percent >= warnAt then
		return WARNING
	end
	return NO_WARNING
end

function Logic.ThreatWarning(rows, count, warnAt, dangerAt)
	dangerAt = max(warnAt, dangerAt)
	local player
	for i = 1, count do
		if rows[i].isPlayer == true then
			player = rows[i]
			break
		end
	end
	if not player then
		return NO_WARNING
	end
	local tanking = player.tanking
	if IsSecret(tanking) then
		return NO_WARNING
	end
	if tanking ~= true then
		local own = Plain(player.scaled)
		return own and Level(own, warnAt, dangerAt) or NO_WARNING
	end
	local highest
	for i = 1, count do
		local row = rows[i]
		if row ~= player then
			local scaled = Plain(row.scaled)
			if scaled and (not highest or scaled > highest) then
				highest = scaled
			end
		end
	end
	return highest and Level(highest, warnAt, dangerAt) or NO_WARNING
end
