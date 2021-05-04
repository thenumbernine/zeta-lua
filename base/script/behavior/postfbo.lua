-- behavior for game singleton class

local vec4i = require 'vec-ffi.vec4i'
local FBO = require 'gl.fbo'
local GLTex2D = require 'gl.tex2d'
local GLProgram = require 'gl.program'
local glreport = require 'gl.report'

return function(parentClass)
	local PostFBOTemplate = class(parentClass)

	local fbo
	local tex
	local texWidth = 1024
	local texHeight = 1024
	local renderShader

	local viewport = vec4i()
	local drawbuffer = ffi.new'int[1]'

	function PostFBOTemplate:render(preDrawCallback, postRenderCallback, ...)
		
		local R = self.R
		local gl = R.gl
		
		local glapp = require 'base.script.singleton.glapp'
		local windowWidth, windowHeight = glapp:size()
		
		PostFBOTemplate.super.render(self, function(...)
			
			gl.glGetIntegerv(gl.GL_VIEWPORT, viewport.s)
			gl.glGetIntegerv(gl.GL_DRAW_BUFFER, drawbuffer)

			if not fbo then
				assert(not tex)
				
				--texWidth = tonumber(viewport.s[2])
				--texHeight = tonumber(viewport.s[3])
				--texWidth = windowWidth
				--texHeight = windowHeight

				tex = GLTex2D{
					width = texWidth,
					height = texHeight,
					type = gl.GL_UNSIGNED_BYTE,
					format = gl.GL_RGB,
					internalFormat = gl.GL_RGB,
					minFilter = gl.GL_NEAREST,
					magFilter = gl.GL_LINEAR,
				}
				fbo = FBO()
				fbo:setColorAttachmentTex2D(0, tex.id, tex.target, 0)
				glreport'here'
			
				renderShader = R:createShader{
					vertexCode = [[
varying vec4 color;
varying vec2 tc;
void main() {
	tc = gl_MultiTexCoord0.xy;
	color = gl_Color;
	gl_Position = ftransform();
}
]],
					fragmentCode = [[
varying vec2 tc;
varying vec4 color;
uniform sampler2D tex;
uniform vec2 texSize;

vec2 cplxmul(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void main() {
	//now march from the view origin (pass this as a uniform ... pass bounds too)
	// to 'tc'

	vec3 grey = vec3(.3, .6, .1);
	vec2 du = vec2(1. / texSize.x, 0.);
	vec2 dv = vec2(0., 1. / texSize.y);

	vec2 origin = vec2(.5, .55);
	float numSteps = 100.;
	
	vec2 raypos = origin;
	vec2 rayvel = (tc - origin) / numSteps;
	float raylength = length(rayvel);
	vec2 raydir = rayvel / raylength;
	
	vec4 color = vec4(1.);

	for (float i = 0; i < numSteps; ++i) {
		raypos += raydir * raylength;
	
		//now add color slope to raydir and normalize
		vec2 dl = vec2(
			.5 * (dot(grey, texture2D(tex, raypos + du)) - dot(grey, texture2D(tex, raypos - du))),
			.5 * (dot(grey, texture2D(tex, raypos + dv)) - dot(grey, texture2D(tex, raypos - dv)))
		);
		dl = normalize(dl);
		raydir = normalize(mix(raydir, cplxmul(raydir, dl), .01));

		vec4 sampleColor = texture2D(tex, raypos);
		float opacity = dot(grey, sampleColor);
		opacity = 1. - pow(1. - opacity, 1. / 8.);
		color *= 1. - opacity;
		color += opacity * sampleColor;
	}

	gl_FragColor = color;
}
]],
					uniforms = {
						tex = 0,
						texSize = {texWidth, texHeight},
					},
				}
			end

			if preDrawCallback then preDrawCallback(...) end

			-- setup FBO

			--gl.glViewport(0, 0, viewport.s[2], viewport.s[3])
			gl.glViewport(0, 0, texWidth, texHeight)
			fbo:bind()
			gl.glDrawBuffer(gl.GL_COLOR_ATTACHMENT0)
			gl.glClear(gl.GL_COLOR_BUFFER_BIT)
		end, function(...)
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

			--[[
			local x = math.min(1, tonumber(viewport.s[0]) / texWidth)
			local y = math.min(1, tonumber(viewport.s[1]) / texHeight)
			local w = math.min(1, tonumber(viewport.s[2]) / texWidth)
			local h = math.min(1, tonumber(viewport.s[3]) / texHeight)
			--]]
			-- [[
			local x,y,w,h = 0,0,1,1
			--]]

			renderShader:use()
			tex:bind()
			gl.glBegin(gl.GL_TRIANGLE_STRIP)
			gl.glTexCoord2f(x, y)		gl.glVertex2f(0, 0)
			gl.glTexCoord2f(x+w, y)     gl.glVertex2f(1, 0)
			gl.glTexCoord2f(x, y+h)     gl.glVertex2f(0, 1)
			gl.glTexCoord2f(x+w, y+h)   gl.glVertex2f(1, 1)
			gl.glEnd()
			tex:unbind()
			renderShader:useNone()

			gl.glMatrixMode(gl.GL_PROJECTION)
			gl.glPopMatrix()
			gl.glMatrixMode(gl.GL_MODELVIEW)
			gl.glPopMatrix()

			if postRenderCallback then postRenderCallback(...) end
		
			glreport'here'
		end, ...)
		glreport'here'
	end

	return PostFBOTemplate
end
