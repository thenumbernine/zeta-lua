return {
	-- solid	
	require 'base.script.tile.solid'(),
	
	-- 45 degrees
	require 'base.script.tile.slope45'{name='ul-diag45', plane={-1,1,0}},
	require 'base.script.tile.slope45'{name='ur-diag45', plane={1,1,-1}},
	require 'base.script.tile.slope45'{name='dl-diag45', plane={-1,-1,1}}, 
	require 'base.script.tile.slope45'{name='dr-diag45', plane={1,-1,0}},
	
	-- 27 degrees on ground
	require 'base.script.tile.slope27'{name='ul2-diag27', plane={-1,2,0}}, 
	require 'base.script.tile.slope27'{name='ul1-diag27', plane={-1,2,-1}},
	require 'base.script.tile.slope27'{name='ur2-diag27', plane={1,2,-1}}, 
	require 'base.script.tile.slope27'{name='ur1-diag27', plane={1,2,-2}}, 
	
	require 'base.script.tile.slope27'{name='dl2-diag27', plane={-1,-2,2}}, 
	require 'base.script.tile.slope27'{name='dl1-diag27', plane={-1,-2,1}},
	require 'base.script.tile.slope27'{name='dr2-diag27', plane={1,-2,1}}, 
	require 'base.script.tile.slope27'{name='dr1-diag27', plane={1,-2,0}}, 
	
	-- water
	require 'base.script.tile.water'(),
	
	-- ladder
	require 'base.script.tile.ladder'(),
}
