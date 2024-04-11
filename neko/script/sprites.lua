-- args:
-- name, n, freq
local function seq(args)
	local res = {}
	for i=0,args.n-1 do
		table.insert(res, args.name..'_'..i)
	end
	res.freq = args.freq
	return res
end

return {
	{
		name='neko',
		dir='neko',
		seqs={
			walk={'stand','step1','step2', freq=8},
			run={'stand','step1','step2', freq=16},
			climb={'climb1', 'climb2', freq=4},
			climbfwd={'climbfwd1', 'climbfwd2', freq=4},
			swimstroke={'swim2','swim3', freq=8},
		},
	},
	{
		name='berry_red',
		dir='berry_red',
		seqs = {},
	},
	{
		name='berry_pink',
		dir='berry_pink',
		seqs = {},
	},
	{
		name='berry_green',
		dir='berry_green',
		seqs = {},
	},
}
