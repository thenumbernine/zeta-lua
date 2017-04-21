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
		name='small-mario',
		dir='mario-small',
		frames={
			stand_arms='stand-arms.png',
			stand_carry='stand-carry.png',
			step_arms='step-arms.png',
			step_carry='step-carry.png',
			lookup_carry='lookup-carry.png',
			duck_carry='duck-carry.png',
			jump_arms='jump-arms.png',
			climb1_fwd='climb1-fwd.png',
			climb2_fwd='climb2-fwd.png',
		},
		seqs={
			walk={'stand','step', freq=8},
			walk_carry={'stand_carry','step_carry', freq=8},
			run={'stand','step', freq=16},
			run_carry={'stand_carry','step_carry', freq=16},
			maxrun={'stand_arms','step_arms', freq=16},
			spinjump={'stand', 'lookfwd', 'stand', 'lookback', freq=16},
			spinjump_carry={'stand_carry', 'lookfwd', 'stand_carry', 'lookback', freq=16},
			jump_carry={'step_carry'},
			climb={'climb1', 'climb2', freq=4},
			climb_fwd={'climb1_fwd', 'climb2_fwd', freq=4},
		},
	},
	{
		name='big-mario',
		dir='mario-big',
		frames={
			stand_arms='stand-arms.png',
			stand_carry='stand-carry.png',
			step='step1.png',
			step1_arms='step-arms1.png',
			step1_carry='step1-carry.png',
			step2_arms='step-arms2.png',
			step2_carry='step2-carry.png',
			lookup_carry='lookup-carry.png',
			duck_carry='duck-carry.png',
			jump_arms='jump-arms.png',
			-- TODO change sprite to small-mario
			die='../mario-small/die.png',
			climb1_fwd='climb1-fwd.png',
			climb2_fwd='climb2-fwd.png',
		},
		seqs={
			walk={'stand','step','step2', freq=8},
			walk_carry={'stand_carry','step1_carry','step2_carry', freq=8},
			run={'stand','step','step2', freq=16},
			run_carry={'stand_carry','step1_carry','step2_carry', freq=16},
			maxrun={'stand_arms','step1_arms','step2_arms', freq=16},
			spinjump={'stand', 'lookfwd', 'stand', 'lookback', freq=16},
			spinjump_carry={'stand_carry', 'lookfwd', 'stand_carry', 'lookback', freq=16},
			jump_carry={'step2_carry'},
			climb={'climb1', 'climb2', freq=4},
			climb_fwd={'climb1_fwd', 'climb2_fwd', freq=4},
		},
	},
	
		-- enemies
	
	{
		name='goomba',
		dir='goomba',
		seqs={
			walk={'stand', 'walk1', 'walk2', 'walk3', 'walk4', 'walk5', freq=16},
			fly={'fly1', 'fly2', 'fly3', freq=4},
		},
	},
	{
		name='koopa',
		dir='koopa',
		seqs={
			walk={'stand', 'step', freq=4},
		},
	},
	{
		name='shell',
		dir='shell',
		seqs={
			spin={'stand', 'spin1', 'spin2', freq=8},
			eyes={'eyes', 'eyes', 'eyes', 'eyes', 'eyes', 'eyes', 'stand', freq=4},
		},
	},
	{name='thwomp', dir='thwomp'},
	{name='ballnchain', dir='ballnchain'},

		-- items
	
	{
		name='wings',
		dir='wings',
		seqs={
			fly={'flap', 'stand', freq=8},
		},
	},
	{name='mushroom', dir='mushroom'},
	{name='pickaxe', dir='pickaxe'},
	{name='bazooka', dir='bazooka'},
	{name='minigun', dir='minigun'},
	{name='shotgun', dir='shotgun'},

	{name='supermissile', dir='supermissile'},
	
	{
		name='missileblast',
		dir='missileblast',
		frames={
			stand1='stand.png',
		},
		seqs={
			stand={'stand1', 'stand2', 'stand3', 'stand4', 'stand5', 'stand6', freq=8},
		},
	},

		-- objects
	

	{name='explosive', dir='explosive'},
	{
		name='blast',
		dir='blast',
		seqs={
			blast={'blast1', 'blast2', freq=16},
		},
	},
	{name='springboard', dir='springboard'},
	{name='p-switch', dir='p-switch'},
	{
		name='pirahnaplant',
		dir='pirahnaplant',
		seqs={
			stand={'chomp0', 'chomp1', 'chomp2', 'chomp3', freq=16},
		},
	},
	{name='egg', dir='egg'},
	{name='exitball', dir='exitball'},
	{name='door', dir='door'},
	{name='puff', dir='puff'},
	
	-- tiles:
	
	{
		name='coin',
		dir='coin',
		seqs={
			stand={'coin1', 'coin2', 'coin3', 'coin4', freq=8},
		},
	},
	{
		name='spinblock',
		dir='spinblock',
		frames={
			stand='spinblock.png',
		},
		seqs={
			spin={'spin1', 'spin2', 'spin3', 'stand', freq=8},
		},
	},
	{	
		name='pickupblock',
		dir='pickupblock',
		frames={
			-- TODO make use of palettes
			yellow='../spinblock/spinblock.png',	
			-- TODO red too			
		},
		seqs={
			pickedup={'stand', 'yellow', freq=16},
			almostgone={'stand', 'yellow', freq=2},
		}
	},
	{
		name='questionblock',
		dir='questionblock',
		frames={
			stand1='stand.png',
		},
		seqs={
			stand={'stand1','stand2','stand3','stand4', freq=8},
		},
	},
	{
		name='breakblock',
		dir='breakblock',
		frames={
			stand1='stand.png',
		},
		seqs={
			stand={'stand1','stand2','stand3','stand4', freq=8},
		},
	},
	{name='exclaimblock', dir='exclaimblock'},
	{name='anticoin', dir='anticoin'},
	{name='water', dir='water'},
	{name='vine', dir='vine'},
	{name='stoneblock', dir='stoneblock'},

}
