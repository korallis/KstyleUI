-- test-ornament-tray-paths.lua: the action-bar tray restyles only when its pair, gap or avoided bars change, a layout rule or the leave-vehicle button included, and an error in a settings pass never stops it; per-event button updates touch no ornament, a hidden tray waits for its owner to show, and in lockdown the protected header's tray only hides the finials an obstacle now covers, calling no protected method, and re-places at PLAYER_REGEN_ENABLED.
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
local own = { Restyle = 0, Place = 0, Piece = 0, Follow = 0 }
for name in pairs(counts) do
	local original = Handle[name]
	Handle[name] = function(self, ...)
		counts[name] = counts[name] + 1
		if self == tray then own[name] = own[name] + 1 end
		return original(self, ...)
	end
end
local function reset()
	for name in pairs(counts) do counts[name], own[name] = 0, 0 end
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
assert(own.Place == 0 and own.Piece == 0 and calls() == before, "a hidden tray places nothing")
main.holder:Show()
assert(main.header:IsVisible() and not tray.stale, "showing bar 1's holder restyles the stale tray from an ancestor's OnShow")
local first = drawn()
tray:Restyle()
assert(first:find("Tray64") and first:find("Keystone6") and drawn() == first, "without the pet bar the tray's first shown frame draws both finials and the keystone, as a fresh Full restyle does: " .. first .. " | " .. drawn())
assert(#ae._errors == 0 and AK.ErrorCount() == 0, "no errors: " .. tostring(ae._errors[1]))
local function Hidden(frame)
	local script = frame._scripts and frame._scripts.OnHide
	frame:Hide()
	if script then script(frame) end
end
local function finials()
	tray:Restyle()
	return drawn():find("Tray64") ~= nil
end
assert(finials(), "bars 1 and 2 pair with no obstacle")
assert(ns.leaveButton and not ns.leaveShown, "the leave-vehicle button is built and hidden")
reset()
ae.CanExitVehicle = function() return true end
ae.FireEvent("UPDATE_VEHICLE_ACTIONBAR")
assert(ns.leaveShown and ns.leaveButton:IsShown(), "a vehicle shows the leave button beside bar 1")
assert(counts.Restyle == 1 and not drawn():find("Tray64"), "the leave button beside bar 1 drops the finials in one restyle: " .. drawn())
reset()
ae.FireEvent("UPDATE_VEHICLE_ACTIONBAR")
assert(counts.Restyle == 0, "a vehicle update that changes nothing does not restyle the tray")
ae.CanExitVehicle = function() return false end
ae.FireEvent("UPDATE_VEHICLE_ACTIONBAR")
assert(not ns.leaveShown and counts.Restyle == 1 and drawn():find("Tray64"), "leaving the vehicle brings the finials back")
local second = ns.bars.bar2
reset()
Hidden(second.holder)
assert(second.holderHidden and counts.Restyle == 1 and not drawn():find("Tray64"), "a layout rule hiding bar 2 drops the finials")
second.holder:Show()
assert(not second.holderHidden and counts.Restyle == 2 and drawn():find("Tray64"), "showing bar 2 again restores them")
local third = ns.bars.bar3
if not third then
	AK.Options.Write("ActionBars", "bar3.enabled", true)
	ae.RunTimers()
	third = ns.bars.bar3
end
local listed = function()
	for _, holder in ipairs(tray.avoidBars) do if holder == third.holder then return true end end
	return false
end
assert(listed(), "a shown bar 3 is an obstacle")
Hidden(third.holder)
assert(not listed(), "a layout rule hiding bar 3 drops it from the obstacles")
third.holder:Show()
if third.holderHidden then Fire(third.holder) end
assert(listed(), "showing bar 3 lists it again")
assert(AK.Layout.Set("actionbars.bar2", "shown", "mouseover"), "bar 2 takes a mouseover rule")
ae.RunTimers()
assert(not tray.pairEnabled and not drawn():find("Tray64"), "a mouseover rule on bar 2 drops the finials: " .. drawn())
assert(AK.Layout.Set("actionbars.bar2", "shown", "always"), "bar 2 is always shown again")
ae.RunTimers()
assert(tray.pairEnabled and drawn():find("Tray64"), "an always-shown bar 2 pairs again")
local FRAME_ONLY = { "Show", "Hide", "SetShown", "SetFrameLevel", "SetFrameStrata", "SetParent", "Raise", "Lower", "SetScale" }
local RESIZING = { "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize", "SetWidth", "SetHeight" }
local function Guard(object, methods, label)
	for _, method in ipairs(methods) do
		local original = object[method]
		if original then
			object[method] = function(self, ...)
				if ae.InCombatLockdown() and not ae._secure then error("ADDON_ACTION_BLOCKED: " .. label .. ":" .. method .. "() in combat", 2) end
				return original(self, ...)
			end
		end
	end
end
Guard(main.header, FRAME_ONLY, "header")
Guard(main.header, RESIZING, "header")
for _, texture in ipairs(tray.textures) do Guard(texture, RESIZING, "tray texture") end
assert(finials(), "out of combat the pair draws both finials")
local right
for i = 1, tray.used do
	local texture = tray.textures[i]
	if texture:IsShown() and texture:GetTexture():find("Tray64") and texture:GetLeft() > main.header:GetRight() then right = texture end
end
assert(right, "the right finial sits beside bar 1's right edge")
local errorsBefore = #ae._errors + AK.ErrorCount()
ae.SetCombat(true)
ae.RunTimers()
ae.CanExitVehicle = function() return true end
ae.FireEvent("UPDATE_VEHICLE_ACTIONBAR")
assert(#ae._errors + AK.ErrorCount() == errorsBefore, "the yield in lockdown calls no protected method: " .. tostring(ae._errors[1]))
assert(ns.leaveButton:IsShown() and tray.queued, "a vehicle in combat shows the leave button and queues the tray's re-place")
assert(not right:IsShown(), "the right finial under the leave button hides at once in lockdown")
local left = drawn():find("Tray64")
assert(left, "a finial clear of the leave button keeps drawing until the re-place")
ae.SetCombat(false)
ae.RunTimers()
assert(not tray.queued and not drawn():find("Tray64") and #ae._errors + AK.ErrorCount() == errorsBefore, "after combat the re-place drops both finials for the leave button: " .. drawn())
ae.CanExitVehicle = function() return false end
ae.FireEvent("UPDATE_VEHICLE_ACTIONBAR")
assert(drawn():find("Tray64"), "leaving the vehicle out of combat brings the finials back")
local errors = AK.ErrorCount()
local apply = third.Apply
third.Apply = function() error("boom") end
AK.Options.Write("ActionBars", "bar1.spacing", AK.Store.Module("ActionBars").bar1.spacing + 1)
ae.RunTimers()
third.Apply = apply
assert(AK.ErrorCount() > errors and ns.trayHeld == false, "an error during a settings pass still releases the tray")
reset()
ae._game.petExists = true
ae.FireEvent("UNIT_PET", "player")
assert(counts.Restyle == 1, "after an error the tray still follows a pet change")
print("ok tray restyles only on real changes, waits while hidden and in lockdown")
