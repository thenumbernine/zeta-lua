return {

	-- tiles:
	
		-- template
	{color=0x00007f, tile=require 'mario.script.tile.notsolid'},

		-- fixed template
	{color=0x7f007f, tile=require 'mario.script.tile.fence'},
	
		-- non-template
	{color=0xbfbfbf, tile=require 'mario.script.tile.stone'},
	{color=0x7f7f00, tile=require 'mario.script.tile.spin'},
	{color=0xffff00, tile=require 'mario.script.tile.coin'},
	{color=0x671f28, tile=require 'mario.script.tile.anticoin'},
	{color=0x7f00ff, tile=require 'mario.script.tile.pickup'},
	{color=0x00ff7f, tile=require 'mario.script.tile.vine'},
	{color=0xffcf00, tile=require 'mario.script.tile.spike'},
	{color=0xffef4f, tile=require 'mario.script.tile.question'},
	{color=0x7f0000, tile=require 'mario.script.tile.break'},
	{color=0x4a4a90, tile=require 'mario.script.tile.exclaim'},
	{color=0xcfcfff, tile=require 'mario.script.tile.exclaimoutline'},
	
	-- spawns:
	
		-- enemies
	{color=0xff0000, spawn=require 'mario.script.obj.koopa'},
	{color=0xff7f00, spawn=require 'mario.script.obj.goomba'},
	{color=0x007f00, spawn=require 'mario.script.obj.shell'},
	{color=0x7f7f7f, spawn=require 'mario.script.obj.thwomp'},
	{color=0x6f6f6f, spawn=require 'mario.script.obj.ballnchain'},
	
		-- powerups
	{color=0xff00ff, spawn=require 'mario.script.obj.mushroom'},
	{color=0x007fff, spawn=require 'mario.script.obj.wings'},
	{color=0x7f3f00, spawn=require 'mario.script.obj.pickaxe'},
	{color=0x00517f, spawn=require 'mario.script.obj.bazooka'},
	{color=0x7f0051, spawn=require 'mario.script.obj.minigun'},

		-- objects
	{color=0xff7f7f, spawn=require 'mario.script.obj.explosive'},
	{color=0x00bf00, spawn=require 'mario.script.obj.springboard'},
	{color=0xa4a56d, spawn=require 'mario.script.obj.vineegg'},
	{color=0x00ffff, spawn=require 'mario.script.obj.flag'},
	{color=0xffeca0, spawn=require 'mario.script.obj.door'},
	{color=0x7f7fff, spawn=require 'mario.script.obj.p-switch'},
}
