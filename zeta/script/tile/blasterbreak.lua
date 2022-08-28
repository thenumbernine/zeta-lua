local class = require 'ext.class'
local Solid = require 'base.script.tile.solid'
local BlasterBreak = class(Solid)
BlasterBreak.name = 'blaster-break'
BlasterBreak.temperature = require 'base.script.temperature'.FtoK(100)
return BlasterBreak
