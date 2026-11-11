-- test-ornament-tray-paths.lua: the action-bar tray restyles only when its pair, gap or avoided bars change; per-event button updates touch no ornament, a hidden tray waits for its owner to show, and in lockdown the protected header's tray waits for PLAYER_REGEN_ENABLED.
local AB = dofile("Tools/regression/actionbars_env.lua")
local ae, AK, ns = AB.New()
AB.Enable(ae, AK)
for n = 1, 12 do
	AB.Slot(ae, n, { texture = 135000 + n, type = "spell", id = 100 + n, cooldown = { name = "cd" .. n } })
end
ae._game.petExists = true
ae.FireEvent("UNIT_PET", "player")
ae.RunTimers()
assert(AK.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")
local main = ns.bars.bar1
local tray = main.ornament
assert(tray.used > 0 and main.header:IsProtected(), "the tray draws on bar 1's protected header")

local function Fire(frame)
	local script = frame._scripts and frame._scripts.OnShow
	if script then script(frame) end
end
for _, frame in ipairs(ae._frames) do
	for _, method in ipairs({ "Show", "SetShown" }) do
		local original = frame[method]
		frame[method] = function(self, ...)
			local was = self:IsVisible()
			original(self, ...)
			if not was and self:IsVisible() then Fire(self) end
		end
	end
end

local Handle = getmetatable(tray)
local counts = { Restyle = 0, Place = 0, Piece = 0, Follow = 0 }
for name in pairs(counts) do
	local original = Handle[name]
	Handle[name] = function(...)
		counts[name] = counts[name] + 1
		return original(...)
	end
end
local function reset()
	for name in pairs(counts) do counts[name] = 0 end
end
local function total()
	return counts.Restyle + counts.Place + counts.Piece + counts.Follow
end

local updates = {}
for _, frame in ipairs(ae._frames) do
	local script = frame._scripts and frame._scripts.OnUpdate
	if script then updates[#updates + 1] = { frame, script } end
end
ae.SetCombat(true)
ae.RunTimers()
reset()
local EVENTS = {
	{ "ACTIONBAR_UPDATE_COOLDOWN" }, { "SPELL_UPDATE_COOLDOWN" }, { "SPELL_UPDATE_CHARGES" }, { "BAG_UPDATE_DELAYED" },
	{ "ACTIONBAR_UPDATE_STATE" }, { "ACTIONBAR_UPDATE_USABLE" }, { "ACTION_USABLE_CHANGED", { { slot = 3, usable = false, noMana = true } } },
	{ "ACTION_RANGE_CHECK_UPDATE", 2, false, true }, { "PLAYER_TARGET_CHANGED" }, { "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 102 },
	{ "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 102 }, { "START_AUTOREPEAT_SPELL" }, { "STOP_AUTOREPEAT_SPELL" },
	{ "PET_BAR_UPDATE" }, { "PET_BAR_UPDATE_COOLDOWN" }, { "PET_BAR_UPDATE_USABLE" }, { "PET_UI_UPDATE" },
	{ "PLAYER_CONTROL_LOST" }, { "PLAYER_CONTROL_GAINED" }, { "UNIT_PET", "player" }, { "UNIT_FLAGS", "pet" },
	{ "UPDATE_SHAPESHIFT_COOLDOWN" }, { "UPDATE_SHAPESHIFT_USABLE" }, { "UPDATE_SHAPESHIFT_FORM" },
}
for i = 1, 40 do
	for _, entry in ipairs(EVENTS) do
		ae.FireEvent(entry[1], entry[2], entry[3], entry[4])
	end
	for _, entry in ipairs(updates) do
		local frame, script = entry[1], entry[2]
		if frame._scripts.OnUpdate == script then script(frame, 0.05 * i) end
	end
	ae.RunTimers()
end
assert(#updates > 0, "the burst drives the running OnUpdate scripts")
assert(total() == 0, string.format("per-event action-bar updates touch no ornament: %d restyles, %d placements, %d anchored pieces, %d follows", counts.Restyle, counts.Place, counts.Piece, counts.Follow))

local function changes(object)
	local n = 0
	for _, call in ipairs(object._calls or {}) do
		if not call.method:find("^Get") and not call.method:find("^Is") then n = n + 1 end
	end
	return n
end
local function calls()
	local n = 0
	for _, t in ipairs(tray.textures) do n = n + changes(t) end
	return n
end
local function drawn()
	local names = {}
	for i = 1, tray.used do
		local texture = tray.textures[i]
		if texture:IsShown() then
			local _, _, _, x, y = texture:GetPoint(1)
			names[#names + 1] = texture:GetTexture():match("([%w]+)%.png$") .. "@" .. string.format("%.3f,%.3f", x, y)
		end
	end
	return table.concat(names, " ")
end
local full = drawn()
assert(full:find("Keystone6") and not full:find("Tray64"), "the shown pet bar blocks the finials and keeps the keystone: " .. full)
local before = calls()
ae._game.petExists = false
ae.FireEvent("UNIT_PET", "player")
AK.Options.Write("Widgets", "ornaments", "Subtle")
ae.RunTimers()
assert(counts.Restyle > 0 and tray.queued, "a pet change and a level change in combat queue the protected header's tray")
assert(calls() == before and drawn() == full, "in lockdown nothing sets, shows, hides or anchors the tray's textures")
reset()
ae.SetCombat(false)
ae.RunTimers()
assert(not tray.queued and counts.Restyle > 0, "PLAYER_REGEN_ENABLED runs the queued tray restyle")
local subtle = drawn()
assert(subtle ~= full and subtle ~= "", "the queued restyle draws the Subtle tray after combat: " .. subtle)

main.holder:Hide()
assert(not main.header:IsVisible(), "hiding bar 1's holder hides the tray's owner")
reset()
before = calls()
AK.Options.Write("Widgets", "ornaments", "Full")
ae.RunTimers()
assert(counts.Restyle > 0 and tray.stale, "a level change while bar 1 is hidden leaves the tray stale")
assert(counts.Place == 0 and counts.Piece == 0 and calls() == before, "a hidden tray places nothing")
main.holder:Show()
assert(main.header:IsVisible() and not tray.stale, "showing bar 1's holder restyles the stale tray from an ancestor's OnShow")
local first = drawn()
tray:Restyle()
assert(first:find("Tray64") and first:find("Keystone6") and drawn() == first, "without the pet bar the tray's first shown frame draws both finials and the keystone, as a fresh Full restyle does: " .. first .. " | " .. drawn())
assert(#ae._errors == 0 and AK.ErrorCount() == 0, "no errors: " .. tostring(ae._errors[1]))
print("ok tray restyles only on real changes, waits while hidden and in lockdown")
