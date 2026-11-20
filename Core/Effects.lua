-- Effects.lua: the Medallions effects layer: its motion level (Full, Calm or Off, never above the Appearance motion setting) and what each level allows, the arbiter that gives each place on screen to one effect at a time by priority with ambient motion yielding to everything, and the art lookup with fallbacks.
local addonName, ns = ...

local Effects = {}
ns.Effects = Effects

local Store, Tokens, L = ns.Store, ns.Tokens, ns.L

local SECTION = "Medallions"
local OWNER = "Effects"
local RANK = { off = 1, calm = 2, full = 3 }
local FROM_MOTION = { full = "full", reduced = "calm", off = "off" }
local ALLOWS = {
	full = { ambient = true, flare = true, pulse = true, particle = true, model = true },
	calm = { flare = true },
	off = {},
}

Effects.SECTION = SECTION
Effects.PRIORITY = {
	lowHealth = 1, proc = 2, levelUp = 1.5, burst = 2, ready = 3, cast = 3, cap = 4, target = 4, combat = 5, rest = 6, ambient = 9,
}
Effects.defaults = { motion = "full" }

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

function Effects.Saved()
	if Store.IsLoaded() then
		local value = Store.Module(SECTION).motion
		if not IsSecret(value) and RANK[value] then
			return value
		end
	end
	return Effects.defaults.motion
end

function Effects.Level()
	local own = Effects.Saved()
	local cap = FROM_MOTION[ns.Motion.Level()] or "full"
	if RANK[cap] < RANK[own] then
		return cap
	end
	return own
end

function Effects.Allows(kind)
	return ALLOWS[Effects.Level()][kind] == true
end

function Effects.Active()
	return ns.HudStyle.Current() == "medallions"
end

function Effects.Texture(name, fallback)
	local ok, path = pcall(Tokens.Texture, name)
	if ok and path then
		return path, true
	end
	if fallback then
		return (Tokens.Texture(fallback)), false
	end
end

local places = {}
local serial = 0

local function Place(place)
	local rec = places[place]
	if not rec then
		rec = {}
		places[place] = rec
	end
	return rec
end

local function Suspend(rec)
	if rec.ambientOn then
		rec.ambientOn = false
		rec.ambientStop()
	end
end

local function Resume(rec)
	if rec.ambientStart and not rec.ambientOn and not rec.priority and Effects.Allows("ambient") then
		rec.ambientOn = true
		rec.ambientStart()
	end
end

function Effects.Claim(place, priority, stop)
	local rec = Place(place)
	local held = rec.priority
	if held and held < priority then
		return nil
	end
	local old = rec.stop
	serial = serial + 1
	rec.priority, rec.stop, rec.token = priority, stop, serial
	if held and old then
		old()
	end
	Suspend(rec)
	return serial
end

function Effects.Release(place, token)
	local rec = places[place]
	if not (rec and rec.priority and rec.token == token) then
		return false
	end
	rec.priority, rec.stop, rec.token = nil, nil, nil
	Resume(rec)
	return true
end

local RING = 8

local function Expire(place, rec, slot)
	slot.waiting = slot.waiting - 1
	if slot.waiting > 0 or slot.token ~= rec.token then
		return
	end
	local stop = rec.stop
	Effects.Release(place, rec.token)
	if stop then
		stop()
	end
end

function Effects.ClaimFor(place, priority, seconds, stop)
	local token = Effects.Claim(place, priority, stop)
	if not token then
		return nil
	end
	local rec = places[place]
	local slots = rec.slots
	if not slots then
		slots = {}
		for i = 1, RING do
			local slot = { waiting = 0 }
			slot.expire = function()
				Expire(place, rec, slot)
			end
			slots[i] = slot
		end
		rec.slots, rec.next = slots, 0
	end
	rec.next = rec.next % RING + 1
	local slot = slots[rec.next]
	slot.token, slot.waiting = token, slot.waiting + 1
	C_Timer.After(seconds, slot.expire)
	return token
end

function Effects.Stop(place)
	local rec = places[place]
	if not (rec and rec.priority) then
		return false
	end
	local stop = rec.stop
	Effects.Release(place, rec.token)
	if stop then
		stop()
	end
	return true
end

function Effects.Holder(place)
	local rec = places[place]
	return rec and rec.priority
end

function Effects.Ambient(place, start, stop)
	local rec = Place(place)
	if start and rec.ambientStart == start and rec.ambientStop == stop then
		Resume(rec)
		return
	end
	Suspend(rec)
	rec.ambientStart, rec.ambientStop = start, stop
	if start then
		Resume(rec)
	end
end

local last

local function Refresh()
	local level = Effects.Level()
	if level == last then
		return
	end
	local old = last
	last = level
	if old then ns.Motion.Settle() end
	for _, rec in pairs(places) do
		if rec.ambientStart then
			if Effects.Allows("ambient") then
				Resume(rec)
			else
				Suspend(rec)
			end
		end
	end
	if old then
		ns.Callbacks.Fire("EffectsLevelChanged", level, old)
	end
end
Effects.Refresh = Refresh

function Effects.Schema()
	Effects.schema = {
		{ type = "header", label = L["Medallions"] },
		{
			type = "dropdown", key = "motion", label = L["Medallions motion"],
			help = L["Full adds the game's 3D effects; Calm keeps short fades and flashes; Off is still."],
			options = {
				{ value = "full", label = L["Full"] },
				{ value = "calm", label = L["Calm"] },
				{ value = "off", label = L["Off"] },
			},
		},
	}
	return Effects.schema
end

Store.RegisterDefaults(SECTION, Effects.defaults)
ns.Options.Register(SECTION, Effects.Schema)

ns.Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
	if module == SECTION or (module == "Appearance" and key == "motion") then
		Refresh()
	end
end)
ns.Callbacks.Register("ProfileChanged", OWNER, Refresh)

ns.Events.Register(OWNER, "ADDON_LOADED", function(_, name)
	if name == addonName and Store.IsLoaded() then
		ns.Events.Unregister(OWNER, "ADDON_LOADED")
		Refresh()
	end
end)
