local game = require 'base.script.singleton.game'
local CoinTile = require 'mario.script.tile.coin'
local SpikeTile = require 'mario.script.tile.spike'

local Mario = behaviors(require 'base.script.obj.player',
	require 'mario.script.behavior.kickable')

Mario.sprite = 'small-mario'

Mario.inputUpDownLast = 0
Mario.inputRun = false
Mario.inputJumpTime = -1
Mario.inputMaxSpeedTime = 0

Mario.maxRunVel = 10
Mario.timeToMaxSpeed = 1

Mario.touchPriority = 10
Mario.pushPriority = 1

function Mario:init(args)
	Mario.super.init(self, args)
	
	if args.color then
		self.color = {unpack(args.color)}
	end
end

function Mario:growBig()
	if self.big then return end
	self:playSound('mushroom')
	self.sprite = 'big-mario'
	self.big = true
	
	-- and force us to duck if we are too close to the ceiling
	self.ducking = true
	self:tryToStand()
end

Mario.invincibleEndTime = -1

function Mario:growSmall()
	self:playSound('hit')
	if not self.big then return end
	self.sprite = 'small-mario'
	self.big = false
	self.invincibleEndTime = game.time + 1
end

function Mario:refreshSize()
	if self.big and not self.ducking then
		self.bbox = box2(-.4, 0, .4, 1.7)
	else
		self.bbox = box2(-.4, 0, .4, .7)
	end
end

function Mario:setHeld(other, kick)
	if self.holding and self.holding ~= other then
		if kick ~= false then
			self:playSound('kick')
			self.holding:playerKick(self, self.inputLeftRight, self.inputUpDown)
		end

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
			other.heldby:setHeld(nil, false)	-- out of their hands!	... without the kick too
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

function Mario:updateHeldPosition()
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
		if self.seq == 'spinjump_carry' then
			local frameno = (math.floor(game.time * 16) % 4) + 1	-- TODO helper function?
			if frameno == 2 or frameno == 4 then
				side = 0
				-- and if it's 4 then draw it behind us ... z order?
			elseif frameno == 3 then
				side = side * -1	-- TODO I don't draw mario flipped ... because flipping isn't part of the animation system
			end
		end
	end
	self.holding.pos[1] = self.pos[1] + side * .625
end

Mario.extraBounceVel = 40
Mario.idleBounceVel = 10

function Mario:touch(other, side)
	if Mario.super.touch(self, other, side) then return true end

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

function Mario:touchTile(tileType, side, n, x, y)
	if tileType.damage then
		self:hit()
	end
end

function Mario:tryToStand()
	local level = game.level
	if not self.big then
		self.ducking = false
	else
		local cantStand = false
		local y = self.pos[2] + self.bbox.max[2] + .5
		for x=math.floor(self.pos[1] + self.bbox.min[1]),math.floor(self.pos[1] + self.bbox.max[1]) do
			local tile = level:getTile(x,y)
			if tile and tile.solid then
				cantStand = true
				break
			end
		end
		if not cantStand then
			self.ducking = false
		end
	end
	return not self.ducking
end

function Mario:beginWarp()
	self.solidFlags = 0
	self.touchFlags = 0
	--self.blockFlags = 0
	self.warping = true
end

function Mario:endWarp(destX, destY, canCarryThru)
	self.solidFlags = nil
	self.touchFlags = nil
	self.blockFlags = nil
	self.warping = false
	if not canCarryThru then	-- by default don't allow folks to carry things through warps
		self:setHeld(nil, false)
	end
	self.pos[1], self.pos[2] = destX, destY
end

Mario.inputSwimTime = -1
Mario.swimDelay = .5

function Mario:update(dt)
	local level = game.level

	self.viewPos[1] = self.viewPos[1] + .25 *  (self.pos[1] - self.viewPos[1])
	self.viewPos[2] = self.viewPos[2] + .25 *  (self.pos[2] - self.viewPos[2])

	self.inputRun = self.inputShoot or self.inputShootAux

	-- horz vels
	local walkVel = 4
	local runVel = 6
	-- climb vel
	local climbVel = 4
	
	if self.climbing then
		self.useGravity = false
		self.ducking = false
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
	
	if self.isClipping then return end
	
	-- duck to slide (TODO still need downhill sliding) 
	self.friction = self.ducking and .5 or nil
	
	-- reattach to world
	Mario.super.update(self, dt)

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
		self:setHeld(nil, false)
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
					if CoinTile.is(tile) then
						self:playSound('coin')
						level:makeEmpty(x,y)
					end
					canClimb = canClimb or tile.canClimb
				end
			end
		end
		if canClimb then
			if self.inputUpDown ~= 0 then		-- push up/down to get on a climbable surface
				if not self.holding then
					self.climbing = true
					self.spinjumping = false
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
			-- NOTICE this is done in Mario:draw just to make sure objs are displayed in the same relative frame as the player
			self:updateHeldPosition()
		else
			self:setHeld(nil)	-- legitimate kick
		end
	end
	
	
	local jumpingOnSomething
	do
		local groundEnt = self.touchEntDown
		if groundEnt then
			if self.spinjumping then
				if groundEnt.spinJumpDestroys then
					self:playSound('spinjump-stomp')
					groundEnt:die(self)
					self.vel[2] = 0

					jumpingOnSomething = true	-- tell ordinary jump not to get involved
				elseif groundEnt.spinJumpImmune then
					self:playSound('stomp')
					if self.inputJumpAux then
						self.vel[2] = self.extraBounceVel
					else
						self.vel[2] = self.idleBounceVel
					end
					jumpingOnSomething = true	-- tell ordinary jump not to get involved
				end
			else
				if groundEnt.playerBounce then
					local didHandleBounce = groundEnt:playerBounce(self)
					if didHandleBounce ~= false then	-- allow 'nil' to be true.  only 'false' fails
						-- do an ordinary jump on them
						self:playSound('kick')
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
	end
	
	if self.climbing then
		self.vel[1] = self.inputLeftRight * climbVel
		self.vel[2] = self.inputUpDown * climbVel
	else
		-- friction when on ground and when not walking ... or when looking up or down
		if self.onground 
		and (self.inputLeftRight == 0 or self.inputUpDown < 0 or self.ducking) 
		then
			self.inputMaxSpeedTime = nil
			-- friction used to be here but I moved it to Object for everyone
		else
			-- movement in air or when walking
			if self.inputLeftRight ~= 0 then
				local moveVel = walkVel
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

				local accel = 1
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
		if self.spinjumping 
		and self.big 
		then
			-- check ground collision tile for SpinTile block
			-- if so then destroy it
			local y = self.pos[2] - .5
			for x=math.floor(self.pos[1] + self.bbox.min[1]),math.floor(self.pos[1] + self.bbox.max[1]) do
				local tile = level:getTile(x,y)
				if tile and tile.solid and tile.onSpinJump then
					tile:onSpinJump(self, x, y)
					jumpingOnSomething = true
					if self.inputJumpAux then
						self.vel[2] = 20
					else
						self.vel[2] = self.idleBounceVel
					end
					break
				end
			end
		end
		if not jumpingOnSomething then
			self.spinjumping = false
		end
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
				self.jumpVel = math.abs(self.vel[1]) * .625
			end
		elseif self.inputJumpAux then
			if not self.inputJumpAuxLast and not jumpingOnSomething and self.inputJumpTime < game.time then
				if self:tryToStand() then	-- can only spin jump on one high ...

					self:playSound('spinjump')

					self.onground = false
					self.climbing = nil
					self.inputJumpTime = game.time
					self.spinjumping = true
					self.jumpVel = math.abs(self.vel[1]) * .625
				end
			end
		else
			if self.collidedLeft or self.collidedRight then
				self.inputMaxSpeedTime = nil
			end
		end
	end
	
	if self.onground and not jumpingOnSomething then
		if self.inputUpDown < 0 then
			if not self.ducking then
				self.ducking = true
			end
		else
			self:tryToStand()
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

	local jumpDuration = .15
	if self.inputJump or self.inputJumpAux or self.swimming then
		--if self.vel[2] < 0 then self.inputJumpTime = nil end		-- doesn't work well with swimming
		if self.inputJumpTime + jumpDuration >= game.time then
			if self.inputJump then
				self.vel[2] = 20
			elseif self.inputJumpAux then
				self.vel[2] = 16
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

function Mario:hit()
	if self.invincibleEndTime >= game.time then return end
	self.item = nil
	if self.big then
		self:growSmall()
	else
		self:die()
	end
end
function Mario:hitByEnemy(other) self:hit(other) end
function Mario:hitByShell(other) self:hit(other) end
function Mario:hitByBlast(other) self:hit(other) end


function Mario:die()
	-- nothing atm
	if self.dead then return end
	if self.heldby then self.heldby:setHeld(nil) end
	self:playSound('die')
	self:setHeld(nil, false)
	self.warping = false
	self.climbing = false
	self.spinjumping = false
	self.ducking = false
	self.big = false
	self.item = nil
	self.lookingUp = false
	self.solidFlags = 0
	self.touchFlags = 0
	self.dead = true
	self.respawnTime = game.time + 1
	self.vel[1], self.vel[2] = 0, 20
end

function Mario:respawn()
	self.respawnTime = nil
	self.solidFlags = nil
	self.touchFlags = nil
	self.blockFlags = nil
	self.dead = nil
	self.vel[1], self.vel[2] = 0,0
	self:setPos(unpack(game:getStartPos()))
end

function Mario:draw(R, viewBBox, holdOverride)

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
			if self.ducking then
				if self.holding then
					self.seq = 'duck_carry'
				else
					self.seq = 'duck'
				end
			else
				if self.onground then
					if not self.warping and self.inputLeftRight ~= 0 then
						if self.inputRun then
							if self.holding then
								self.seq = 'run_carry'
							else
								if vx ~= self.maxRunVel and vx ~= -self.maxRunVel then
									self.seq = 'run'
								else
									self.seq = 'maxrun'
								end
							end
						else
							if self.holding then
								self.seq = 'walk_carry'
							else
								self.seq = 'walk'
							end
						end
					else
						if self.warping or self.inputUpDown > 0 then
							if self.holding then
								self.seq = 'lookup_carry'
							else
								self.seq = 'lookup'
							end
						else
							if self.holding then
								self.seq = 'stand_carry'
							else
								self.seq = 'stand'
							end
						end
					end
				else
					if self.swimming then
						self.seq = 'jump_arms'
					elseif self.spinjumping then
						if self.holding then
							self.seq = 'spinjump_carry'
						else
							self.seq = 'spinjump'
						end
					else
						if self.inputMaxSpeedTime >= self.timeToMaxSpeed and not self.holding then
							self.seq = 'jump_arms'
						else
							if self.vel[2] > 0 then
								if self.holding then
									self.seq = 'jump_carry'
								else
									self.seq = 'jump'
								end
							else
								if self.holding then
									self.seq = 'jump_carry'	-- same as fall
								else
									self.seq = 'fall'
								end
							end
						end
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
	
	Mario.super.draw(self, R, viewBBox, holdOverride)

	if self.item then
		self.item:drawItem(self, R, viewBBox)
	end
end

return Mario
