local ffi = require 'ffi'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'
local game = require 'base.script.singleton.game'
local animsys = require 'base.script.singleton.animsys'

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

	-- [[ without ffi
	self.pos = vec2()
	self.lastpos = vec2()
	self.vel = vec2()
	--]]
	--[[ with ffi, but without losing indexing
	self.pos = ffi.new('float[3]', 0,0,0)
	self.lastpos = ffi.new('float[3]', 0,0,0)
	self.vel = ffi.new('float[3]', 0,0,0)
	--]]
	
	self.bbox = box2(self.bbox.min[1], self.bbox.min[2], self.bbox.max[1], self.bbox.max[2])

	self.tiles = {}
	
	if args.pos then self.pos[1], self.pos[2] = args.pos[1], args.pos[2] end
	if args.vel then self.vel[1], self.vel[2] = args.vel[1], args.vel[2] end
	
	game:addObject(self)	-- only do this once per object.  don't reuse, or change the uid system
	
	-- in case anyone wants the tile info.
	self:link()
end

function Object:unlink()
	local numtiles = #self.tiles
	for i=1,numtiles do
		local tile = self.tiles[i]
		if tile.objs then
			assert(tile.objs:removeObject(self))
			if #tile.objs == 0 then
				tile.objs = nil
			end
		end
		-- clear as we go. safe because #self.tiles is stored upon iteration init		
		self.tiles[i] = nil
	end
end

function Object:link()
	local level = game.level
	local minx = self.pos[1] + self.bbox.min[1] - level.pos[1]
	local miny = self.pos[2] + self.bbox.min[2] - level.pos[2]
	local maxx = self.pos[1] + self.bbox.max[1] - level.pos[1]
	local maxy = self.pos[2] + self.bbox.max[2] - level.pos[2]
	local numtiles = 0
	
	for x=math.floor(minx),math.floor(maxx) do
		local levelcol = level.tile[x]
		if levelcol then
			for y=math.floor(miny),math.floor(maxy) do
				local tile = levelcol[y]
				if tile then
					if not tile.objs then
						tile.objs = table()
					end
					tile.objs:insertUnique(self)
					numtiles = numtiles + 1
					self.tiles[numtiles] = tile
				end		
			end
		end
	end
end

function Object:update(dt)

	self.lastpos[1], self.lastpos[2] = self.pos[1], self.pos[2]

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
	if tile and tile.fluid and #tile.fluid > 0 then
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
	self:unlink()
	self.pos[1], self.pos[2] = x,y
	self:link()
end

function Object:moveToPos(x,y)
	self:move(x - self.pos[1], y - self.pos[2])
end

function Object:move(moveX, moveY)
	local level = game.level
	local epsilon = .0001
	
	self:unlink()
	
	self.pos[2] = self.pos[2] + moveY

	-- falling down
	if moveY < 0 then
		local y = math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2])
		
		for x = math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1]), math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1]) do
			local tile = level:getTile(x,y)
			if tile then
				if self.collidesWithWorld and tile.solid then
					local collides
					if tile.planes and #tile.planes > 0 and tile.planes[1][2] > 0 then
						local plane = tile.planes[1]
						local cx
						if plane[1] > 0 then
							cx = self.pos[1] + self.bbox.min[1] - (tile.pos[1] + level.pos[1])
						else
							cx = self.pos[1] + self.bbox.max[1] - (tile.pos[1] + level.pos[1])
						end
						if cx >= 0 and cx <= 1 then
							local cy = -(cx * plane[1] + plane[3]) / plane[2]
							self.pos[2] = (cy + tile.pos[2] + level.pos[2]) - self.bbox.min[2] + epsilon
							collides = true
						end
					else
						-- TODO push precedence
						local oymax = y + 1 + level.pos[2]
						self.pos[2] = oymax - self.bbox.min[2] + epsilon
						collides = true
					end
					if collides then
						self.vel[2] = 0
						self.collidedDown = true
						self.onground = true
						if self.touchTile then self:touchTile(tile, 'down') end
						if tile.touch then tile:touch(self) end
					end
				end
				
				if self.collidesWithObjects then
					if tile.objs then
						for _,obj in ipairs(tile.objs) do
							if obj.collidesWithObjects then
								if self.pos[1] + self.bbox.min[1] <= obj.pos[1] + obj.bbox.max[1]
								and self.pos[1] + self.bbox.max[1] >= obj.pos[1] + obj.bbox.min[1]
								and self.pos[2] + self.bbox.min[2] <= obj.pos[2] + obj.bbox.max[2]
								and self.pos[2] + self.bbox.max[2] >= obj.pos[2] + obj.bbox.min[2]
								then
									-- run a pretouch routine that has the option to prevent further collision
									local donttouch
									if self.preTouchPriority >= obj.preTouchPriority then
										donttouch = self:pretouch(obj, 'down') or donttouch
										donttouch = obj:pretouch(self, 'up') or donttouch
									else
										donttouch = obj:pretouch(self, 'up') or donttouch
										donttouch = self:pretouch(obj, 'down') or donttouch
									end

									if not donttouch then
										if self.solid and obj.solid then
											
											if self.pushPriority >= obj.pushPriority then
												obj:move(
													0,
													self.pos[2] + self.bbox.min[2] - obj.bbox.max[2] - epsilon - obj.pos[2]
												)
											end

											self.vel[2] = obj.vel[2]
											self.pos[2] = obj.pos[2] + obj.bbox.max[2] - self.bbox.min[2] + epsilon
											
											self.onground = true	-- 'onground' is different from 'collidedDown' in that 'onground' means we're on something solid
										end
										self.collidedDown = true
										self.touchEntDown = obj
										
										-- run post touch after any possible push
										if self.touchPriority >= obj.touchPriority then
											if self.touch then self:touch(obj, 'down') end
											if obj.touch then obj:touch(self, 'up') end
										else
											if obj.touch then obj:touch(self, 'up') end
											if self.touch then self:touch(obj, 'down') end
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
	
	-- jumping up
	if moveY > 0 then
		local y = math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2])
		
		for x = math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1]), math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1]) do
			local tile = level:getTile(x,y)
			if tile then
				if self.collidesWithWorld and tile.solid then
					local collides
					if tile.planes and #tile.planes > 0 and tile.planes[1][2] < 0 then
						local plane = tile.planes[1]
						local cx
						if plane[1] > 0 then
							cx = self.pos[1] + self.bbox.min[1] - (tile.pos[1] + level.pos[1])
						else
							cx = self.pos[1] + self.bbox.max[1] - (tile.pos[1] + level.pos[1])
						end
						if cx >= 0 and cx <= 1 then
							local cy = -(cx * plane[1] + plane[3]) / plane[2]
							self.pos[2] = (cy + tile.pos[2] + level.pos[2]) - self.bbox.max[2] - epsilon
							collides = true
						end
					else
						local oymin = y + level.pos[2]
						self.pos[2] = oymin - self.bbox.max[2] - epsilon
						collides = true
					end
					if collides then
						self.vel[2] = 0
						self.collidedUp = true
						if self.touchTile then self:touchTile(tile, 'up') end
						if tile.touch then tile:touch(self) end
					end
				end
				
				if self.collidesWithObjects then
					if tile.objs then
						for _,obj in ipairs(tile.objs) do
							if obj.collidesWithObjects then
								if self.pos[1] + self.bbox.min[1] <= obj.pos[1] + obj.bbox.max[1]
								and self.pos[1] + self.bbox.max[1] >= obj.pos[1] + obj.bbox.min[1]
								and self.pos[2] + self.bbox.min[2] <= obj.pos[2] + obj.bbox.max[2]
								and self.pos[2] + self.bbox.max[2] >= obj.pos[2] + obj.bbox.min[2]
								then
									local donttouch
									if self.preTouchPriority >= obj.preTouchPriority then
										donttouch = self:pretouch(obj, 'up') or donttouch
										donttouch = obj:pretouch(self, 'down') or donttouch
									else
										donttouch = obj:pretouch(self, 'down') or donttouch
										donttouch = self:pretouch(obj, 'up') or donttouch
									end

									if not donttouch then
										if self.solid and obj.solid then
										
											if self.pushPriority >= obj.pushPriority then
												obj:move(
													0,
													self.pos[2] + self.bbox.max[2] - obj.bbox.min[2] + epsilon - obj.pos[2]
												)
											end

											self.vel[2] = obj.vel[2]
											self.pos[2] = obj.pos[2] + obj.bbox.min[2] - self.bbox.max[2] - epsilon
										end
										self.collidedUp = true
										self.touchEntUp = obj
										if self.touchPriority >= obj.touchPriority then
											if self.touch then self:touch(obj, 'up') end
											if obj.touch then obj:touch(self, 'down') end
										else
											if obj.touch then obj:touch(self, 'down') end
											if self.touch then self:touch(obj, 'up') end
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

	-- left
	if moveX < 0 then
		local x = math.floor(self.pos[1] + self.bbox.min[1] - level.pos[1])
		
		for y = math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2]), math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2]) do
			local tile = level:getTile(x,y)
			if tile then
				if self.collidesWithWorld and tile.solid then
					local collides
					if tile.planes and #tile.planes > 0 then
						local plane = tile.planes[1]
						if plane[2] > 0 then
							local cx
							if plane[1] > 0 then
								cx = self.pos[1] + self.bbox.min[1] - (tile.pos[1] + level.pos[1])
							else
								cx = self.pos[1] + self.bbox.max[1] - (tile.pos[1] + level.pos[1])
							end
							if cx >= 0 and cx <= 1 then
								local cy = -(cx * plane[1] + plane[3]) / plane[2]
								self.pos[2] = (cy + tile.pos[2] + level.pos[2]) - self.bbox.min[2] + epsilon
								self.vel[2] = 0
								self.collidedDown = true
								self.onground = true
								if self.touchTile then self:touchTile(tile, 'down') end
								if tile.touch then tile:touch(self) end
							end
						end
					--[[
						if plane[1] > 0 then
							local cy
							if plane[2] > 0 then
								cy = self.pos[2] + self.bbox.min[2] - (tile.pos[2] + level.pos[2])
							else
								cy = self.pos[2] + self.bbox.max[2] - (tile.pos[2] + level.pos[2])
							end
							if cy >= 0 and cy <= 1 then
								local cx = -(cy * plane[2] + plane[3]) / plane[1]
								self.pos[1] = (cx + tile.pos[1] + level.pos[1]) - self.bbox.min[2] + epsilon
								collides = true
							end
						end
					--]]
					else
						local oxmax = x + 1 + level.pos[1]
						self.pos[1] = oxmax - self.bbox.min[1] + epsilon
						self.vel[1] = 0
						self.collidedLeft = true
						if self.touchTile then self:touchTile(tile, 'left') end
						if tile.touch then tile:touch(self) end
					end
				end
				
				if self.collidesWithObjects then
					if tile.objs then
						for _,obj in ipairs(tile.objs) do
							if obj.collidesWithObjects then
								if self.pos[1] + self.bbox.min[1] <= obj.pos[1] + obj.bbox.max[1]
								and self.pos[1] + self.bbox.max[1] >= obj.pos[1] + obj.bbox.min[1]
								and self.pos[2] + self.bbox.min[2] <= obj.pos[2] + obj.bbox.max[2]
								and self.pos[2] + self.bbox.max[2] >= obj.pos[2] + obj.bbox.min[2]
								then
									local donttouch
									if self.preTouchPriority >= obj.preTouchPriority then
										donttouch = self:pretouch(obj, 'left') or donttouch
										donttouch = obj:pretouch(self, 'right') or donttouch
									else
										donttouch = obj:pretouch(self, 'right') or donttouch
										donttouch = self:pretouch(obj, 'left') or donttouch
									end

									if not donttouch then
										if self.solid and obj.solid then

											if self.pushPriority >= obj.pushPriority then
												obj:move(
													self.pos[1] + self.bbox.min[1] - obj.bbox.max[1] - epsilon - obj.pos[1],
													0
												)
											end

											self.vel[1] = obj.vel[1]
											self.pos[1] = obj.pos[1] + obj.bbox.max[1] - self.bbox.min[1] + epsilon
										end
										self.collidedLeft = true
										self.touchEntLeft = obj
										if self.touchPriority >= obj.touchPriority then
											if self.touch then self:touch(obj, 'left') end
											if obj.touch then obj:touch(self, 'right') end
										else
											if obj.touch then obj:touch(self, 'right') end
											if self.touch then self:touch(obj, 'left') end
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

	-- right
	if moveX > 0 then
		local x = math.floor(self.pos[1] + self.bbox.max[1] - level.pos[1])
		
		for y = math.floor(self.pos[2] + self.bbox.min[2] - level.pos[2]), math.floor(self.pos[2] + self.bbox.max[2] - level.pos[2]) do
			local tile = level:getTile(x,y)
			if tile then
				if self.collidesWithWorld and tile.solid then
					local collides
					if tile.planes and #tile.planes > 0 then
						local plane = tile.planes[1]
						if plane[2] > 0 then
							local cx
							if plane[1] > 0 then
								cx = self.pos[1] + self.bbox.min[1] - (tile.pos[1] + level.pos[1])
							else
								cx = self.pos[1] + self.bbox.max[1] - (tile.pos[1] + level.pos[1])
							end
							if cx >= 0 and cx <= 1 then
								local cy = -(cx * plane[1] + plane[3]) / plane[2]
								self.pos[2] = (cy + tile.pos[2] + level.pos[2]) - self.bbox.min[2] + epsilon
								self.vel[2] = 0
								self.collidedDown = true
								self.onground = true
								if self.touchTile then self:touchTile(tile, 'down') end
								if tile.touch then tile:touch(self) end
							end
						end
					--[[
						if plane[1] < 0 then
							local cy
							if plane[2] > 0 then
								cy = self.pos[2] + self.bbox.min[2] - (tile.pos[2] + level.pos[2])
							else
								cy = self.pos[2] + self.bbox.max[2] - (tile.pos[2] + level.pos[2])
							end
							if cy >= 0 and cy <= 1 then
								local cx = -(cy * plane[2] + plane[3]) / plane[1]
								self.pos[1] = (cx + tile.pos[1] + level.pos[1]) - self.bbox.max[2] - epsilon
								collides = true
							end
						end
					--]]
					else
						local oxmin = x + level.pos[1]
						self.pos[1] = oxmin - self.bbox.max[1] - epsilon
						self.vel[1] = 0
						self.collidedRight = true
						if self.touchTile then self:touchTile(tile, 'right') end
						if tile.touch then tile:touch(self) end
					end
				end
				
				if self.collidesWithObjects then
					if tile.objs then
						for _,obj in ipairs(tile.objs) do
							if obj.collidesWithObjects then
								if self.pos[1] + self.bbox.min[1] <= obj.pos[1] + obj.bbox.max[1]
								and self.pos[1] + self.bbox.max[1] >= obj.pos[1] + obj.bbox.min[1]
								and self.pos[2] + self.bbox.min[2] <= obj.pos[2] + obj.bbox.max[2]
								and self.pos[2] + self.bbox.max[2] >= obj.pos[2] + obj.bbox.min[2]
								then
									local donttouch
									if self.preTouchPriority >= obj.preTouchPriority then
										donttouch = self:pretouch(obj, 'right') or donttouch
										donttouch = obj:pretouch(self, 'left') or donttouch
									else
										donttouch = obj:pretouch(self, 'left') or donttouch
										donttouch = self:pretouch(obj, 'right') or donttouch
									end

									if not donttouch then
										if self.solid and obj.solid then
										
											if self.pushPriority >= obj.pushPriority then
												obj:move(
													self.pos[1] + self.bbox.max[1] - obj.bbox.min[1] + epsilon - obj.pos[1],
													0
												)
											end

											self.vel[1] = obj.vel[1]
											self.pos[1] = obj.pos[1] + obj.bbox.min[1] - self.bbox.max[1] - epsilon
										end
										self.collidedRight = true
										self.touchEntRight = obj
										if self.touchPriority >= obj.touchPriority then
											if self.touch then self:touch(obj, 'right') end
											if obj.touch then obj:touch(self, 'left') end
										else
											if obj.touch then obj:touch(self, 'left') end
											if self.touch then self:touch(obj, 'right') end
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

	self:link()
end

-- default pretouch routine: player precedence
function Object:pretouch(other, side)
	-- kick ignore 
	if other == self.kickedBy and self.kickHandicapTime >= game.time then
		return true
	end
end

--[[
give the kicker a temp non-collide window
--]]
function Object:hasBeenKicked(other)
	self.kickedBy = other
	self.kickHandicapTime = game.time + .5
end

--[[
kick an object from carrying it
other: who is kicking
dx: their intended left/right kick direction
dy: their intended up/down kick direction
--]]
function Object:playerKick(other, dx, dy)
	local holderLookDir = 0
	if other.drawMirror then
		holderLookDir = -1
	else
		holderLookDir = 1
	end
	if dy > 0 then	-- kick up
		self.vel[2] = self.vel[2] + 40
	elseif dy >= 0 and dx ~= 0	then	-- kicking and not setting down
		self.vel[2] = self.vel[2] + 6
		self.vel[1] = self.vel[1] + holderLookDir * 10
	else	-- setting down
		self.vel[2] = self.vel[2] + 4
		self.vel[1] = self.vel[1] + holderLookDir * 4
	end
	
	self:hasBeenKicked(other)
end

function Object:draw(R, viewBBox, holdOverride)
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

	-- rotation center
	local rcx, rcy = 0, 0
	if self.rotCenter then
		rcx, rcy = self.rotCenter[1], self.rotCenter[2]
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
