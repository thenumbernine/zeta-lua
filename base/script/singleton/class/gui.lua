-- hack, make sure this is called first
local Font = require 'gui.font'
function Font:drawBegin(
	posX, posY,
	fontSizeX, fontSizeY,
	text,
	sizeX, sizeY,
	colorR, colorG, colorB, colorA
)
	if colorR then
		self.colorR = colorR
		self.colorG = colorG
		self.colorB = colorB
		self.colorA = colorA
	else
		self.colorR = 1
		self.colorG = 1
		self.colorB = 1
		self.colorA = 1
	end
end
function Font:drawQuad(drawX, drawY, tx, ty, startWidth, finishWidth, fontSizeX, fontSizeY)
	local game = require 'base.script.singleton.game'
	self.tex:bind()
	game.R:quad(
		drawX, drawY,
		(finishWidth - startWidth) * fontSizeX,
		fontSizeY,
		(tx + startWidth) / 16,
		ty / 16,
		(finishWidth - startWidth) / 16,
		1 / 16,
		self.colorR, self.colorG, self.colorB, self.colorA
	)
	self.tex:unbind()
end
function Font:drawEnd() end



local class = require 'ext.class'
local table = require 'ext.table'
local modio = require 'base.script.singleton.modio'
local GUI = require 'gui'

local BaseGUI = GUI:subclass()
BaseGUI.fontFile = 'res/font.png'

function BaseGUI:init(args)
	args = table(args)
	args.font = modio:find(BaseGUI.fontFile)
	BaseGUI.super.init(self, args)
end

function BaseGUI:update()
end

return BaseGUI
