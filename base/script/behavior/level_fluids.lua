return function(parentClass)
	local FluidLevelTemplate = parentClass:subclass()

	function FluidLevelTemplate:initSpawn(...)
		FluidLevelTemplate.super.initSpawn(self, ...)

		-- TODO can't store per-tile cuz I'm not allocating each Tile object ...
		for i=1,self.size[1] do
			local tilecol = self.tile[i]
			for j=1,self.size[2] do
				local tile = tilecol[j]

				-- reset fluids
				tile.fluid = nil
				
				-- init particles
				local fluidClass = tile.fluidClass
				if fluidClass then
					--[[ 4-lattice
					fluidClass{pos={i + .375, j + .25}}
					fluidClass{pos={i + .875, j + .25}}
					fluidClass{pos={i + .125, j + .75}}
					fluidClass{pos={i + .625, j + .75}}
					--]]
					
					--[[ 2-lattice
					fluidClass{pos={i + .25, j + .25}}
					fluidClass{pos={i + .75, j + .75}}
					--]]
					
					-- [[ 1-lattice
					fluidClass{pos={i + .25 + (j%2) * .5, j + .5}}
					--]]
				end
			end
		end
	end

	function FluidLevelTemplate:draw(...)
		local R, bbox = ...
		
		-- TODO do this after testing view bbox and before drawing objects
		for x=xmin,xmax do
			local tilecol = self.tile[x]
			for y=ymin,ymax do
				local tile = tilecol[y]
				local fluid = tile.fluid
				if fluid then
					for i=1,#fluid do
						fluid[i]:draw(R, bbox)
					end
				end
			end
		end
		
		FluidLevelTemplate.super.draw(self, ...)
	end

	function FluidLevelTemplate:update(...)
	

		for _,particle in ipairs(self.fluid) do
			particle:update(dt)
		end
	
		for i=#self.fluid,1,-1 do
			local particle = self.fluid[i]
			if particle.remove then
				particle:unlink()
				self.fluid:remove(i)
			end
		end
	end

	function Game:resetObjects()
		Game.super.resetObjects(self)
		self.fluid = table()	-- enumeration of all fluid particles
	end

	--[[ 

	-- fluids affect fall speed
	-- in base/script/obj/object.lua ...
	local tile = level:getTile(self.pos[1], self.pos[2])
	if tile and tile.fluid and #tile.fluid > 0 then
		gravity = gravity * .1
		maxFallVel = maxFallVel and maxFallVel * .1
		--self.vel[2] = self.vel[2] * .1
	end

	-- swimming control: 
	-- in mario/script/obj/mario.lua ...
	self.swimming = tile and tile.fluid and #tile.fluid > 0

	-- block has fluids
	-- in base/script/tile/water.lua:	
	WaterTile.fluidClass = WaterParticle

	--]]

	return FluidLevelTemplate
end
