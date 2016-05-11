local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'

local Terminal = class(Object)
Terminal.sprite = 'terminal'
Terminal.solid = false
Terminal.collidesWithObjs = false

function Terminal:init(args)
	Terminal.super.init(self, args)
	self.text = args.text
	self.use = args.use
end

function Terminal:playerLook(player)
	local threads = require 'base.script.singleton.threads'
	if self.text then
		threads:add(function()
			player:popupMessage(self.text)
		end)
	end
	if self.use then
-- TODO sandbox: http://stackoverflow.com/a/6982080/2714073
		local code = [[
local object, player, game = ...
local level = game.level
local function popup(...) return player:popupMessage(...) end
local function create(spawnTypeStr)
	-- verify the spawnTypeStr is valid
	if not game.levelcfg.spawnTypes:find(nil, function(spawnType)
		return spawnType.spawn == spawnTypeStr
	end) then 
		error("failed to find spawntype "..spawnTypeStr)
	end
	return require(spawnTypeStr)
end
]] .. self.use
		threads:add(assert(load(code)), self, player, game)
	end
end

return Terminal
