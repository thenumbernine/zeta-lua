--[[
gameplay system ...

stand
left/right - walk
up/down - climb
up - go through doors
down - duck / crawl
inputShoot - shoot
inputJump - jump
inputShootAux - pick up / put down object 
inputJumpAux - use selected item / run 

when you pick up an item, you're holding it...

- primary attack:
	- weapon
- secondary attack:	
	- shield
	- jetpack
	- grappling hook
	- visor
- second jump:
	- speed boost
	- carry

--]]
local class = require 'ext.class'
local table = require 'ext.table'
local box2 = require 'vec.box2'
local gui = require 'base.script.singleton.gui'
local game = require 'base.script.singleton.game'
local editor = require 'base.script.singleton.editor'
local Object = require 'base.script.obj.object'
local Player = require 'base.script.obj.player'
local takesDamageBehavior = require 'zeta.script.obj.takesdamage'

local Hero = class(takesDamageBehavior(Player))

Hero.sprite = 'hero'
Hero.maxHealth = 5

Hero.inputUpDownLast = 0
Hero.inputRun = false
Hero.inputJumpTime = -1
Hero.inputMaxSpeedTime = 0
Hero.canCarry = true

Hero.maxRunVel = 10
Hero.timeToMaxSpeed = 1

Hero.preTouchPriority = 10
Hero.touchPriority = 10
Hero.pushPriority = 1

Hero.nextShootTime = -1

function Hero:init(args)
	Hero.super.init(self, args)
	self.items = table()	-- self.items = {{obj1, ...}, {obj2, ...}, ...} for each unique class
	self.holding = nil
	self.color = nil	-- TODO team colors
end

function Hero:refreshSize()
	if not self.ducking then
		self.bbox = box2(-.4, 0, .4, 1.8)
	else
		self.bbox = box2(-.4, 0, .4, .8)
	end
end

function Hero:setHeld(other)
	if self.holding and self.holding ~= other then
		--self.holding:playerKick(self, self.inputLeftRight, self.inputUpDown)
		self.holding.vel[1] = self.vel[1]
		self.holding.vel[2] = self.vel[2]
self.holding.pos[1] = self.pos[1]
self.holding.pos[2] = self.pos[2]
		self.holding:hasBeenKicked(self)
		
		-- true for any Item subclass, who calls Item:playerGrab
		for j=#self.items,1,-1 do
			self.items[j]:removeObject(self.holding)
			if #self.items[j] == 0 then
				self.items:remove(j)
			end
		end
		
		if self.weapon == self.holding then
			self.weapon = nil	-- TODO switch to next weapon?
		end

		self.holding.heldby = nil
		self.holding.collidesWithObjects = nil
		self.holding.collidesWithWorld = nil
		self.holding = nil	
	end
	
	if other then
		if other.heldby then
--			if other.heldby == self then return end	-- we're already holding it?
			other.heldby:setHeld(nil)	-- out of their hands!	... without the kick too
		end
	
		if other.playerGrab then other:playerGrab(self) end
		self.holding = other
		self.holding.heldby = self
		self.holding.collidesWithObjects = false
		self.holding.collidesWithWorld = false
		
		self.nextHoldTime = game.time + .1
	end
end

-- TODO isn't this handled by PlayerItem:drawItem ?
function Hero:updateHeldPosition()
	if self.holding.updateHeldPosition then
		self.holding:updateHeldPosition()
		return
	end

	local offset
	if not self.ducking then
		offset = self.holding.playerHoldOffsetStanding
	else
		offset = self.holding.playerHoldOffsetDucking
	end
	offset = offset or {.625, .125}	
	
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
	self.holding.pos[1] = self.pos[1] + side * offset[1]
	self.holding.pos[2] = self.pos[2] + offset[2]
end

Hero.extraBounceVel = 40
Hero.idleBounceVel = 10

function Hero:pretouch(other, side)
	if Hero.super.pretouch(self, other, side) then return true end

	-- skip push collisions
	for _,items in ipairs(self.items) do
		for _,item in ipairs(items) do
			if other == item then return true end
		end
	end
	if other == self.holding then return true end
	if other == self.weapon then return true end
end

function Hero:tryToStand()
	local level = game.level
	local cantStand = false
	local y = self.pos[2] + self.bbox.max[2] + .5 - level.pos[2]
	for x=math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1]),math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1]) do
		local tile = level:getTile(x,y)
		if tile and tile.solid then
			cantStand = true
			break
		end
	end
	if not cantStand then
		self.ducking = false
		self.lookingUp = false
	end
	return not self.ducking
end

function Hero:beginWarp()
	self.solid = false
	self.warping = true
end

function Hero:endWarp(destX, destY, canCarryThru)
	self.solid = true
	self.warping = false
	if not canCarryThru then	-- by default don't allow folks to carry things through warps
		self:setHeld(nil)
	end
	self.pos[1], self.pos[2] = destX, destY
end

Hero.inputSwimTime = -1
Hero.swimDelay = .5

function Hero:update(dt)
	local level = game.level

	--[[ respawn objects near player
	-- TODO rooms? and link by rooms?
	for _,spawnInfo in ipairs(self.spawnInfos) do
		spawnInfo:respawn()
	end
	--]]

	-- slowly track player
	local editor = require 'base.script.singleton.editor'
	if self.fixedViewPos and not (editor and editor.active) then
		self.viewPos[1] = self.fixedViewPos[1]
		self.viewPos[2] = self.fixedViewPos[2]
	else
		self.viewPos[1] = self.viewPos[1] + .5 *  (self.pos[1] - self.viewPos[1])
		self.viewPos[2] = self.viewPos[2] + .9 *  (self.pos[2] - self.viewPos[2])
	end

	self.inputRun = self.inputJumpAux

	-- horz vels
	local walkVel = 5
	local crawlVel = 3
	local runVel = 7
	-- climb vel
	local climbVel = 5
	
	if self.climbing then
		self.useGravity = false
		self.ducking = false
		self.lookingUp = false
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
	
	-- TODO put this in base?
	if editor.active
	and editor.noClipping[0]
	then
		self.isClipping = true
		self.useGravity = false
		self.collidesWithWorld = false
		self.collidesWithObjects = false
		local flySpeed = 2 * game.viewSize
		self.vel[1] = self.inputLeftRight * flySpeed
		self.vel[2] = self.inputUpDown * flySpeed
		self.invincibleEndTime = game.time + .1
	else
		if self.isClipping then
			self.isClipping = nil
			self.useGravity = true
			self.collidesWithWorld = nil
			self.collidesWithObjects = nil
		end
	end

	-- reattach to world
	Hero.super.update(self, dt)
	
	if self.pos[2] < -10 then
		self:die()
	end

	if self.dead then
		if self.respawnTime then
			if game.time > self.respawnTime then
				self:respawn()
			end
		end
		return
	end
	
	if self.warping then return end
	
	if self.holding and self.holding.remove then
		self:setHeld(nil)
	end
	if self.weapon and self.weapon.remove then
		self.weapon = nil
	end

--	if self.weapon and self.weapon.update then 
--		self.weapon:update(dt, self)
--	end
	
	-- if we pushed the pickup-item button 
	if self.inputShootAux and not self.inputShootAuxLast then
	
		-- if we're already holding something -- set it down

		if self.holding then
			
			if game.time > self.nextHoldTime then
				self:setHeld(nil)
			end

		-- try to pick up a tile ...
		else
			-- pretouch is called upon movement into an object
			-- i want this to run any time
			for _,other in ipairs(game.objs) do
				if other ~= self
				and not other.remove
				and not other.heldby
				and other.canCarry
				and (not other.canBeHeldBy or other:canBeHeldBy(self))	-- ... refined "can carry" test
				and self.pos[1] + self.bbox.min[1] <= other.pos[1] + other.bbox.max[1]
				and self.pos[1] + self.bbox.max[1] >= other.pos[1] + other.bbox.min[1]
				and self.pos[2] + self.bbox.min[2] <= other.pos[2] + other.bbox.max[2]
				and self.pos[2] + self.bbox.max[2] >= other.pos[2] + other.bbox.min[2]
				then
					--self.holdCandidate = other
					--self.holdCandidatePos = vec2(self.pos:unpack())
					self:setHeld(other)
					break
				end
			end
			
			--[[ if we're standing on something we can pick up ...
			if self.holdCandidate 
			and self.holdCandidatePos == self.pos
			then
				self.holdCandidate = nil
				self.holdCandidatePos = nil
				self:setHeld(self.holdCandidate)
			end
			--]]
			if self.collidedLeft and not self.touchEntLeft then
				local x = self.pos[1] + self.bbox.min[1] - .5 - level.pos[1]
				for y=math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2]),math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2]) do
					local tile = level:getTile(x,y)
					if tile and tile.onCarry then
						tile:onCarry(self)
						if self.holding then break end
					end
				end
			end
			if self.collidedRight and not self.touchEntRight then
				local x = self.pos[1] + self.bbox.max[1] + .5 - level.pos[1]
				for y=math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2]),math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2]) do
					local tile = level:getTile(x,y)
					if tile and tile.onCarry then
						tile:onCarry(self)
						if self.holding then break end
					end
				end
			end
			-- TODO evaluate from center outwards? rather than left to right
			if self.collidedDown and not self.touchEntDown then
				local y = self.pos[2] + self.bbox.min[1] - .5 - level.pos[1]
				for x=math.floor(self.pos[1] + self.bbox.min[1] - level.pos[2]),math.floor(self.pos[1] + self.bbox.max[1] - level.pos[2]) do
					local tile = level:getTile(x,y)
					if tile and tile.onCarry then
						tile:onCarry(self)
						if self.holding then break end
					end
				end
			end
			if self.collidedUp and not self.touchEntUp then
				local y = self.pos[2] + self.bbox.max[1] + .5 - level.pos[2]
				for x=math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1]),math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1]) do
					local tile = level:getTile(x,y)
					if tile and tile.onCarry then
						tile:onCarry(self)
						if self.holding then break end
					end
				end
			end	
		end
	end

	-- see if we have a weapon to shoot
	if self.inputShoot 
	--and not self.inputShootLast 
	then
		if self.weapon
		and self.weapon.onShoot
		and self.nextShootTime < game.time
		then
			self.weapon:onShoot(self)
		end
	end

	if self.inputJumpAux
	then
		if self.holding
		and self.holding ~= self.weapon
		and self.holding.onUse
		then
			self.holding:onUse(self)
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
		for x=math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1]),math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1]) do
			for y=math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2]),math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2]) do
				local tile = level:getTile(x,y)
				if tile then
					canClimb = canClimb or tile.canClimb
				end
			end
		end
		if canClimb then
			if self.inputUpDown ~= 0 then		-- push up/down to get on a climbable surface
				self.climbing = true
			end
		else
			self.climbing = nil		-- move off of it to fall off!
		end
	end
		
	if self.collidedUp then
		self.inputJumpTime = nil
		local y = self.pos[2] + self.bbox.max[2] + .5 - level.pos[2]
		for x=math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1]),math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1]) do
			local tile = level:getTile(x,y)
			if tile and tile.solid and tile.onHit then
				tile:onHit(self)
				break
			end
		end
	end

	
	--[[ check squish
	do
		local tile = level:getTile(self.pos[1] - level.pos[1], self.pos[2] - level.pos[2])
		if tile
		and tile.solid
		and not tile.diag		-- objects can walk through solid tiles if they are flagged diagonal.  in that case, collision with the side is special (and buggy) and I don't know what I'll do for squishing
		then
			self:die()
		end
	end
	--]]

	if self.climbing then
		self.vel[1] = self.inputLeftRight * climbVel
		self.vel[2] = self.inputUpDown * climbVel
		if self.inputLeftRight ~= 0 then
			self.drawMirror = self.inputLeftRight < 0
		end
	else
		-- friction when on ground and when not walking ... or when looking up or down
		if self.onground and (
			self.inputLeftRight == 0
			--or self.inputUpDown < 0
			--or self.ducking
			--or self.lookingUp
			)
		then
			self.inputMaxSpeedTime = nil
			-- friction used to be here but I moved it to GameObject for everyone
		else
			-- movement in air or when walking
			if self.inputLeftRight ~= 0 then
				local moveVel = walkVel
				if self.ducking then
					moveVel = crawlVel
				elseif self.inputRun then
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
					self.vel[1] = self.vel[1] - (self.friction + .25)
					if self.vel[1] < -moveVel then self.vel[1] = -moveVel end
				elseif self.inputLeftRight > 0 then
					self.vel[1] = self.vel[1] + (self.friction + .25)
					if self.vel[1] > moveVel then self.vel[1] = moveVel end
				end
				
				self.drawMirror = self.inputLeftRight < 0
			end
		end
	end
	
	-- if we just hit the ground then see if we're at max vel.  if not then reset the run meter
	if self.onground and not self.ongroundLast then
		-- TODO check jumping on a tile here

		if self.vel[1] ~= self.maxRunVel and self.vel[1] ~= -self.maxRunVel then
			self.inputMaxSpeedTime = nil
		end
	end

	do
		local tile = level:getTile(self.pos[1] - level.pos[1], self.pos[2] - level.pos[2])
		self.swimming = tile and tile.fluid and #tile.fluid > 0
	end
		
	--[[
	standing: 4
	walking: 4.5
	running: 5
	max speed: 6
	--]]
	if self.onground or self.climbing or self.swimming then
		if self.swimming then
			if self.inputJump and (self.inputSwimTime + self.swimDelay < game.time) then
				self:playSound('swim')
			
				self.onground = false
				self.climbing = nil
				self.inputJumpTime = game.time
				self.jumpVel = -10
				self.inputSwimTime = game.time
			end
		
		elseif self.inputJump then
			if not self.inputJumpLast and self.inputJumpTime < game.time then
				self:playSound('jump')
			
				self.onground = false
				self.climbing = nil
				self.inputJumpTime = game.time
				self.jumpVel = math.abs(self.vel[1]) * .625
			end
		else
			if self.collidedLeft or self.collidedRight then
				self.inputMaxSpeedTime = nil
			end
		end
	end
	
	if self.onground and self.inputLeftRight == 0 then
		if self.inputUpDown < 0 and self.inputUpDownLast >= 0 then
			if not self.ducking then
				self.ducking = true
			end
		elseif self.inputUpDown > 0 and self.inputUpDownLast <= 0 then
			if not self.lookingUp then
				self.lookingUp = true
			end
		elseif self.inputUpDown == 0 then 
			self:tryToStand()
		end
	end
	if self.ducking or self.lookingUp then
		if self.inputLeftRight ~= 0 then 
			self.drawMirror = self.inputLeftRight < 0
		end
	end

	-- test doors
	if self.onground and self.inputUpDown > 0 and self.inputUpDownLast <= 0 and self.vel[1] == 0 then
		--[[
		local tile = level:getTile(self.pos[1] - level.pos[1], self.pos[2] - level.pos[2])
		if tile and tile.objs then
			for _,obj in ipairs(tile.objs) do
				if obj.playerLook then
					obj:playerLook(self)
				end
			end
		end
		--]]
		-- [[
		for _,obj in ipairs(game.objs) do
			if math.abs(self.pos[1] - obj.pos[1]) < 1 and math.abs(self.pos[2] - obj.pos[2]) < 1 then
				if obj.playerLook then
					obj:playerLook(self)
				end
			end
		end
		--]]
	end

	local jumpDuration = .15
	if self.inputJump or self.swimming then
		--if self.vel[2] < 0 then self.inputJumpTime = nil end		-- doesn't work well with swimming
		if self.inputJumpTime + jumpDuration >= game.time then
			if self.inputJump then
				self.vel[2] = 15
			end
			if self.swimming then
				self.vel[2] = self.vel[2] + self.jumpVel
			end
		end
	end

	self:refreshSize()

	local pageUpPress = self.inputPageUp and not self.inputPageUpLast
	local pageDownPress = self.inputPageDown and not self.inputPageDownLast
	if pageUpPress or pageDownPress then
		-- if we're holding an object that can't be stored, don't bother
		if not self.holding or self.holding.canStoreInv then
			local itemIndex = self.items:find(nil, function(items)
				return items:find(self.holding)
			end)
			itemIndex = itemIndex or 0 
			if pageUpPress then
				itemIndex = (itemIndex + 1) % (#self.items + 1)
			elseif pageDownPress then
				itemIndex = (itemIndex - 1) % (#self.items + 1)
			end
		
			if self.holding then
				if self.holding.canStoreInv and self.holding.onStoreInv then
					self.holding:onStoreInv()
				end
				self.holding = nil
			end

			-- TODO onHoldHide/onHoldShow ?
			local newHeld
			if itemIndex > 0 then
				newHeld = self.items[itemIndex][1]
			end
			if newHeld and newHeld.canStoreInv and newHeld.onRestoreInv then
				newHeld:onRestoreEnv()
			end

			--self:setHeld(newHeld)
			self.holding = newHeld
		
		end
	end

	-- clean out the removed items
	for j=#self.items,1,-1 do
		local items = self.items[j]
		for i=#items,1,-1 do
			if items[i].remove then
				items:remove(i)
			end
		end
		if #items == 0 then
			self.items:remove(j)
		end
	end


	self.inputUpDownLast = self.inputUpDown
	self.inputRunLast = self.inputRun
	self.inputShootLast = self.inputShoot
	self.inputShootAuxLast = self.inputShootAux
	self.inputJumpLast = self.inputJump
	self.inputJumpAuxLast = self.inputJumpAux
	self.inputPageUpLast = self.inputPageUp
	self.inputPageDownLast = self.inputPageDown
	self.ongroundLast = self.onground
end

function Hero:die(damage, attacker, inflicter, side)
	-- nothing atm
	if self.dead then return end
	if self.heldby then self.heldby:setHeld(nil) end
	self:playSound('explode2')
	self:setHeld(nil)
	self.warping = false
	self.climbing = false
	self.ducking = false
	self.lookingUp = false
	self.solid = false
	self.collidesWithObjects = false
	self.dead = true
	
	-- if we're respawning, keep items and weapon?
	-- but really I should be restarting the whole level
	--self.weapon = nil
	--self.items = table()
	--self.respawnTime = game.time + 1

	setTimeout(1, game.reset, game)
end

function Hero:respawn()
	self.health = self.maxHealth
	self.respawnTime = nil
	self.solid = nil
	self.collidesWithWorld = nil
	self.collidesWithObjects = nil
	self.dead = nil
	self.vel[1], self.vel[2] = 0,0
	self:setPos(unpack(game:getStartPos()))
end

function Hero:hit(damage, attacker, inflicter, side)
	self.invincibleEndTime = game.time + 1
end

function Hero:modifyDamageGiven(damage, receiver, inflicter, side)
	return math.max(0, damage + (self.attackBonus or 0))
end

function Hero:modifyDamageTaken(damage, attacker, inflicter, side)
	return math.max(0, damage - (self.defenseBonus or 0))
end

function Hero:draw(R, viewBBox, holdOveride)
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
				self.seq = 'duck'
			elseif self.lookingUp then
				self.seq = 'lookup'
			else
				if self.onground then
					if not self.warping and self.inputLeftRight ~= 0 then
						if self.inputRun then
							if vx ~= self.maxRunVel and vx ~= -self.maxRunVel then
								self.seq = 'run'
							else
								self.seq = 'maxrun'
							end
						else
							self.seq = 'walk'
						end
					else
						if self.warping then
							self.seq = 'lookup'
						else
							if self.holding then
								self.seq = 'stand-carry'
							else
								self.seq = 'stand'
							end
						end
					end
				else
					if self.swimming then
						self.seq = 'jump-arms'
					else
						if self.inputMaxSpeedTime >= self.timeToMaxSpeed and not self.holding then
							self.seq = 'jump-arms'
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
		end
	end

	Hero.super.draw(self, R, viewBBox, holdOverride)
	
	if self.weapon and self.weapon ~= self.holding then
		self.weapon:updateHeldPosition(R, viewBBox, true)
		self.weapon:draw(R, viewBBox, true)	
	end

	if self.holding then
		self:updateHeldPosition(R, viewBBox)
		self.holding:draw(R, viewBBox, true)
	end

	for _,items in ipairs(self.items) do
		for _,item in ipairs(items) do
			if item ~= self.holding
			and item ~= self.weapon
			then
				if item.updateHeldPosition then
					item:updateHeldPosition(R, viewBBox, true)
				else
					item.pos[1] = self.pos[1]
					item.pos[2] = self.pos[2]
					item.vel[1] = self.vel[1]
					item.vel[2] = self.vel[2]
				end
			end
		end
	end
end

function Hero:drawHUD(R, viewBBox)
	if Hero.super.drawHUD then Hero.super.drawHUD(self, R, viewBBox) end
	
	-- draw gui
	-- health:
	gui.font:drawUnpacked(viewBBox.min[1], viewBBox.min[2]+2, 1, -1, self.health .. '/' .. self.maxHealth)
	local gl = R.gl

	-- items:
	for i,items in ipairs(self.items) do
		i = i + 1
		local item = items[1]
		Object.draw({
			sprite = item.sprite,
			seq = item.invSeq,
			pos = viewBBox.min + vec2(1, 2 + i),
			angle = 0,
			color = item.color,
		}, R, viewBBox)
		if items:find(self.holding) then
			gui.font:drawUnpacked(viewBBox.min[1]+1.5, viewBBox.min[2]+3+i, 1, -1, '<')
		end
		if items:find(self.weapon) then
			gui.font:drawUnpacked(viewBBox.min[1]+2, viewBBox.min[2]+3+i, 1, -1, 'W')
		end
		if #items > 1 then
			gui.font:drawUnpacked(viewBBox.min[1]+2.5, viewBBox.min[2]+3+i, 1, -1, 'x'..#items)
		end
	end
	
	-- popup messages from terminals, talking, etc
	if self.popupMessageText then
		-- TODO use something other than game.paused?
		-- or fix game.paused vs Object:draw so objects can't animate while the game is paused (specifically player, geemer, etc, but not terminal)
		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		R:quad(
			viewBBox.min[1]+.7, viewBBox.min[2]+.7,	-- pos
			viewBBox.max[1]-viewBBox.min[1]-1.6,
			viewBBox.max[2]-viewBBox.min[2]-1.6, -- size
			0,0,0,0,0,
			0,0,0,.5)
		gui.font:drawUnpacked(
			viewBBox.min[1]+1, viewBBox.max[2]-1,	-- pos
			1, -1,	-- fontSize
			tostring(self.popupMessageText),	-- text
			viewBBox.max[1]-viewBBox.min[1]-2,
			viewBBox.max[2]-viewBBox.min[2]-2) -- size

		-- can't use inputJumpLast because Last keys don't refresh when paused
		if not game.paused
		or self.inputJump
		or self.inputShoot
		or self.inputJumpAux
		or self.inputShootAux
		then
			-- can't use setTimeout because timeouts don't run when paused
			--setTimeout(.5, function()
			if self.popupMessageCloseSysTime
			and self.popupMessageCloseSysTime < game.sysTime
			then
				self.popupMessageText = nil
				game.paused = false
			end
			--end)
		end
	end

	gl.glEnable(gl.GL_TEXTURE_2D)
end

-- script functions...
-- run as a coroutine

function Hero:popupMessage(text)
	self.popupMessageCloseSysTime = game.sysTime + 1
	self.popupMessageText = text
	game.paused = true
	repeat
		coroutine.yield()
	until not game.paused
end

function Hero:centerView(pos)
	self.fixedViewPos = pos
end

return Hero
