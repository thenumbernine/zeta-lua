[![Donate via Stripe](https://img.shields.io/badge/Donate-Stripe-green.svg)](https://buy.stripe.com/00gbJZ0OdcNs9zi288)<br>

# Zeta
## A Metroidvania Game

![](docs/images/pic1.png)
![](docs/images/pic2.png)
![](docs/images/pic3.png)
![](docs/images/pic4.png)
![](docs/images/pic5.png)
![](docs/images/pic6.png)
![](docs/images/pic7.png)
![](docs/images/pic8.png)
![](docs/images/pic-editor-1.png)
![](docs/images/pic-editor-2.png)

I'm dumping a whole bunch of random stuff into a platformer engine.

### Features ###
* multiplayer split-screen and netplay (albeit very unoptimized)
* built-in editor

### Dependencies ###
* ImGuiApp Lua lib
	* cimgui + ImGui
* GLApp Lua lib
	* Malkia's UFO bindings
	* SDL
* audio Lua lib, with options for:
	* SDL_mixer
	* OpenAL
* image Lua lib, with options for:
	* SDL_image
	* pure luajit
* various other Lua libs:
	* gl
	* ext
	* template
	* vec
	* parser
	* netrefl
	* resourcecache
	* threadmanager
	* simplexnoise
	* gui
	* vec-ffi
	* lua-ffi-bindings

Uses my lua-dist project to create cross-platform distributables.
I've ported this manually to Android and Wii before, but still need to integrate the changes. 
