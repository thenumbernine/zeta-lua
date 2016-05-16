local ffi = require 'ffi'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
local modio = require 'base.script.singleton.modio'
local animsys = require 'base.script.singleton.animsys'
local game = require 'base.script.singleton.game'

local Object = class()

Object.solid = true
Object.collidesWithWorld = true
Object.collidesWithObjects = true
Object.useGravity = true
Object.friction = 1		-- additive, not scalar
Object.seq = 'stand'
Object.drawMirror = false

-- used to evaluate whose touch function to run first
Object.preTouchPriority = 0
Object.touchPriority = 0

-- used to evaluate who gets priority when pushing
Object.pushPriority = 0

-- used to init the per-object bbox.  don't manip this plz
Object.bbox = box2(-.4, 0, .4, .8)

-- useful vars to have around that I should just put in util.lua
Object.touchEntFields = {'touchEntUp', 'touchEntDown', 'touchEntLeft', 'touchEntRight'}
Object.touchEntHorzFields = {'touchEntLeft', 'touchEntRight'}
Object.touchEntVertFields = {'touchEntUp', 'touchEntDown'}


-- my attempt to make the animation system more flexible:
Object.seqStartTime = 0	-- time offset at which the sequence starts
Object.seqNext = nil		-- this says what sequence comes next.  it means I need some return info from the animation update.


function Object:init(args)
	self.pos = vec2()
	self.lastpos = vec2()
	self.vel = vec2()
	self.lastvel = vec2()
	self.bbox = box2(self.bbox.min[1], self.bbox.min[2], self.bbox.max[1], self.bbox.max[2])

	if args.pos then self.pos[1], self.pos[2] = args.pos[1], args.pos[2] end
	if args.vel then self.vel[1], self.vel[2] = args.vel[1], args.vel[2] end
	if args.sprite then self.sprite = args.sprite end
	if args.solid ~= nil then self.solid = args.solid end
	if args.drawScale then self.drawScale = vec2(table.unpack(args.drawScale)) end
	if args.color then self.color = {table.unpack(args.color)} end 
	if args.bbox then self.bbox = box2(table.unpack(args.bbox)) end

	game:addObject(self)	-- only do this once per object.  don't reuse, or change the uid system

	if args.create then
		local threads = require 'base.script.singleton.threads'
		local sandbox = modio:require 'script.sandbox'
		threads:add(function()
			-- wait for ctor to resolve
			coroutine.yield()
			sandbox(args.create, 'self', self)
		end)
	end
end

function Object:update(dt)

	self.lastpos[1], self.lastpos[2] = self.pos[1], self.pos[2]
	self.lastvel[1], self.lastvel[2] = self.vel[1], self.vel[2]

	if self.removeTime and self.removeTime < game.time then
		self.remove = true
		return
	end

	local level = game.level
	local gravity = game.gravity
	local maxVel = game.maxVel
	local maxFallVel = game.maxFallVel	-- optional
	
	-- speed limit
	if self.vel[1] < -maxVel then self.vel[1] = -maxVel end
	if self.vel[1] > maxVel then self.vel[1] = maxVel end
	if self.vel[2] < -maxVel then self.vel[2] = -maxVel end
	if self.vel[2] > maxVel then self.vel[2] = maxVel end

	local tile = level:getTile(self.pos[1], self.pos[2])
	if tile and tile.canSwim then
		gravity = gravity * .1
		maxFallVel = maxFallVel and maxFallVel * .1
		--self.vel[2] = self.vel[2] * .1
	end
	
	-- special falling speed
	if maxFallVel then
		if self.vel[2] < -maxFallVel then self.vel[2] = -maxFallVel end
	end
		
	if self.useGravity then
		self.vel[2] = self.vel[2] + gravity * dt
	end
	
	local moveX = self.vel[1] * dt
	local moveY = self.vel[2] * dt
	
	if self.touchEntDown then
		moveX = moveX + self.touchEntDown.pos[1] - self.touchEntDown.lastpos[1]
		moveY = moveY + self.touchEntDown.pos[2] - self.touchEntDown.lastpos[2]
	end
	
	self.collidedUp = false
	self.collidedDown = false
	self.collidedLeft = false
	self.collidedRight = false
	self.onground = false
	self.touchEntUp = nil
	self.touchEntDown = nil
	self.touchEntLeft = nil
	self.touchEntRight = nil
	
	self:move(moveX, moveY)
	
	if self.onground then
		if self.vel[1] > 0 then
			self.vel[1] = self.vel[1] - self.friction
			if self.vel[1] < 0 then self.vel[1] = 0 end
		elseif self.vel[1] < 0 then
			self.vel[1] = self.vel[1] + self.friction
			if self.vel[1] > 0 then self.vel[1] = 0 end
		end
	end
	
	-- animation next cycle
	
	self.seqHasFinished = nil	-- NOTICE this only gets set when 'seqNext' is set
	if self.seqNext then
		-- determine frame number (without modulo) for this animation
		self.seqHasFinished = animsys:seqHasFinished(self.sprite, self.seq or 'stand', self.seqStartTime)
		if self.seqHasFinished then
			self:setSeq(self.seqNext)	-- or maybe a stack?
		end
	end
	
end

function Object:setSeq(seq, seqNext)
	self.seqNext = seqNext
	if self.seq == seq then return end	-- don't reset it when continually setting it
	self.seq = seq
	self.seqStartTime = game.time
end

function Object:setPos(x,y)
	self.pos[1], self.pos[2] = x,y
end

function Object:moveToPos(x,y)
	self:move(x - self.pos[1], y - self.pos[2])
end

local debugDraw = table()

function Object:move(moveX, moveY)
	local level = game.level
	local epsilon = .001

	-- when doing line trace, and dividing by moveX or moveY, make sure we don't get near-infinite values
	if math.abs(moveX) < epsilon then moveX = 0 end
	if math.abs(moveY) < epsilon then moveY = 0 end

--print('move start at',self.pos,'bbox',self.bbox + self.pos)
	self.pos[2] = self.pos[2] + moveY
--print('up/down move to',self.pos,'bbox',self.bbox + self.pos)

	if moveY ~= 0 then
		local y
		-- the side of obj that will be impacting:
		local side, oppositeSide
		if moveY < 0 then
			side = 'down'
			oppositeSide = 'up'
			y = math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2])
		else
			side = 'up'
			oppositeSide = 'down'
			y = math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2])
		end

		-- need to search x in the correct order or else player skips n the air when running downhill at 27 degrees to the right
		local xmin = math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1])
		local xmax = math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1])
		local x1, x2 = xmin, xmax
		local xstep = 1
		if moveX > 0 then
			x1,x2 = x2,x1
			xstep = -1
		end
		for x = x1,x2,xstep do
			local tile = level:getTile(x,y)
			if tile then
				local plane
				if self.collidesWithWorld and tile.solid then
					local collides
					local testPlane

					if tile.plane then
						plane = tile.plane
						if moveY < 0 then
							testPlane = plane[2] > 0
						else
							testPlane = plane[2] < 0
						end
						if testPlane then
							local cx
							if plane[1] > 0 then
								cx = self.pos[1] + self.bbox.min[1] - (x + level.pos[1])
							else
								cx = self.pos[1] + self.bbox.max[1] - (x + level.pos[1])
							end
							cx = math.clamp(cx, 0, 1)
							do --if cx >= -epsilon and cx <= 1+epsilon then
								local cy = -(cx * plane[1] + plane[3]) / plane[2]
								local edge
								if moveY < 0 then
									edge = self.bbox.min[2] - epsilon
								else
									edge = self.bbox.max[2] + epsilon
								end
								local destY = (cy + y + level.pos[2]) - edge
								self.pos[2] = destY --(moveY > 0 and math.min or math.max)(self.pos[2], destY)
--print('up/down plane push to',self.pos,'bbox',self.bbox + self.pos)
								collides = true
							end
						end
					end
					if not testPlane then
						-- TODO push precedence
						local destY
						if moveY < 0 then
							local oymax = y + 1 + level.pos[2]
							destY = oymax - self.bbox.min[2] + epsilon
						else
							local oymin = y + level.pos[2]
							destY = oymin - self.bbox.max[2] - epsilon
						end
						self.pos[2] = (moveY > 0 and math.min or math.max)(self.pos[2], destY)
--print('up/down block push to',self.pos,'bbox',self.bbox + self.pos)
						collides = true
					end
					if collides then
						self.vel[2] = 0
						if moveY < 0 then
							self.collidedDown = true
							self.onground = true
						else
							self.collidedUp = true
						end
--debugDraw:insert{tile=tile, pos={x,y}, color={0,0,1}}
						if self.touchTile then self:touchTile(tile, side, plane) end
						if tile.touch then tile:touch(self) end
					end
				end
--[[ tile-bound entities
				if self.collidesWithObjects then
					if tile.objs then
						for _,obj in ipairs(tile.objs) do
--]]
-- [[ world-bound entities
			end
		end
		if self.collidesWithObjects then
			for _,obj in ipairs(game.objs) do
				if obj ~= self then
					local t
					if moveY > 0 then	-- going up, test top of self with bottom of obj
						--self.pos[2] + self.bbox.max[2] + moveY * t = obj.pos[2] + obj.bbox.min[2]
						 t = (obj.pos[2] + obj.bbox.min[2] - self.pos[2] - self.bbox.max[2]) / moveY
					elseif moveY < 0 then
						--self.pos[2] + self.bbox.min[2] + moveY * t = obj.pos[2] + obj.bbox.max[2]
						 t = (obj.pos[2] + obj.bbox.max[2] - self.pos[2] - self.bbox.min[2]) / moveY
					else
						error("moveY = 0")
					end
					if t >= 0 and t <= 1
					and self.pos[1] + self.bbox.min[1] + moveX * t <= obj.pos[1] + obj.bbox.max[1]
					and self.pos[1] + self.bbox.max[1] + moveX * t >= obj.pos[1] + obj.bbox.min[1]
					then
						do
				
				-- this looks like a relic from the tile-linked obj lists
				-- whatever it does...
				-- with it, objects don't get hit by larger-than-1x1 objects if they're standing still
				-- without it, as soon as the player hits a non-solid object, the both of them skate across the world
				--[=[
				and xmin <= obj.pos[1]+1 and obj.pos[1]-1 <= xmax and math.abs(y-obj.pos[2]) < 1
				--]=]
				--[=[
				and math.floor(self.pos[1] + self.bbox.min[1]) <= math.floor(obj.pos[1] + obj.bbox.max[1])
				and math.floor(self.pos[1] + self.bbox.max[1]) >= math.floor(obj.pos[1] + obj.bbox.min[1])
				and math.floor(self.pos[2] + self.bbox.min[2]) <= math.floor(obj.pos[2] + obj.bbox.max[2])
				and math.floor(self.pos[2] + self.bbox.max[2]) >= math.floor(obj.pos[2] + obj.bbox.min[2])
				--]=]
--]]
							if obj.collidesWithObjects then
								do --[[
								if self.pos[1] + self.bbox.min[1] <= obj.pos[1] + obj.bbox.max[1]
								and self.pos[1] + self.bbox.max[1] >= obj.pos[1] + obj.bbox.min[1]
								and self.pos[2] + self.bbox.min[2] <= obj.pos[2] + obj.bbox.max[2]
								and self.pos[2] + self.bbox.max[2] >= obj.pos[2] + obj.bbox.min[2]
								then
								--]]
									-- run a pretouch routine that has the option to prevent further collision
									local donttouch
									if self.preTouchPriority >= obj.preTouchPriority then
										donttouch = self:pretouch(obj, side) or donttouch
										donttouch = obj:pretouch(self, oppositeSide) or donttouch
									else
										donttouch = obj:pretouch(self, oppositeSide) or donttouch
										donttouch = self:pretouch(obj, side) or donttouch
									end

									if not donttouch then
										if self.solid and obj.solid then
											
											if self.pushPriority >= obj.pushPriority then
												if moveY < 0 then
													obj:move(
														0,
														self.pos[2] + self.bbox.min[2] - obj.bbox.max[2] - epsilon - obj.pos[2]
													)
												else
													obj:move(
														0,
														self.pos[2] + self.bbox.max[2] - obj.bbox.min[2] + epsilon - obj.pos[2]
													)
												end
											end

											self.vel[2] = obj.vel[2]
											if moveY < 0 then
												self.pos[2] = obj.pos[2] + obj.bbox.max[2] - self.bbox.min[2] + epsilon
												self.onground = true	-- 'onground' is different from 'collidedDown' in that 'onground' means we're on something solid
											else
												self.pos[2] = obj.pos[2] + obj.bbox.min[2] - self.bbox.max[2] - epsilon
											end
--print('up/down object push to',self.pos,'bbox',self.bbox + self.pos)
										end
										if moveY < 0 then
											self.collidedDown = true
											self.touchEntDown = obj
										else
											self.collidedUp = true
											self.touchEntUp = obj
										end
										
										-- run post touch after any possible push
										if self.touchPriority >= obj.touchPriority then
											if self.touch then self:touch(obj, side) end
											if obj.touch then obj:touch(self, oppositeSide) end
										else
											if obj.touch then obj:touch(self, oppositeSide) end
											if self.touch then self:touch(obj, side) end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	self.pos[1] = self.pos[1] + moveX
--print('left/right move to',self.pos,'bbox',self.bbox + self.pos)

	-- left/right
	if moveX ~= 0 then
		local x
		-- the side of obj that will be impacting:
		local side, oppositeSide
		if moveX < 0 then
			side = 'left'
			oppositeSide = 'right'
			x = math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1])
		else
			side = 'right'
			oppositeSide = 'left'
			x = math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1])
		end
	
		local ymin = math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2])
		local ymax = math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2])
		for y = ymin,ymax do
			local tile = level:getTile(x,y)
			if tile then
				if self.collidesWithWorld and tile.solid then
					local collides
					if tile.plane then
						local plane = tile.plane
--print('found planes, first plane is',table.unpack(plane))
						if plane[2] > 0 then
							local cx
							if plane[1] > 0 then	-- plane normal facing right / slope up&left
								cx = self.pos[1] + self.bbox.min[1] - (x + level.pos[1])
							else	-- plane normal facing left / slope up&right
								cx = self.pos[1] + self.bbox.max[1] - (x + level.pos[1])
							end
--print('tile slope collision cx=',cx)							
							cx = math.clamp(cx, 0, 1)
							do --if cx >= -epsilon and cx <= 1+epsilon then
								local cy = -(cx * plane[1] + plane[3]) / plane[2]
								local destY = (cy + y + level.pos[2]) - self.bbox.min[2]
								self.pos[2] = math.max(self.pos[2], destY)
--print('left/right plane push up/down to',self.pos,'bbox',self.bbox + self.pos)
								self.vel[2] = 0
								self.collidedDown = true
								self.onground = true
								if self.touchTile then self:touchTile(tile, 'down', plane) end
								if tile.touch then tile:touch(self) end
--debugDraw:insert{tile=tile, pos={x,y}, color={0,1,0}}
							end
						end
					--[[
						if plane[1] > 0 then
							local cy
							if plane[2] > 0 then
								cy = self.pos[2] + self.bbox.min[2] - (y + level.pos[2])
							else
								cy = self.pos[2] + self.bbox.max[2] - (y + level.pos[2])
							end
							if cy >= 0 and cy <= 1 then
								local cx = -(cy * plane[2] + plane[3]) / plane[1]
								self.pos[1] = (cx + x + level.pos[1]) - self.bbox.min[2] + epsilon
								collides = true
							end
						end
					--]]
					else
						-- if there's a tile on the side of this tile that is solid, then don't test
						-- this will keep blocks in the floor from snagging collisions when walking up diagonals
						-- (only collide exposed planes)
						local nextTile
						local sideCantBeHit
						if moveX < 0 then
							-- if we're moving left, and the tile to this tile's right is solid on its left side, then ignore this tile
							nextTile = level:getTile(x+1,y)
							local plane = nextTile and nextTile.plane
							if not plane then
								sideCantBeHit = nextTile and nextTile.solid
							else
								sideCantBeHit = plane[1] > 0 and plane[2] > 0
							end
						else
							-- moving right, check tile to the left for solid on its right side
							nextTile = level:getTile(x-1,y)
							local plane = nextTile and nextTile.plane
							if not plane then
								sideCantBeHit = nextTile and nextTile.solid
							else
								sideCantBeHit = plane[1] < 0 and plane[2] > 0 
							end
						end
						if not sideCantBeHit then
							if moveX < 0 then
								local oxmax = x + 1 + level.pos[1]
								self.pos[1] = oxmax - self.bbox.min[1] + epsilon
								self.collidedLeft = true
							else
								local oxmin = x + level.pos[1]
								self.pos[1] = oxmin - self.bbox.max[1] - epsilon
								self.collidedRight = true
							end
--print('left/right block push to',self.pos,'bbox',self.bbox + self.pos)
							self.vel[1] = 0
							if self.touchTile then self:touchTile(tile, side) end
							if tile.touch then tile:touch(self) end
--debugDraw:insert{tile=tile, pos={x,y}, color={1,0,0}}
						end
					end
				end

--[[ tile-bound entities
				if self.collidesWithObjects then
					if tile.objs then
						for _,obj in ipairs(tile.objs) do
--]]
-- [[ world-bound entities
			end
		end

		if self.collidesWithObjects then
			for _,obj in ipairs(game.objs) do
				if obj ~= self then
					local t
					if moveX > 0 then	-- going up, test top of self with bottom of obj
						--self.pos[1] + self.bbox.max[1] + moveX * t = obj.pos[1] + obj.bbox.min[1]
						 t = (obj.pos[1] + obj.bbox.min[1] - self.pos[1] - self.bbox.max[1]) / moveX
					elseif moveX < 0 then
						--self.pos[1] + self.bbox.min[1] + moveX * t = obj.pos[1] + obj.bbox.max[1]
						 t = (obj.pos[1] + obj.bbox.max[1] - self.pos[1] - self.bbox.min[1]) / moveX
					else
						error("moveX = 0")
					end
					if t >= 0 and t <= 1
					and self.pos[2] + self.bbox.min[2] + moveY * t <= obj.pos[2] + obj.bbox.max[2]
					and self.pos[2] + self.bbox.max[2] + moveY * t >= obj.pos[2] + obj.bbox.min[2]
					then
						do

				
				--[=[
				and math.abs(x-obj.pos[1]) < 1 and ymin <= obj.pos[2]+1 and obj.pos[2]-1 <= ymax
				--]=]
				--[=[
				and math.floor(self.pos[1] + self.bbox.min[1]) <= math.floor(obj.pos[1] + obj.bbox.max[1])
				and math.floor(self.pos[1] + self.bbox.max[1]) >= math.floor(obj.pos[1] + obj.bbox.min[1])
				and math.floor(self.pos[2] + self.bbox.min[2]) <= math.floor(obj.pos[2] + obj.bbox.max[2])
				and math.floor(self.pos[2] + self.bbox.max[2]) >= math.floor(obj.pos[2] + obj.bbox.min[2])
				--]=]
--]]
							if obj.collidesWithObjects then
								do --[[
								if self.pos[1] + self.bbox.min[1] <= obj.pos[1] + obj.bbox.max[1]
								and self.pos[1] + self.bbox.max[1] >= obj.pos[1] + obj.bbox.min[1]
								and self.pos[2] + self.bbox.min[2] <= obj.pos[2] + obj.bbox.max[2]
								and self.pos[2] + self.bbox.max[2] >= obj.pos[2] + obj.bbox.min[2]
								then
								--]]
									local donttouch
									if self.preTouchPriority >= obj.preTouchPriority then
										donttouch = self:pretouch(obj, side) or donttouch
										donttouch = obj:pretouch(self, oppositeSide) or donttouch
									else
										donttouch = obj:pretouch(self, oppositeSide) or donttouch
										donttouch = self:pretouch(obj, side) or donttouch
									end

									if not donttouch then
										if self.solid and obj.solid then

											if self.pushPriority >= obj.pushPriority then
												if moveX < 0 then
													obj:move(
														self.pos[1] + self.bbox.min[1] - obj.bbox.max[1] - epsilon - obj.pos[1],
														0
													)
												else
													obj:move(
														self.pos[1] + self.bbox.max[1] - obj.bbox.min[1] + epsilon - obj.pos[1],
														0
													)
												end
											end

											self.vel[1] = obj.vel[1]
											if moveX < 0 then
												self.pos[1] = obj.pos[1] + obj.bbox.max[1] - self.bbox.min[1] + epsilon
											else
												self.pos[1] = obj.pos[1] + obj.bbox.min[1] - self.bbox.max[1] - epsilon
											end
--print('left/right object push to',self.pos,'bbox',self.bbox + self.pos)
										end
										if moveX < 0 then
											self.collidedLeft = true
											self.touchEntLeft = obj
										else
											self.collidedRight = true
											self.touchEntRight = obj
										end
										if self.touchPriority >= obj.touchPriority then
											if self.touch then self:touch(obj, side) end
											if obj.touch then obj:touch(self, oppositeSide) end
										else
											if obj.touch then obj:touch(self, oppositeSide) end
											if self.touch then self:touch(obj, side) end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
--print('move finished at',self.pos,'bbox',self.bbox + self.pos)
end


--[[ =========================
  second attempt at movement
========================= --]]

--[[
move is always run by all objects on update, even if dx,dy == 0,0
for any useGravity objects it'll be 0,-gravity

this means non-solid objects will potentially be starting inside other objects
but they don't collide with other objects anyways, do they?
--]]
Object.SOLID_WORLD = 1
Object.SOLID_YES = 2
Object.SOLID_SHOT = 4
Object.SOLID_ITEM = 8
Object.SOLID_NO = 16
Object.SOLID_GRENADE = 32

-- what you are.  used as a reference for others.
Object.solidFlags = Object.SOLID_YES	-- have 'yes'-flags react to you

-- what you can touch.  
-- if your touch flag matches their solid flag (or vice versa) 
-- then both yours and their touch functions will trigger,
-- in order according to each of your touchPriority
Object.touchFlags = -1					-- call touch for everything

-- what blocks you
-- notice if you want something's block to pass thru then have your touch function to return true 
Object.blockFlags = Object.SOLID_WORLD + Object.SOLID_YES

local collisionEpsilon = 1e-4

local function testBox(self, bxmin, bymin, bxmax, bymax, dt, dx, dy)
	local side

--print('  ====================')
--print('  == BEGIN BOX TEST ==')
--print('  ====================')
--print('testing bbox',box2(bxmin,bymin,bxmax,bymax))	

	-- see if we're touching at our current time
	if self.pos[1]+self.bbox.min[1] < bxmax
	and self.pos[1]+self.bbox.max[1] > bxmin
	and self.pos[2]+self.bbox.min[2] < bymax
	and self.pos[2]+self.bbox.max[2] > bymin
	then
		dt = 0
		-- side is the smallest penetrating side
		local depthXMin = bxmax - self.pos[1] - self.bbox.min[1]
		local depthXMax = self.pos[1] + self.bbox.max[1] - bxmin
		local depthYMin = bymax - self.pos[2] - self.bbox.min[2]
		local depthYMax = self.pos[2] + self.bbox.max[2] - bymin
		local sideX, depthX
		if depthXMin > depthXMax then
			sideX = 'Left'
			depthX = depthXMin
		else
			sideX = 'Right'
			depthX = depthXMax
		end
		local sideY, depthY
		if depthYMin > depthYMax then
			sideY = 'Down'
			depthY = depthYMin
		else
			sideY = 'Up'
			depthY = depthYMax
		end
		-- TODO push back as well?
		if depthX > depthY then
			side = sideX
		else
			side = sideY
		end
--print('stuck with box:',box2(bxmin,bymin,bxmax,bymax))
	else
	
		-- not yet touching, see if our step is touching
		local dtx = dt	-- time to x collision
		local sideX
		if dx > 0 then
--print('dtx',dtx,' > 0 so testing right side')
			--self.pos[1] + self.bbox.max[1] + dtx*dx = bxmin 
			dtx = (bxmin - self.pos[1] - self.bbox.max[1]) / dx
			sideX = 'Right'
		elseif dx < 0 then
--print('dtx',dtx,' < 0 so testing left side')
			--self.pos[1] + self.bbox.min[1] + dtx*dx = bxmax 
			dtx = (bxmax - self.pos[1] - self.bbox.min[1]) / dx
			sideX = 'Left'
		end
		if dtx then
			if math.abs(dtx) < collisionEpsilon then dtx = 0 end
--print('found x movement collision',dtx)
			-- if, at that time, we will not be colliding on the other axis, then clear it
			-- because a clear dtx means a full step
--print('blocking y axis info:',tolua({dy = dy,dtx = dtx,self_ymin = self.pos[2] + self.bbox.min[2] + dtx * dy,self_ymax = self.pos[2] + self.bbox.max[2] + dtx * dy,box_ymin = bymin,box_ymax = bymax},{indent=true}))
			-- use < > instead of <= >= to let objects slide across the sides of others
			if not (self.pos[2] + self.bbox.min[2] + dtx * dy < bymax 
			and self.pos[2] + self.bbox.max[2] + dtx * dy > bymin)
			then
--print('recalled x movement collision -- not being blocked on y axis')
				sideX = nil
				dtx = dt 
			else

			end
		end

		local dty = dt	-- time to y collision
		local sideY
		if dy > 0 then
--print('dty',dty,' > 0 so testing up side')
			--self.pos[2] + self.bbox.max[2] + dty*dy = bymin 
			dty = (bymin - self.pos[2] - self.bbox.max[2]) / dy
			sideY = 'Up'
		elseif dy < 0 then
--print('dty',dty,' < 0 so testing down side')
			--self.pos[2] + self.bbox.min[2] + dty*dy = bymax 
			dty = (bymax - self.pos[2] - self.bbox.min[2]) / dy
			sideY = 'Down'
		end
		if dty then
			if math.abs(dty) < collisionEpsilon then dty = 0 end
--print('found y movement collision',dty)			
--print('blocking x axis info:',tolua({dx = dx,dty = dty,self_xmin = self.pos[1] + self.bbox.min[1] + dty * dx,self_xmax = self.pos[1] + self.bbox.max[1] + dty * dx,box_xmin = bxmin, box_xmax = bxmax},{indent=true}))
			if not (self.pos[1] + self.bbox.min[1] + dty * dx < bxmax
			and self.pos[1] + self.bbox.max[1] + dty * dx > bxmin)
			then
--print('recalled y movement collision - not being blocked on x axis')					
				dty = dt
				sideY = nil
			end
		end

		-- if our collision will happen in positive time then find when that is 
--print('checking x collision time',dtx,'to current step time',dt)			
		if 0 <= dtx and dtx < dt then
--print('found it is better - using it')				
			dt = dtx
			side = sideX
		end
--print('checking y collision time',dty,'to current step time',dt)
		if 0 <= dty and dty < dt then
--print('found it is better - using it')
			dt = dty
			side = sideY
		end
--print('possible collision on side',side,'dt',dt,'tile',touchedTile,'obj',touchedObj)
	end
--print('  ==================')
--print('  == END BOX TEST ==')
--print('  ==================')
	return side, dt
end


function Object:move(dx,dy)
	
	-- make sure you can't hit an object twice in the same movement
	-- TODO less allocations here. right now i'm making a vec2 every time I look up tilesTested
	local objsTested
	local tilesTested

--print()
--print('================')
--print('== BEGIN MOVE ==')
--print('================')

	local level = game.level
--print('dx,dy before epsilon test:',vec2(dx,dy))
	if math.abs(dx) < collisionEpsilon then dx = 0 end
	if math.abs(dy) < collisionEpsilon then dy = 0 end
--print('dx,dy after epsilon test:',vec2(dx,dy))

	local t = 0
	local dt = 1
	-- assume self.pos is the position at time 't'
	-- if we're not letting passthru objects then up to 2 tries
	--for tries=1,2 do	-- up to 2 tries before all axii are blocked completely
	-- if we are then ... infinite ...
	local maxTries = 10
	for tries=1,maxTries+1 do
		if tries == maxTries+1 then
			print("too many collision tries")
		end
--print(' =================')
--print(' == BEGIN TRACE ==')
--print(' =================')
--print('obj pos',self.pos,'box',self.bbox+self.pos,'moving',vec2(dx,dy))
		
		local side
		local touchedObj
		local touchedTile
		local touchedTileX, touchedTileY
		
		-- get combined bbox of current bbox and destination bbox
		local cxmin = self.pos[1] + self.bbox.min[1] + math.min(dt * dx,0)
		local cymin = self.pos[2] + self.bbox.min[2] + math.min(dt * dy,0)
		local cxmax = self.pos[1] + self.bbox.max[1] + math.max(dt * dx,0)
		local cymax = self.pos[2] + self.bbox.max[2] + math.max(dt * dy,0)
--print('testing entire bbox',box2(cxmin,cymin,cxmax,cymax)) 
		
		-- if we can collide with the world
		-- I'm not checking touchFlags because allowing touching non-blocking tiles 
		--  would mean rechecking tiles with certain tiles (previously checked, touched, and non-blocked) excluded
		-- which I don't have support for, nor see a use for
		-- I'm thinking of getting rid of touchTile and tile.touch anyways.
		if bit.band(self.blockFlags, Object.SOLID_WORLD) ~= 0 then
			-- test world
			local xmin = math.floor(cxmin)-1
			local ymin = math.floor(cymin)-1
			local xmax = math.floor(cxmax)+1
			local ymax = math.floor(cymax)+1
--print('testing tile bounds',box2(xmin,ymin,xmax,ymax))
			-- test oob
			if xmax < 1 or ymax < 1 or xmin > level.size[1] or ymin > level.size[2] then
--print('movement off the tile map')
			else
				-- clamp size
				if xmin < 1 then xmin = 1 end
				if xmax > level.size[1] then xmax = level.size[1] end
				if ymin < 1 then ymin = 1 end
				if ymax > level.size[2] then ymax = level.size[2] end
--print('clamped tile bounds to',box2(xmin,ymin,xmax,ymax))			
				for y=ymin,ymax do
					for x=xmin,xmax do
						local tile = level:getTile(x,y)
						if tile
						and tile.solid
						and (not tilesTested or not table.find(tilesTested, vec2(x,y)))
						then
							local newSide
							newSide, dt = testBox(self, x,y,x+1,y+1, dt, dx, dy)
							if newSide then
								side = newSide
								touchedObj = obj
								touchedTile = tile
								touchedTileX = x
								touchedTileY = y
							end
						end
					end
				end
			end
		end

		-- test objs
		for _,obj in ipairs(game.objs) do
			-- don't collide self with self
			if obj ~= self 
			-- only collide objects touching the combined bbox
			and cxmin <= obj.pos[1] + obj.bbox.max[1]
			and cxmax >= obj.pos[1] + obj.bbox.min[1]
			and cymin <= obj.pos[2] + obj.bbox.max[2]
			and cymax >= obj.pos[2] + obj.bbox.min[2]
			-- only collide if we will can touch or be blocked by them
			and (bit.band(self.touchFlags, obj.solidFlags) ~= 0
				or bit.band(obj.touchFlags, self.solidFlags) ~= 0
				or bit.band(self.blockFlags, obj.solidFlags) ~= 0
				or bit.band(obj.blockFlags, self.solidFlags) ~= 0
			)
			-- don't check objects twice
			and (not objsTested or not table.find(objsTested, obj))
			then
				local newSide
				newSide, dt = testBox(self, obj.pos[1]+obj.bbox.min[1], obj.pos[2]+obj.bbox.min[2], obj.pos[1]+obj.bbox.max[1], obj.pos[2]+obj.bbox.max[2], dt, dx, dy)
				if newSide then
					side = newSide
					touchedObj = obj
					touchedTile = nil
					touchedTileX = nil
					touchedTileY = nil
				end
			end
		end

		if math.abs(dt) < collisionEpsilon then dt = 0 end
		assert(dt >= 0)

		-- move up to the point of collision
--print('starttime is t=',t)
--print('stepping by timestep dt=',dt)
		t = t + dt
		self.pos[1] = self.pos[1] + dt * dx
		self.pos[2] = self.pos[2] + dt * dy

		if t < 1 then
			dt = 1 - t
			if math.abs(dt) < collisionEpsilon then 
				t = 1
				dt = 0 
			end
		end

		-- are these two exclusive?
		-- so long as I'm using newDT < dt tests to register new collisions, they should be
		assert(t == 1 or side)

--print('collided on side',side)
		if side then
			local lside = side:lower()
			local normal = dirs[oppositeSide[lside]]
			assert(normal, "got side set without normal")

			-- don't check this object again
			-- that way if it can be passed through
			-- then the next traceline won't check it
			if touchedObj then
--print('adding obj',touchedObj,'to the already-checked list')				
				if not objsTested then objsTested = {} end
				table.insert(objsTested, touchedObj)
			end
			if touchedTile then
				if not tilesTested then tilesTested = {} end
				table.insert(tilesTested, vec2(touchedTileX,touchedTileY))
			end

			-- run 'touch' after velocity clipping
			-- pass collision velocity as a separate parameter?
			local dontblock
			if touchedTile then
--print('calling self.touchTile_v2',self.touchTile_v2,touchedTile,lside,plane)
				local plane = nil	-- TODO for sloped tiles
				if self.touchTile_v2 then dontblock = self:touchTile_v2(touchedTile, lside, normal) or dontblock end
			end
			
--print('touchedObj is',touchedObj)			
			if touchedObj then
--print('checking self.touchFlags',self.touchFlags,'vs touchedObj.solidFlags',touchedObj.solidFlags)
				if bit.band(self.touchFlags, touchedObj.solidFlags) ~= 0 
				or bit.band(touchedObj.touchFlags, self.solidFlags) ~= 0
				then
--print('running touches based on priority. self.touchPriority=',self.touchPriority,'touchedObj.touchPriority=',touchedObj.touchPriority)					
					local opposite = oppositeSide[lside] or error("can't find opposite side for side "..tostring(side))
					if self.touchPriority >= touchedObj.touchPriority then
						if self.touch_v2 then dontblock = self:touch_v2(touchedObj, lside) or dontblock end
						if touchedObj.touch_v2 then dontblock = touchedObj:touch_v2(self, opposite) or dontblock end
					else
						if touchedObj.touch_v2 then dontblock = touchedObj:touch_v2(self, opposite) or dontblock end
						if self.touch_v2 then dontblock = self:touch_v2(touchedObj, lside) or dontblock end
					end
--print('after calling touch, dontblock=',dontblock)				
				end
			end
			
			-- flags of who we're touching.  or WORLD if we're touching the world.
			local touchedSolidFlags = touchedObj and touchedObj.solidFlags or Object.SOLID_WORLD
			local touchedBlockFlags = touchedObj and touchedObj.blockFlags or 0
--print('checking self.blockFlags=',self.blockFlags,' vs touchedSolidFlags=',touchedSolidFlags,' and not dontblock=',dontblock)
			-- if the touch didn't override the blocking
			if not dontblock
			-- if we're supposed to be blocked by this entity
			and (bit.band(self.blockFlags, touchedSolidFlags) ~= 0
			or bit.band(touchedBlockFlags, self.solidFlags) ~= 0)
			then
				-- TODO push objects out of the way
--print('setting collision flags for side',side,'for obj',touchedObj)
				self['collided'..side] = true
				self['touchEnt'..side] = touchedObj

				-- clip velocity and movement on the collided axis and try again
--print('zeroing velocity against normal',normal)
				local vDotN = self.vel:dot(normal)
				if vDotN < 0 then
					self.vel[1] = self.vel[1] - normal[1] * vDotN
					self.vel[2] = self.vel[2] - normal[2] * vDotN
				end
				
				local deltaDotN = dx * normal[1] + dy * normal[2]
				if deltaDotN < 0 then
					dx = dx - normal[1] * deltaDotN
					dy = dy - normal[2] * deltaDotN
				end
			end
		end

--print(' ===============')
--print(' == END TRACE ==')
--print(' ===============')

		if t == 1 then
--print('completely whole timestep -- breaking')
			break
		end
		if dx == 0 and dy == 0 then
--print('movement stuck -- breaking')
			break
		end
	end

	-- TODO onground = collidedDown only if collision was with a solid object
	self.onground = self.collidedDown
--print('onground',self.onground)

--print('==============')
--print('== END MOVE ==')
--print('==============')
end



-- default pretouch routine: player precedence
Object.pretouch = nil -- function(other, side)

-- new system
Object.touch_v2 = nil -- function(other, side) 

function Object:draw(R, viewBBox, holdOverride)
	if not self.sprite then return end
	
	-- heldby means re-rendering the obj to keep it in frame sync with the player	
	if self.heldby and not holdOverride then return end
	
	local tex
	if self.tex then
		tex = self.tex
	elseif self.sprite then
		tex = animsys:getTex(self.sprite, self.seq or 'stand', self.seqStartTime)
	end
	if tex then tex:bind() end
	local cr,cg,cb,ca
	if self.color then
		cr,cg,cb,ca = unpack(self.color)
	else
		cr,cg,cb,ca = 1,1,1,1
	end

	local uBias, uScale
	if self.drawMirror then
		uBias, uScale = 1, -1
	else
		uBias, uScale = 0, 1
	end
	
	local vBias, vScale
	if self.drawFlipped then
		vBias, vScale = 0,1
	else
		vBias, vScale = 1, -1
	end

	local sx, sy = 1, 1
	if tex then
		sx = tex.width/16
		sy = tex.height/16
	end
	if self.drawScale then
		sx, sy = table.unpack(self.drawScale)
	end

	-- rotation center
	local rcx, rcy = 0, 0
	if self.rotCenter then
		rcx, rcy = self.rotCenter[1], self.rotCenter[2]
		if self.drawMirror then
			rcx = 1 - rcx
		end
		rcx = rcx * sx
		rcy = rcy * sy
	end

	R:quad(
		self.pos[1]-sx*.5,
		self.pos[2],
		sx, sy,
		uBias, vBias,
		uScale, vScale,
		self.angle,
		cr,cg,cb,ca,
		self.shader,
		self.uniforms,
		rcx, rcy)
end

--[[
function Object:drawHUD(R, viewBBox)
if #debugDraw > 0 then
	local gl = R.gl
	gl.glDisable(gl.GL_TEXTURE_2D)
	gl.glBegin(gl.GL_QUADS)
	for _,info in ipairs(debugDraw) do
		gl.glColor3f(table.unpack(info.color))
		gl.glVertex2f(info.pos[1], info.pos[2])
		gl.glVertex2f(info.pos[1]+1, info.pos[2])
		gl.glVertex2f(info.pos[1]+1, info.pos[2]+1)
		gl.glVertex2f(info.pos[1], info.pos[2]+1)
	end
	gl.glEnd()
	gl.glEnable(gl.GL_TEXTURE_2D)
	debugDraw = table()
end
end
--]]

local sounds = require 'base.script.singleton.sounds'

function Object:playSound(name)	
	-- clientside ...
	local source = game:getNextAudioSource()
	if source then
		local sound = sounds:load(name..'.wav')
		source:setBuffer(sound)
		
		-- openal supports only one listener
		-- rather than reposition the listener according to what player is closest ... position the sound!
		-- and don't bother with listener velocity
		local closestPlayer, closestDistSq
		-- TODO only cycle through local connections
		for _,player in ipairs(game.players) do
			local dx, dy = player.pos[1] - self.pos[1], player.pos[2] - self.pos[2]
			local distSq = dx * dx + dy * dy
			if not closestDistSq or closestDistSq > distSq then
				closestDistSq = distSq
				closestPlayer = player
			end
		end
		if closestDistSq < game.maxAudioDist * game.maxAudioDist then
			source:setPosition(self.pos[1] - closestPlayer.pos[1], self.pos[2] - closestPlayer.pos[2], 0)
			source:setVelocity(self.vel[1], self.vel[2], 0)
			source:play()
		end
	else
		print('all audio sources used')
	end
end

return Object
