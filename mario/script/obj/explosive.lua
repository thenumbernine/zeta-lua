local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
local EmptyTile = require 'base.script.tile.empty'
local SpinParticle = require 'mario.script.obj.spinparticle'
local game = require 'base.script.singleton.game'

local Explosive = class(GameObject)

Explosive.sprite = 'explosive'
Explosive.canCarry = true

function Explosive:playerBounce(player)
	self:hit()
end

function Explosive:update(dt)
	Explosive.super.update(self, dt)
	
	if self.detonateTime then
		local oldTick  = math.floor(self.detonateTime)
		self.detonateTime = self.detonateTime - dt
		local newTick = math.floor(self.detonateTime)
		
		if oldTick ~= newTick and oldTick > 0 then
			local gui = require 'base.script.singleton.gui'
			-- show the 'oldTick'
			local tick = GameObject{
				pos = self.pos,
			}
			tick.solid = false
			tick.collidesWithWorld = false
			tick.collidesWithObjects = false
			tick.removeTime = game.time + 3
			tick.vel[2] = 1
			tick.useGravity = false
			tick.draw = function(self, R)
				gui.font:drawUnpacked(self.pos[1], self.pos[2]+2, 1, -1, tostring(oldTick))
				-- gui hasn't been R-integrated yet ...
				local gl = R.gl
				gl.glEnable(gl.GL_TEXTURE_2D)
			end
		end
	
		if self.detonateTime < 0 then
			if self.heldby then self.heldby:setHeld(nil, false) end
			self.solid = false
			self.removeTime = game.time + 1
			self.sprite = 'blast'
			self.drawMirror = false
			self.seq = 'blast'
			self.canCarry = false
			self.collidesWithWorld = false
			self.collidesWithObjects = false
			self.useGravity = false
			self.vel[1], self.vel[2] = 0, 0
			
			-- ... and kill some things
			local level = game.level
			local blastRange = 3.5
			local centerx, centery = self.pos[1] - level.pos[1], self.pos[2] - level.pos[2]
			local xmin, xmax = math.floor(centerx - blastRange), math.floor(centerx + blastRange)
			local ymin, ymax = math.floor(centery - blastRange), math.floor(centery + blastRange)
			local testedObjs = {[self] = true}
			for x=xmin, xmax do
				for y=ymin, ymax do
					local dx = x - math.floor(centerx)
					local dy = y - math.floor(centery)
					local distSq = dx * dx + dy * dy
					if distSq <= blastRange * blastRange then	-- circular radius
						local tile = level:getTile(x,y)
						if tile then
							if tile.objs then
								for _,obj in ipairs(tile.objs) do
									if not testedObjs[obj] then
										testedObjs[obj] = true
										if obj.hitByBlast then
											local div = math.max(distSq, .1)
											obj.vel[1] = obj.vel[1] + (obj.pos[1] - self.pos[1]) * 20 / div
											obj.vel[2] = obj.vel[2] + (obj.pos[2] - self.pos[2]) * 20 / div
											obj:hitByBlast(self)
										end
									end
								end
							end
							
							--[[ hit tiles
							if tile.onHit then tile:onHit(self) end
							--]]
							-- [[ destroy tiles!
							if getmetatable(tile) ~= EmptyTile then
								SpinParticle.breakAt(level.pos[1] + tile.pos[1] + .5, level.pos[2] + tile.pos[2] + .5)
								tile:makeEmpty()
							end
							--]]
						end
					end
				end
			end
			-- [[ destroy tiles!
			level:alignTileTemplates(xmin, ymin, xmax, ymax)
			--]]
			
			-- don't run this twice!
			self.detonateTime = nil
		end
	end
end

function Explosive:hit()
	self.vel[1] = 0
	self.vel[2] = 0

	-- if we have been hit then don't delay again
	if self.detonateTime then return end
	-- if we're an explosion then return 
	if self.sprite == 'blast' then return end
	
	self.detonateTime = 3 + math.random() * .5 + .5
	self.seq = 'detonate'
end

function Explosive:hitByEnemy(other) self:hit(other) end
function Explosive:hitByShell(other) self:hit(other) end
function Explosive:hitByBlast(other) self:hit(other) end

return Explosive
