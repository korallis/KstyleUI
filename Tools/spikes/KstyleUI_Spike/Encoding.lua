-- Encoding.lua: the encoding spike checks C_EncodingUtil and round-trips a sample profile through export and import.
local _, ns = ...

local PREFIX = "KSUI1:"
local FUNCTIONS = { "SerializeCBOR", "DeserializeCBOR", "CompressString", "DecompressString", "EncodeBase64", "DecodeBase64" }
local GARBAGE = "!!not a profile string!!"

local function SampleProfile()
	return {
		version = 1,
		profiles = {
			Default = {
				UnitFrames = { enabled = true, portraits = false, width = 220, scale = 1.25 },
				ActionBars = { enabled = true, buttonSize = 34, rows = 2, gap = 3 },
			},
		},
		characters = { ["Realm-Name"] = "Default" },
		layouts = {
			Default = {
				player = { anchor = "BOTTOM", x = -262.5, y = 214 },
				target = { anchor = "BOTTOM", x = 262.5, y = 214 },
			},
		},
		account = { iconSet = "A", tint = { 0.25, 0.5, 1 } },
		list = { 1, 2, 3, "four", false },
		negative = -42,
	}
end

local function Step(stages, name, fn, ...)
	local ok, out = pcall(fn, ...)
	stages[#stages + 1] = {
		stage = name,
		ok = ok,
		kind = ok and type(out) or nil,
		size = ok and type(out) == "string" and #out or nil,
		error = not ok and tostring(out) or nil,
	}
	return ok, out
end

local function Probe(fn, input)
	local ok, out = pcall(fn, input)
	return { ok = ok, kind = ok and type(out) or nil, error = not ok and tostring(out) or nil }
end

ns.Register("encoding", {
	group = "basic",
	summary = "checks the C_EncodingUtil functions profile export needs and round-trips a sample profile.",
	Run = function(run)
		local api = C_EncodingUtil
		local exists, all = {}, true
		for _, name in ipairs(FUNCTIONS) do
			exists[name] = api ~= nil and type(api[name]) == "function"
			all = all and exists[name]
		end
		run:Set("exists", exists)
		if not all then
			run:Set("roundTrip", "unavailable")
			run:Note("C_EncodingUtil is incomplete on this client.")
			return
		end

		local stages, profile = {}, SampleProfile()
		run:Set("stages", stages)
		local ok, cbor = Step(stages, "SerializeCBOR", api.SerializeCBOR, profile)
		local packed, encoded, decoded, unpacked, restored
		if ok then
			ok, packed = Step(stages, "CompressString", api.CompressString, cbor)
		end
		if ok then
			ok, encoded = Step(stages, "EncodeBase64", api.EncodeBase64, packed)
		end
		if not ok or type(encoded) ~= "string" then
			run:Set("roundTrip", false)
			return
		end
		local exported = PREFIX .. encoded
		run:Set("prefix", exported:sub(1, #PREFIX))
		run:Set("exportLength", #exported)

		ok, decoded = Step(stages, "DecodeBase64", api.DecodeBase64, exported:sub(#PREFIX + 1))
		if ok then
			ok, unpacked = Step(stages, "DecompressString", api.DecompressString, decoded)
		end
		if ok then
			ok, restored = Step(stages, "DeserializeCBOR", api.DeserializeCBOR, unpacked)
		end
		if ok then
			local same, where = ns.DeepEqual(profile, restored)
			run:Set("roundTrip", same)
			run:Set("mismatch", where)
		else
			run:Set("roundTrip", false)
		end

		run:Set("rejectsGarbage", {
			DecodeBase64 = Probe(api.DecodeBase64, GARBAGE),
			DecompressString = Probe(api.DecompressString, GARBAGE),
			DeserializeCBOR = Probe(api.DeserializeCBOR, GARBAGE),
		})
		run:Note("round trip " .. (run.data.results.roundTrip == true and "matched." or "did not match."))
	end,
})
