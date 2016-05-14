-- subclass of Geemer that shows up before the first Geemer boss
local class = require 'ext.class'
local Geemer = require 'zeta.script.obj.geemer'
local FirstGeemer = class(Geemer)
FirstGeemer.spawnAtFirst = true
return FirstGeemer
