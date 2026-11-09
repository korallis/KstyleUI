-- Calm.lua: combat calm: in combat the rails' slow cards rest at 30% until the pointer wakes them and return a few seconds after; alpha only, through Layout for its own elements.
local _, ns = ...

local Layout = ns.Layout
local Motion, Modules, Tokens = ns.Motion, ns.Modules, ns.Tokens

local Calm = {}
Layout.Calm = Calm

Calm.ALPHA, Calm.FALL, Calm.RISE, Calm.DELAY, Calm.HOVER = 0.3, 0.24, 0.6, 3, 0.24
Calm.CARDS = {
	"chat.main", "minimap.main", "databars.strip", "databars.micro", "databars.bags",
	"databars.xp", "databars.rep", "databars.honor",
}
Calm.SURFACES = { "ObjectiveTrackerFrame", "RXPFrame" }

local OWNER = "Calm"
local POLL = 0.1
local SKINS = "Skins"
local EPSILON = 0.01

local isCard = {}
for _, key in ipairs(Calm.CARDS) do
	isCard[key] = true
end

local calm, wait, listening = false, nil, false
local hovered, owned = {}, {}
local driver, ticker

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function Duration(seconds)
	if Motion.ReducedMotion() then
		return 0
	end
	return seconds
end

local function Accessible(frame)
	local check = frame.CanBeAccessedInContext
	if type(check) ~= "function" then
		return true
	end
	local ok, allowed = pcall(check, frame)
	return ok and not IsSecret(allowed) and allowed ~= false
end

local function IsOver(frame)
	if not Accessible(frame) then
		return false
	end
	local ok, over = pcall(frame.IsMouseOver, frame)
	if not ok then
		return false
	end
	return IsSecret(over) or over == true
end

local function Alpha(frame)
	local alpha = frame:GetAlpha()
	if IsSecret(alpha) or type(alpha) ~= "number" then
		return nil
	end
	return alpha
end

local function Surfaces()
	local out = {}
	if not Modules.IsRunning(SKINS) then
		return out
	end
	for _, name in ipairs(Calm.SURFACES) do
		local frame = _G[name]
		if type(frame) == "table" and type(frame.SetAlpha) == "function" and type(frame.GetAlpha) == "function" then
			out[#out + 1] = frame
		end
	end
	return out
end

local function Fade(frame, rec, value, duration, onDone)
	rec.value = value
	rec.tween = Motion.Tween(frame, "SetAlpha", Alpha(frame) or value, value, duration, Tokens.Easing("fade"), onDone)
end

local function Mine(frame, rec)
	if Motion.IsPlaying(rec.tween) then
		return true
	end
	local alpha = Alpha(frame)
	return alpha ~= nil and math.abs(alpha - rec.value) < EPSILON
end

local function CalmSurface(frame, duration)
	local rec = owned[frame]
	if rec then
		if not Mine(frame, rec) then
			owned[frame] = nil
			return
		end
	else
		local alpha = Alpha(frame)
		if alpha == nil or math.abs(alpha - 1) >= EPSILON then
			return
		end
		rec = { value = 1 }
		owned[frame] = rec
	end
	local target = hovered[frame] and 1 or Calm.ALPHA
	if rec.value ~= target then
		Fade(frame, rec, target, duration)
	end
end

local function Apply(duration)
	for _, key in ipairs(Calm.CARDS) do
		Layout.RefreshAlpha(key, duration)
	end
	if calm then
		for _, frame in ipairs(Surfaces()) do
			CalmSurface(frame, duration)
		end
		return
	end
	for frame, rec in pairs(owned) do
		if Mine(frame, rec) then
			Fade(frame, rec, 1, duration, function()
				if owned[frame] == rec and not calm then
					owned[frame] = nil
				end
			end)
		else
			owned[frame] = nil
		end
	end
end

local function Poll()
	if not calm then
		return
	end
	local duration = Duration(Calm.HOVER)
	for _, key in ipairs(Calm.CARDS) do
		local el = Layout.Element(key)
		local over = el ~= nil and Layout.Live(key) and IsOver(el.frame)
		if over ~= (hovered[key] == true) then
			hovered[key] = over or nil
			Layout.RefreshAlpha(key, duration)
		end
	end
	for _, frame in ipairs(Surfaces()) do
		local over = IsOver(frame)
		if over ~= (hovered[frame] == true) then
			hovered[frame] = over or nil
			CalmSurface(frame, duration)
		end
	end
end

local function StartPoll()
	if ticker or type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then
		return
	end
	ticker = C_Timer.NewTicker(POLL, Poll)
end

local function StopPoll()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function StopWait()
	wait = nil
	if driver then
		driver:SetScript("OnUpdate", nil)
	end
end

local function Wake()
	StopWait()
	StopPoll()
	if not calm then
		return
	end
	calm = false
	hovered = {}
	Apply(Duration(Calm.RISE))
end

local function Count(_, elapsed)
	wait = wait - elapsed
	if wait <= 0 then
		Wake()
	end
end

local function StartWait()
	if not driver then
		driver = CreateFrame("Frame")
	end
	wait = Calm.DELAY
	driver:SetScript("OnUpdate", Count)
end

local function Fall()
	StopWait()
	if calm or not Layout.Setting("calm") then
		return
	end
	calm = true
	Apply(Duration(Calm.FALL))
	StartPoll()
end

function Calm.Active()
	return calm
end

function Calm.Level(key)
	if calm and isCard[key] and not hovered[key] then
		return Calm.ALPHA
	end
	return 1
end

local function Ended()
	if calm then
		StartWait()
	end
end

local function Needed()
	if not Layout.Setting("calm") then
		return false
	end
	if Modules.IsRunning(SKINS) then
		return true
	end
	for _, key in ipairs(Calm.CARDS) do
		if Layout.Element(key) then
			return true
		end
	end
	return false
end

function Calm.Update()
	local need = Needed()
	if need ~= listening then
		listening = need
		if need then
			ns.Events.Register(OWNER, "PLAYER_REGEN_DISABLED", Fall)
			ns.Events.Register(OWNER, "PLAYER_REGEN_ENABLED", Ended)
		else
			ns.Events.Unregister(OWNER, "PLAYER_REGEN_DISABLED")
			ns.Events.Unregister(OWNER, "PLAYER_REGEN_ENABLED")
		end
	end
	if not need then
		Wake()
	elseif InCombatLockdown() then
		Fall()
	end
end

ns.Events.Register(OWNER, "PLAYER_LOGIN", Calm.Update)
ns.Callbacks.Register("SettingChanged", OWNER, function(_, module, key)
	if module == "Layout" and key == "calm" then
		Calm.Update()
	end
end)
ns.Callbacks.Register("ProfileChanged", OWNER, Calm.Update)
ns.Callbacks.Register("ModuleChanged", OWNER, function(_, name)
	if name == SKINS then
		Calm.Update()
	end
end)
