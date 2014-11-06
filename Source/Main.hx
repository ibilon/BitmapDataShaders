package;

import openfl.display.Bitmap;
import openfl.display.OpenGLView;
import openfl.display.Sprite;
import openfl.Assets;

class Main extends Sprite {

	private var view:OpenGLView;

	public function new () {

		super ();

		if (OpenGLView.isSupported) {

			ShaderCompositing.init (400, 400);

			var c1 = ShaderCompositing.uploadLayers ([Assets.getBitmapData ("assets/c1_bottom.png"), Assets.getBitmapData ("assets/c1_middle.png"), Assets.getBitmapData ("assets/c1_top.png")]);
			var c2 = ShaderCompositing.uploadLayers ([Assets.getBitmapData ("assets/c2_bottom.png"), Assets.getBitmapData ("assets/c2_middle.png"), Assets.getBitmapData ("assets/c2_top.png")]);

			var shader = "varying vec2 vTexCoord;
			uniform sampler2D uImage0;
			uniform vec3 param;
			
			void main (void)
			{
				vec4 color = texture2D (uImage0, vTexCoord);
				gl_FragColor = vec4 (color.r + param.r, color.g + param.g, color.b + param.b, color.a);
			}";

			var c1_bitmap = new Bitmap (ShaderCompositing.composite (c1, shader, [{name: "param", value: [0.2, 0.5, 0.2], type: Float3}]));
			var c2_bitmap = new Bitmap (ShaderCompositing.composite (c2, shader, [{name: "param", value: [0.2, 0.5, 0.2], type: Float3}]));

			addChild (c1_bitmap);
			addChild (c2_bitmap);
			c2_bitmap.x = c1_bitmap.width + 20;

			var shader = "varying vec2 vTexCoord;
			uniform sampler2D uImage0;

			void main (void)
			{
				vec4 color = texture2D (uImage0, vTexCoord);
				float c = 0.3*color.r + 0.59*color.g + 0.11*color.b;
				gl_FragColor = vec4 (c, c, c, color.a);
			}";

			var c1_bitmap = new Bitmap (ShaderCompositing.composite (c1, shader));
			var c2_bitmap = new Bitmap (ShaderCompositing.composite (c2, shader));

			addChild (c1_bitmap);
			c1_bitmap.y = 420;
			addChild (c2_bitmap);
			c2_bitmap.y = 420;
			c2_bitmap.x = c1_bitmap.width + 20;

			c1.delete ();
			c2.delete ();

			ShaderCompositing.clean ();

		} else {

			trace("Couldn't get openGL view");

		}

	}

}


