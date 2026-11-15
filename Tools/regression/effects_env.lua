-- effects_env.lua: fixtures for the Medallions effects layer: C_CurveUtil curves that evaluate in Lua, UnitHealthPercent and UnitPowerPercent that answer secrets through them, and UnitPowerType, so a test or a perf path can drive the curve-driven effects.
--
--   local FX = dofile("Tools/regression/effects_env.lua")
--   local env, K = W.New({ setup = FX.Install })   -- then env._health, env._power, env._powerType, env._powerToken
local FX = {}

local function NewCurve()
	local curve = { points = {} }
	function curve.SetType(self, kind)
		self.kind = kind
	end
	function curve.AddPoint(self, x, y)
		self.points[#self.points + 1] = { x, y }
		table.sort(self.points, function(a, b)
			return a[1] < b[1]
		end)
	end
	function curve.Evaluate(self, x)
		local pts = self.points
		if x <= pts[1][1] then
			return pts[1][2]
		end
		for i = 2, #pts do
			local a, b = pts[i - 1], pts[i]
			if x < b[1] then
				if self.kind == "Step" then
					return a[2]
				end
				return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
			end
		end
		return pts[#pts][2]
	end
	return curve
end

function FX.Install(env)
	env.Enum = env.Enum or {}
	env.Enum.LuaCurveType = env.Enum.LuaCurveType or { Linear = "Linear", Step = "Step" }
	env.Enum.PowerType = env.Enum.PowerType or { Mana = 0, Rage = 1, SoulShards = 7, HolyPower = 9 }
	env.C_CurveUtil = env.C_CurveUtil or {}
	env.C_CurveUtil.CreateCurve = NewCurve
	env._health, env._power = 1, 1
	env._powerType, env._powerToken = 1, "RAGE"
	env.UnitHealthPercent = function(_, _, curve)
		return env.Secret(curve and curve:Evaluate(env._health) or env._health)
	end
	env.UnitPowerPercent = function(_, kind, _, curve)
		env._askedPower = kind
		return env.Secret(curve and curve:Evaluate(env._power) or env._power)
	end
	env.UnitPowerType = function()
		return env._powerType, env._powerToken
	end
	env.UnitIsDeadOrGhost = function()
		return env._dead == true
	end
end

return FX
