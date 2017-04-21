local class = require 'ext.class'
local GameObject = require 'base.script.obj.object'
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
			tick.solidFlags = 0
			tick.touchFlags = 0
			tick.blockFlags = 0
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
			self.solidFlags = 0
			self.touchFlags = 0
			self.blockFlags = 0
			self.removeTime = game.time + 1
			self.sprite = 'blast'
			self.drawMirror = false
			self.seq = 'blast'
			self.canCarry = false
			self.useGravity = false
			self.vel[1], self.vel[2] = 0, 0
			
			-- ... and kill some things
			local level = game.level
			local blastRange = 3.5
			local centerx, centery = self.pos[1] - level.pos[1], self.pos[2] - level.pos[2]
			local xmin, xmax = math.floor(centerx - blastRange), math.floor(centerx + blastRange)
			local ymin, ymax = math.floor(centery - blastRange), math.floor(centery + blastRange)
			for x=xmin, xmax do
				for y=ymin, ymax do
					local dx = x - math.floor(centerx)
					local dy = y - math.floor(centery)
					local distSq = dx * dx + dy * dy
					if distSq <= blastRange * blastRange then	-- circular radius
						local tile = level:getTile(x,y)
						if tile then
							for _,obj in ipairs(game.objs) do
								if obj ~= self
								and math.floor(obj.pos[1]) == x 
								and math.floor(obj.pos[2]) == y 
								and obj.hitByBlast
								then
									local div = math.max(distSq, .1)
									obj.vel[1] = obj.vel[1] + (obj.pos[1] - self.pos[1]) * 20 / div
									obj.vel[2] = obj.vel[2] + (obj.pos[2] - self.pos[2]) * 20 / div
									obj:hitByBlast(self)
								end
							end
							
							--[[ hit tiles
							if tile.onHit then tile:onHit(self) end
							--]]
							-- [[ destroy tiles!
							SpinParticle.breakAt(x + .5, y + .5)
							level:makeEmpty(x,y)
							--]]
						end
					end
				end
			end
			-- [[ destroy tiles!
			print'TODO smooth'
			--level:alignTileTemplates(xmin, ymin, xmax, ymax)
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
