-- test-ornament-plate-regions.lua: forty plates that have all cast once allocate no ornament region when Off, at most four in the idle set and six in the casting set (its ends, rails and the backing under a level dot), and draw at most six per plate.
local N = dofile("Tools/regression/nameplates_env.lua")
local Scene = dofile("Tools/render/scene.lua")
local counts = {}
for _, level in ipairs({ "Off", "Subtle", "Full" }) do
	local env, K, ns = N.New({ width = 1920, height = 1080 })
	env._textWidth = function(text, fontPath, size) return Scene.TextWidth(Scene.PlainText(text), size, fontPath) end
	local widgets = K.Store.Module("Widgets")
	widgets.cardMaterial, widgets.ornaments = "ForgedBrackets", level
	env.WorldFrame:SetPoint("TOPLEFT")
	env.WorldFrame:SetPoint("BOTTOMRIGHT")
	env._time = 10
	for i = 1, 40 do
		local unit = { name = "Mob " .. i, health = 500, maxHealth = 1000, level = 30 + i % 5, reaction = 2, canAttack = true }
		if i % 7 == 0 then unit.classification = "elite" end
		if i % 20 == 0 then unit.classification = "worldboss"; unit.level = -1 end
		if i % 13 == 0 then unit.raid = 1 + i % 8 end
		if i % 19 == 0 then unit.reaction, unit.canAttack, unit.isPlayer, unit.class = 5, false, true, "PALADIN" end
		local base = N.Add(env, "nameplate" .. i, unit, { scale = 0.58 })
		base:ClearAllPoints()
		base:SetPoint("CENTER", env.WorldFrame, "BOTTOMLEFT", 100 + (i % 8) * 220, 100 + math.floor(i / 8) * 120)
	end
	for _, frame in ipairs(env._frames) do
		for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
			local original = frame[method]
			frame[method] = function(self, ...)
				local was = self:IsVisible()
				original(self, ...)
				local now = self:IsVisible()
				if was ~= now then
					local fn = self._scripts and self._scripts[now and "OnShow" or "OnHide"]
					if fn then fn(self) end
				end
			end
		end
	end
	N.Target(env, "nameplate1")
	for i = 1, 40 do
		N.Cast(env, "nameplate" .. i, { name = "Bolt", text = "Bolt", texture = 136124, notInterruptible = false })
		ns.Plates.Get("nameplate" .. i).cast:Hide()
	end
	for i = 1, 40, 4 do N.Cast(env, "nameplate" .. i, { name = "Bolt", text = "Bolt", texture = 136124, notInterruptible = false }) end
	for _ = 1, 20 do N.Tick(env, 0.05) end
	Scene.Build(env)
	K.Callbacks.Fire("SettingChanged", "Widgets", "ornaments")
	local scene = Scene.Build(env)
	local drawn = {}
	for _, item in ipairs(scene.items) do drawn[item.object] = true end
	local allocated, used, visible, most = 0, 0, 0, 0
	for i = 1, 40 do
		local plate = ns.Plates.Get("nameplate" .. i)
		local per = 0
		local handle, sets, own = plate.ornament, {}, 0
		sets[handle.textures] = true
		for _, set in pairs(handle.sets or {}) do sets[set] = true end
		for set in pairs(sets) do
			local cap = handle.sets and handle.sets[false] == set and 4 or 6
			assert(#set <= cap, level .. ": plate " .. i .. " allocated " .. #set .. " regions for one placed set")
			own = own + #set
		end
		assert(own <= 10, level .. ": plate " .. i .. " allocated " .. own .. " regions")
		if level ~= "Off" and plate.unit and i % 19 ~= 0 then
			assert(handle.sets and handle.sets[true] and handle.sets[false], level .. ": plate " .. i .. " keeps an idle and a casting set after its cast")
		end
		allocated, used = allocated + own, used + handle.used
		for j = 1, handle.used do
			if drawn[handle.textures[j]] then visible, per = visible + 1, per + 1 end
		end
		assert(per <= 6, level .. ": plate " .. i .. " draws " .. per .. " ornament regions")
		most = math.max(most, per)
	end
	if level == "Off" then assert(allocated == 0, "Off allocated " .. allocated .. " ornament regions") end
	counts[#counts + 1] = string.format("%s %d/%d/%d max %d", level, allocated, used, visible, most)
end
print("ok forty plates after a cast each: " .. table.concat(counts, ", ") .. " (allocated/set/drawn, most on one plate)")
