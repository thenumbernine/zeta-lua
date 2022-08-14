local class = require 'ext.class'
local Solid = require 'base.script.tile.solid'
local Spike = class(Solid)
Spike.name = 'spike'
Spike.damage = true
return Spike
