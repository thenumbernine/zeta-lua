return {
	require 'zeta.script.tile.blasterbreak'(),
	require 'zeta.script.tile.plasmabreak'(),
	require 'zeta.script.tile.skillsawbreak'(),
	require 'zeta.script.tile.missilebreak'(),
	require 'zeta.script.tile.grenadebreak'(),
	require 'zeta.script.tile.speedbreak'(),
	require 'zeta.script.tile.spikes'(),

	require 'zeta.script.tile.blasterbreak'{regen=true, name='blaster-break-regen'},
	require 'zeta.script.tile.plasmabreak'{regen=true, name='plasma-break-regen'},
	require 'zeta.script.tile.skillsawbreak'{regen=true, name='skillsaw-break-regen'},
	require 'zeta.script.tile.missilebreak'{regen=true, name='missile-break-regen'},
	require 'zeta.script.tile.grenadebreak'{regen=true, name='grenade-break-regen'},
	require 'zeta.script.tile.speedbreak'{regen=true, name='speed-break-regen'},
}
