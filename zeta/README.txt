TODO list

- editor: 
	- move texpack tiles and change map tiles accordingly
	- separate 'object' into 'create object' and 'select object'
- object classes use 'spawnfields' for editor fields, types, and tooltips
- camera align via room info, or helper objects
- fix collisions with sloped tiles.  determine ymin and ymax on the x side of sloped tiles and test that against object bbox. 
- make deactivated turrets shoot at enemies.  do room links first to cut down on game.objs iterations.
- geemers and doors don’t mix.  one pushes the other and the geemer teleports.
- second kind of cave monster ... bats or something? or separate ground from wall geemers?
- environmental effects ... foreground warping (underwater, heat), blowing wind, falling snow/rain/leaves, etc
- get savepoint loading to work
weapons:
	- missile launcher missile ammo
	- number-based rather than index-based ... and overhaul the item system
rooms:
	- every time an item is grabbed, set a session var that says the item at this level at this index is grabbed
		then have the respawn system ignore it if that var is set
		(serialize those session vars with the save file)
	- same with the electric fields and 'toggleDisabled'
	in fact, for both, why not just serialize all objects as they leave?
	upon removing room spawns, serialize objects and store them in a session/cache file
		then upon adding room spawns, create the objs, then check the cache and overwrite values
		then double the caching system as the savegame system
	- if an *object* leaves your neighborhood then remove it 
	 	but if a *spawninfo* enters into your neighborhood (and it has no current object bound) then add it 
		... but items would need all their positions updated to keep alive
		... or get rid of items-as-objects completely - replace with items-as-values
	- touch triggers don't get along with room system?
	
VETOED list:
- screen base spawning
	- first i tried spawn and remove based on spawninfo.  enemies would disappear if they walked too far from their start.
	- then i did spawn by spawninfo, remove by object.  if you lure an enemy too far from their home to kill them, they reappear.  this is frustrating. 
	- finally i'm going back to metroid/castlevania/cavestory-styled rooms 
- don't use 'spawnclass' as a class shortcut to register classes that are spawned.
	to execute the spawn code, all the class will have to be require()'d somewhere in one spot anyways
	it's better to list the names in 'spawnTypes' than have everything being required
- don't separating playerLook vs canCarry.  set an item down by a terminal, and try to pick it up again.
	item system options:
		- carrying items (spelunky / current system)
			pros:
			- most flexible
			cons:
			- using 'a' for run and use item means ... you can't run / always run when using an item 
			- need terminal/savepoint button *and* object button, or else objects can get stuck if you put them down by terminals
			- item order is never the same (can be fixed)
			- have to have your hands empty to pick something up
			- when you pick something up, it switches your inventory
		- touch to get (metroid)
			pros:
			- most simple
			cons:
			- no easy way to switch between and use individual items
			- need a distinct weapon for throwing objects
		- push 'interact' button to to pick up (cave story)
			- just like metroid style, but with an extra button to get things
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
