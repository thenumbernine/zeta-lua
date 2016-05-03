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
	-- single-frame sprites
	{name='blaster', dir='blaster', frames={stand='stand.png'}},
	{name='blaster-shot', dir='blaster-shot', frames={stand='stand.png'}},
	{name='geemer', dir='geemer', frames={stand='stand.png', chunk='chunk.png'}},
	{name='puff', dir='puff', frames={stand='stand.png'}},
	-- tiles	
	{name='tile-metal', dir='tile-metal', frames={stand='stand.png'}},
}
