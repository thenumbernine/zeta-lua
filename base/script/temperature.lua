local _0C_in_K = 273.15
local function CtoF(c) return 9 / 5 * c + 32 end
local function CtoK(c) return c + _0C_in_K end
local function FtoC(f) return 5/9 * (f - 32) end
local function FtoK(f) return CtoK(FtoC(f)) end
local function KtoC(k) return k - _0C_in_K end
local function KtoF(k) return CtoF(KtoC(k)) end
return {
	_0C_in_K  = _0C_in_K,
	CtoF = CtoF,
	CtoK = CtoK,
	FtoC = FtoC,
	FtoK = FtoK,
	KtoC = KtoC,
	KtoF = KtoF,
}
