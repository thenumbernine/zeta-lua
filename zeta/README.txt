TODO list

next: add next cave section
	and some more cave monsters

- you can slide through doors sometimes.  maybe it's only if it's a keycard door and it starts open from you walking into the room. 
- put non-colliding objects on a separate update loop ... or link objects to rooms/tiles/etc, and have collision detection only test those objects

- editor: 
	- separate 'object' into 'create object' and 'select object'
	- click-and-drag on tile selection to form rectangles for brush + stamp size?
	- show bbox box2 field around object and have manipulators
	- show vec2 fields as offsets ...? or absolute positions if the meta editor info says so.
	- object classes use 'spawnfields' for editor fields, types, and tooltips
- environmental effects ... foreground warping (underwater, heat), blowing wind, falling snow/rain/leaves, etc

LOW PRIORITY:
save files:
	- save files aren't saving spawninfo association in some cases
	- save files don't save threads 
- separate lua env for level/init.lua and for sandboxes
- hit 100 objects and you'll stop in midair
- movement still needs pushing (making use of pushPriority) implementation ... maybe ...
- arbitrary room sizes (no fixed grid) - in fact, double as spawnInfo and bbox

monsters:
	- add moar mining base monsters:
		- flying drones ...
		- evil robots 
	- add moar cave monsters.  
		- close-range guy
		- maybe some kind of shooter

buttons:
	- up/down to aim, left/right to move
	- L/R: weapon prev/next (shift+L/R for inv prev/next? or too confusing?  separate L2&R2 for inv prev/next?  or too many buttons?)

	- B: jump
	- Y: shoot
	- A: use selected aux item.  
		- for weapons/armor: this equips it.
		- for aux things like grappling hook, speed booster, jetpack, pick-up gloves, etc, this uses it.
	- X: go to inventory, where arrows select and B uses the item.  
		using items involves:
			- one-time use items (reserve, powerup, etc)
			- activating/deactivating items (powerup suits, high-jump, etc)
			- selecting current aux item (grappling hook, speed booster, jetpack, pick-up gloves, etc)

- how to craft? designated locations (like aquaria)? or anywhere?

stats:
	* attack (+ to damage)
	* defense (- to damage ... with a minimum?)
	* health
	- jump height? or only special mod for high jump boots?
	- running max speed? or only special mod for speed boost?

items:
	* health boost
		- craft: 1 green tentacle + 1 emerald
	* attack boost (temporary)
		- craft: 1 red tentacle + 1 ruby 
	* shield boost (temporary)
		- craft: 1 red tentacle + 1 emeralde
	- grenades
	- cloak (temporary)
	- flare (lighting)

ammo:
	- plasma
		craft to create: 1 emerald -> 50 plasma, 1 ruby -> 200 plasma
	- petrol
		craft to create: 1 oil
	- electricity
		craft to create: 1 sapphire
	- bullets
	- grenades
	- missiles

weapons (not crafted):
	* blaster 
		weight: light
		damage type: projectile + electricity
		ammo: plasma (slowly recharges, initial capacity 10 or 50 or so)
	- flamethrower (heat)
		ammo: petrol
	- freeze weapon (ice)
		ammo: electricity
	- minigun (projectile)
		ammo: bullets
	* grenade launcher (splash)
		ammo: grenades
	* rocket launcher (/homing? as a modifier?) (projectile + splash)
		ammo: missiles
	- electricity gun / tesla coil (electricity)
		ammo: electricity
	* plasma rifle / rapid fire (projectile + electricity)
		ammo: plasma (added capacity to 100 or 200 or so)
	- skillsaw
		ammo: electricity
	- Halo sword (heat + electricity)
		ammo: ?
	- heat ray (heat)
		ammo: ? 

modifiers (not crafted):
	- ammo capacity
		- plasma
		- petrol
		- electricity
		- bullets
		- grenades
		- missiles
	- grappling hook
	- shield
	- jetpack
	- visors:
		- infrared
		- motion
		- x-ray

inventory (not crafted):
	- armor
		types:
		- reduce biological damage (monster touch)
		- reduce plasma damage
		- reduce explosion damage
		- reduce projectile damage
		- reduce acid damage (environment / radsuit / slime)
		- reduce heat damage ... heat weapons? hear air? heat magma?
		- water breathe time?
		- reduce ice damage
	- legs:
		- speed shoes
		- high jump boots
	- arms:
		- ledge pull-up ? only certain walls?
		- touch & go? only certain walls?
		- lifting objects / upgrade for heavier?

craft materials, found on their own:
	emerald
	ruby
	sapphire	
	blaster frame
	oil

enemies:
	
		mining baes:
	turret -> drop 5% grenade, 5% heart 
	shocking things - vertical and horizontal
	sawblades from mario world ... or indiana jones 
	sentry? 
	rogue robots ... that look like you?

		intro to caves:
	green geemer -> 10% heart 
	red geemer -> 10% heart
	venus fly trap / hides in background
	some sort of close-range guy who walks slowly
	bats or something that hover in circles
	something that shoots something out


inspirations:

Super Mario World (1990.11.21)
Super Metroid (1994.03.19)
Abuse (1996.02.29)
Castlevania: Symphony of the Night (Super Metroid) (1997.03.20)
Cave Story (Super Metroid) (2004.12.20)
Aquaria (Super Metroid) (2007.12.07)
Spelunky (Super Mario World, La-Mulana, Rick Dangerous, Spelunker) (2008.12.21)
Minecraft (Dwarf Fortress) (2009.03.17)
Aliens: Infestation (2011.09.29)
