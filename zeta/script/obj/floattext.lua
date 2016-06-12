local Object = require 'base.script.obj.object'
return function(args)
	local gui = require 'base.script.singleton.gui'
	local game = require 'base.script.singleton.game'
	local tick = Object{
		pos = args.pos,
	}
	tick.solid = false
	tick.solidFlags = 0
	tick.touchFlags = 0
	tick.blockFlags = 0
	tick.removeTime = game.time + 1
	--tick.vel[2] = 1
	tick.useGravity = false
	tick.draw = function(self, R)
		gui.font:drawUnpacked(self.pos[1], self.pos[2]+2, 1, -1, args.text)
		-- gui hasn't been R-integrated yet ...
		local gl = R.gl
		gl.glEnable(gl.GL_TEXTURE_2D)
	end
end
