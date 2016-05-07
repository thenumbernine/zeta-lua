return {
	{
		name='hero',
		dir='hero',
		seqs={
			walk={'stand','step','step2', freq=8},
			run={'stand','step','step2', freq=16},
			maxrun={'stand-arms','step1-arms','step2-arms', freq=16},
			climb={'climb1', 'climb2', freq=4},
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
	
	{name='blaster', dir='blaster'},
	{name='blaster-shot', dir='blaster-shot'},
	
	{name='grenadelauncher', dir='grenadelauncher'},
	{name='grenade', dir='grenade'},
	
	{name='missilelauncher', dir='missilelauncher'},
	{name='missile', dir='missile'},
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

	{name='minigun', dir='minigun'},
		
		-- enemies
	{name='geemer', dir='geemer'},
	{name='turret-body', dir='turret-body'},
	{name='turret-base', dir='turret-base'},
	{name='gato', dir='gato'},

		-- etc
	{name='puff', dir='puff'},
	
	-- tiles	
	{name='tile-metal', dir='tile-metal'},
	{name='tile-ladder', dir='tile-ladder'},
}
