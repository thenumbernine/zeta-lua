local class = require 'ext.class'
local Geemer = require 'zeta.script.obj.geemer'
local box2 = require 'vec.box2'
local game = require 'base.script.singleton.game'
local GeemerChunk = require 'zeta.script.obj.geemerchunk'

local BossGeemer = class(Geemer)
BossGeemer.maxHealth = 20
BossGeemer.bbox = box2(-.9, 0, .9, 1.8)
BossGeemer.sprite = 'boss-geemer'
-- todo - some parabola math to make sure they jump right on the player
BossGeemer.jumpVel = 20
BossGeemer.runVel = 10
BossGeemer.attackDist = 10

function BossGeemer:init(...)
	BossGeemer.super.init(self, ...)
	self.spawnedGeemers = table()
	game.bosses:insert(self)
end

BossGeemer.itemDrops = nil
function BossGeemer:calcVelForJump(delta)
	--[[ delta is the vector from the geemer to the player
	delta[1] = vel[1]*t
	delta[2] = vel[2]*t + .5*game.gravity*t^2
	
	TODO factor in max-fall-vel now that i'm using that
	--]]
	local t = 1 -- desired time til impact
	self.vel[1] = delta[1] / t
	self.vel[2] = delta[2] / t - .5 * game.gravity * t
end

-- don't mess with the soft copy of the parent class's states
BossGeemer.states = table(BossGeemer.super.states)
for k,v in pairs(BossGeemer.states) do
	BossGeemer.states[k] = table(BossGeemer.states[k])
end

BossGeemer.jumpsBeforeShaking = 0
BossGeemer.states.waitingToJump.enter = function(self, ...)
--	print(tolua(BossGeemer.super.states.waitingToJump))
	BossGeemer.super.states.waitingToJump.enter(self, ...)
		-- spawn a few

	self.jumpsBeforeShaking = self.jumpsBeforeShaking + 1
	if self.jumpsBeforeShaking >= 3 then
		self.jumpsBeforeShaking = 0
		-- spawn a whole bunch of geemers at the top of the room
		self:spawnSomeGeemers(5)
	else
		self:spawnSomeGeemers(1)
	end
end

BossGeemer.maxSpawnedGeemers = 20
function BossGeemer:spawnSomeGeemers(n)
	
	for i=#self.spawnedGeemers,1,-1 do
		if self.spawnedGeemers[i].remove then
			self.spawnedGeemers:remove(i)
		end
	end
	
	if #self.spawnedGeemers > self.maxSpawnedGeemers then return end
	
	local level = game.level
	local xmin = math.floor(self.pos[1] / level.mapTileSize[1]) * level.mapTileSize[1] + 1
	local xmax = xmin + level.mapTileSize[1] - 2
	local y = math.ceil(self.pos[2] / level.mapTileSize[2]) * level.mapTileSize[2] - 2
	local Geemer = require 'zeta.script.obj.geemer'
	local RedGeemer = require 'zeta.script.obj.redgeemer'
	RedGeemer = class(RedGeemer)
	RedGeemer.maxHealth = 3
	local classes = {Geemer,Geemer,Geemer,Geemer,Geemer,RedGeemer}
	for i=1,n do
		local x = math.random(xmax-xmin+1)-1+xmin
		local geemer = classes[math.random(#classes)]{pos={x,y}}
		geemer.removeTime = game.time + 15	-- reset after a while
		self.spawnedGeemers:insert(geemer)
	end
end

function BossGeemer:die(damage, attacker, inflicter, side)
	BossGeemer.super.die(self, damage, attacker, inflicter, side)
	for i=1,4 do
		GeemerChunk.makeAt{
			pos = self.pos,
			-- should be inflicter.pos, but the shot needs to stop at the surface for that to happen
			dir = (self.pos - attacker.pos):normalize(),
		}
	end

	for _,geemer in ipairs(self.spawnedGeemers) do
		geemer:die(damage, attacker, inflicter, side)
	end
end

return BossGeemer
