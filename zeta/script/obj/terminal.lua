local class = require 'ext.class'
local Object = require 'base.script.obj.object'
local modio = require 'base.script.singleton.modio'
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

Terminal.solidFlags = 0
Terminal.touchFlags = Object.SOLID_WORLD + Object.SOLID_YES
Terminal.blockFlags = Object.SOLID_WORLD

function Terminal:playerUse(player)
	local threads = require 'base.script.singleton.threads'
	if self.text then
		threads:add(function()
			player:popupMessage(self.text)
		end)
	end
	if self.use then
		local sandbox = modio:require 'script.sandbox'
		sandbox(self.use, 'self, player', self, player)
	end
end

return Terminal
