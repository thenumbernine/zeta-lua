return {
	{
		name='hero',
		dir='hero',
		frames={
			stand='stand.png',
			stand_arms='stand-arms.png',
			step='step1.png',
			step1_arms='step-arms1.png',
			step2='step2.png',
			step2_arms='step-arms2.png',
			lookfwd='lookfwd.png',
			lookback='lookback.png',
			lookup='lookup.png',
			duck='duck.png',
			jump='jump.png',
			jump_arms='jump-arms.png',
			fall='fall.png',
			die='die.png',
			kick='kick.png',
			skid='skid.png',
			climb1='climb1.png',
			climb2='climb2.png',
			climb1_fwd='climb1-fwd.png',
			climb2_fwd='climb2-fwd.png',
		},
		seqs={
			walk={'stand','step','step2', freq=8},
			run={'stand','step','step2', freq=16},
			maxrun={'stand_arms','step1_arms','step2_arms', freq=16},
			climb={'climb1', 'climb2', freq=4},
			climb_fwd={'climb1_fwd', 'climb2_fwd', freq=4},
		},
	},
	{
		name='heart',
		dir='heart',
		frames={
			stand1='stand1.png',
			stand2='stand2.png',
			stand3='stand3.png',
		},
		seqs={
			stand={'stand1','stand2','stand3', freq=16},
		},
	},
		
		-- weapons
	
	{name='blaster', dir='blaster', frames={stand='stand.png'}},
	{name='blaster-shot', dir='blaster-shot', frames={stand='stand.png'}},
	
	{name='missilelauncher', dir='missilelauncher', frames={stand='stand.png'}},
	{name='missile', dir='missile', frames={stand='stand.png'}},
	{
		name='missileblast',
		dir='missileblast',
		frames={
			stand1='stand.png',
			stand2='stand2.png',
			stand3='stand3.png',
			stand4='stand4.png',
			stand5='stand5.png',
			stand6='stand6.png',
		},
		seqs={
			stand={'stand1', 'stand2', 'stand3', 'stand4', 'stand5', 'stand6', freq=8},
		},
	},
	
	{name='minigun', dir='minigun', frames={stand='stand.png'}},
		-- enemies
	{name='geemer', dir='geemer', frames={stand='stand.png', chunk='chunk.png'}},
		-- etc
	{name='puff', dir='puff', frames={stand='stand.png'}},
	
	-- tiles	
	{name='tile-metal', dir='tile-metal', frames={stand='stand.png'}},
}
