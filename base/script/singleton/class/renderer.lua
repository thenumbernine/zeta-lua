local modio = require 'base.script.singleton.modio'

local Renderer = class()
Renderer.requireClasses = {}

do
	local GLRenderer = class(Renderer)
	GLRenderer.glname = 'gl'
	Renderer.requireClasses.gl = GLRenderer

	local uvs = {
		vec2(0,0),
		vec2(1,0),
		vec2(1,1),
		vec2(0,1),
	}

	local GLTex2D
	local GLProgram
	local glreport
	local gl
	function GLRenderer:init(gl_)
		self.gl = gl_
		gl = gl_
		GLTex2D = require 'gl.tex2d'
		GLProgram = require 'gl.program'
		glreport = require 'gl.report'

		local texsys = modio:require 'script.singleton.texsys'
		texsys:setVars(gl,GLTex2D,{
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		})
	end
	function GLRenderer:ortho(a,b,c,d,e,f)
		gl.glMatrixMode(gl.GL_PROJECTION)
		gl.glLoadIdentity()
		gl.glOrtho(a,b,c,d,e,f)
	end
	function GLRenderer:viewPos(x,y)
		gl.glMatrixMode(gl.GL_MODELVIEW)
		gl.glLoadIdentity()
		gl.glTranslatef(-x,-y,0)
	end
	function GLRenderer:report(s)
		glreport(s)
	end
	function GLRenderer:createShader(args)
		return GLProgram(args)
	end
	local f4 = ffi.new('float[4]')
	function GLRenderer:quad(
		x,y,
		w,h,
		tx,ty,
		tw,th,
		angle,
		r,g,b,a,
		shader,
		uniforms,
		rcx, rcy
	)
		rcx = rcx or 0
		rcy = rcy or 0
		
		if shader then
			gl.glUseProgram(shader.id)
			if uniforms then
				for k,v in pairs(uniforms) do
					local loc = shader.uniforms[k]
					if not loc then
						error('tried to set unknown uniform '..k)
					end
					if type(v) == 'number' then
						gl.glUniform1f(loc, v)
					elseif type(v) == 'table' then
						if #v == 3 then
							for i=0,2 do
								f4[i] = v[i+1]
							end
							gl.glUniform3fv(loc, 1, f4)
						elseif #v == 4 then
							for i=0,3 do
								f4[i] = v[i+1]
							end
							gl.glUniform4fv(loc, 1, f4)
						else
							error('uniform cant handle table of length '..#v)
						end
					else
						error('cant handle uniform type '..type(v))
					end
				end
			end
		else
			gl.glEnable(gl.GL_TEXTURE_2D)
		end
		local costh, sinth
		if angle then
			local radians = math.rad(angle)
			costh = math.cos(radians)
			sinth = math.sin(radians)
		end
		-- and set uniforms ...
		gl.glColor4f(r,g,b,a)
		gl.glBegin(gl.GL_QUADS)
		for _,uv in ipairs(uvs) do
			gl.glTexCoord2f(tx + tw * uv[1], ty + th * uv[2])
			local rx, ry = w * uv[1], h * uv[2]
			if angle then
				rx, ry = rx - rcx, ry - rcy
				rx, ry = rx * costh - ry * sinth, rx * sinth + ry * costh
				rx, ry = rx + rcx, ry + rcy
			end
			gl.glVertex2f(x + rx, y + ry)
		end
		gl.glEnd()
		if shader then
			gl.glUseProgram(0)
		else
			gl.glDisable(gl.GL_TEXTURE_2D)
		end
	end
end

do
	local GLES2Renderer = class(Renderer)
	GLES2Renderer.glname = 'OpenGLES2'
	Renderer.requireClasses.OpenGLES2 = GLES2Renderer
	local vertexes = ffi.new('float[12]',
		0, 0, 0,
		1, 0, 0,
		0, 1, 0,
		1, 1, 0
	)
	local tristrip = ffi.new('unsigned short[4]',
		0,1,2,3
	)
	local color = ffi.new('float[4]')

	local gl
	local GLTex2D, GLProgram, GLMatrix4x4
	local shader
	local viewx, viewy = 0, 0
	local mvmat, projmat, texmat
	function GLES2Renderer:init(gl_)
		self.gl = gl_
		gl = gl_
		gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1)
		GLMatrix4x4 = require 'gles2.matrix4'
		GLProgram = require 'gles2.program'
		GLTex2D = require 'gles2.tex2d'
		local texsys = modio:require 'script.singleton.texsys'
		texsys:setVars(gl, GLTex2D, {
			minFilter = gl.GL_NEAREST, --gl.GL_LINEAR,
			magFilter = gl.GL_NEAREST, --gl.GL_LINEAR,
		})

		texmat = GLMatrix4x4()
		mvmat = GLMatrix4x4()
		projmat = GLMatrix4x4()
		pmvmat = GLMatrix4x4()
		shader = GLProgram{
			vertexCode = [[
uniform mat4 vtxmat;
uniform mat4 texmat;
attribute vec4 pos;
varying vec2 tc;
void main() {
	tc = (texmat * pos).xy;
	gl_Position = vtxmat * pos;
} 
]],
			fragmentCode=[[
precision mediump float;
uniform vec4 color;
uniform sampler2D tex;
varying vec2 tc;
void main() {
	gl_FragColor = color * texture2D(tex, tc);
} 
]],
			attributes={'pos'},
			uniforms={'vtxmat','texmat','color','tex'},
		}
	end
	function GLES2Renderer:createTex2D(args)
		return GLTex2D(args)
	end
	function GLES2Renderer:createShader(args)
		local newargs = {}
		for k,v in pairs(args) do newargs[k] = v end
		newargs.vertexCode = '#define ANDROID\n'..newargs.vertexCode
		newargs.fragmentCode = '#define ANDROID\n'..newargs.fragmentCode
		return GLProgram(newargs)
	end
	function GLES2Renderer:ortho(a,b,c,d,e,f)
		projmat:ortho(a,b,c,d,e,f)
	end
	function GLES2Renderer:viewPos(x,y)
		viewx = x
		viewy = y
	end
	local f4 = ffi.new('float[4]')
	function GLES2Renderer:quad(
		x,y,
		w,h,
		tx,ty,
		tw,th,
		angle,	-- TODO
		r,g,b,a,
		customShader,
		uniforms
	)
		local shader = customShader or shader
		-- rotate would go between the two...
		texmat:translateMultScale(tx,ty,0,tw,th,1)
		mvmat:translateMultScale(x-viewx,y-viewy,0,w,h,1)
		pmvmat:mult(projmat,mvmat)
		color[0] = r
		color[1] = g
		color[2] = b
		color[3] = a
		gl.glUseProgram(shader.id)
		gl.glVertexAttribPointer(shader.attributes.pos, 3, gl.GL_FLOAT, false, 12, vertexes)
		gl.glEnableVertexAttribArray(shader.attributes.pos)
		gl.glUniform1i(shader.uniforms.tex, 0);
		gl.glUniform4fv(shader.uniforms.color, 1, color)
		gl.glUniformMatrix4fv(shader.uniforms.vtxmat, 1, false, pmvmat.v)
		gl.glUniformMatrix4fv(shader.uniforms.texmat, 1, false, texmat.v)
 		if uniforms then
			for k,v in pairs(uniforms) do
				local loc = shader.uniforms[k]
				if not loc then
					error('tried to set unknown uniform '..k)
				end
				if type(v) == 'number' then
					gl.glUniform1f(loc, v)
				elseif type(v) == 'table' then
					if #v == 3 then
						for i=0,2 do
							f4[i] = v[i+1]
						end
						gl.glUniform3fv(loc, 1, f4)
					elseif #v == 4 then
						for i=0,3 do
							f4[i] = v[i+1]
						end
						gl.glUniform4fv(loc, 1, f4)
					else
						error('uniform cant handle table of length '..#v)
					end
				else
					error('cant handle uniform type '..type(v))
				end
			end
		end
		gl.glDrawElements(gl.GL_TRIANGLE_STRIP,4,gl.GL_UNSIGNED_SHORT,tristrip)
        gl.glDisableVertexAttribArray(shader.attributes.pos)
		gl.glUseProgram(0)
	end
	function GLES2Renderer:report(s)
		local err = gl.glGetError()
		if err == 0 then return end
		if s then s = tostring(s)..': ' end
		print(s..err)
		print(debug.traceback())
	end
end

return Renderer
