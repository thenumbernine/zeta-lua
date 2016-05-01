return {

	{color=0xffffff},
	
	-- special:
	
	{color=0x00ff00, startPos=true},

	-- tiles:
	
		-- template
	{color=0x000000, tile=require 'base.script.tile.solid'},
	{color=0x5f5f5f, tile=require 'base.script.tile.slope45'},
	{color=0x8f8f8f, tile=require 'base.script.tile.slope27'},

		-- fluid
	{color=0x0000ff, tile=require 'base.script.tile.water'},

}