-- test-stubs-pending-size.lua: frame measurements synchronously deliver a pending layout size notification once, including re-entrant measurements.
local env = dofile("Tools/regression/stubs/wow.lua").NewEnv()
for _, method in ipairs({ "GetWidth", "GetHeight" }) do
	local frame = env.CreateFrame("Frame", nil, env.UIParent)
	frame:SetSize(200, 120)
	local events = 0
	frame:SetScript("OnSizeChanged", function(self, width, height)
		events = events + 1
		assert(width == 200 and height == 120, "the pending notification carries the frame's size")
		assert(self:GetWidth() == width and self:GetHeight() == height, "measuring inside the handler does not recurse")
	end)
	assert(events == 0, "attaching the handler does not resolve a pending size")
	assert(frame[method](frame) == (method == "GetWidth" and 200 or 120))
	assert(events == 1, method .. " must fire OnSizeChanged before returning")
	frame[method](frame)
	assert(events == 1, "a consumed notification does not fire twice")
	env.QueueSizeChanged(frame)
	assert(events == 1, "pending layout is deferred until measurement")
	frame[method](frame)
	assert(events == 2, "pending layout can resolve even when the measured size is unchanged")
end
print("stubs pending size ok")
