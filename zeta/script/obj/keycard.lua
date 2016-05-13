local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'
local KeyCard = class(Item)
KeyCard.sprite = 'keycard'
KeyCard.playerHoldOffsetStanding = {.625, .5}
KeyCard.playerHoldOffsetDucking = {.625, .25}
return KeyCard
