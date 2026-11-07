-- Pool.lua: reusable numbers, each a small frame with one font string and one AnimationGroup, so the combat path makes no frames.
local _, ns = ...

local Pool = {}
Pool.__index = Pool
ns.Pool = Pool

local NUMBER_SIZE = 1

local function Remove(list, item)
	for i = #list, 1, -1 do
		if list[i] == item then
			table.remove(list, i)
			return
		end
	end
end

local function Make(pool)
	local frame = CreateFrame("Frame", nil, pool.parent)
	frame:SetSize(NUMBER_SIZE, NUMBER_SIZE)
	frame:Hide()
	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	local group = frame:CreateAnimationGroup()
	local number = { frame = frame, text = text, group = group, live = false }
	number.move = group:CreateAnimation("Translation")
	number.fall = group:CreateAnimation("Translation")
	number.pop = group:CreateAnimation("Scale")
	number.pop:SetOrigin("CENTER", 0, 0)
	number.pop:SetScaleTo(1, 1)
	number.fade = group:CreateAnimation("Alpha")
	number.fade:SetFromAlpha(1)
	number.fade:SetToAlpha(0)
	number.fade:SetSmoothing("IN")
	group:SetScript("OnFinished", function()
		pool:Release(number)
	end)
	pool.made = pool.made + 1
	return number
end

function Pool.New(parent, capacity)
	return setmetatable({ parent = parent, capacity = capacity, active = {}, free = {}, made = 0 }, Pool)
end

function Pool:Acquire()
	local free = self.free
	local number = free[#free]
	if number then
		free[#free] = nil
	elseif self.made < self.capacity then
		number = Make(self)
	else
		self:Release(self.active[1])
		number = free[#free]
		free[#free] = nil
	end
	number.live = true
	local active = self.active
	active[#active + 1] = number
	return number
end

function Pool:Release(number)
	if not number or not number.live then
		return
	end
	number.live = false
	number.group:Stop()
	number.frame:Hide()
	Remove(self.active, number)
	local emitter = number.emitter
	if emitter then
		Remove(emitter.active, number)
		number.emitter = nil
	end
	local free = self.free
	free[#free + 1] = number
end

function Pool:ReleaseAll()
	local active = self.active
	while #active > 0 do
		self:Release(active[#active])
	end
end
