local bit = require 'bit'
local box2 = require 'vec.box2'
local game = require 'base.script.singleton.game'
local behaviors = require 'base.script.behaviors'
local dirs = require 'base.script.dirs'

local Neko = behaviors(require 'base.script.obj.player'
	--,require 'neko.script.behavior.kickable'
)

Neko.sprite = 'neko'

Neko.inputUpDownLast = 0
Neko.inputRun = false
Neko.inputJumpTime = -1
Neko.inputMaxSpeedTime = 0

Neko.maxRunVel = 10
Neko.timeToMaxSpeed = 1

Neko.touchPriority = 10
Neko.pushPriority = 1

function Neko:init(args)
	Neko.super.init(self, args)

	self.color = nil	-- don't override player color.  how about always?
end

Neko.invincibleEndTime = -1

function Neko:refreshSize()
	self.bbox = box2(-.4, 0, .4, .7)
end

function Neko:setHeld(other)
	if self.holding and self.holding ~= other then

		self.holding.heldby = nil
		
		-- revert to class originals
--		rawset(self.holding, 'solidFlags', self.holdingLastSolidFlags)
--		rawset(self.holding, 'touchFlags', self.holdingLastTouchFlags)
--		rawset(self.holding, 'blockFlags', self.holdingLastBlockFlags)
		
		self.holding = nil
	end
	
	if other then
		-- no grabbing the person who is grabbing you
		if other.holding == self then return end
		
		if other.heldby then
			if other.heldby == self then return end	-- we're already holding it?
			other.heldby:setHeld(nil)	-- out of their hands!	... without the kick too
		end
	
		if other.playerGrab then other:playerGrab(self) end
		self.holding = other
		self.holding.heldby = self
	
		-- clear collision flags 
		-- this assumes only classes set flags and not objects
		-- TODO getters and setters for custom behavior per-object
--		self.holdingLastSolidFlags = rawget(self.holding, 'solidFlags')
--		self.holdingLastTouchFlags = rawget(self.holding, 'touchFlags')
--		self.holdingLastBlockFlags = rawget(self.holding, 'blockFlags')
--		self.holding.solidFlags = 0
--		self.holding.touchFlags = 0
--		self.holding.blockFlags = 0
	
	end
end

function Neko:updateHeldPosition()
	self.holding.pos[2] = self.pos[2] + .125
	
	self.holding.drawMirror = self.drawMirror
	local side
	if self.climbing then
		side = 0
	else
		if self.drawMirror then
			side = -1
		else
			side = 1
		end
	end
	self.holding.pos[1] = self.pos[1] + side * .625
end

Neko.extraBounceVel = 40
Neko.idleBounceVel = 10

function Neko:touch(other, side)
	if Neko.super.touch and Neko.super.touch(self, other, side) then return true end

	-- TODO kick handicap time, so shells thrown up can't be immediately caught?
	if self.inputRun	-- if we're holding the grab button
	and not self.holding	-- and we're not holding anything atm
	and other.canCarry		-- and we can carry the other object
	and (not other.canBeHeldBy or other:canBeHeldBy(self))	-- ... refined "can carry" test
	then
		self:setHeld(other)
	end
	
	if other == self.holding then return true end	-- skip push collisions
end

function Neko:touchTile(tileType, side, n, x, y)
	if tileType.damage then
		self:hit()
	end
end

function Neko:beginWarp()
	self.solidFlags = 0
	self.touchFlags = 0
	--self.blockFlags = 0
	self.warping = true
end

function Neko:endWarp(destX, destY, canCarryThru)
	self.solidFlags = nil
	self.touchFlags = nil
	self.blockFlags = nil
	self.warping = false
	if not canCarryThru then	-- by default don't allow folks to carry things through warps
		self:setHeld(nil)
	end
	self.pos[1], self.pos[2] = destX, destY
end

Neko.inputSwimTime = -1
Neko.swimDelay = .5

function Neko:update(dt)
	local level = game.level


	-- only spawn what's in our room
	local roomPosX, roomPosY = level:getMapTilePos(self.pos:unpack())
	self.room = level:getRoomAtMapTilePos(roomPosX, roomPosY)

	-- [[ create/remove objects based on our current room
	if self.room ~= self.roomLast then
		for _,spawnInfo in ipairs(level.spawnInfos) do
			local spawnInfoRoom = level:getRoom(table.unpack(spawnInfo.pos))
			if spawnInfoRoom == self.room then
				if not spawnInfo.obj then
					spawnInfo:respawn()
				end
			elseif spawnInfoRoom == self.roomLast then
				spawnInfo:removeObj()
			end
		end
		-- reload tiles from the original buffers (in case any were modified)
		level:refreshTiles()
		self.roomLast = self.room
	end
	--]]

	-- slowly track player
	if self.fixedViewPos and not (editor and editor.active) then
		self.viewPos[1] = self.fixedViewPos[1]
		self.viewPos[2] = self.fixedViewPos[2]
	else
		local viewSizeX = (self.viewBBox.max[1] - self.viewBBox.min[1]) / 2
		local viewSizeY = (self.viewBBox.max[2] - self.viewBBox.min[2]) / 2
		
		local targetPosX = self.pos[1]
		local targetPosY = self.pos[2] + .15 * viewSizeY

		if not (editor and editor.active) then

			local different = {}
			for side,dir in pairs(dirs) do
				local sideRoom = level:getRoom(
					self.pos[1] + level.mapTileSize[1] * dir[1],
					self.pos[2] + level.mapTileSize[2] * dir[2])
				different[side] = sideRoom ~= self.room
			end

			local pushedRight, pushedLeft
			if different.right then
				local xmax = roomPosX * level.mapTileSize[1] + 1 - viewSizeX
				if targetPosX > xmax then
					targetPosX = xmax
					pushedRight = true
				end
			end
			if different.left then
				local xmin = (roomPosX-1) * level.mapTileSize[1] + 1 + viewSizeX
				if targetPosX < xmin then
					targetPosX = xmin
					pushedLeft = true
				end
			end
			if pushedRight and pushedLeft then
				targetPosX = (roomPosX - .5) * level.mapTileSize[1] + 1
			end

			local pushedUp, pushedDown
			if different.up then
				local ymax = roomPosY * level.mapTileSize[2] + 1 - viewSizeY
				if targetPosY > ymax then
					targetPosY = ymax
					pushedUp = true
				end
			end
			if different.down then
				local ymin = (roomPosY-1) * level.mapTileSize[2] + 1 + viewSizeY
				if targetPosY < ymin then
					targetPosY = ymin
					pushedDown = true
				end
			end
			if pushedUp and pushedDown then
				targetPosY = (roomPosY - .5) * level.mapTileSize[2] + 1
			end
		end

		self.viewPos[1] = self.viewPos[1] + .3 *  (targetPosX - self.viewPos[1])
		self.viewPos[2] = self.viewPos[2] + .3 *  (targetPosY - self.viewPos[2])
	end

	self.inputRun = self.inputShoot or self.inputShootAux

	if self.isClipping then return end

	-- horz vels
	local walkVel = 4
	local runVel = 6
	-- climb vel
	local climbVel = 4
				
	local moveVel = walkVel
	local accel = 1
	local jumpDuration = .05
	
	if self.climbing then
		self.useGravity = false
		self.inputMaxSpeedTime = nil
	else
		self.useGravity = true
	end
	

	--[[ fly hack
	if self.inputJump then
		self.useGravity = false
		self.vel[1] = self.inputLeftRight * 5
		self.vel[2] = self.inputUpDown * 5
	else
		self.useGravity = true
	end
	--]]
	
	-- reattach to world
	Neko.super.update(self, dt)

	-- fallen off the world?
	if self.pos[2] < -10 then
		self:die()
	end

	-- dead?
	if self.dead then
		if game.time > self.respawnTime then
			self:respawn()
		end
		return
	end

	-- is the player warping?
	if self.warping then return end

	-- was the player kicked?
	if self.kickHandicapTime and self.kickHandicapTime >= game.time then return end

	if self.holding and self.holding.remove then
		self:setHeld(nil)
	end	
	
	if self.item and self.item.update then self.item:update(self, dt) end
	
	-- if we pushed run1 or run2 ...
	if (self.inputShoot and not self.inputShootLast)
	or (self.inputShootAux and not self.inputShootAuxLast)
	then
		-- try to pick something up ...
		
		if not self.holding and self.collidedLeft and not self.touchEntLeft then
			local x = self.pos[1] + self.bbox.min[1] - .5
			for y=math.floor(self.pos[2] + self.bbox.min[2]),math.floor(self.pos[2] + self.bbox.max[2]) do
				local tile = level:getTile(x,y)
				if tile and tile.onCarry then
					tile:onCarry(self,x,y)
					if self.holding then break end
				end
			end
		end
		if not self.holding and self.collidedRight and not self.touchEntRight then
			local x = self.pos[1] + self.bbox.max[1] + .5
			for y=math.floor(self.pos[2] + self.bbox.min[2]),math.floor(self.pos[2] + self.bbox.max[2]) do
				local tile = level:getTile(x,y)
				if tile and tile.onCarry then
					tile:onCarry(self,x,y)
					if self.holding then break end
				end
			end
		end
		-- TODO evaluate from center outwards? rather than left to right
		if not self.holding and self.collidedDown and not self.touchEntDown then
			local y = self.pos[2] + self.bbox.min[1] - .5
			for x=math.floor(self.pos[1] + self.bbox.min[1]),math.floor(self.pos[1] + self.bbox.max[1]) do
				local tile = level:getTile(x,y)
				if tile and tile.onCarry then
					tile:onCarry(self,x,y)
					if self.holding then break end
				end
			end
		end
		if not self.holding and self.collidedUp and not self.touchEntUp then
			local y = self.pos[2] + self.bbox.max[1] + .5
			for x=math.floor(self.pos[1] + self.bbox.min[1]),math.floor(self.pos[1] + self.bbox.max[1]) do
				local tile = level:getTile(x,y)
				if tile and tile.onCarry then
					tile:onCarry(self,x,y)
					if self.holding then break end
				end
			end
		end	
		
		-- see if we have a powerup
		if self.item and self.item.onShoot then
			self.item:onShoot(self)
		end
	end

	-- if we're on ground and climbing then clear climbing flag
	-- do this before we check for climb & re-enable it & potentially move off-ground
	if self.onground then
		self.climbing = nil
	end

	-- general touch with all non-solid tiles
	do
		local canClimb
		for x=math.floor(self.pos[1] + self.bbox.min[1]),math.floor(self.pos[1] + self.bbox.max[1]) do
			for y=math.floor(self.pos[2] + self.bbox.min[2]),math.floor(self.pos[2] + self.bbox.max[2]) do
				local tile = level:getTile(x,y)
				if tile then
					canClimb = canClimb or tile.canClimb
				end
			end
		end
		if canClimb then
			if self.inputUpDown ~= 0 then		-- push up/down to get on a climbable surface
				if not self.holding then
					self.climbing = true
				end
			end
		else
			self.climbing = nil		-- move off of it to fall off!
		end
	end
		
	if self.collidedUp then
		self.inputJumpTime = nil
		local y = math.floor(self.pos[2] + self.bbox.max[2] + .5)
		for x=math.floor(self.pos[1] + self.bbox.min[1]),math.floor(self.pos[1] + self.bbox.max[1]) do
			local tile = level:getTile(x,y)
			if tile and tile.solid and tile.onHit then
				tile:onHit(self, x, y)
				break
			end
		end
	end

	
	--[[ check squish
	do
		local tile = level:getTile(self.pos[1], self.pos[2])
		if tile
		and tile.solid
		and not tile.diag		-- objects can walk through solid tiles if they are flagged diagonal.  in that case, collision with the side is special (and buggy) and I don't know what I'll do for squishing
		then
			self:die()
		end
	end
	--]]
	
	if self.holding then
		self.holding.vel[1] = self.vel[1]
		self.holding.vel[2] = self.vel[2]
		if self.inputRun then
			-- NOTICE this is done in Neko:draw just to make sure objs are displayed in the same relative frame as the player
			self:updateHeldPosition()
		else
			self:setHeld(nil)
		end
	end
	
	
	local jumpingOnSomething
	do
		local groundEnt = self.touchEntDown
		if groundEnt then
--print'here'			
			if groundEnt.playerBounce then
				local didHandleBounce = groundEnt:playerBounce(self)
				if didHandleBounce ~= false then	-- allow 'nil' to be true.  only 'false' fails
					-- do an ordinary jump on them
					--self:playSound'kick'
					if self.inputJump then
						self.vel[2] = self.extraBounceVel
					else
						self.vel[2] = self.idleBounceVel
					end
					jumpingOnSomething = true	-- tell ordinary jump not to get involved
				end
			end
		end
	end
	
	if self.climbing then
		self.vel[1] = self.inputLeftRight * climbVel
		self.vel[2] = self.inputUpDown * climbVel
	else
		-- friction when on ground and when not walking ... or when looking up or down
		if self.onground 
		and (self.inputLeftRight == 0 or self.inputUpDown < 0) 
		then
			self.inputMaxSpeedTime = nil
			-- friction used to be here but I moved it to Object for everyone
		else
			-- movement in air or when walking
			if self.inputLeftRight ~= 0 then
				if self.inputRun then
					moveVel = runVel
					if self.onground then
						self.inputMaxSpeedTime = self.inputMaxSpeedTime + dt
					end
					if self.inputMaxSpeedTime >= self.timeToMaxSpeed then
						moveVel = self.maxRunVel
					end
						
					if self.onground and (self.inputLeftRight > 0) ~= (self.vel[1] > 0) then
						self.inputMaxSpeedTime = nil
					end
				end

				if self.inputLeftRight < 0 then
					self.vel[1] = self.vel[1] - (self.friction + accel)
					if self.vel[1] < -moveVel then self.vel[1] = -moveVel end
				elseif self.inputLeftRight > 0 then
					self.vel[1] = self.vel[1] + (self.friction + accel)
					if self.vel[1] > moveVel then self.vel[1] = moveVel end
				end
				
				self.drawMirror = self.inputLeftRight < 0
			end
		end
	end
	
	-- if we just hit the ground then see if we're at max vel.  if not then reset the run meter
	if self.onground 
	and not self.ongroundLast 
	then
		if self.vel[1] ~= self.maxRunVel and self.vel[1] ~= -self.maxRunVel then
			self.inputMaxSpeedTime = nil
		end
	end


	do
		local tile = level:getTile(self.pos[1], self.pos[2])
		self.swimming = tile and tile.canSwim
	end
		
	--[[
	standing: 4
	walking: 4.5
	running: 5
	max speed: 6
	--]]
	if self.onground or self.climbing or self.swimming then
		if self.swimming then
			if (self.inputJump or self.inputJumpAux) and (self.inputSwimTime + self.swimDelay < game.time) then
				self:playSound('swim')
			
				self.onground = false
				self.climbing = nil
				self.inputJumpTime = game.time
				self.jumpVel = -15	-- counteract the jump yvel below
				self.inputSwimTime = game.time
			end
		elseif self.inputJump or (self.holding and self.inputJumpAux) then
			if not self.inputJumpLast and not jumpingOnSomething and self.inputJumpTime < game.time then
				self:playSound('jump')
			
				self.onground = false
				self.climbing = nil
				self.inputJumpTime = game.time
				self.jumpVel = math.abs(self.vel[1]) * .3
			end
		else
			if self.collidedLeft or self.collidedRight then
				self.inputMaxSpeedTime = nil
			end
		end
	end
	
	-- test doors
	if self.onground and self.inputUpDown > 0 and self.inputUpDownLast <= 0 and self.vel[1] == 0 then
		for _,obj in ipairs(game.objs) do
			if obj ~= self
			and math.floor(self.pos[1]) == math.floor(obj.pos[1])
			and math.floor(self.pos[2]) == math.floor(obj.pos[2])
			and obj.playerLook
			then
				obj:playerLook(self)
			end
		end
	end

	if self.inputJump or self.inputJumpAux or self.swimming then
		--if self.vel[2] < 0 then self.inputJumpTime = nil end		-- doesn't work well with swimming
		if self.inputJumpTime + jumpDuration >= game.time then
			if self.inputJump or self.inputJumpAux then
				self.vel[2] = 20
			end
			self.vel[2] = self.vel[2] + self.jumpVel
		end
	end

	self:refreshSize()

	self.inputUpDownLast = self.inputUpDown
	self.inputRunLast = self.inputRun
	self.inputShootLast = self.inputShoot
	self.inputShootAuxLast = self.inputShootAux
	self.inputJumpLast = self.inputJump
	self.inputJumpAuxLast = self.inputJumpAux
	self.ongroundLast = self.onground
end

function Neko:hit()
	if self.invincibleEndTime >= game.time then return end
	self.item = nil
	self:die()
end
function Neko:hitByEnemy(other) self:hit(other) end
function Neko:hitByShell(other) self:hit(other) end
function Neko:hitByBlast(other) self:hit(other) end


function Neko:die()
	-- nothing atm
	if self.dead then return end
	if self.heldby then self.heldby:setHeld(nil) end
	--self:playSound'die'
	self:setHeld(nil)
	self.warping = false
	self.climbing = false
	self.item = nil
	self.lookingUp = false
	self.solidFlags = 0
	self.touchFlags = 0
	self.dead = true
	self.respawnTime = game.time + 1
	self.vel[1], self.vel[2] = 0, 20
end

function Neko:respawn()
	self.respawnTime = nil
	self.solidFlags = nil
	self.touchFlags = nil
	self.blockFlags = nil
	self.dead = nil
	self.vel[1], self.vel[2] = 0,0
	self:setPos(unpack(game:getStartPos()))
end

function Neko:draw(R, viewBBox, holdOverride)

	if self.invincibleEndTime >= game.time then
		if math.floor(game.time * 8) % 2 == 0 then
			return
		end
	end

	local vx = self.vel[1]
	if self.touchEntDown then
		vx = vx - self.touchEntDown.vel[1]
	end
	
	if self.dead then
		self.seq = 'die'
		self.drawMirror = bit.band(math.floor(game.time * 8), 1) == 1
	else
		if self.climbing then
			if self.vel[1] ~= 0 or self.vel[2] ~= 0 then
				self.seq = 'climb'	-- moving
			else
				self.seq = 'climb1'	-- still
			end
		else
			if self.onground then
				if not self.warping and self.inputLeftRight ~= 0 then
					if self.inputRun then
						self.seq = 'run'
					else
						self.seq = 'walk'
					end
				else
					if self.warping or self.inputUpDown > 0 then
						self.seq = 'lookup'
					else
						self.seq = 'stand'
					end
				end
			else
				if self.swimming then
					self.seq = 'swim'
				else
					if self.vel[2] > 0 then
						self.seq = 'jump'
					else
						self.seq = 'fall'
					end
				end
			end
		end
	end
	
	if self.holding and not holdOverride then
		-- update position
		self:updateHeldPosition()
		self.holding:draw(R, viewBBox, true)
	end
	
	Neko.super.draw(self, R, viewBBox, holdOverride)

	if self.item then
		self.item:drawItem(self, R, viewBBox)
	end
end

return Neko
