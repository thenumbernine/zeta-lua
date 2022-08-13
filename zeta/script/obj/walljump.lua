local WallJump = behaviors(
	require 'zeta.script.obj.item',
	require 'zeta.script.behavior.crystalitem')
WallJump.name = 'walljump'	-- TODO automated names?  1-1 with lua filename?
WallJump.sprite = 'walljump'
return WallJump
