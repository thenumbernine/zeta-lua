local game = require 'base.script.singleton.game'

local Berry = require 'neko.script.obj.item':subclass()
Berry.sprite = 'berry_red'
Berry.useGravity = false

Berry.pickDuration = 1

-- item playerGrab?
function Berry:playerGrab(player)
	self.grabTime = game.time
end

-- item update?
function Berry:update(...)
	Berry.super.update(self, ...)

	local heldby = self.heldby
	if heldby
	and self.grabTime
	and game.time - self.grabTime > self.pickDuration
	then
		-- get in muh backpack
		heldby:setHeld(nil)
		heldby.items:insert(self)
		self.solidFlags = 0
		self.blockFlags = 0
		self.touchFlags = 0
		self.inInventory = true
	end
end

return Berry
