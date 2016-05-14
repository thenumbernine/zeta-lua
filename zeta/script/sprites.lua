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
}
