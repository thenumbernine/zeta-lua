local ffi = require 'ffi'
local class = require 'ext.class'
local game = require 'base.script.singleton.game'
local animsys = require 'base.script.singleton.animsys'

local FluidParticle = class()
FluidParticle.sprite = 'water'
FluidParticle.seq = 'stand'

function FluidParticle:init(args)
	-- [[ without ffi
	self.pos = vec2(args.pos[1], args.pos[2])
	self.lastPos = vec2(self.pos[1], self.pos[2])
	self.vel = vec2()
	--]]
	--[[ with ffi, keeping indexing
	self.pos = ffi.new('float[3]', 0, args.pos[1], args.pos[2])
	self.lastPos = ffi.new('float[3]', 0, args.pos[1], args.pos[2])
	self.vel = ffi.new('float[3]', 0, 0, 0)
	--]]

	game.fluid:insert(self)
	self:link()
end

function FluidParticle:link()
	local tile = game.level:getTile(self.pos[1], self.pos[2])
	if tile then
		if not tile.fluid then
			tile.fluid = table()
		end
		tile.fluid:insertUnique(self)
		self.tile = tile
	end
end

function FluidParticle:unlink()
	local tile = self.tile
	if tile then
		if tile.fluid then	--assert(tile.fluid)
			tile.fluid:removeObject(self)
			if #tile.fluid == 0 then
				tile.fluid = nil
			end
		end
	end
end

--[[
another source (with fortran sample code):
http://books.google.com/books?id=_cwFMmEQvZQC&pg=PA365&lpg=PA365&dq=sph+code&source=bl&ots=QBBIxmZ-2S&sig=7y-EDCLfIBtRoEW5iek5FrkMzN0&hl=en&sa=X&ei=xmoqT9y2A8TmiALV_rWjCg&ved=0CF0Q6AEwCTgK#v=onepage&q&f=false
--]]


-- computed values
FluidParticle.density = 0		-- kernel of mass
FluidParticle.pressure = 0		-- computed from density
FluidParticle.pressureForceX = 0		-- gradient of kernel of pressure
FluidParticle.pressureForceY = 0		-- gradient of kernel of pressure
FluidParticle.viscousForceX = 0
FluidParticle.viscousForceY = 0

-- fluid constants
FluidParticle.radius = .5		-- 'h' radius of influence of the particle
FluidParticle.mass = 1			-- mass per particle
FluidParticle.gasPressureConstant = .01
FluidParticle.restPressure = 1
FluidParticle.restDensity = 1
FluidParticle.viscosity = .001

function FluidParticle:update(dt)
	local level = game.level
	
	self:unlink()
	
--[===[ sph ...
	do
		local virtualParticleWallRes = 5
		local wallParticleMass = 1
		local wallParticleDensity = 1
		local wallPressure = 10
	
		local wallEpsilon = .1
		local wallPushEpsilon = .1
		
		local searchRadius = 1
		
		local centerIX = math.floor(self.pos[1])
		local centerIY = math.floor(self.pos[2])
		local xmin = centerIX - searchRadius
		local xmax = centerIX + searchRadius
		local ymin = centerIY - searchRadius
		local ymax = centerIY + searchRadius
		if xmin <= level.size[1] and xmax >= 1 and ymin <= level.size[2] and ymax >= 1 then
			if xmin < 1 then xmin = 1 end
			if xmax > level.size[1] then xmax = level.size[1] end
			if ymin < 1 then ymin = 1 end
			if ymax > level.size[2] then ymax = level.size[2] end
			
			-- calculate density from rest density
			self.density = self.mass
			for x=xmin,xmax do
				local tilecol = level.tile[x]
				for y=ymin,ymax do
					tile = tilecol[y]
					if tile.fluid then
						for _,particle in ipairs(tile.fluid) do
							local dx = particle.pos[1] - self.pos[1]
							local dy = particle.pos[2] - self.pos[2]
							local r = math.sqrt(dx * dx + dy * dy)
							if r < self.radius then
								local w = 315 / (64 * math.pi * self.radius^9) * (self.radius^2 - r^2)^3
								self.density = self.density + particle.mass * w
							end
						end
					end
					
					if tile.solid then
						for i=1,virtualParticleWallRes do
							local fi = (i-.5)/virtualParticleWallRes
							for j=1,virtualParticleWallRes do
								local fj = (j-.5)/virtualParticleWallRes
								local dx = (tile.pos[1] + fi) - self.pos[1]
								local dy = (tile.pos[2] + fj) - self.pos[2]
								local r = math.sqrt(dx * dx + dy * dy)
								if r < self.radius then
									local w = 315 / (64 * math.pi * self.radius^9) * (self.radius^2 - r^2)^3
									self.density = self.density + wallParticleMass * w
								end
							end
						end
					end
				end
			end
			self.pressure = self.restPressure + self.gasPressureConstant * (self.density - self.restDensity)
			
			-- calculate pressure and viscous forces
			self.pressureForceX = 0
			self.pressureForceY = 0
			self.viscousForceX = 0
			self.viscousForceY = 0
			for x=xmin,xmax do
				local tilecol = level.tile[x]
				for y=ymin,ymax do
					tile = tilecol[y]
					if tile.fluid then
						for _,particle in ipairs(tile.fluid) do
							local dx = particle.pos[1] - self.pos[1]
							local dy = particle.pos[2] - self.pos[2]
							local r = math.sqrt(dx * dx + dy * dy)
							if r < self.radius then
								self.pressureForceX = self.pressureForceX - particle.mass / particle.density * .5 * (self.pressure + particle.pressure) * 45 / (math.pi * self.radius^6) * (self.radius - r)^3 * dx / r
								self.pressureForceY = self.pressureForceY - particle.mass / particle.density * .5 * (self.pressure + particle.pressure) * 45 / (math.pi * self.radius^6) * (self.radius - r)^3 * dy / r
								
								self.viscousForceX = self.viscousForceX + self.viscosity * particle.mass / particle.density * (particle.vel[1] - self.vel[1]) * 45 / (math.pi * self.radius^6) * (self.radius - r)
								self.viscousForceY = self.viscousForceY + self.viscosity * particle.mass / particle.density * (particle.vel[2] - self.vel[2]) * 45 / (math.pi * self.radius^6) * (self.radius - r) 
							end
						end
					end
					
					-- calculate wall pressure
					if tile.solid then
						for i=1,virtualParticleWallRes do
							local fi = (i-.5)/virtualParticleWallRes
							for j=1,virtualParticleWallRes do
								local fj = (j-.5)/virtualParticleWallRes
								local dx = (tile.pos[1] + fi) - self.pos[1]
								local dy = (tile.pos[2] + fj) - self.pos[2]
								
								local r = math.sqrt(dx * dx + dy * dy)
								if r < self.radius then
									self.pressureForceX = self.pressureForceX - wallParticleMass / wallParticleDensity * .5 * (self.pressure + wallPressure) * 45 / (math.pi * self.radius^6) * (self.radius - r)^3 * dx / r
									self.pressureForceY = self.pressureForceY - wallParticleMass / wallParticleDensity * .5 * (self.pressure + wallPressure) * 45 / (math.pi * self.radius^6) * (self.radius - r)^3 * dy / r
									
									self.viscousForceX = self.viscousForceX + self.viscosity * wallParticleMass / wallParticleDensity * (0 - self.vel[1]) * 45 / (math.pi * self.radius^6) * (self.radius - r)
									self.viscousForceY = self.viscousForceY + self.viscosity * wallParticleMass / wallParticleDensity * (0 - self.vel[2]) * 45 / (math.pi * self.radius^6) * (self.radius - r) 
								end
							end
						end
						
						
						-- [[ keep from going through blocks?
						local dx = self.pos[1] - (tile.pos[1] + .5)
						local dy = self.pos[2] - (tile.pos[2] + .5)
						local adx = math.abs(dx)
						local ady = math.abs(dy)
						local dist = math.max(adx, ady)
						if dist < .5 + wallEpsilon then	-- wall epsilon ...
							if adx > ady then	-- left/right
								if dx > 0 then	-- push right
									self.pos[1] = tile.pos[1] + 1 + wallPushEpsilon
								else			-- push left
									self.pos[1] = tile.pos[1] - wallPushEpsilon
								end
							else
								if dy > 0 then	-- push up
									self.pos[2] = tile.pos[2] + 1 + wallPushEpsilon
								else			-- push down
									self.pos[2] = tile.pos[2] - wallPushEpsilon
								end
							end
						end
						--]]
						
					end
				end
			end
		end
	end
	
	local gravity = -10
	
	-- [[ leapfrog?
	if self.leap then
		self.vel[1] = self.vel[1] + (self.pressureForceX + self.viscousForceX) / self.mass * dt
		self.vel[2] = self.vel[2] + ((self.pressureForceY + self.viscousForceY) / self.mass + gravity) * dt
	else
		self.pos[1] = self.pos[1] + self.vel[1] * dt
		self.pos[2] = self.pos[2] + self.vel[2] * dt
	end
	self.leap = not self.leap
	--]]

	--[[ stomer verlet
	local lastX, lastY = self.lastPos[1], self.lastPos[2]
	self.lastPos[1] = self.pos[1]
	self.lastPos[2] = self.pos[2]
	local velDecay = .9
	self.pos[1] = self.pos[1] + velDecay * (self.pos[1] - lastX) + dt * dt * (self.pressureForceX + self.viscousForceX) / self.mass
	self.pos[2] = self.pos[2] + velDecay * (self.pos[2] - lastY) + dt * dt * ((self.pressureForceY + self.viscousForceY) / self.mass + gravity)
	--]]
	
	--[[ euler
	self.vel[1] = self.vel[1] + (self.pressureForceX + self.viscousForceX) / self.mass * dt
	self.vel[2] = self.vel[2] + ((self.pressureForceY + self.viscousForceY) / self.mass + gravity) * dt
	self.pos[1] = self.pos[1] + self.vel[1] * dt
	self.pos[2] = self.pos[2] + self.vel[2] * dt
	--]]
--]===]

-- [===[ regular.  no momentum.  not even verlet integration.

	do
		
		local particleRadius = 1
		local particlePressure = 1
		local wallEpsilon = .1
		local wallPushEpsilon = .1
		
		local wallRadius = 1
		local wallPressure = 1
		
		local gradx = 0
		local grady = 0

		local sampleRadius = 2
		local centerIX = math.floor(self.pos[1])
		local centerIY = math.floor(self.pos[2])
		local xmin = centerIX - sampleRadius
		local xmax = centerIX + sampleRadius
		local ymin = centerIY - sampleRadius
		local ymax = centerIY + sampleRadius
		if xmin <= level.size[1] and xmax >= 1 and ymin <= level.size[2] and ymax >= 1 then
			if xmin < 1 then xmin = 1 end
			if xmax > level.size[1] then xmax = level.size[1] end
			if ymin < 1 then ymin = 1 end
			if ymax > level.size[2] then ymax = level.size[2] end
				
			for x=xmin,xmax do
				local tilecol = level.tile[x]
				for y=ymin,ymax do
					tile = tilecol[y]
					if tile.fluid then
						for _,particle in ipairs(tile.fluid) do
							local dx = self.pos[1] - particle.pos[1]
							local dy = self.pos[2] - particle.pos[2]
							local distSq = dx * dx + dy * dy
							if distSq > .0001 and distSq <= particleRadius * particleRadius then
								local dist = math.sqrt(distSq)
								gradx = gradx + dx / dist
								grady = grady + dy / dist
							end
						end
					end
					
					if tile.solid then
						local dx = self.pos[1] - (tile.pos[1] + .5)
						local dy = self.pos[2] - (tile.pos[2] + .5)
						
						-- [[ keep from going through blocks
						local adx = math.abs(dx)
						local ady = math.abs(dy)
						local dist = math.max(adx, ady)
						if dist < .5 + wallEpsilon then	-- wall epsilon ...
							if adx > ady then	-- left/right
								if dx > 0 then	-- push right
									self.pos[1] = tile.pos[1] + 1 + wallPushEpsilon
								else			-- push left
									self.pos[1] = tile.pos[1] - wallPushEpsilon
								end
							else
								if dy > 0 then	-- push up
									self.pos[2] = tile.pos[2] + 1 + wallPushEpsilon
								else			-- push down
									self.pos[2] = tile.pos[2] - wallPushEpsilon
								end
							end
						end
						--]]
						
						-- [[
						local distSq = dx * dx + dy * dy
						if distSq > .0001 and distSq <= wallRadius * wallRadius then
							local dist = math.sqrt(distSq)
							gradx = gradx + wallPressure * dx / dist
							grady = grady + wallPressure * dy / dist
						end
						--]]
					end
				end
			end
		end
		
		local gradLenSq = gradx * gradx + grady * grady
		
		local gravity = -10

		-- [[ works good, because all momentum stops as soon as two particles touch.
		if gradLenSq > .0001 then
			local gradLen = math.sqrt(gradLenSq)

			local velDecay = .8		-- zero works well
			self.vel[1] = self.vel[1] * velDecay + particlePressure * gradx / gradLen
			self.vel[2] = self.vel[2] * velDecay + particlePressure * grady / gradLen
		end
		self.vel[2] = self.vel[2] + gravity * dt

		self.pos[1] = self.pos[1] + self.vel[1] * dt
		self.pos[2] = self.pos[2] + self.vel[2] * dt
		--]]
		
		--[[ ehh ... stomer verlet integration
		if gradLenSq < .1 then gradLenSq = .1 end
		local gradLen = math.sqrt(gradLenSq)
		local lastX, lastY = self.lastPos[1], self.lastPos[2]
		self.lastPos[1] = self.pos[1]
		self.lastPos[2] = self.pos[2]
		local velDecay = 1
		self.pos[1] = self.pos[1] + velDecay * (self.pos[1] - lastX) + dt * dt * gradx / gradLen
		self.pos[2] = self.pos[2] + velDecay * (self.pos[2] - lastY) + dt * dt * (grady / gradLen + gravity)
		--]]
		
		--[[ leapfrog?
		if self.leap then
			if gradLenSq > .1 then
				local gradLen = math.sqrt(gradLenSq)

				self.vel[1] = self.vel[1] + gradx / gradLen
				self.vel[2] = self.vel[2] + grady / gradLen
			end
			self.vel[2] = self.vel[2] + gravity * dt
		else
			self.pos[1] = self.pos[1] + self.vel[1] * dt
			self.pos[2] = self.pos[2] + self.vel[2] * dt
		end
		self.leap = not self.leap
		--]]
		
	end

--]===]
	
	if self.pos[2] < -10 then self.remove = true end
	
	self:link()
end

function FluidParticle:draw(R, viewBBox)
	local tex
	if self.tex then
		tex = self.tex
	elseif self.sprite and self.seq then
		tex = animsys:getTex(self.sprite, self.seq)
	end
	if not tex then return end
	tex:bind()
	R:quad(
		self.pos[1] - .5, self.pos[2] - .5,
		1, 1,
		0, 1,
		1, -1,
		0,
		1, 1, 1, 1)
end

return FluidParticle