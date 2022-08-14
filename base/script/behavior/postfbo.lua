-- behavior for game singleton class
local ffi = require 'ffi'
local vec4i = require 'vec-ffi.vec4i'
local vec2i = require 'vec-ffi.vec2i'
local FBO = require 'gl.fbo'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local glreport = require 'gl.report'

return function(parentClass)
	local PostFBOTemplate = class(parentClass)

	local fbo
	local tex
	local texSize = vec2i(768, 768)
	local renderShader

	local viewport = vec4i()
	local drawbuffer = ffi.new'int[1]'

	function PostFBOTemplate:render(preDrawCallback, postDrawCallback, ...)
		
		local editor = require 'base.script.singleton.editor'()
		if editor.active then
			return parentClass.render(self, preDrawCallback, postDrawCallback, ...)
		end

		local R = self.R
		local gl = R.gl
		
		local glapp = require 'base.script.singleton.glapp'
		local windowWidth, windowHeight = glapp:size()
		local aspectRatio = windowWidth / windowHeight
		
		PostFBOTemplate.super.render(self, 

		-- preDrawCallback
		function(playerIndex, ...)
			
			gl.glGetIntegerv(gl.GL_VIEWPORT, viewport.s)
			gl.glGetIntegerv(gl.GL_DRAW_BUFFER, drawbuffer)

			--[[ use window size in case the individual viewport sizes vary
			-- the downside? right now most of the raytrace shader assumes the texture sampling region is [0,1]^2
			local targetFBOWidth = windowWidth
			local targetFBOHeight = windowHeight
			--]]
			--[[ use the viewport width/height
			local targetFBOWidth = tonumber(viewport.s[2])
			local targetFBOHeight  = tonumber(viewport.s[3])
			--]]
			-- [[ use the fixed width originally specified and for rendering we just upscale it
			-- and use the aspect ratio to determine our height
			-- however, to do this, you need to fake app:size() for the duration of the render
			-- looks like no one's using it, so just resetting the ortho should be good enough
			local targetFBOWidth = texSize.x
			local targetFBOHeight = math.floor(texSize.x / aspectRatio)
			--]]

			if not fbo 
			or texSize.x ~= targetFBOWidth
			or texSize.y ~= targetFBOHeight
			then
				print('resizing post-processing fbo from '..texSize..' to '..targetFBOWidth..', '..targetFBOHeight..' for viewport '..viewport)
				
				texSize.x = targetFBOWidth
				texSize.y = targetFBOHeight

				tex = GLTex2D{
					width = texSize.x,
					height = texSize.y,
					type = gl.GL_UNSIGNED_BYTE,
					format = gl.GL_RGB,
					internalFormat = gl.GL_RGB,
					minFilter = gl.GL_NEAREST,
					--magFilter = gl.GL_LINEAR,
					magFilter = gl.GL_NEAREST,
				}
				fbo = FBO()
				fbo:setColorAttachmentTex2D(0, tex.id, tex.target, 0)
				glreport'here'
			
				renderShader = R:createShader{
					vertexCode = [[
varying vec4 color;
varying vec2 tc;	//in pixels

uniform vec4 viewport;	//xy=xy, zw=wh

void main() {
	tc = gl_Vertex.xy * viewport.zw + .5 + viewport.xy;

	color = gl_Color;
	gl_Position = ftransform();
}
]],
					fragmentCode = [[
varying vec2 tc;	// in pixels
varying vec4 color;
uniform sampler2D tex;

/*
ortho is (-viewSize, viewSize, -viewSize / aspectRatio, viewSize / aspectRatio, -100, 100)
so the screen is (tilesWide = 2 * viewSize tiles) wide and (tilesTall = 2 * viewSize / aspectRatio tiles) tall
and one tile is (2 * viewSize tiles = viewport.z pixels <=> 1 tile = .5 * viewport.z / viewSize pixels)
(maybe write that as a uniform to save calculations?)
*/
uniform float viewSize;

uniform vec2 texSize;
uniform vec4 viewport;	//xy=xy, zw=wh
uniform vec2 eyePos;

float lenSq(vec3 a) {
	return dot(a, a);
}

void main() {
#if 1	// debug: disable raytracing
	gl_FragColor = texture2D(tex, (viewport.xy + tc) / viewport.zw);
	return;
#endif

	//now march from the view origin (pass this as a uniform ... pass bounds too) to 'tc'

	//how big is 1 tile, in pixels
	float tileSizeInPixels = .5 * viewport.z / viewSize;

	//assuming a tile is 16 texels, how many pixels in a texel?
	//float sizeOfATexelForTex16 = max(1., tileSizeInPixels / 16.);

	vec3 grey = vec3(.3, .6, .1);

	//vec2 origin = viewport.xy + .5 * viewport.zw;
	//origin.y += tileSizeInPixels;
	vec2 origin = viewport.xy + eyePos * viewport.zw;
	
	vec2 raypos = origin;
	vec2 rayvel = tc - origin;
	float raylength = length(rayvel);
	float rayLInfLength = max(abs(rayvel.x), abs(rayvel.y));
	vec2 raydir = rayvel / raylength;

	//float numSteps = 100.;
	float numSteps = max(1., rayLInfLength);
	//numSteps = min(numSteps, 100.);	
	//if I have to cap the raytrace steps, then that means there are samples I'm missing, so how about I scale my step randomly to make up for it?

	vec4 color = vec4(1.);

//TODO numSteps should be l-inf dist of pixels covered
// TODO sampling below - esp transparency - should be step-independent
	float dlen = raylength / numSteps;
	for (float i = 0.; i < numSteps; ++i) {
		vec2 oldraypos = raypos;
		raypos += raydir * dlen;

		vec4 sampleColor = texture2D(tex, (raypos + viewport.xy) / viewport.zw);
	
		
/* TODO 
add some extra render info into the buffer on how to transform the rays at each point

- transform ray direction (reflection/refraction effects)
- transform ray position (portals)
- transparency
*/

		//opacity==1 means ordinary rendering, no smearing
		//opacity==0 means fully smeared
		//float opacity = 1.;

		vec3 translateColor = vec3(248., 216., 32.) / 255.;		//yellow block color

		// this is for the transparency and refraction effect
		vec3 effectSrcColor = vec3(0., 0., 1.);
		//vec3 effectSrcColor = vec3(104., 104., 176.) / 255.;	// blue block color
		//vec3 effectSrcColor = vec3(34., 208., 56.) / 255.;	// which color was this?
		//vec3 effectSrcColor = vec3(0., 1., .5);

		//vec3 reflectEffectSrcColor = vec3(0., 1., 0.);
		vec3 reflectEffectSrcColor = vec3(0., 200., 0.) / 255.;
		
		float opacity = lenSq(sampleColor.rgb - effectSrcColor)
		//+ lenSq(sampleColor.rgb - reflectEffectSrcColor)
		;
		
		opacity -= .1;
		opacity *= 3.;
		opacity = clamp(opacity, 0., 1.);
		//opacity = smoothstep(.1, .8, opacity);
		
		//float refractivity = 0.;
		float refractivity = .05 * (1. - opacity);
		
		//opacity = 1. - sqrt(1. - opacity);	//pulls down, more at the bottom
		//opacity *= opacity;					//pulls down, more at the top
		//opacity = 1. - pow(1. - opacity, 1. / 8.);
		//opacity = pow(opacity, 8.);
		//opacity *= .1;
		//opacity = 1.;

		//now add color slope to raydir and normalize
		float l0m = dot(grey, texture2D(tex, (raypos + vec2( 0., -1.) + viewport.xy) / viewport.zw).rgb);
		float lm0 = dot(grey, texture2D(tex, (raypos + vec2(-1.,  0.) + viewport.xy) / viewport.zw).rgb);
		float lp0 = dot(grey, texture2D(tex, (raypos + vec2( 1.,  0.) + viewport.xy) / viewport.zw).rgb);
		float l0p = dot(grey, texture2D(tex, (raypos + vec2( 0.,  1.) + viewport.xy) / viewport.zw).rgb);
		//float lmm = dot(grey, texture2D(tex, (raypos + vec2(-1., -1.) + viewport.xy) / viewport.zw).rgb);
		//float lpm = dot(grey, texture2D(tex, (raypos + vec2( 1., -1.) + viewport.xy) / viewport.zw).rgb);
		//float lmp = dot(grey, texture2D(tex, (raypos + vec2(-1.,  1.) + viewport.xy) / viewport.zw).rgb);
		//float lpp = dot(grey, texture2D(tex, (raypos + vec2( 1.,  1.) + viewport.xy) / viewport.zw).rgb);
		//float l00 = dot(grey, texture2D(tex, (raypos + vec2( 0.,  0.) + viewport.xy) / viewport.zw).rgb);

		// 1st order dx,dy
		vec2 dl = vec2(.5 * (lp0 - lm0), .5 * (l0p - l0m));
		// Sobel
		//vec2 dl = vec2(.25 * (lpp - lmp + 2. * (lp0 -lm0) + lpm - lmm), .25 * (lpp - lpm + 2. * (l0p -l0m) + lmp - lmm));
		
		dl = normalize(dl);
		//cheap I know
		raydir = normalize(mix(raydir, raydir + dl, refractivity));


		//cheap portal translations
		if (lenSq(sampleColor.rgb - translateColor) < .01) {
			raypos.y += tileSizeInPixels * 5.;
		}
		
		//cheap reflections
		if (lenSq(sampleColor.rgb - reflectEffectSrcColor) < .15) {
			raydir = normalize(raydir - 2. * dl * dot(raydir, dl));
			raypos = oldraypos + raydir * 2.;
		
			//and don't just reflect but also dim
			opacity = .9;
			sampleColor = vec4(0., 0., 0., 0.);
		}



		//color.a = opacity;
		color.a *= opacity;
		//color.a = 1. - color.a * (1. - opacity);
		
		color.rgb *= 1. - color.a;
		color.rgb += color.a * sampleColor.rgb;
	}
	
	gl_FragColor = vec4(color.rgb, 1.);
}
]],
					uniforms = {
						tex = 0,
						texSize = {texSize.x, texSize.y},
					},
				}
			end

			if preDrawCallback then preDrawCallback(playerIndex, ...) end

			-- setup FBO

			--gl.glViewport(0, 0, viewport.s[2], viewport.s[3])
			gl.glViewport(0, 0, texSize.x, texSize.y)
			fbo:bind()
			gl.glDrawBuffer(gl.GL_COLOR_ATTACHMENT0)
			gl.glClear(gl.GL_COLOR_BUFFER_BIT)
		
			-- [[ if our viewport size is not the original then reset our matrixes here:
			local viewSize = self.viewSize
			R:ortho(-viewSize, viewSize, -viewSize / aspectRatio, viewSize / aspectRatio, -100, 100)
			gl.glMatrixMode(gl.GL_MODELVIEW)
			--]]
		end, 

		-- postDrawCallback
		function(playerIndex, ...)
			fbo:unbind()
			gl.glDrawBuffer(drawbuffer[0])
			gl.glViewport(viewport:unpack())

			-- render FBO here
			
			gl.glMatrixMode(gl.GL_PROJECTION)
			gl.glPushMatrix()
			gl.glMatrixMode(gl.GL_MODELVIEW)
			gl.glPushMatrix()
			
			R:ortho(0, 1, 0, 1, -1, 1)
			R:viewPos(0, 0)

			-- where to find the render region in the fbo's texture, in pixels:
			--[[
			local x = math.min(1, tonumber(viewport.s[0]) / texSize.x)
			local y = math.min(1, tonumber(viewport.s[1]) / texSize.y)
			local w = math.min(1, tonumber(viewport.s[2]) / texSize.x)
			local h = math.min(1, tonumber(viewport.s[3]) / texSize.y)
			--]]
			--[[
			local x, y, w, h = viewport:unpack()
			--]]
			--[[
			local x = 0
			local y = 0
			local w = tonumber(viewport.s[2])
			local h = tonumber(viewport.s[3])
			--]]
			-- [[
			local x, y, w, h = 0, 0, texSize.x, texSize.y
			--]]
			--[[
			local x, y, w, h = 0, 0, 1, 1
			--]]
		
			local player = self.clientConn.players[playerIndex]
			local playerClientObj = self.playerClientObjs[playerIndex]

			renderShader:use()
			if renderShader.uniforms.viewSize then
				gl.glUniform1f(renderShader.uniforms.viewSize.loc, self.viewSize)
			end
			if renderShader.uniforms.viewport then
				gl.glUniform4f(renderShader.uniforms.viewport.loc, x, y, w, h)
			end
			if renderShader.uniforms.eyePos then
				gl.glUniform2f(renderShader.uniforms.eyePos.loc,
					(player.pos[1] - player.viewBBox.min[1]) / (player.viewBBox.max[1] - player.viewBBox.min[1]),
					(player.pos[2] + 1.5 - player.viewBBox.min[2]) / (player.viewBBox.max[2] - player.viewBBox.min[2]))
			end
			tex:bind()
			gl.glBegin(gl.GL_TRIANGLE_STRIP)
			gl.glVertex2f(0, 0)
			gl.glVertex2f(1, 0)
			gl.glVertex2f(0, 1)
			gl.glVertex2f(1, 1)
			gl.glEnd()
			tex:unbind()
			renderShader:useNone()

			gl.glMatrixMode(gl.GL_PROJECTION)
			gl.glPopMatrix()
			gl.glMatrixMode(gl.GL_MODELVIEW)
			gl.glPopMatrix()

			if postDrawCallback then postDrawCallback(playerIndex, ...) end
		
			glreport'here'
		end, ...)
		glreport'here'
	end

	return PostFBOTemplate
end
