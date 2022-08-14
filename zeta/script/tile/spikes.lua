local class = require 'ext.class'
local Solid = require 'base.script.tile.solid'
local Spikes = class(Solid)
Spikes.name = 'spikes'
Spikes.damage = 5
return Spikes
