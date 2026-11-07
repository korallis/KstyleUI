-- Cooldowns.lua: the cdm spike lists the Cooldown Manager's data, mirrors the essential cooldowns as KstyleUI-style icons in combat, and compares them with Blizzard's viewer.
local _, ns = ...

local WINDOW = 900
local SAMPLE = 1
local MAX_SAMPLES = 300
local ICON_SIZE = 40
local ICON_GAP = 4
local ICON_INSET = 2
local ROW_Y = 300
local ACCENT_HEIGHT = 2
local TOLERANCE_MS = 100
local INFO_FIELDS = { "spellID", "overrideSpellID", "charges", "isKnown", "category", "selfAura", "hasAura", "isInvisible", "flags", "equipSlot", "buffSlot" }
local SPELL_COOLDOWN_FIELDS = { "startTime", "duration", "isEnabled", "modRate" }
local EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES" }

local function Plain(value)
	if ns.IsSecret(value) or value == nil then
		return nil
	end
	return value
end

local function ListData(run, api)
	local categories, essential, infoById = {}, {}, {}
	run:Set("categories", categories)
	for name, value in pairs(Enum.CooldownViewerCategory) do
		local entry = {}
		local ok, ids = pcall(api.GetCooldownViewerCategorySet, value, false)
		if not ok then
			entry.error = tostring(ids)
		elseif ns.IsSecret(ids) then
			entry.secret = true
		elseif type(ids) == "table" then
			entry.ids = {}
			for i, id in ipairs(ids) do
				entry.ids[i] = ns.Describe(id)
			end
			entry.count = #entry.ids
			if value == Enum.CooldownViewerCategory.Essential then
				essential = entry.ids
			end
		end
		categories[name] = entry
	end
	for _, entry in pairs(categories) do
		for _, id in ipairs(entry.ids or {}) do
			if type(id) == "number" and not infoById[id] then
				local ok, info = pcall(api.GetCooldownViewerCooldownInfo, id)
				local row = { cooldownID = id, secretFields = 0 }
				if not ok then
					row.error = tostring(info)
				elseif type(info) == "table" and not ns.IsSecret(info) then
					for _, field in ipairs(INFO_FIELDS) do
						local value = info[field]
						row[field] = ns.Describe(value)
						if ns.IsSecret(value) then
							row.secretFields = row.secretFields + 1
						end
					end
					infoById[id] = { spell = Plain(info.overrideSpellID) or Plain(info.spellID), charges = Plain(info.charges) == true }
				end
				run:Add("cooldowns", row)
			end
		end
	end
	return essential, infoById
end

local function BuildIcons(essential, infoById)
	local icons = {}
	local row = CreateFrame("Frame", nil, ns.Root())
	for _, id in ipairs(essential) do
		local info = infoById[id]
		if info and info.spell then
			local icon = CreateFrame("Frame", nil, row)
			icon:SetSize(ICON_SIZE, ICON_SIZE)
			icon:SetPoint("LEFT", row, "LEFT", #icons * (ICON_SIZE + ICON_GAP), 0)
			local edge = icon:CreateTexture(nil, "BACKGROUND")
			edge:SetAllPoints()
			edge:SetColorTexture(0, 0, 0, 0.9)
			local art = icon:CreateTexture(nil, "ARTWORK")
			art:SetPoint("TOPLEFT", icon, "TOPLEFT", ICON_INSET, -ICON_INSET)
			art:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
			art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
				local ok, texture = pcall(C_Spell.GetSpellTexture, info.spell)
				art:SetTexture(ok and texture or nil)
			end
			local accent = icon:CreateTexture(nil, "OVERLAY")
			accent:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", ICON_INSET, ICON_INSET)
			accent:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
			accent:SetHeight(ACCENT_HEIGHT)
			accent:SetColorTexture(0.31, 0.76, 1, 1)
			local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
			cooldown:SetAllPoints(art)
			cooldown:SetDrawEdge(false)
			icons[#icons + 1] = { id = id, spell = info.spell, charges = info.charges, cooldown = cooldown }
		end
	end
	row:SetSize(math.max(1, #icons * (ICON_SIZE + ICON_GAP) - ICON_GAP), ICON_SIZE)
	row:SetPoint("BOTTOM", ns.Root(), "BOTTOM", 0, ROW_Y)
	local label = ns.Text(row, "GameFontHighlightSmall")
	label:SetPoint("BOTTOM", row, "TOP", 0, 4)
	label:SetText("KstyleUI Spike mirror of the essential cooldowns")
	return row, icons
end

local function Update(icons, calls)
	local spell = C_Spell or {}
	for _, icon in ipairs(icons) do
		local getter = icon.charges and spell.GetSpellChargeDuration or spell.GetSpellCooldownDuration
		local cooldown = icon.cooldown
		if type(getter) == "function" and type(cooldown.SetCooldownFromDurationObject) == "function" then
			calls.duration.calls = calls.duration.calls + 1
			local ok, duration = pcall(getter, icon.spell)
			if not ok then
				calls.duration.errors = calls.duration.errors + 1
				calls.duration.firstError = calls.duration.firstError or tostring(duration)
			elseif ns.IsSecret(duration) then
				calls.duration.secretObject = calls.duration.secretObject + 1
			elseif duration == nil then
				calls.duration.nilResult = calls.duration.nilResult + 1
			else
				local okSecret, hasSecret = pcall(function() return duration:HasSecretValues() end)
				if okSecret and hasSecret == true then
					calls.duration.secret = calls.duration.secret + 1
				end
				calls.setFromDuration.calls = calls.setFromDuration.calls + 1
				local okSet, err = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
				if not okSet then
					calls.setFromDuration.errors = calls.setFromDuration.errors + 1
					calls.setFromDuration.firstError = calls.setFromDuration.firstError or tostring(err)
				end
			end
		end
		if type(spell.GetSpellCooldown) == "function" then
			calls.spellCooldown.calls = calls.spellCooldown.calls + 1
			local ok, info = pcall(spell.GetSpellCooldown, icon.spell)
			if ok and type(info) == "table" and not ns.IsSecret(info) then
				for _, field in ipairs(SPELL_COOLDOWN_FIELDS) do
					if ns.IsSecret(info[field]) then
						calls.spellCooldown.secretFields = calls.spellCooldown.secretFields + 1
					end
				end
			end
		end
	end
end

local function ProbeSetCooldown(run, row, icons)
	local spell = C_Spell
	local icon = icons[1]
	if not icon or not spell or type(spell.GetSpellCooldown) ~= "function" then
		return
	end
	local ok, info = pcall(spell.GetSpellCooldown, icon.spell)
	if not ok or type(info) ~= "table" or ns.IsSecret(info) then
		run:Set("setCooldownProbe", "no cooldown info")
		return
	end
	local scratch = CreateFrame("Cooldown", nil, row, "CooldownFrameTemplate")
	scratch:Hide()
	local okSet, err = pcall(scratch.SetCooldown, scratch, info.startTime, info.duration)
	run:Set("setCooldownProbe", {
		ok = okSet,
		error = not okSet and tostring(err) or nil,
		startSecret = ns.IsSecret(info.startTime),
		durationSecret = ns.IsSecret(info.duration),
	})
end

local function Times(cooldown)
	local ok, start, duration = pcall(function() return cooldown:GetCooldownTimes() end)
	if not ok then
		return "error"
	elseif ns.IsSecret(start) or ns.IsSecret(duration) then
		return "secret"
	end
	return start, duration
end

local function Compare(run, icons)
	local sample = { t = run:Since(), inCombat = ns.InCombat(), ours = #icons, compared = 0, equal = 0, secret = 0 }
	local viewer = _G.EssentialCooldownViewer
	local ok, frames = false, nil
	if viewer and type(viewer.GetItemFrames) == "function" then
		ok, frames = pcall(viewer.GetItemFrames, viewer)
	end
	if not ok or type(frames) ~= "table" then
		sample.blizzard = "missing"
		run:Add("samples", sample)
		return
	end
	sample.blizzard = #frames
	sample.idsMatch = #frames == #icons
	for i, frame in ipairs(frames) do
		local okId, id = pcall(function() return frame:GetCooldownID() end)
		id = okId and ns.Describe(id) or "error"
		local icon = icons[i]
		if not icon or id ~= icon.id then
			sample.idsMatch = false
		elseif icon then
			local okCd, theirs = pcall(function() return frame.Cooldown end)
			if okCd and theirs then
				local theirStart, theirDuration = Times(theirs)
				local ourStart, ourDuration = Times(icon.cooldown)
				if theirStart == "secret" or ourStart == "secret" then
					sample.secret = sample.secret + 1
				elseif type(theirStart) == "number" and type(ourStart) == "number" and type(theirDuration) == "number" and type(ourDuration) == "number" then
					sample.compared = sample.compared + 1
					if math.abs(theirStart - ourStart) <= TOLERANCE_MS and math.abs(theirDuration - ourDuration) <= TOLERANCE_MS then
						sample.equal = sample.equal + 1
					end
				end
			end
		end
	end
	run:Add("samples", sample)
end

ns.Register("cdm", {
	group = "pull",
	summary = "lists Cooldown Manager data, then in combat mirrors the essential cooldowns from duration objects and compares them with Blizzard's viewer, for 15 minutes.",
	Run = function(run)
		local api = C_CooldownViewer
		if not (api and Enum and type(Enum.CooldownViewerCategory) == "table" and type(api.GetCooldownViewerCategorySet) == "function") then
			run:Set("available", "unavailable")
			run:Note("C_CooldownViewer is missing on this client.")
			return
		end
		if type(api.IsCooldownViewerAvailable) == "function" then
			local ok, available, reason = pcall(api.IsCooldownViewerAvailable)
			run:Set("available", ok and ns.Describe(available) or "error")
			run:Set("failureReason", ok and ns.Describe(reason) or nil)
		end
		if C_CVar and C_CVar.GetCVar then
			run:Set("cvarCooldownViewerEnabled", C_CVar.GetCVar("cooldownViewerEnabled"))
		end
		run:Set("windowSeconds", WINDOW)
		local essential, infoById = ListData(run, api)
		local calls = {
			duration = { calls = 0, errors = 0, secret = 0, secretObject = 0, nilResult = 0 },
			setFromDuration = { calls = 0, errors = 0 },
			spellCooldown = { calls = 0, secretFields = 0 },
		}
		run:Set("calls", calls)
		local row, icons
		local samples = 0

		local function Tick()
			if not icons and ns.InCombat() and #essential > 0 then
				local ok, a, b = pcall(BuildIcons, essential, infoById)
				if not ok then
					run:Set("buildError", tostring(a))
					essential = {}
					return
				end
				row, icons = a, b
				run:Set("icons", #icons)
				run:Set("builtInCombat", ns.InCombat())
				run:Set("builtAt", run:Since())
				ProbeSetCooldown(run, row, icons)
			end
			if icons and ns.InCombat() and samples < MAX_SAMPLES then
				samples = samples + 1
				Update(icons, calls)
				Compare(run, icons)
			end
		end

		local ticker = ns.Ticker(SAMPLE, Tick)
		local listener = ns.Listen(EVENTS, function()
			if icons then
				Update(icons, calls)
			end
		end)
		ns.After(WINDOW, function() ns.Stop("cdm", "timeout", run) end)
		run:Note("listed " .. #essential .. " essential cooldowns. Icons appear above the action bars in combat.")
		return function()
			if ticker then
				ticker:Cancel()
			end
			ns.Unlisten(listener)
			if row then
				row:Hide()
			end
		end
	end,
})
