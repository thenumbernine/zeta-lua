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
local Object = require 'base.script.obj.object'
local gui = require 'base.script.singleton.gui'
local game = require 'base.script.singleton.game'
local editor = require 'base.script.singleton.editor'
local Hero = behaviors(require 'base.script.obj.player',
	require 'zeta.script.behavior.takesdamage',
	require 'zeta.script.behavior.deathtopieces')

Hero.sprite = 'hero'
Hero.maxHealth = 5

Hero.inputUpDownLast = 0
Hero.inputRun = false
Hero.inputJumpTime = -1
Hero.canCarry = true

Hero.preTouchPriority = 10
Hero.touchPriority = 10
Hero.pushPriority = 1

Hero.nextShootTime = -1

Hero.attackStat = 0
Hero.defenseStat = 0
Hero.rechargeCellsDuration = 10	-- seconds
Hero.nextRechargeCellsTime = -1

for _,ammo in ipairs{'Cells', 'Grenades', 'Missiles'} do
	Hero['ammo'..ammo] = 0
	Hero['maxAmmo'..ammo] = 0
end

function Hero:init(...)
	Hero.super.init(self, ...)
	self.items = table()	-- self.items = {{obj1, ...}, {obj2, ...}, ...} for each unique class
	self.holding = nil
	self.color = nil	-- TODO team colors
end

function Hero:refreshSize()
	if not self.ducking then
		self.bbox = box2(-.4, 0, .4, 1.7)
	else
		self.bbox = box2(-.4, 0, .4, .7)
	end
end

function Hero:setHeld(other)
	if self.holding and self.holding ~= other then
-- revert to class originals
rawset(self.holding, 'solidFlags', self.holdingLastSolidFlags)
rawset(self.holding, 'touchFlags', self.holdingLastTouchFlags)
rawset(self.holding, 'blockFlags', self.holdingLastBlockFlags)
		
		self.holding.vel[1] = self.vel[1]
		self.holding.vel[2] = self.vel[2]
-- without this, items fall through floor
self.holding.pos[1] = self.pos[1]
self.holding.pos[2] = self.pos[2]
		self:hasKicked(self.holding)
		
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
	
		self.holding = other
		self.holding.heldby = self
		self.holding.collidesWithObjects = false
		self.holding.collidesWithWorld = false
	
-- clear collision flags 
-- this assumes only classes set flags and not objects
-- TODO getters and setters for custom behavior per-object
self.holdingLastSolidFlags = rawget(self.holding, 'solidFlags')
self.holdingLastTouchFlags = rawget(self.holding, 'touchFlags')
self.holdingLastBlockFlags = rawget(self.holding, 'blockFlags')
self.holding.solidFlags = 0
self.holding.touchFlags = 0
self.holding.blockFlags = 0

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

function Hero:touchTile(tileType, side, plane, x, y)
	if tileType.damage then
		self:takeDamage(tileType.damage, tileType, tileType, side)
	end

	if self.speedBoostCharge == 1
	and tileType.name == 'speed-break'
	then
		game.level:clearTileAndBreak(x,y, self)
		return true
	end
end

Hero.speedBoostDamageTime = -1
function Hero:touch(other, side)
	-- kick ignore 
	if other.kickedBy == self
	and other.kickHandicapTime >= game.time
	then
		return true
	end

	-- skip push collisions
	for _,items in ipairs(self.items) do
		for _,item in ipairs(items) do
			if other == item then return true end
		end
	end
	if other == self.holding then return true end
	if other == self.weapon then return true end
	if other.heldby == self then return true end

	if self.speedBoostCharge == 1 
	and other.takeDamage
	and self.speedBoostDamageTime < game.time
	then
		self.speedBoostDamageTime = game.time + .1
		other:takeDamage(self.maxHealth, self, self, side)
		return true
	end
end

--[[
give the kicker a temp non-collide window
--]]
function Hero:hasKicked(other)
	other.kickedBy = self
	other.kickHandicapTime = game.time + .5
end

function Hero:tryToStand()
	-- TODO in collision v2, because we can go right up to walls, if you're next to one, then the ul tile gets tested for solid and you can't stand
	-- in v2 we have touch and stuck detection working
	-- so fix this in that by standing, doing a single move test, and going back to ducking if we hit anything 

	local level = game.level
	local cantStand = false
	local y = math.floor(self.pos[2] + self.bbox.max[2] + .5 - level.pos[2] - self.collisionEpsilon)
	for x=math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1] + self.collisionEpsilon),
		math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1] - self.collisionEpsilon)
	do
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
-- horz vels
Hero.walkVel = 7
Hero.crawlVel = 3
Hero.runVel = 15
Hero.maxRunVel = 15	-- why are these different?
Hero.timeToMaxSpeed = 1
-- climb vel
Hero.climbVel = 5
				
Hero.walkAccel = .5	-- ... plus friction ... to counteract friction ... ?
Hero.airAccel = .75

Hero.speedBoostMaxRunVel = 30
-- goes from 0 to 1 as player goes from max speed to max speed boosted speed
Hero.speedBoostCharge = 0
function Hero:getMaxRunVel()
	local SpeedBooster = require 'zeta.script.obj.speedbooster'
	for _,items in ipairs(self.items) do
		if items[1]:isa(SpeedBooster) then
			return self.speedBoostMaxRunVel
		end
	end
	return self.maxRunVel
end


Hero.swimmingJumpVel = 10
-- t0 = jump duration
-- v = jump velocity
-- before jump duration: y = v t
-- after jump duration: y0 = v t0 is the height at which gravity kicks in
-- a is gravity, a < 0 
-- y = y0 + v (t - t0) + 1/2 a (t - t0)^2 is the height after the jump
-- y' = 0 at v + a (t - t0) = 0 <=> a (t - t0) = -v <=> th = t0 - v / a
-- y(th) = y0 + v (th - t0) + 1/2 a (th - t0)^2 = y0 + v (-v/a) + 1/2 a (-v/a)^2 = y0 - v^2/a + 1/2 v^2/a = y0 - 1/2 v^2/a = yh is the max height of the jump
-- yh = y0 - 1/2 v^2 / a <=> 1/2 v^2 / (-a) + v t0 - yh = 0 <=> v = a (t0 ± sqrt(t0^2 - 2 yh / a ))
-- also means t0 = yh / v + 1/2 v / a
do 
	local jumpHeight = 6.5
-- [[ define by height
	Hero.jumpDuration = .15
	Hero.ongroundJumpVel = game.gravity * (Hero.jumpDuration - math.sqrt(Hero.jumpDuration^2 - 2 * jumpHeight / game.gravity))
--]]
--[[ define by time ... can't get too high of vel before duration becomes zero
	Hero.ongroundJumpVel = 12
	Hero.jumpDuration = jumpHeight / Hero.ongroundJumpVel + .5 * Hero.ongroundJumpVel / game.gravity
--]]
end

Hero.wallJumpEndTime = -1
Hero.wallJumpHorzVel = 10
function Hero:update(dt)
	local level = game.level

	local maxRunVel = self:getMaxRunVel()

	-- only spawn what's in our room
	local roomPosX, roomPosY = level:getMapTilePos(self.pos:unpack())
	self.room = level:getRoomAtMapTilePos(roomPosX, roomPosY)

	-- [[ create/remove objects based on our current room 
	if self.room ~= self.roomLast then
		-- reload tiles from the original buffers (in case any were modified)
		level:refreshTiles()
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
		self.roomLast = self.room
	end
	--]]

	if game.time > self.nextRechargeCellsTime then
		self.ammoCells = math.min(self.maxAmmoCells, self.ammoCells + self.maxAmmoCells * dt / self.rechargeCellsDuration)
	end

	-- slowly track player
	if self.fixedViewPos and not (editor and editor.active) then
		self.viewPos[1] = self.fixedViewPos[1]
		self.viewPos[2] = self.fixedViewPos[2]
	else
		local targetPosX = self.pos[1]
		local targetPosY = self.pos[2]
			
		if not (editor and editor.active) then
			local viewSizeX = (self.viewBBox.max[1] - self.viewBBox.min[1]) / 2 
			local viewSizeY = (self.viewBBox.max[2] - self.viewBBox.min[2]) / 2

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

	self.inputRun = self.inputJumpAux
		
	if self.isClipping then return end

	if self.climbing then
		self.useGravity = false
		if self.ducking then self:tryToStand() end
		self.lookingUp = false
		self.inputMaxSpeedTime = nil
		--self.speedBoostCharge = nil
	else
		self.useGravity = true
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
	-- TODO's ...
	-- 1) make all items touch-to-pickup
	-- 2) keep 'pickup' and 'interact' separate
	-- 3) merge the two
	if self.inputShootAux and not self.inputShootAuxLast then
		for _,other in ipairs(game.objs) do
			if other ~= self
			and not other.remove
			and other.playerGrab
			and not other.heldby
			and self.pos[1] + self.bbox.min[1] <= other.pos[1] + other.bbox.max[1]
			and self.pos[1] + self.bbox.max[1] >= other.pos[1] + other.bbox.min[1]
			and self.pos[2] + self.bbox.min[2] <= other.pos[2] + other.bbox.max[2]
			and self.pos[2] + self.bbox.max[2] >= other.pos[2] + other.bbox.min[2]
			then
				other:playerGrab(self)
				break
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
			-- push up/down to get on a climbable surface
			if self.inputUpDown ~= 0
			-- but if you're on the ground, allow them to duck/crawl
			and (self.inputUpDown > 0 or not self.onground)
			then
				self.climbing = true
			end
		else
			self.climbing = nil		-- move off of it to fall off!
		end
	end
		
	if self.collidedUp then
		self.inputJumpTime = nil
		self.vel[2] = 0
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
		self.vel[1] = self.inputLeftRight * self.climbVel
		self.vel[2] = self.inputUpDown * self.climbVel
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
			self.speedBoostCharge = nil
			-- friction used to be here but I moved it to GameObject for everyone
		else
			-- movement in air or when walking
			if self.inputLeftRight ~= 0 then
				local moveVel = self.walkVel
				if self.onground and self.ducking and self.speedBoostCharge == 0 then
					moveVel = self.crawlVel
				elseif self.inputRun then
					moveVel = self.runVel
					if self.onground then
						-- we're running.  determine how long we must keep running to hit the max speed.
						-- don't keep resetting this value too. 
						if not self.inputMaxSpeedTime then
							self.inputMaxSpeedTime = game.time
						end
					end
					-- notice, this movement in air or walking on ground ...
					-- and here i'm using maxRunVel, which is regular or speed boosted ...
					if self.inputMaxSpeedTime and game.time >= self.inputMaxSpeedTime + self.timeToMaxSpeed then
						local t = self.speedBoostCharge
						moveVel = self.runVel * (1 - t) + self.speedBoostMaxRunVel * t
					end

					-- if we're on ground
					if self.onground
					-- and we're at max vel (don't forget friction has been applied last frame)
					and math.abs(self.vel[1]) >= self.maxRunVel - self.friction
					and self:findItem(nil, require 'zeta.script.obj.speedbooster'.is)
					then
						self.speedBoostCharge = math.min(1, self.speedBoostCharge + dt)
					end	
					
					if self.onground and (self.inputLeftRight > 0) ~= (self.vel[1] > 0) then
						self.inputMaxSpeedTime = nil
						self.speedBoostCharge = nil
					end
				end

				local accel = self.onground and (self.walkAccel + self.friction) or self.airAccel
				if self.inputLeftRight < 0 then
					self.vel[1] = self.vel[1] - accel
					if self.vel[1] < -moveVel then self.vel[1] = -moveVel end
				elseif self.inputLeftRight > 0 then
					self.vel[1] = self.vel[1] + accel
					if self.vel[1] > moveVel then self.vel[1] = moveVel end
				end
				self.drawMirror = self.inputLeftRight < 0
			end
		end
	end
	
-- [[ if we just hit the ground then see if we're at max vel.  if not then reset the run meter
	if self.onground and not self.ongroundLast then
		-- TODO check jumping on a tile here

		--if self.vel[1] ~= maxRunVel and self.vel[1] ~= -maxRunVel then
		if math.abs(self.vel[1]) < self.runVel then
			self.inputMaxSpeedTime = nil
			self.speedBoostCharge = nil
		end
	end
--]]
	
	do
		local tile = level:getTile(self.pos[1] - level.pos[1], self.pos[2] - level.pos[2])
		self.swimming = tile and tile.fluid and #tile.fluid > 0
	end
		
	if self.onground or self.climbing or self.swimming then
		if self.swimming then
			if self.inputJump and (self.inputSwimTime + self.swimDelay < game.time) then
				self:playSound('swim')
			
				self.onground = false
				self.climbing = nil
				self.inputJumpTime = game.time
				self.jumpVel = -self.swimmingJumpVel
				self.inputSwimTime = game.time
			end
		
		elseif self.inputJump then
			if not self.inputJumpLast and self.inputJumpTime < game.time then
				self:playSound('jump')
			
				self.onground = false
				self.climbing = nil
				self.inputJumpTime = game.time
				self.jumpVel = self.ongroundJumpVel
			end
		else
			if self.collidedLeft or self.collidedRight then
				self.inputMaxSpeedTime = nil
				self.speedBoostCharge = nil
			end
		end
	end

	-- walljump?
	if not self.onground
	and not self.climbing
	and not self.swimming
	and not self.ducking
	and (self.collidedLeft or self.collidedRight)
	then
		self.drawMirror = not self.collidedLeft
		self.vel[2] = self.vel[2] * .5
		local WallJump = require 'zeta.script.obj.walljump'
		if self:findItem(nil, WallJump.is) then
			self.wallJumpEndTime = game.time + .15
		end
	end

	-- then start the touch-n-go state
	if not self.ongroundLast
	and not self.climbing
	and not self.swimming
	and not self.ducking
	and self.inputJump
	and not self.inputJumpLast
	and game.time < self.wallJumpEndTime
	then
		self.inputJumpTime = game.time
		self.jumpVel = self.ongroundJumpVel
		self.vel[2] = self.jumpVel
		if self.collidedLeft then
			self.vel[1] = self.wallJumpHorzVel
		else
			self.vel[1] = -self.wallJumpHorzVel
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
	-- pushed up or down while jumping?
	if not self.onground
	and game.time > self.wallJumpEndTime
	and self.inputUpDown ~= 0
	and self.inputUpDownLast == 0 then
		if self.inputUpDown < 0 and not self.ducking then
			self.ducking = true
		elseif self.inputUpDown > 0 and self.ducking then
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
				if obj.playerUse then
					obj:playerUse(self)
				end
			end
		end
		--]]
		-- [[
		local bestObj
		local bestDist = 1
		for _,obj in ipairs(game.objs) do
			if obj.playerUse then
				-- l-inf dist
				local dist = math.max(math.abs(self.pos[1] - obj.pos[1]), math.abs(self.pos[2] - obj.pos[2]))
				if dist < bestDist then
					bestDist = dist
					bestObj = obj
				end
			end
		end
		if bestObj then
			bestObj:playerUse(self)
		end
		--]]
	end

	if self.inputJump or self.swimming then
		--if self.vel[2] < 0 then self.inputJumpTime = nil end		-- doesn't work well with swimming
		if self.inputJumpTime + self.jumpDuration >= game.time then
			if self.inputJump then
				self.vel[2] = self.jumpVel
			end
			if self.swimming then
				self.vel[2] = self.vel[2] + self.jumpVel
			end
		end
	end
	if not self.inputJump 
	and self.inputJumpLast 
	and self.vel[2] > 0
	then
		self.inputJumpTime = nil
		self.vel[2] = 0
	end

	self:refreshSize()

	-- cycle weapons
	local pageUpPress = self.inputPageUp and not self.inputPageUpLast
	local pageDownPress = self.inputPageDown and not self.inputPageDownLast
	if pageUpPress or pageDownPress then
		local itemIndex = self.items:find(nil, function(items)
			return items:find(self.weapon)
		end)
		itemIndex = itemIndex or 0 
	
		local dir
		if pageUpPress then
			dir = 1
		elseif pageDownPress then
			dir = -1
		end

		local Weapon = require 'zeta.script.obj.weapon'
		local newWeapon
		while true do
			itemIndex = (itemIndex + dir) % (#self.items + 1)
	
			-- TODO onHoldHide/onHoldShow ?
			if itemIndex == 0 then
				break
			else
				local item = self.items[itemIndex][1]
				if item:isa(Weapon) then
					newWeapon = item
					break
				end
			end
		end
		self.weapon = newWeapon
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

	-- speaking of inventory...
	self.inputUpDownLast = self.inputUpDown
	self.inputRunLast = self.inputRun
	self.inputShootLast = self.inputShoot
	self.inputShootAuxLast = self.inputShootAux
	self.inputJumpLast = self.inputJump
	self.inputJumpAuxLast = self.inputJumpAux
	self.inputPageUpLast = self.inputPageUp
	self.inputPageDownLast = self.inputPageDown
end

Hero.removeOnDie = false
function Hero:die(damage, attacker, inflicter, side)
	-- nothing atm
	if self.dead then return end
	if self.heldby then self.heldby:setHeld(nil) end
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
	
	Hero.super.die(self, damage, attacker, inflicter, side)

	self.sprite = false
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
	return math.max(0, damage + self.attackStat)
end

function Hero:modifyDamageTaken(damage, attacker, inflicter, side)
	return math.max(0, damage - self.defenseStat)
end

function Hero:takeDamage(damage, attacker, inflicter, side)
	if self.dead then return end
	--if self.speedBoostCharge == 1 then return end	-- should speed boost make you invincible, or just hit first?
	return Hero.super.takeDamage(self, damage, attacker, inflicter, side) 
end

function Hero:draw(R, viewBBox, holdOveride)
	if not self.sprite then return end

	if self.invincibleEndTime >= game.time then
		if math.floor(game.time * 8) % 2 == 0 then
			return
		end
	end

	local vx = self.vel[1]
	if self.touchEntDown then
		vx = vx - self.touchEntDown.vel[1]
	end
	
	if not self.dead then
		if self.climbing then
			if self.vel[1] ~= 0 or self.vel[2] ~= 0 then
				self.seq = 'climb'	-- moving
			else
				self.seq = 'climb1'	-- still
			end
		else
			if self.ducking then
				self.seq = 'duck'
			elseif self.lookingUp and self.inputLeftRight == 0 then
				if self.weapon then
					self.seq = 'lookup_carry'
				else
					self.seq = 'lookup'
				end
			else
				if self.onground then
					if not self.warping and self.inputLeftRight ~= 0 then
						if self.inputRun then
							if self.weapon then
								self.seq = 'run_carry'
							else
								self.seq = 'run'
							end
						else
							if self.weapon then
								self.seq = 'walk_carry'
							else
								self.seq = 'walk'
							end
						end
					else
						if self.warping then
							self.seq = 'lookup'
						else
							-- TODO separate animation for holding weapon, holding item, or both
							if self.weapon then
								self.seq = 'stand_carry'
							else
								self.seq = 'stand'
							end
						end
					end
				else
					if self.swimming then
						self.seq = 'jump-arms'
					else
						--if self.inputMaxSpeedTime >= self.timeToMaxSpeed and not self.holding then
						--	self.seq = 'jump-arms'
						do --else
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

	if self.speedBoostCharge > 0 then
		local l = self.speedBoostCharge
		local color = rawget(self, 'color')
		self.color = {0,.5*l,l,1}
		local gl = R.gl
		gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE)
		Hero.super.draw(self, R, viewBBox, holdOverride)
		if l == 1 then
			local speedEchoTick = math.floor(game.time * 20)
			if speedEchoTick ~= self.speedEchoTick then
				self.speedEchoTick = speedEchoTick 
			
				-- get current frame ...
				
				local animsys = require 'base.script.singleton.animsys'
				local sprite, seq, frameNumber = animsys:getInfo(self.sprite, self.seq, self.seqStartTime)
				local freq = seq.freq or sprite.freq or 1
				local startTime = game.time
				local lifetime = 1
				local SpeedEcho = Object{
					solidFlags = 0,
					blockFlags = 0,
					touchFlags = 0,
					pos = self.pos,
					angle = self.angle,
					sprite = self.sprite,
					seq = self.seq,
					drawMirror = self.drawMirror,
					color = {0,.5,1,1},
					update = function(self)
						self.seqStartTime = game.time - frameNumber / freq 
						self.color[4] = 1 - (game.time - startTime) / lifetime
						if self.color[4] < 0 then self.remove = true end
					end,
				}
			end
			
			local s = math.sin(game.time * 2 * math.pi) * .5 + .5
			self.color = {0,.5,1,s}
			self.drawScale = {1+.2*s, 1+.2*s}
			Hero.super.draw(self, R, viewBBox, holdOverride)
			self.drawScale = nil
		end
		gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA)
		self.color = color
	end

	if self.weapon then
		self.weapon:updateHeldPosition(R, viewBBox, true)
		self.weapon:draw(R, viewBBox, true)	
	end

	if self.holding then
		self:updateHeldPosition(R, viewBBox)
		self.holding:draw(R, viewBBox, true)
	end

	for _,items in ipairs(self.items) do
		for _,item in ipairs(items) do
			do--if item ~= self.holding and item ~= self.weapon then
				if item.updateHeldPosition then
					item:updateHeldPosition(R, viewBBox, true)
				end
				--else
				
				-- update all items positions
				-- so that they don't leave the player's mapTile and get removed
				-- looks like the overlay drawing doesn't use their pos anyways
				item.pos[1] = self.pos[1]
				item.pos[2] = self.pos[2]
				item.vel[1] = self.vel[1]
				item.vel[2] = self.vel[2]
				--end
			end
		end
	end
end

function Hero:drawHUD(R, viewBBox)
	if Hero.super.drawHUD then Hero.super.drawHUD(self, R, viewBBox) end
	
	local gl = R.gl
	-- TODO if start button pushed ...
	-- then show inventory
	-- otherwise have 'l' and 'r' cycle ... weapons only? 

	local x = viewBBox.min[1]
	local y = viewBBox.min[2]+1
	-- draw gui
	-- health:
	y=y+1
	gui.font:drawUnpacked(x, y, 1, -1, 'HP: '..self.health .. '/' .. self.maxHealth)
	gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
	-- hp
	R:quad(x+5, y-1, 2, .7,
		0,0,0,0,0,
		0,0,0,.5)
	R:quad(x+5.1, y-.9, 1.8*self.health/self.maxHealth, .5,
		0,0,0,0,0,
		1,0,0,.5)
	
	y=y+1
	-- vel
	R:quad(x+5, y-1, 2, .7,
		0,0,0,0,0,
		0,0,0,.5)
	R:quad(x+5.1, y-.9, 1.8*self.speedBoostCharge, .5,
		0,0,0,0,0,
		0,1,1,.5)

	--y=y+1 gui.font:drawUnpacked(viewBBox.min[1], y, 1, -1, 'Cells: ' .. ('%.1f'):format(self.ammoCells)..'/'..self.maxAmmoCells)
	--y=y+1 gui.font:drawUnpacked(viewBBox.min[1], y, 1, -1, 'ATK +' .. self.attackStat)
	--y=y+1 gui.font:drawUnpacked(viewBBox.min[1], y, 1, -1, 'DEF +' .. self.defenseStat)
	
	local x = viewBBox.min[1]
	local function drawInv(item, x, y, items)
		Object.draw({
			sprite = item.sprite,
			seq = item.invSeq,
			pos = {x + 1, y - 1},
			angle = 0,
			color = item.color,
			drawScale = item.drawScale,
		}, R, viewBBox)
		if items and #items > 1 then
			gui.font:drawUnpacked(x+1.5, y, 1, -1, 'x'..#items)
		end
	end

	y=y+1 
	if self.weapon then
		drawInv(self.weapon, x, y, select(2, self.items:find(nil, function(items)
			return items:find(self.weapon)
		end)))
		if self.weapon.ammo then
			local ammo = self['ammo'..self.weapon.ammo]
			local max = self['maxAmmo'..self.weapon.ammo]
			gui.font:drawUnpacked(x+3.5, y, 1, -1, ('%.3f'):format(ammo)..'/'..max)
		end
	end

	if game.paused and not self.popupMessageText then

		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		R:quad(
			viewBBox.min[1]+.7, viewBBox.min[2]+.7,	-- pos
			viewBBox.max[1]-viewBBox.min[1]-1.6,
			viewBBox.max[2]-viewBBox.min[2]-1.6, -- size
			0,0,0,0,0,
			0,0,0,.5)

		x = viewBBox.min[1] + 2
		y = viewBBox.max[2] - 2
		-- items:
		for _,items in ipairs(self.items) do
			y=y-1
			local item = items[1]
			drawInv(item,x,y,items)
			if item.name then
				gui.font:drawUnpacked(x+3.5, y, 1, -1, item.name)
			end
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

	if #game.bosses > 0 then
		local boss = game.bosses[1]
		local x = .5*(viewBBox.min[1]+viewBBox.max[1])
		local y = viewBBox.min[2]+.7
		local w = .5*(viewBBox.max[1]-viewBBox.min[1])-.7
		local h = 1
		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		R:quad(
			x,y,w,h,
			0,0,0,0,0,
			0,0,0,.5)
		local f = boss.health / boss.maxHealth
		R:quad(
			x,y,w*f,h,
			0,0,0,0,0,
			1,0,0,.5)
	end

	gl.glEnable(gl.GL_TEXTURE_2D)
end

-- script functions...
-- run as a coroutine

function Hero:popupMessage(text)
	self.popupMessageCloseSysTime = game.sysTime + .3
	self.popupMessageText = text
	game.paused = true
	repeat
		coroutine.yield()
	until not game.paused
end

function Hero:centerView(pos)
	self.fixedViewPos = pos
end

function Hero:findItemNamed(name, callback)
	for _,items in ipairs(self.items) do
		for _,item in ipairs(items) do
			if callback then
				if callback(item) then return item end
			else
				if item.name == name then return item end
			end
		end
	end
	return false
end
Hero.findItem = Hero.findItemNamed

-- remove an item from the inventory with matching class, or callback
-- doesn't remove it from the game
-- returns it
function Hero:removeItem(removeItem, callback)
	for i=#self.items,1,-1 do
		local items = self.items[i]
		for j,item in ipairs(items) do
			local found
			if callback then
				found = callback(item, removeItem)
			else
				found = item == removeItem
			end
			if found then
				items:remove(j)
				if #items == 0 then self.items:remove(i) end
				if self.weapon == item then self.weapon = nil end
				if item.heldby == self then item.heldby = nil end
				return item
			end
		end
	end
end

return Hero
