local game = require 'base.script.singleton.game'
local threads = require 'base.script.singleton.threads'

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

	-- after holding the berry for a sec, pick it
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
	
		-- also unlink from spawnInfo, and after some time have the spawnInfo respawn a berry
		local spawnInfo = self.spawnInfo
		if spawnInfo then
			spawnInfo.obj = nil
			-- TODO berry vs berry spawnpoint, to get rid of threads (and thread serialization challenges)
			threads:add(function()
				local endTime = game.time + 5
				while game.time < endTime do
					coroutine.yield()
				end

				spawnInfo:respawn()
				local obj = spawnInfo.obj
				obj.drawScale = {0,0}
				local startTime = game.time
				local endTime = game.time + 2
				while game.time < endTime do
					local s = (game.time - startTime) / (endTime - startTime)
					obj.drawScale[1] = s
					obj.drawScale[2] = s
					coroutine.yield()
				end
				obj.drawScale = {1, 1}
			end)
		end
	end
end


local BerryShot = require 'base.script.obj.object':subclass()
local box2 = require 'vec.box2'
BerryShot.bbox = box2(-.1, -.1, .1, .1)
BerryShot.sprite = 'berry_red'
BerryShot.useGravity = false
BerryShot.damage = 1
BerryShot.drawScale = {.8, .8}
BerryShot.rotCenter = {.5, .5}
BerryShot.drawCenter = {.5, .5}

function BerryShot:init(...)
	BerryShot.super.init(self, ...)
	
	--self.angle = self.shooter.weapon.angle
	--self.drawMirror = self.shooter.weapon.drawMirror
	self.angle = math.deg(math.atan2(self.vel[2], self.vel[1]))
	self.drawMirror = self.vel[1] < 0
	if self.drawMirror then self.angle = self.angle + 180 end

--	self.removeTime = game.time + .2
end

BerryShot.solidFlags = BerryShot.SOLID_SHOT
BerryShot.touchFlags = bit.bor(BerryShot.SOLID_WORLD, BerryShot.SOLID_YES, BerryShot.SOLID_NO)
BerryShot.blockFlags = bit.bor(BerryShot.SOLID_WORLD, BerryShot.SOLID_YES)

function BerryShot:touchTile(tileType, side, plane, x, y)
	self.remove = true
end

function BerryShot:touch(other, side)
	if self.remove then return true end
	if other == self.shooter then return true end	-- don't hit shooter
	if other.takeDamage then
		other:takeDamage(self.damage, self.shooter, self, side)
	end
	self.remove = true
end

-- for shooter:getShootPosVel
Berry.shotSpeed = 30
Berry.shotOffset = vec2(0, .45)
Berry.drawOffset = vec2(.5, .75)

-- if the user selects the item from inventory and throws it
function Berry:onShoot(shooter)
	-- wait for button press (not hold)
	if not (shooter.inputRun and not shooter.inputRunLast) then return end
	
	-- remove self from shooter inventory
	self.remove = true

	-- spawn a new obj thats the thrown version of this or something
	local pos, vel = shooter:getShootPosVel(self)
	local shot = BerryShot{
		shooter = shooter,
		pos = pos,
		vel = vel, 
	}
	shot.sprite = self.sprite
end

return Berry
