TODO list

- editor: move texpack tiles and change map tiles accordingly
- object classes use 'spawnfields' for editor fields, types, and tooltips
- missile launcher missile ammo
- link objs and spawninfos to rooms, respawn by room
- camera align via room info, or helper objects
- fix collisions with sloped tiles.  determine ymin and ymax on the x side of sloped tiles and test that against object bbox. 
- make deactivated turrets shoot at enemies.  do room links first to cut down on game.objs iterations.
- geemers and doors don’t mix.  one pushes the other and the geemer teleports.
- second kind of defense monster: heat shields or something
- second kind of cave monster ... bats or something? or separate ground from wall geemers?
- spawn more monsters in the mining base area *after* beating the boss
- room environmental effects ... foreground warping (underwater, heat), blowing wind, falling snow/rain/leaves, etc
- get savepoint loading to work

VETOED list:
- don't use 'spawnclass' as a class shortcut to register classes that are spawned.
	to execute the spawn code, all the class will have to be require()'d somewhere in one spot anyways
	it's better to list the names in 'spawnTypes' than have everything being required
- don't separating playerLook vs canCarry.  set an item down by a terminal, and try to pick it up again.
	- using 'a' for run and use item means ... you can't run / always run when using an item 
	solution? get rid of carrying items altogether? options:
		- carrying items (spelunky)
		- touch to get (metroid)
		- push 'interact' button to to pick up (cave story)
	item overhaul:
		- touch/interaact to pick everything up -- no carrying
		- left/right switches weapons only.  one weapon is 'throw grenades' -- only if you have grenades.
		- canCarry only operates with a powerup: carry gloves, used for story stuff
		- separate inventory screen for using non-weapon objects
			(this means no more 'take the keycard out to open the door')

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
	green geemer -> 10% green tentacle 
	red geemer -> 10% red tentacle 
	venus fly trap / hides in background
	some sort of close-range guy who walks slowly
	bats or something that swoops from ceiling
	sawblades from mario world / cave story egg zone

	turret -> 10% metal 
	flying sentry -> 10% metal



inspirations:

Super Mario World (1990.11.21)
Super Metroid (1994.03.19)
Abuse (1996.02.29)
Castlevania: Symphony of the Night (Super Metroid) (1997.03.20)

Cave Story (Super Metroid) (2004.12.20)
Aquaria (Super Metroid) (2007.12.07)
Spelunky (Super Mario World, La-Mulana, Rick Dangerous, Spelunker) (2008.12.21)
Minecraft (Dwarf Fortress) (2009.03.17)
