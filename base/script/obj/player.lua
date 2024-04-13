local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'

local Player = require 'base.script.obj.object':subclass()

-- all PlayerObjects:
Player.inputUpDown = 0
Player.inputLeftRight = 0
Player.inputJump = false
Player.inputJumpAux = false
Player.inputShoot = false
Player.inputShootAux = false

function Player:init(...)
	self.viewPos = vec2()
	self.viewBBox = box2()
	-- only needed for games that use the mouse ... hmm ...
	self.mouseScreenPos = vec2()
	self.mousePos = vec2()
	
	Player.super.init(self, ...)
end

return Player
