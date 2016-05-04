-- inventory object
-- used for drawing inventory GUI
-- also used for drawing overlays
-- subclass of (the misleadingly named) base.script.item
--  which is really the class that does image overlays 
local class = require 'ext.class'
local OverlayObject = require 'base.script.item'

local InvObject = class(OverlayObject)

return InvObject
