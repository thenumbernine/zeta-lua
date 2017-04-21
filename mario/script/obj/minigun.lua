local class = require 'ext.class'
local ItemObject  = require 'mario.script.obj.item'
local PlayerItem = require 'base.script.item'
local SpinParticle = require 'mario.script.obj.spinparticle'
local game = require 'base.script.singleton.game'


local MinigunItem = class(PlayerItem)
MinigunItem.sprite = 'minigun'
MinigunItem.drawOffset = {.25, .25}

function MinigunItem:onShoot(shooter)
	local x, y = shooter.pos[1], shooter.pos[2] + shooter.bbox.max[2] - .4
	local dx, dy = 0, 0

	-- (1) traceline from shooter

	-- matches bazooka
	if shooter.inputUpDown > 0 then
		dx = shooter.inputLeftRight
		dy = shooter.inputUpDown
	else
		if shooter.drawMirror then
			dx = -1
		else
			dx = 1
		end
	end
	
	local hit
	local level = game.level
	for i=1,20 do
		local tile = level:getTile(math.floor(x),math.floor(y))
		if not tile then break end
		
		-- (3) hurt anything we hit
		-- (2) spawn spinparticles on hit
		if tile.objs then
			for _,obj in ipairs(tile.objs) do
				if obj ~= shooter and obj.hitByShell then
					if obj.solid and obj.collidesWithObjects then hit = true end
					obj:hitByShell(self)
				end
			end
		end
		
		if tile.solid then
			hit = true
			if tile.onSpinJump then
				tile:onSpinJump(self)
			elseif tile.onHit then
				tile:onHit(self)
			end
		end
		
		if hit then
			SpinParticle.breakAt(x + .5, y + .5)	-- ... in addition to the (possible) spinjump particles ...
			break
		end
		
		x,y = x + dx, y + dy
	end
end


local Minigun = class(ItemObject)
Minigun.sprite = 'minigun'
Minigun.itemClass = MinigunItem

return Minigun
