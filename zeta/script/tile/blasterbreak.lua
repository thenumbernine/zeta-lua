local class = require 'ext.class'
local Solid = require 'base.script.tile.solid'
local BlasterBreak = class(Solid)
BlasterBreak.name = 'blaster-break'
BlasterBreak.Q_per_Cp_rho = 1			-- K / s = volumetric heat source, divided by specific heat capacity for constant pressure, divided by density
BlasterBreak.temperature = require 'base.script.temperature'.FtoK(100)
return BlasterBreak
