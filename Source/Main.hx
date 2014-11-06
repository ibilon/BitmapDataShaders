package;

import openfl.display.*;
import openfl.geom.*;
import openfl.gl.*;
import openfl.utils.*;
import openfl.Assets;

class Main extends Sprite {

	private var view:OpenGLView;

	public function new () {

		super ();

		if (OpenGLView.isSupported) {

			var shader = "varying vec2 vTexCoord;
			uniform sampler2D uImage0;
			
			void main(void)
			{
				vec4 color = texture2D (uImage0, vTexCoord);
				gl_FragColor = vec4 (1 - color.r, 1 - color.g, 1 - color.b, color.a);
			}";

			var source = Assets.getBitmapData ("assets/openfl.png");
			var result = applyShader (source, shader);

			var bitmap_source = new Bitmap (source);
			addChild (bitmap_source);

			var bitmap_result = new Bitmap (result);
			addChild (bitmap_result);

			bitmap_result.x = bitmap_source.width;

		} else {

			trace("Couldn't get openGL view");

		}

	}

	public static function applyShader (source:BitmapData, fragmentSource:String) : BitmapData {

		var width = source.width;
		var height = source.height;
		var size = width * height * 4;
		source = source.clone();

		// FrameBuffer construction

		var texture = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, texture);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.REPEAT);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.REPEAT);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);

        GL.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);

        var framebuffer = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer);

        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, texture, 0);

        var renderBuffer = GL.createRenderbuffer();
        GL.bindRenderbuffer(GL.RENDERBUFFER, renderBuffer);
        GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT, width, height);

        GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, renderBuffer);

        var status = GL.checkFramebufferStatus(GL.FRAMEBUFFER);
        switch(status)
        {
            case GL.FRAMEBUFFER_COMPLETE:
            
            default:
				trace ("FrameBuffer error");
				return null;
        }
        
        // Draw
        
        var vertexSource = 
					
			"attribute vec4 aPosition;
			attribute vec2 aTexCoord;
			varying vec2 vTexCoord;
			
			uniform mat4 uMatrix;
			
			void main(void) {
				
				vTexCoord = aTexCoord;
				gl_Position = uMatrix * aPosition;
				
			}";
		
		var program = GLUtils.createProgram (vertexSource, fragmentSource);
		GL.useProgram (program);
		
		var vertexAttribute = GL.getAttribLocation (program, "aPosition");
		var textureAttribute = GL.getAttribLocation (program, "aTexCoord");
		var matrixUniform = GL.getUniformLocation (program, "uMatrix");
		var imageUniform = GL.getUniformLocation (program, "uImage0");
		
		GL.enableVertexAttribArray (vertexAttribute);
		GL.enableVertexAttribArray (textureAttribute);
		GL.uniform1i (imageUniform, 0);
		
		var data = [
			
			width, height, 0, 1, 1,
			0, height, 0, 0, 1,
			width, 0, 0, 1, 0,
			0, 0, 0, 0, 0
			
		];
		
		var buffer = GL.createBuffer ();
		GL.bindBuffer (GL.ARRAY_BUFFER, buffer);
		GL.bufferData (GL.ARRAY_BUFFER, new Float32Array (cast data), GL.STATIC_DRAW);
		GL.bindBuffer (GL.ARRAY_BUFFER, null);
		
		var textureDisplay = GL.createTexture ();
		GL.bindTexture (GL.TEXTURE_2D, textureDisplay);
		GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
		GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
		GL.texImage2D (GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, new UInt8Array (BitmapData.getRGBAPixels (source)));
		GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
		GL.texParameteri (GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
		GL.bindTexture (GL.TEXTURE_2D, null);
		
		GL.viewport (0, 0, width, height);
		
		GL.clearColor (0.0, 0.0, 0.0, 1.0);
		GL.clear (GL.COLOR_BUFFER_BIT);
		
		var matrix = Matrix3D.createOrtho (0, width, height, 0, -1000, 1000);
		GL.uniformMatrix4fv (matrixUniform, false, Float32Array.fromMatrix(matrix));
		
		GL.activeTexture (GL.TEXTURE0);
		GL.bindTexture (GL.TEXTURE_2D, textureDisplay);
		GL.enable (GL.TEXTURE_2D);
		
		GL.bindBuffer (GL.ARRAY_BUFFER, buffer);
		GL.vertexAttribPointer (vertexAttribute, 3, GL.FLOAT, false, 5 * Float32Array.SBYTES_PER_ELEMENT, 0);
		GL.vertexAttribPointer (textureAttribute, 2, GL.FLOAT, false, 5 * Float32Array.SBYTES_PER_ELEMENT, 3 * Float32Array.SBYTES_PER_ELEMENT);
		
		GL.drawArrays (GL.TRIANGLE_STRIP, 0, 4);

        // Get result
         
        var result = new ByteArray (size);
        GL.readPixels(0, 0, width, height, GL.RGBA, GL.UNSIGNED_BYTE, result);
        
		// Clean up

        GL.deleteTexture(texture);
        GL.deleteTexture(textureDisplay);
        GL.deleteRenderbuffer(renderBuffer);
        GL.deleteBuffer(buffer);

        GL.bindFramebuffer(GL.FRAMEBUFFER, null);
        GL.deleteFramebuffer(framebuffer);
        
        // Make final BitmapData
		
		var res = new BitmapData(width, height, true);
		
		var index = 0;
		for (y in 0...height)
		{
			for (x in 0...width)
			{
				var r = result.readUnsignedByte();
				var g = result.readUnsignedByte();
				var b = result.readUnsignedByte();
				var a = result.readUnsignedByte();
				
				var color = (a << 24) + (r << 16) + (g << 8) + b;				
				res.setPixel32(x, height - y - 1, color);
			}
		}
		
		return res;

	}

}

class GLUtils {
	
	
	public static function compileShader (source:String, type:Int):GLShader {
		
		var shader = GL.createShader (type);
		GL.shaderSource (shader, source);
		GL.compileShader (shader);
		
		if (GL.getShaderParameter (shader, GL.COMPILE_STATUS) == 0) {
			
			switch (type) {
				
				case GL.VERTEX_SHADER: throw "Error compiling vertex shader";
				case GL.FRAGMENT_SHADER: throw "Error compiling fragment shader";
				default: throw "Error compiling unknown shader type";
				
			}
			
		}
		
		return shader;
		
	}
	
	
	public static function createProgram (vertexSource:String, fragmentSource:String):GLProgram {
		
		var vertexShader = compileShader (vertexSource, GL.VERTEX_SHADER);
		var fragmentShader = compileShader (fragmentSource, GL.FRAGMENT_SHADER);
		
		var program = GL.createProgram ();
		GL.attachShader (program, vertexShader);
		GL.attachShader (program, fragmentShader);
		GL.linkProgram (program);
		
		if (GL.getProgramParameter (program, GL.LINK_STATUS) == 0) {
			
			throw "Unable to initialize the shader program.";
			
		}
		
		return program;
		
	}
	
	
}
