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
		local sandbox = require 'zeta.script.sandbox'
		sandbox(self.use, 'self, player', self, player)
	end
end

return Terminal
