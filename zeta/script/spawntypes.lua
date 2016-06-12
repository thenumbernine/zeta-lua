return {
	spawn = {
		-- interaction
		{spawn='zeta.script.obj.solid'},	-- solid, but can be moved/removed by script 
		{spawn='zeta.script.obj.trigger'},	-- touch to perform events 
		{spawn='zeta.script.obj.door'},
		{spawn='zeta.script.obj.terminal'},
		{spawn='zeta.script.obj.savepoint'},
		{spawn='zeta.script.obj.energyrefill'},
		-- items	
		{spawn='zeta.script.obj.item'},
		{spawn='zeta.script.obj.keycard'},
		-- weapons
		{spawn='zeta.script.obj.blaster'},
		{spawn='zeta.script.obj.skillsaw'},
		{spawn='zeta.script.obj.missilelauncher'},
		{spawn='zeta.script.obj.grenadelauncher'},
		{spawn='zeta.script.obj.plasmarifle'},
		-- powerups
		{spawn='zeta.script.obj.heart'},
		{spawn='zeta.script.obj.grenadeitem'},
		{spawn='zeta.script.obj.missileitem'},
		{spawn='zeta.script.obj.cells'},
		{spawn='zeta.script.obj.attackbonus'},
		{spawn='zeta.script.obj.defensebonus'},
		{spawn='zeta.script.obj.healthmaxitem'},
		{spawn='zeta.script.obj.speedbooster'},
		{spawn='zeta.script.obj.walljump'},
		-- monsters
			-- mining base
		{spawn='zeta.script.obj.turret'},
		{spawn='zeta.script.obj.barrier'},
		{spawn='zeta.script.obj.sawblade'},
			-- caves
		{spawn='zeta.script.obj.geemer'},
		{spawn='zeta.script.obj.redgeemer'},
		{spawn='zeta.script.obj.boss-geemer'},
		{spawn='zeta.script.obj.bat'},
		{spawn='zeta.script.obj.zoomer'},
		{spawn='zeta.script.obj.teeth'},
	},
	serialize = {
		-- serialization uses spawntypes for metatable lookup, so any object that is saved needs to be in this list
		-- that includes shots and death particles
		{spawn='zeta.script.obj.spritepieces'},
		{spawn='zeta.script.obj.blastershot'},
		{spawn='zeta.script.obj.plasmashot'},
		{spawn='zeta.script.obj.grenade'},
		{spawn='zeta.script.obj.missile'},
	},
}
