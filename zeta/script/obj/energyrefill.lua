local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local threads = require 'base.script.singleton.threads'
local game = require 'base.script.singleton.game'
local animsys = require 'base.script.singleton.animsys'

local EnergyRefill = class(Object)
EnergyRefill.sprite = 'energyrefill'
EnergyRefill.solid = false

-- TODO get from animsys:
local sparkSeqTime = .5
local numSparks = 4

function EnergyRefill:init(args)
	EnergyRefill.super.init(self, args)
	self.sparks = table()
	for i=1,numSparks do
		self.sparks:insert{
			t = game.time + i/numSparks*sparkSeqTime,
			x = 16/16*(i-1)/numSparks - 10/16,
		}
	end
end

function EnergyRefill:playerLook(player)
	threads:add(function()
		player:popupMessage('health refilling...')
		player.health = player.maxHealth
		player.ammoCells = player.maxAmmoCells
	end)
end

function EnergyRefill:update(dt)
	EnergyRefill.super.update(self, dt)
	for _,spark in ipairs(self.sparks) do
		if game.time - spark.t >= sparkSeqTime then	-- animation sequence time
			spark.t = game.time
			spark.x = 9/16*math.random() - .5
		end
	end
end

function EnergyRefill:draw(R, viewBBox)
	EnergyRefill.super.draw(self, R, viewBBox)
	for _,spark in ipairs(self.sparks) do
		local tex = animsys:getTex('energyrefill', 'spark', spark.t)
		tex:bind()
		R:quad(
			self.pos[1]+spark.x,
			self.pos[2],
			.5, 2,
			0, 1,
			1, -1,
			0,
			1,1,1,1)
	end
end

return EnergyRefill
