local class = require 'ext.class'
local modio = require 'base.script.singleton.modio'
local GUI = require 'gui'

local BaseGUI = class(GUI)
BaseGUI.fontFile = 'res/font.png'

function BaseGUI:init(args)
	args = table(args)
	args.font = modio:find(BaseGUI.fontFile)
	BaseGUI.super.init(self, args)
end

return BaseGUI
