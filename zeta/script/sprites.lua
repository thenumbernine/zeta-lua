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
		name='hero',
		dir='hero',
		seqs={
			walk=seq{name='run', n=16, freq=24},
			walk_carry=seq{name='run_carry', n=16, freq=24},
			run=seq{name='run', n=16, freq=50},
			run_carry=seq{name='run_carry', n=16, freq=48},
			crawl=seq{name='crawl', n=1},
			crawl_walk=seq{name='crawl', n=16, freq=24},
			climb={'climb_1'},
			climb_updown=seq{name='climb', n=16, freq=24},
			stand={'stand_0'},
			stand_carry={'stand_carry_0'},
			lookup={'lookup_0'},
			lookup_carry={'lookup_carry_0'},
			jump={'jump_0'},
			fall={'fall_0'},
		},
	},

	{
		name='savepoint',
		dir='savepoint',
		seqs={
			stand={'stand1', 'stand2', freq=16},
		},
	},

	{
		name='energyrefill',
		dir='energyrefill',
		seqs={
			spark={
				'spark1','spark2','spark3','spark4','spark5',
				'spark6','spark7','spark8','spark9','spark10',
				freq=20,
			},
		},
	},

	{
		name='crystal',
		dir='crystal',
		seqs={
			stand={
				'stand1', 'stand2', 'stand3', 'stand4', 'stand5',
				'stand6', 'stand7', 'stand8', 'stand9', 'stand10',
				'stand11', 'stand12', 'stand13', 'stand14', 'stand15',
				freq=16,
			},
		},
	},

	{
		name='cells',
		dir='cells',
		seqs={
			stand={
				'stand1', 'stand2', 'stand3', 'stand4', 'stand5', 'stand6', 'stand7', 
				'stand8', 'stand7', 'stand6', 'stand5', 'stand4', 'stand3', 'stand2',
				freq=16,
			},
		},
	},

	{
		name='heart',
		dir='heart',
		seqs={
			stand={'stand1','stand2','stand3', freq=16},
		},
	},
	{
		name='attack-bonus',
		dir='attack-bonus',
		seqs={
			stand={'stand1','stand2','stand3', freq=16},
		},
	},
	{
		name='defense-bonus',
		dir='defense-bonus',
		seqs={
			stand={'stand1','stand2','stand3', freq=16},
		},
	},
		
		-- weapons
	
	{
		name='missileblast',
		dir='missileblast',
		seqs={
			stand={'stand1', 'stand2', 'stand3', 'stand4', 'stand5', 'stand6', freq=8},
		},
	},
	
	{name='plasma-rifle', dir='plasma-rifle'},
	{name='plasma-shot', dir='plasma-shot'},
	{
		name='plasma-blast',
		dir='plasma-blast',
		seqs={
			stand={'stand1', 'stand2', 'stand3', 'stand4', 'stand5', freq=8},
		},
	},

	-- enemies

	{
		name='barrier',
		dir='barrier',
		seqs={
			stand={'stand1', 'stand2', 'stand3', 'stand4', 'stand5', freq=30},
		},
	},

	{
		name='bat',
		dir='bat',
		seqs={
			stand=seq{name='stand', n=16, freq=50},
		},
	},

	{
		name='teeth',
		dir='teeth',
		seqs={
			stand=seq{name='stand',n=1},
			chomp=seq{name='chomp',n=12,freq=25},
		},
	},

	-- misc

	{
		name='breakblock',
		dir='breakblock',
		seqs={
			stand={'stand1', 'stand2', 'stand3', 'stand4', 'stand5', freq=15},
			unbreak={'stand5', 'stand4', 'stand3', 'stand2', 'stand1', freq=15},
		},
	},
}
