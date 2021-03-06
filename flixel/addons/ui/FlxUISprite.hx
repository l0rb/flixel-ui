package flixel.addons.ui;

import flixel.addons.ui.FlxUI.UIEventCallback;
import flixel.addons.ui.interfaces.IFlxUIWidget;
import flixel.addons.ui.interfaces.IResizable;
import flixel.FlxSprite;
import flixel.animation.FlxAnimation;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxGraphicAsset;

/**
 * Cheap extension of FlxSprite
 * @author Lars Doucet
 */
class FlxUISprite extends FlxSprite implements IFlxUIWidget implements IResizable
{
	public var broadcastToFlxUI:Bool = true;

	// simple string ID, handy for identification, etc
	public var name:String;

	// pointer to the thing that "owns" it
	public var ptr_owner:Dynamic = null;

	// whether it has ever been recycled or not (useful for object pooling)
	public var recycled:Bool = false;

	public static inline var RESIZE_RATIO_X:Int = 0;
	public static inline var RESIZE_RATIO_Y:Int = 1;
	public static inline var RESIZE_RATIO_UNKNOWN:Int = -1;

	// what the image's aspect ratio is for rescaling by just X or just Y
	public var resize_ratio(default, set):Float;

	// whether the resize_ratio means X in terms of Y, or Y in terms of X
	public var resize_ratio_axis:Int = RESIZE_RATIO_Y;

	public var scale_on_resize:Bool = false;

	private function set_resize_ratio(r:Float):Float
	{
		resize_ratio = r;
		return r;
	}

	// resize about this point, so that after resizing this point in the object remains in the same place on screen
	public var resize_point(default, set):FlxPoint;

	private function set_resize_point(r:FlxPoint):FlxPoint
	{
		if (r != null)
		{
			if (resize_point == null)
			{
				resize_point = new FlxPoint();
			}
			resize_point.x = r.x;
			resize_point.y = r.y;
		}
		return resize_point;
	}

	public function new(X:Float = 0, Y:Float = 0, SimpleGraphic:Dynamic = null)
	{
		super(X, Y, SimpleGraphic);
	}

	override public function clone():FlxSprite
	{
		var fuis:FlxUISprite = new FlxUISprite();
		fuis.loadGraphicFromSprite(this);
		fuis.broadcastToFlxUI = broadcastToFlxUI;
		fuis.ptr_owner = ptr_owner;
		fuis.resize_ratio = resize_ratio;
		fuis.resize_ratio_axis = resize_ratio_axis;
		fuis.scale_on_resize = scale_on_resize;
		fuis.resize_point = resize_point;
		fuis.x = x;
		fuis.y = y;
		return fuis;
	}

	public function recycle(data:Dynamic):Void
	{
		recycled = true;
		// override per subclass
	}

	public function resize(w:Float, h:Float):Void
	{
		var old_width:Float = width;
		var old_height:Float = height;

		if (resize_ratio > 0)
		{
			var effective_ratio:Float = (w / h);
			if (Math.abs(effective_ratio - resize_ratio) > 0.0001)
			{
				if (resize_ratio_axis == RESIZE_RATIO_Y)
				{
					h = w * (1 / resize_ratio);
				}
				else
				{
					w = h * (1 / resize_ratio);
				}
			}
		}

		if (!scale_on_resize)
		{
			if (_originalKey != "" && _originalKey != null)
			{
				if (animation.frames > 1)
				{
					// it's animated
					var newScale = h / old_height;
					var tileW = Std.int(frameWidth * newScale);
					var tileH = Std.int(frameHeight * newScale);
					var imgSrc = U.scaleAndStoreTileset(_originalKey, newScale, frameWidth, frameHeight, tileW, tileH, true);
					if (imgSrc != "" && imgSrc != null)
					{
						loadFromScaledGraphic(imgSrc, true, tileW, tileH);
					}
				}
				else
				{
					var newKey:String = U.loadScaledImage(_originalKey, w, h);
					if (newKey != "" && newKey != null)
					{
						loadFromScaledGraphic(newKey);
					}
				}
			}
		}

		if (scale_on_resize)
		{
			scale.set(w / graphic.bitmap.width, h / graphic.bitmap.height);
			updateHitbox();
			width = w;
			height = h;
		}

		var diff_w:Float = width - old_width;
		var diff_h:Float = height - old_height;

		if (resize_point != null)
		{
			var delta_x:Float = diff_w * resize_point.x;
			var delta_y:Float = diff_h * resize_point.y;
			x -= delta_x;
			y -= delta_y;
		}
	}

	public function loadGraphicAtScale(GraphicKey:String, W:Float, H:Float):Void
	{
		loadGraphic(GraphicKey, false);
		resize(W, H);
	}

	/**
	 * Load an image from an embedded graphic file.
	 * 
	 * @param	Graphic		The image you want to use.
	 * @param	Animated	Whether the Graphic parameter is a single sprite or a row of sprites.
	 * @param	Width		Optional, specify the width of your sprite (helps FlxSprite figure out what to do with non-square sprites or sprite sheets).
	 * @param	Height		Optional, specify the height of your sprite (helps FlxSprite figure out what to do with non-square sprites or sprite sheets).
	 * @param	Unique		Optional, whether the graphic should be a unique instance in the graphics cache.  Default is false.
	 * @param	Key			Optional, set this parameter if you're loading BitmapData.
	 * @return	This FlxSprite instance (nice for chaining stuff together, if you're into that).
	 */
	public override function loadGraphic(Graphic:FlxGraphicAsset, Animated:Bool = false, Width:Int = 0, Height:Int = 0, Unique:Bool = false,
			?Key:String):FlxSprite
	{
		var sprite = super.loadGraphic(Graphic, Animated, Width, Height, Unique, Key);
		if (graphic != null)
		{
			_originalKey = graphic.assetsKey;
			if (_originalKey == null)
			{
				_originalKey = graphic.key;
			}
		}
		return sprite;
	}

	public override function destroy():Void
	{
		ptr_owner = null;
		super.destroy();
	}

	private function loadFromScaledGraphic(Graphic:FlxGraphicAsset, Animated:Bool = false, Width:Int = 0, Height:Int = 0, Unique:Bool = false,
			?Key:String):Void
	{
		super.loadGraphic(Graphic, Animated, Width, Height, Unique, Key);
	}

	private var _originalKey:String = "";
}
