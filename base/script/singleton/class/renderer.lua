local ffi = require 'ffi'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local modio = require 'base.script.singleton.modio'

local matrix = require 'matrix.ffi'
matrix.real = 'float'

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

	local vertexes = ffi.new('float[12]',
		0, 0, 0,
		1, 0, 0,
		0, 1, 0,
		1, 1, 0
	)
	local tristrip = ffi.new('unsigned short[4]',
		0,1,2,3
	)

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

		self.projMat = matrix{4,4}:zeros()
		self.mvMat = matrix{4,4}:zeros()
		self.mvProjMat = matrix{4,4}:zeros()

		self.identMat = matrix{4,4}:zeros()
		self.identMat:setIdent()

		local texsys = modio:require 'script.singleton.texsys'
		texsys:setVars(gl,GLTex2D,{
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
		})

		-- default shader
		self.shader = GLProgram{
			vertexCode = [[
#version 320 es
precision highp float;

layout(location=0) in vec2 vertex;

out vec2 tc;

uniform mat4 mvProjMat;

uniform vec4 rect;
uniform vec4 texrect;	//xy = texcoord offset, zw = texcoord size
uniform vec4 centerAndRot;	//zw = cos(angle), sin(angle)

void main() {
	tc = texrect.xy + texrect.zw * vertex;

	vec2 rxy = vertex * rect.zw - centerAndRot.xy;
	rxy = vec2(
		rxy.x * centerAndRot.z - rxy.y * centerAndRot.w,
		rxy.y * centerAndRot.z + rxy.x * centerAndRot.w
	);
	rxy += centerAndRot.xy + rect.xy;
	gl_Position = mvProjMat * vec4(rxy, 0., 1.);
}
]],
			fragmentCode = [[
#version 320 es
precision highp float;

in vec2 tc;

out vec4 fragColor;

uniform vec4 color;
uniform sampler2D tex;

void main() {
	fragColor = color * texture(tex, tc);
}
]],
			uniforms = {
				color = {1,1,1,1},
				tex = 0,
			},
		}
	end
	function GLRenderer:ortho(...)
		self.projMat:setOrtho(...)
		self.mvProjMat:mul4x4(self.projMat, self.mvMat)
	end
	function GLRenderer:viewPos(x,y)
		self.mvMat:setTranslate(-x,-y,0)
		self.mvProjMat:mul4x4(self.projMat, self.mvMat)
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

		shader = shader or self.shader
		shader:use()
		if shader.uniforms.mvProjMat then
			gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, self.mvProjMat.ptr)
		end
		if uniforms then
			for k,v in pairs(uniforms) do
				local loc = shader.uniforms[k].loc
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

		local costh, sinth
		if angle then
			local radians = math.rad(angle)
			costh = math.cos(radians)
			sinth = math.sin(radians)
		else
			costh, sinth = 1, 0
		end
		-- and set uniforms ...
		if shader.uniforms.color then
			gl.glUniform4f(shader.uniforms.color.loc, r, g, b, a)
		end
		if shader.uniforms.rect then
			gl.glUniform4f(shader.uniforms.rect.loc, x, y, w, h)
		end
		if shader.uniforms.texrect then
			gl.glUniform4f(shader.uniforms.texrect.loc, tx, ty, tw, th)
		end
		if shader.uniforms.centerAndRot then
			gl.glUniform4f(shader.uniforms.centerAndRot.loc, rcx, rcy, costh, sinth)
		end

		gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, false, 12, vertexes)
		gl.glEnableVertexAttribArray(0)
		gl.glDrawElements(gl.GL_TRIANGLE_STRIP,4,gl.GL_UNSIGNED_SHORT,tristrip)
        gl.glDisableVertexAttribArray(0)

		shader:useNone()
	end
end

-- TODO I can get rid of this once I replace all gl->gles2 content, then I can just use the gles2 library with the typical gl renderer
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
			uniforms={tex=0},
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
		gl.glUniform1i(shader.uniforms.tex.loc, 0);
		gl.glUniform4fv(shader.uniforms.color.loc, 1, color)
		gl.glUniformMatrix4fv(shader.uniforms.vtxmat.loc, 1, false, pmvmat.v)
		gl.glUniformMatrix4fv(shader.uniforms.texmat.loc, 1, false, texmat.v)
 		if uniforms then
			for k,v in pairs(uniforms) do
				local loc = shader.uniforms[k].loc
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
