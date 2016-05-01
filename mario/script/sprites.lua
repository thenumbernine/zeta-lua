return {
	{
		name='small-mario',
		dir='mario-small',
		frames={
			stand='stand.png',
			stand_arms='stand-arms.png',
			stand_carry='stand-carry.png',
			step='step.png',
			step_arms='step-arms.png',
			step_carry='step-carry.png',
			lookfwd='lookfwd.png',
			lookback='lookback.png',
			lookup='lookup.png',
			lookup_carry='lookup-carry.png',
			lookupback1='lookupback1.png',
			lookupback2='lookupback2.png',
			duck='duck.png',
			duck_carry='duck-carry.png',
			jump='jump.png',
			jump_arms='jump-arms.png',
			fall='fall.png',
			die='die.png',
			kick='kick.png',
			skid='skid.png',		-- TODO skidding stop
			slide='slide.png',		-- TODO sliding
			climb1='climb1.png',
			climb2='climb2.png',
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
			stand='stand.png',
			stand_arms='stand-arms.png',
			stand_carry='stand-carry.png',
			step='step1.png',
			step1_arms='step-arms1.png',
			step1_carry='step1-carry.png',
			step2='step2.png',
			step2_arms='step-arms2.png',
			step2_carry='step2-carry.png',
			lookfwd='lookfwd.png',
			lookback='lookback.png',
			lookup='lookup.png',
			lookup_carry='lookup-carry.png',
			duck='duck.png',
			duck_carry='duck-carry.png',
			jump='jump.png',
			jump_arms='jump-arms.png',
			fall='fall.png',
			die='../mario-small/die.png',
			kick='kick.png',
			skid='skid.png',
			climb1='climb1.png',
			climb2='climb2.png',
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
		frames={
			stand='stand.png',
			walk1='walk1.png',
			walk2='walk2.png',
			walk3='walk3.png',
			walk4='walk4.png',
			walk5='walk5.png',
			die='die.png',
			fly1='fly1.png',
			fly2='fly2.png',
			fly3='fly3.png',
		},
		seqs={
			walk={'stand', 'walk1', 'walk2', 'walk3', 'walk4', 'walk5', freq=16},
			fly={'fly1', 'fly2', 'fly3', freq=4},
		},
	},
	{
		name='koopa',
		dir='koopa',
		frames={
			stand='stand.png',
			step='step.png',
			turn='turn.png',
		},
		seqs={
			walk={'stand', 'step', freq=4},
		},
	},
	{
		name='shell',
		dir='shell',
		frames={
			stand='stand.png',
			spin1='spin1.png',
			spin2='spin2.png',
			eyes='eyes.png',
		},
		seqs={
			spin={'stand', 'spin1', 'spin2', freq=8},
			eyes={'eyes', 'eyes', 'eyes', 'eyes', 'eyes', 'eyes', 'stand', freq=4},
		},
	},
	{
		name='thwomp',
		dir='thwomp',
		frames={
			stand='stand.png',
			ready='ready.png',
			stomp='stomp.png',
		},
	},
	{
		name='ballnchain',
		dir='ballnchain',
		frames={
			stand='ball.png',
			chain='chain.png',
		},
	},
	
		-- items
	
	{
		name='wings',
		dir='wings',
		frames={
			stand='stand.png',
			flap='flap.png',
		},
		seqs={
			fly={'flap', 'stand', freq=8},
		},
	},
	{name='mushroom', dir='mushroom', frames={stand='stand.png'}},
	{name='pickaxe', dir='pickaxe', frames={stand='stand.png'}},
	{name='bazooka', dir='bazooka', frames={stand='stand.png'}},
	{name='minigun', dir='minigun', frames={stand='stand.png'}},
	{name='shotgun', dir='shotgun', frames={stand='stand.png'}},

	{name='supermissile', dir='supermissile', frames={stand='stand.png'}},
	
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

		-- objects
	

	{
		name='explosive',
		dir='explosive',
		frames={
			stand='stand.png',
			detonate='detonate.png',
		},
	},
	{
		name='blast',
		dir='blast',
		frames={
			blast1='blast1.png',
			blast2='blast2.png',
		},
		seqs={
			blast={'blast1', 'blast2', freq=16},
		},
	},
	{
		name='springboard',
		dir='springboard',
		frames={
			stand='stand.png',
			spring1='spring1.png',
			spring2='spring2.png',
		},
	},
	{
		name='p-switch',
		dir='p-switch',
		frames={
			stand='stand.png',
			hit='hit.png',
		},
	},
	{
		name='pirahnaplant',
		dir='pirahnaplant',
		frames={
			chomp0='chomp0.png',
			chomp1='chomp1.png',
			chomp2='chomp2.png',
			chomp3='chomp3.png',
		},
		seqs={
			stand={'chomp0', 'chomp1', 'chomp2', 'chomp3', freq=16},
		},
	},
	{
		name='egg',
		dir='egg',
		frames={
			stand='stand.png',
		}
	},
	{
		name='exitball',
		dir='exitball',
		frames={
			stand='stand.png',
		},
	},
	{
		name='door',
		dir='door',
		frames={
			stand='stand.png',
			ghost='ghost.png',
			castle='castle.png',
			chocolate='chocolate.png',
		},
	},
	{name='puff', dir='puff', frames={stand='stand.png'}},
	
	-- tiles:
	
	{
		name='coin',
		dir='coin',
		frames={
			coin1='coin1.png',
			coin2='coin2.png',
			coin3='coin3.png',
			coin4='coin4.png',
		},
		seqs={
			stand={'coin1', 'coin2', 'coin3', 'coin4', freq=8},
		},
	},
	{
		name='spinblock',
		dir='spinblock',
		frames={
			stand='spinblock.png',
			spin1='spin1.png',
			spin2='spin2.png',
			spin3='spin3.png',
			particle='particle.png',
		},
		seqs={
			spin={'spin1', 'spin2', 'spin3', 'stand', freq=8},
		},
	},
	{	
		name='pickupblock',
		dir='pickupblock',
		frames={
			stand='stand.png',
			yellow='../spinblock/spinblock.png',	-- TODO make use of palettes
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
			stand2='stand2.png',
			stand3='stand3.png',
			stand4='stand4.png',
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
			stand2='stand2.png',
			stand3='stand3.png',
			stand4='stand4.png',
		},
		seqs={
			stand={'stand1','stand2','stand3','stand4', freq=8},
		},
	},
	{name='exclaimblock', dir='exclaimblock', frames={stand='stand.png'}},
	{name='anticoin', dir='anticoin', frames={stand='stand.png'}},
	{name='water', dir='water', frames={stand='stand.png'}},
	{name='vine', dir='vine', frames={stand='stand.png'}},
	{name='stoneblock', dir='stoneblock', frames={stand='stand.png'}},
}
