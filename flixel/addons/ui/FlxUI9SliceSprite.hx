package flixel.addons.ui;

import flash.display.BitmapData;
import flash.display.Sprite;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flixel.FlxSprite;
import flixel.addons.ui.interfaces.IFlxUIWidget;
import flixel.addons.ui.interfaces.IResizable;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxTilemapGraphicAsset;
import flixel.tile.FlxTilemap;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.tile.FlxBaseTilemap.FlxTilemapAutoTiling;
import openfl.Assets;

/**
 * @author Lars Doucet
 */
class FlxUI9SliceSprite extends FlxUISprite implements IResizable implements IFlxUIWidget 
{
	private static var bitmapsCreated:Int = 0;	// for debug

	private var _bmpCanvas:BitmapData;
	
	private static var useSectionCache:Bool = true;
	private static var sectionCache:Map<String,BitmapData>;	 //  key: assetId + "_" + src.left + "_" + src.top + "_" + src.width + "_" + src.height + "_"
															 //value: bitmapData for that section
															 
	private static var cacheCounter:Map<String,SectionCounter>;			// key: assetId + "_" + slice9String + "_" + rectangle
																		//value: SectionCounter
																		//		   - useCount
																		//		   - array of keys generated by this configuration
	private var paintScale9_id:String = "";
	
	private var _slice9:Array<Int> = null;
	
	private var _tile:Int = TILE_NONE;			//tile neither
	private var _smooth:Bool = false;
	
	private var _asset_id:String = "";
	
	private var _useSubSprites:Bool = false;
	private var _subSprites:FlxSpriteGroup;
	private var _subSpriteTiles:Array<FlxTilemap>;
	
	private var _raw_pixels:BitmapData;
	
	//for internal static use
	private static var _staticPoint:Point = new Point();
	private static var _staticRect:Rectangle = new Rectangle();
	private static var _staticRect2:Rectangle = new Rectangle();
	
	private static var _staticPointZero:Point = new Point(0, 0);	//ALWAYS 0,0
	private static var _staticMatrix:Matrix = new Matrix();
	
	private static var _staticFlxRect:FlxRect = FlxRect.get();
	private static var _staticFlxRect2:FlxRect = FlxRect.get();
	
	//specialty smoothing modes
	public static inline var TILE_NONE:Int = 0x00;
	public static inline var TILE_BOTH:Int = 0x11;
	public static inline var TILE_H:Int = 0x10;
	public static inline var TILE_V:Int = 0x01;
	
	//rectangle map
	private static var _staticRects:Map<String,FlxRect>;
	
	/** 
	 * @param	X	X position of final sprite
	 * @param	Y	Y position of final sprite
	 * @param	Graphic	Asset
	 * @param	Rect	Width/Height of the final scaled sprite
	 * @param	slice9	[x1,y1,x2,y2] : 2 points (upper-left middle and lower-right middle) that define the 9-slice grid
	 * @param	tile	Whether to tile the middle pieces or stretch them (default is false --> stretch)
	 * @param	smooth	When stretching, whether to smooth middle pieces (default false)
	 * @param 	id	if Graphic is a BitmapData, manually specify its original source id, if any
	 * @param   ratio	Resize ratio to force, if desired (W/H)
	 * @param	Resize_point	Point for anchoring resizes
	 * @param	Resize_axis	Whether resizing is based around the X or Y axis
	 * @param	Color	Color to tint this graphic to.  (White has no effect.)
	 */
	
	public function new(X:Float, Y:Float, Graphic:Dynamic, Rect:Rectangle, Slice9:Array<Int>=null, Tile:Int=TILE_NONE, Smooth:Bool=false, Id:String="",Ratio:Float=-1,Resize_point=null,Resize_axis:Int=FlxUISprite.RESIZE_RATIO_Y,DeferResize:Bool=false,Color:FlxColor=FlxColor.WHITE,UseSubSprites:Bool=false) 
	{
		super(X, Y, null);
		color = Color;
		
		_useSubSprites = UseSubSprites;
		if (_useSubSprites)
		{
			_subSprites = new FlxSpriteGroup();
			while(_subSprites.length < 9)
			{
				_subSprites.add(new FlxSprite(0, 0));
			}
			if (Tile != TILE_NONE)
			{
				_subSpriteTiles = [];
				while (_subSpriteTiles.length < 5)
				{
					_subSpriteTiles.push(new FlxTilemap());
				}
			}
		}
		
		_slice9 = Slice9;
		_tile = Tile;
		_smooth = Smooth;
				
		_asset_id = "";
		
		if (Graphic == null) {
			Graphic = FlxUIAssets.IMG_CHROME;
		}
		
		if(Std.is(Graphic,String)){
			_asset_id = Graphic;
			_raw_pixels = null;
		}else if (Std.is(Graphic, BitmapData)) {
			_asset_id = Id;
			_raw_pixels = cast Graphic;
		}else if (Std.is(Graphic, FlxGraphic)) {
			var fg:FlxGraphic = cast Graphic;
			_asset_id = fg.key;
			_raw_pixels = fg.bitmap;
		}
		
		resize_ratio = Ratio;
		resize_ratio_axis = Resize_axis;
		if (Resize_point != null) {
			resize_point = Resize_point;
		}
		
		if (DeferResize)
		{
			var pt = U.applyResize(resize_ratio, resize_ratio_axis, Rect.width, Rect.height);
			width = pt.x;
			height = pt.y;
		}
		else
		{
			resize(Rect.width, Rect.height);
		}
	}
	
	public override function destroy():Void
	{
		noLongerUsingCachedID(paintScale9_id);
		super.destroy();
	}
	
	public override function resize(w:Float, h:Float):Void {
		
		if (Std.int(w) < 1) {
			w = 1;
		}
		if (Std.int(h) < 1) {
			h = 1;
		}
		
		var old_width:Float = width;
		var old_height:Float = height;
		
		var pt = U.applyResize(resize_ratio, resize_ratio_axis, w, h);
		
		w = pt.x;
		h = pt.y;
		
		var iw = Std.int(pt.x);
		var ih = Std.int(pt.y);
		
		if (_slice9 == null || _slice9 == []) {
			_slice9 = [4, 4, 7, 7];
		}
		
		if (_useSubSprites)
		{
			resizeWithSubSprites(iw, ih);
		}
		else
		{
			resizeStandard(iw, ih);
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
	
	private function resizeStandard(iw:Int, ih:Int):Void
	{
		//for caching purposes:
		var key:String = _asset_id + "_" + _slice9.join(",") + "_" + iw + "x" + ih + "_"+_tile+"_"+_smooth;
		
		//check if something just like this already exists
		if (FlxG.bitmap.checkCache(key))
		{
			//just load the old one
			loadGraphic(key, false, iw, ih);
		}
		else
		{
			//make a fresh one
			var bmpCanvas = new BitmapData(iw, ih);
			_staticFlxRect.x = 0;
			_staticFlxRect.y = 0;
			_staticFlxRect.width = iw;
			_staticFlxRect.height = ih;
			
			var oldID:String = paintScale9_id;
			
			//see what the new configuration ID will be for this repaint
			var newID:String = makePaintScale9Id(_asset_id, _slice9, _staticFlxRect);
			
			//if it's different
			if (newID != oldID)
			{
				//redraw the image and get the new identifier
				paintScale9_id = paintScale9(bmpCanvas, _asset_id, _slice9, _staticFlxRect, _tile, _smooth, _raw_pixels);
			
				//add one to the uses for this configuration
				var sectionCounter = cacheCounter.get(paintScale9_id);
				sectionCounter.useCount++;
				
				noLongerUsingCachedID(oldID);
			}
			
			loadGraphic(bmpCanvas, false, bmpCanvas.width, bmpCanvas.height, false, key);
		}
	}
	
	private function resizeWithSubSprites(iw:Int, ih:Int):Void
	{
		_staticFlxRect.x = 0;
		_staticFlxRect.y = 0;
		_staticFlxRect.width = iw;
		_staticFlxRect.height = ih;
		
		_subSprites.x = 0;
		_subSprites.y = 0;
		paintScale9(null, _asset_id, _slice9, _staticFlxRect, _tile, _smooth, _raw_pixels, _subSprites);
		var pieces = _subSprites.members;
		for (i in 0...9)
		{
			var piece = pieces[i];
			switch(i)
			{
				case 0: piece.x = 0;                piece.y = 0;					//top left
				case 1: piece.x = iw - piece.width; piece.y = 0;					//top right
				case 2: piece.x = pieces[0].width;  piece.y = 0;					//top
				case 3: piece.x = 0;                piece.y = ih - piece.height;	//bottom left
				case 4: piece.x = iw - piece.width; piece.y = ih - piece.height;	//bottom right
				case 5: piece.x = pieces[3].width;  piece.y = ih - piece.height;	//bottom
				case 6: piece.x = 0;                piece.y = pieces[0].height;		//left
				case 7: piece.x = iw - piece.width; piece.y = pieces[1].height;		//right
				case 8: piece.x = pieces[6].width;  piece.y = pieces[2].height;		//middle
			}
		}
		
		if (_subSpriteTiles != null)
		{
			for (i in 0...5)
			{
				var tiles = _subSpriteTiles[i];
				var spanw = 0.0;
				var spanh = 0.0;
				var pw = Std.int(pieces[i].width);
				var ph = Std.int(pieces[i].height);
				var tilesf = 0.0;
				var tilesi = 0;
				var remainder = 0.0;
				var tileGfx:FlxTilemapGraphicAsset = null;
				var piece = null;
				var wit = 0;
				var hit = 0;
				
				tiles.x = 0;
				tiles.y = 0;
				
				FlxG.bitmapLog.add(pieces[i].graphic.bitmap, "tile:" + i);
				
				switch(i)
				{
					case 0: spanw = iw - pieces[0].width - pieces[1].width;		//top
							tilesf = spanw / pw;
							hit = 1;
							
							piece = pieces[2];
							tiles.x = pieces[2].x;
							tiles.y = pieces[2].y;
							
					case 1: spanw = iw - pieces[3].width - pieces[4].width;		//bottom
							tilesf = spanw / pw;
							hit = 1;
							
							piece = pieces[5];
							tiles.x = pieces[5].x;
							tiles.y = pieces[5].y;
							
					case 2: spanh = ih - pieces[0].height - pieces[3].height;	//left
							tilesf = spanh / ph;
							wit = 1;
							
							piece = pieces[6];
							tiles.x = pieces[6].x;
							tiles.y = pieces[6].y;
							
					case 3: spanh = ih - pieces[1].height - pieces[4].height;	//right
							tilesf = spanh / ph;
							wit = 1;
							
							piece = pieces[7];
							tiles.x = pieces[7].x;
							tiles.y = pieces[7].y;
							
					case 4: spanw = iw - pieces[0].width - pieces[1].width;		//center
							tilesf = spanw / pw;
							tilesi = Std.int(tilesf);
							wit = tilesi;
							
							var remainderx = tilesf - tilesi;
							
							spanh = ih - pieces[0].height - pieces[3].height;
							tilesf = spanh / ph;
							tilesi = Std.int(tilesf);
							hit = tilesi;
							
							piece = pieces[8];
							tiles.x = pieces[8].x;
							tiles.y = pieces[8].y;
							
							var remaindery = tilesf - tilesi;
							
							var rxi = remainderx > 0 ? 1 : 0;
							var ryi = remaindery > 0 ? rxi + 1 : 0;
							
							var map2D:Array<Array<Int>> = [];
							for (i in 0...hit)
							{
								var row:Array<Int> = [];
								for (j in 0...wit)
								{
									row.push(0);
								}
								if (rxi > 0) row.push(rxi);
								map2D.push(row);
							}
							if (ryi > 0)
							{
								var row:Array<Int> = [];
								for (j in 0...wit)
								{
									row.push(ryi);
								}
								map2D.push(row);
								if (rxi > 0) row.push(rxi);
								//if (rxi > 0) row.push(rxi + ryi);
							}
							
							tileGfx = getTilePixels2(piece.graphic.bitmap, remainderx, remaindery);
							
							//tileGfx = piece.graphic;
							
							/*var map2D:Array<Array<Int>> = [];
							for (i in 0...hit)
							{
								var row:Array<Int> = [];
								for (j in 0...wit)
								{
									row.push(0);
								}
								map2D.push(row);
							}*/
							
							tiles.loadMapFrom2DArray(map2D, tileGfx, pw, ph, FlxTilemapAutoTiling.OFF, 0, 0);
				}
				
				if (i != 4)
				{
					tilesi = Std.int(tilesf);
					
					remainder = tilesf - tilesi;
					
					var map = [];
					for (i in 0...tilesi)
					{
						map.push(0);
					}
					
					if (remainder > 0)
					{
						tilesi++;
						map.push(1);
					}
					
					if (wit == 1) hit = tilesi;
					if (hit == 1) wit = tilesi;
					
					tileGfx = piece.graphic;
					tileGfx = getTilePixels(piece.graphic.bitmap, remainder, hit == 1);
					
					tiles.loadMapFromArray(map, wit, hit, tileGfx, pw, ph, FlxTilemapAutoTiling.OFF, 0, 0);
				}
				
				switch(i)
				{
					case 0: tiles.x = pieces[2].x;	//top
							tiles.y = pieces[2].y;
							
					case 1: tiles.x = pieces[5].x;	//bottom
							tiles.y = ih - tiles.height;
							
					case 2: tiles.x = pieces[6].x;	//left
							tiles.y = pieces[6].y;
							
					case 3: tiles.x = iw - tiles.width;	//right
							tiles.y = pieces[7].y;
							
					case 4: tiles.x = pieces[8].x;	//center
							tiles.y = pieces[8].y;
				}
			}
		}
		
		_subSprites.x = x;
		_subSprites.y = y;
	}
	
	private static function getTilePixels2(bmp:BitmapData, remainder:Float, remainder2:Float):BitmapData
	{
		if (remainder == 0.0 && remainder2 == 0.0) return bmp;
		return U.combineTiles(
			[
				bmp, 
				getRemainderPixels(bmp, remainder, true),
				getRemainderPixels(bmp, remainder2, false)
			]
		);
	}
	
	private static function getTilePixels(bmp:BitmapData, remainder:Float, horizontal:Bool):BitmapData
	{
		return U.combineTiles([bmp, getRemainderPixels(bmp, remainder, horizontal)]);
	}
	
	private static function getRemainderPixels(bmp:BitmapData, f:Float, horizontal:Bool):BitmapData
	{
		if (f == 0) return null;
		var bmp2:BitmapData = new BitmapData(bmp.width, bmp.height, true, FlxColor.TRANSPARENT);
		var r:Rectangle = new Rectangle(0, 0, Std.int(bmp.width * (horizontal ? f : 1.0)), Std.int(bmp.height * (horizontal ? 1.0 : f)));
		bmp2.copyPixels(bmp, r, new Point(0, 0));
		return bmp2;
	}
	
	override function get_width():Float 
	{
		if (_useSubSprites)
			return _subSprites.width;
		return super.get_width();
	}
	
	override function get_height():Float 
	{
		if (_useSubSprites)
			return _subSprites.height;
		return super.get_height();
	}
	
	override function set_x(NewX:Float):Float 
	{
		if (_useSubSprites)
		{
			var dx = NewX - _subSprites.x;
			_subSprites.x = NewX;
			if (_subSpriteTiles != null)
			{
				for (t in _subSpriteTiles){
					t.x += dx;
				}
			}
		}
		return super.set_x(NewX);
	}
	
	override function set_y(NewY:Float):Float 
	{
		if (_useSubSprites)
		{
			var dy = NewY - _subSprites.y;
			_subSprites.y = NewY;
			if (_subSpriteTiles != null)
			{
				for (t in _subSpriteTiles){
					t.y += dy;
				}
			}
		}
		return super.set_y(NewY);
	}
	
	override function set_alpha(Alpha:Float):Float 
	{
		if (_useSubSprites)
		{
			_subSprites.alpha = Alpha;
			if (_subSpriteTiles != null)
			{
				for (t in _subSpriteTiles){
					t.alpha = Alpha;
				}
			}
		}
		return super.set_alpha(Alpha);
	}
	
	override function set_visible(Value:Bool):Bool 
	{
		if (_useSubSprites)
		{
			_subSprites.visible = Value;
			if (_subSpriteTiles != null)
			{
				for (t in _subSpriteTiles){
					t.visible = Value;
				}
			}
		}
		return super.set_visible(Value);
	}
	
	override public function draw():Void 
	{
		if (!_useSubSprites)
		{
			super.draw();
		}
		else
		{
			for (i in 0..._subSprites.members.length)
			{
				var piece = _subSprites.members[i];
				if (piece.visible)
				{
					piece.draw();
				}
			}
			if (_subSpriteTiles != null)
			{
				for (i in 0..._subSpriteTiles.length)
				{
					var tile = _subSpriteTiles[i];
					if (tile.visible)
					{
						tile.draw();
					}
				}
			}
		}
	}
	
	
	private function noLongerUsingCachedID(id:String):Void
	{
		//see if the old configuration exists
		if (cacheCounter.exists(id))
		{
			//if so, subtract a use from the old configuration
			var oldCounter = cacheCounter.get(id);
			oldCounter.useCount--;
			
			//if the use count reaches zero, purge the cached sections
			if (oldCounter.useCount <= 0)
			{
				purgeSections(id);
			}
		}
	}
	
	private function purgeSections(id:String):Void
	{
		//get the section counter in question
		var counter:SectionCounter = cacheCounter.get(id);
		
		if (counter != null)
		{
			//go through all its subkeys (representing cached 9-slice sections)
			//and remove them from the cache
			for (key in counter.subKeys)
			{
				sectionCache.remove(key);
			}
			
			//destroy the section counter as well
			counter.subKeys = null;
			cacheCounter.remove(id);
		}
	}
	
	public static inline function getRectFromString(str:String):Rectangle{
		var coords:Array<String> = str.split(",");
		var rect:Rectangle = null;
		if(coords != null && coords.length == 4){
			var x_:Int = Std.parseInt(coords[0]);
			var y_:Int = Std.parseInt(coords[1]);
			var w_:Int = Std.parseInt(coords[2]);
			var h_:Int = Std.parseInt(coords[3]);
			rect = new Rectangle(x_,y_,w_,h_);
		}
		return rect;
	}
	
	public static inline function getRectIntsFromString(str:String):Array<Int>{
		var coords:Array<String> = str.split(",");
		if(coords != null && coords.length == 4){
			var x1:Int = Std.parseInt(coords[0]);
			var y1:Int = Std.parseInt(coords[1]);
			var x2:Int = Std.parseInt(coords[2]);
			var y2:Int = Std.parseInt(coords[3]);
			return [x1, y1, x2, y2];
		}
		return null;
	}
	
	//These functions were borrowed from:
	//https://github.com/ianharrigan/YAHUI/blob/master/src/yahui/style/StyleHelper.hx
	
	/**
	 * Does the actual drawing for a 9-slice scaled graphic
	 * @param	g the graphics object for drawing to (ie, sprite.graphic)
	 * @param	assetID id of bitmapdata asset you are scaling
	 * @param	scale9 int array defining 2 points that define the grid as [x1,y1,x2,y2] (upper-interior-left, lower-interior-right)
	 * @param	rc rectangle object defining how big you want to scale it to
	 * @param	tile if a bit is false, scale those pieces, if true, tile them (default both false)
	 * @param	smooth whether to smooth when scaling or not (default false)
	 * @param	raw raw pixels supplied, if any
	 * @param	group group to add subsprites too (optional)
	 * @return	the new unique id
	 */
	
	public static function paintScale9(g:BitmapData, assetID:String, scale9:Array<Int>, rc:FlxRect, tile:Int = TILE_NONE, smooth:Bool = false, ?raw:BitmapData, ?group:FlxSpriteGroup):String
	{
		if (scale9 != null) { // create parts
			
			var w:Int;
			var h:Int;
			if (raw == null) {
				var assetBmp = U.getBmp(assetID);
				if (assetBmp != null)
				{
					w = assetBmp.width;
					h = assetBmp.height;
				}
				else
				{
					var assetFlx = FlxG.bitmap.get(assetID);
					w = assetFlx.width;
					h = assetFlx.height;
				}
			}else {
				w = raw.width;
				h = raw.height;
			}
			
			var x1:Int = scale9[0];
			var y1:Int = scale9[1];
			var x2:Int = scale9[2];
			var y2:Int = scale9[3];
			
			if (_staticRects == null)
			{
				_staticRects = new Map<String,FlxRect>();
				_staticRects.set("top.left", FlxRect.get());
				_staticRects.set("top", FlxRect.get());
				_staticRects.set("top.right", FlxRect.get());
				_staticRects.set("left", FlxRect.get());
				_staticRects.set("middle", FlxRect.get());
				_staticRects.set("right", FlxRect.get());
				_staticRects.set("bottom.left", FlxRect.get());
				_staticRects.set("bottom", FlxRect.get());
				_staticRects.set("bottom.right", FlxRect.get());
			}
			
			_staticRects.get("top.left").set(0, 0, x1, y1);
			_staticRects.get("top").set(x1, 0, x2-x1, y1);
			_staticRects.get("top.right").set(x2, 0, w-x2, y1);
			
			_staticRects.get("left").set(0, y1, x1, y2-y1);
			_staticRects.get("middle").set(x1, y1, x2-x1, y2-y1);
			_staticRects.get("right").set(x2, y1, w-x2, y2-y1);
			
			_staticRects.get("bottom.left").set(0, y2, x1, h-y2);
			_staticRects.get("bottom").set(x1, y2, x2-x1, h-y2);
			_staticRects.get("bottom.right").set(x2, y2, w-x2, h-y2);
			
			if (cacheCounter == null)
			{
				cacheCounter = new Map<String,SectionCounter>();
			}
			
			//Find a unique key to represent this combination of asset, scale9 rules, and final destination size
			var uniqueID = makePaintScale9Id(assetID, scale9, rc);
			
			//See if that combination has been used before
			var sectionCounter = cacheCounter.get(uniqueID);
			
			if (sectionCounter == null)
			{
				//If not, create an entry for that and generate the subkeys for it to represent each 9-slice section
				sectionCounter = { useCount:0, subKeys:[] };
				
				for (i in 0...9)
				{
					var rect = 
					switch(i)
					{
						case 0: _staticRects.get("top.left");
						case 1: _staticRects.get("top");
						case 2: _staticRects.get("top.right");
						case 3: _staticRects.get("left");
						case 4: _staticRects.get("middle");
						case 5: _staticRects.get("right");
						case 6: _staticRects.get("bottom.left");
						case 7: _staticRects.get("bottom");
						case 8: _staticRects.get("bottom.right");
						default: _staticRects.get("top.left");
					}
					var cacheId = assetID + "_" + rect.left + "_" + rect.top + "_" + rect.width + "_" + rect.height + "_";
					sectionCounter.subKeys.push(cacheId);
				}
				cacheCounter.set(uniqueID, sectionCounter);
			}
			
			paintCompoundBitmap(g, assetID, _staticRects, rc, tile, smooth, raw, group);
			
			return uniqueID;
		}
		return "";
	}
	
	public static function makePaintScale9Id(assetId:String,slice9:Array<Int>,rect:FlxRect):String
	{
		return assetId + "_" + slice9.join(",") + "_" + rect.toString();
	}

	public static function paintCompoundBitmap(g:BitmapData, assetID:String, sourceRects:Map<String,FlxRect>, targetRect:FlxRect, tile:Int=TILE_NONE, smooth:Bool = false, raw:BitmapData=null, group:FlxSpriteGroup=null):Void {
		var fillcolor = #if (neko) { rgb:0x00FFFFFF, a:0 }; #else 0x00FFFFFF; #end
		
		targetRect.x = Std.int(targetRect.x);
		targetRect.y = Std.int(targetRect.y);
		targetRect.width = Std.int(targetRect.width);
		targetRect.height = Std.int(targetRect.height);
		
		// top row
		var tl:FlxRect = sourceRects.get("top.left");
		if (tl != null) {
			_staticFlxRect2.set(0, 0, tl.width, tl.height);
			_paintBitmapSection(g, assetID, tl, _staticFlxRect2,null,TILE_NONE,smooth,raw,group,0);
		}

		var tr:FlxRect = sourceRects.get("top.right");
		if (tr != null) {
			_staticFlxRect2.set(targetRect.width - tr.width, 0, tr.width, tr.height);
			_paintBitmapSection(g, assetID, tr, _staticFlxRect2,null,TILE_NONE,smooth,raw,group,1);
		}

		var t:FlxRect = sourceRects.get("top");
		if (t != null) {
			_staticFlxRect2.set(tl.width, 0, (targetRect.width - tl.width - tr.width), t.height);
			_paintBitmapSection(g, assetID, t, _staticFlxRect2,null,(tile & 0x10),smooth,raw,group,2);
		}

		// bottom row
		var bl:FlxRect = sourceRects.get("bottom.left");
		if (bl != null) {
			_staticFlxRect2.set(0, targetRect.height - bl.height, bl.width, bl.height);
			_paintBitmapSection(g, assetID, bl, _staticFlxRect2,null,TILE_NONE,smooth,raw,group,3);
		}

		var br:FlxRect = sourceRects.get("bottom.right");
		if (br != null) {
			_staticFlxRect2.set(targetRect.width - br.width, targetRect.height - br.height, br.width, br.height);
			_paintBitmapSection(g, assetID, br, _staticFlxRect2,null,TILE_NONE,smooth,raw,group,4);
		}

		var b:FlxRect = sourceRects.get("bottom");
		if (b != null) {
			_staticFlxRect2.set(bl.width, targetRect.height - b.height, (targetRect.width - bl.width - br.width), b.height);
			_paintBitmapSection(g, assetID, b, _staticFlxRect2,null,(tile & 0x10),smooth,raw,group,5);
		}

		// middle row
		var l:FlxRect = sourceRects.get("left");
		if (l != null) {
			_staticFlxRect2.set(0, tl.height, l.width, (targetRect.height - tl.height - bl.height));
			_paintBitmapSection(g, assetID, l, _staticFlxRect2,null,(tile & 0x01),smooth,raw,group,6);
		}

		var r:FlxRect = sourceRects.get("right");
		if (r != null) {
			_staticFlxRect2.set(targetRect.width - r.width, tr.height, r.width, (targetRect.height - tl.height - bl.height));
			_paintBitmapSection(g, assetID, r, _staticFlxRect2,null,(tile & 0x01),smooth,raw,group,7);
		}

		var m:FlxRect = sourceRects.get("middle");
		if (m != null) {
			_staticFlxRect2.set(l.width, t.height, (targetRect.width - l.width - r.width), (targetRect.height - t.height - b.height));
			_paintBitmapSection(g, assetID, m, _staticFlxRect2,null,tile,smooth,raw,group,8);
		}
	}

	public static function paintBitmapSection(g:BitmapData, assetId:String, src:FlxRect, dst:FlxRect, srcData:BitmapData = null, tile:Int = TILE_NONE, smooth:Bool = false, raw:BitmapData = null):Void
	{
		_paintBitmapSection(g, assetId, src, dst, srcData, tile, smooth, raw);
	}
	
	private static function _paintBitmapSection(g:BitmapData, assetId:String, src:FlxRect, dst:FlxRect, srcData:BitmapData = null, tile:Int = TILE_NONE, smooth:Bool = false, raw:BitmapData = null, group:FlxSpriteGroup = null, groupIndex:Int =-1):Void
	{
		if (srcData == null)
		{
			if (raw != null)
			{
				srcData = raw;
			}
			else
			{
				srcData = U.getBmp(assetId);
			}
		}
		
		src.x = Std.int(src.x);
		src.y = Std.int(src.y);
		src.width = Std.int(src.width);
		src.height = Std.int(src.height);
		
		dst.x = Std.int(dst.x);
		dst.y = Std.int(dst.y);
		dst.width = Std.int(dst.width);
		dst.height = Std.int(dst.height);
		
		var section:BitmapData = null;
		var cacheId:String = null;
		if (useSectionCache == true && assetId != null)
		{
			if (sectionCache == null)
			{
				sectionCache = new Map<String,BitmapData>();
			}
			cacheId = assetId + "_" + src.left + "_" + src.top + "_" + src.width + "_" + src.height + "_";
			section = sectionCache.get(cacheId);
		}

		if (section == null)
		{
			var fillcolor = 0x00FFFFFF;
			section = new BitmapData(Std.int(src.width), Std.int(src.height), true, fillcolor);
			
			_staticRect2.x = src.x;
			_staticRect2.y = src.y;
			_staticRect2.width = src.width;
			_staticRect2.height = src.height;
			
			section.copyPixels(srcData, _staticRect2, _staticPointZero);
			
			if (useSectionCache == true && cacheId != null) {
				sectionCache.set(cacheId, section);
			}
			bitmapsCreated++;
		}

		if (dst.width > 0 && dst.height > 0) {
			
			_staticRect2.x = dst.x;
			_staticRect2.y = dst.y;
			_staticRect2.width = dst.width;
			_staticRect2.height = dst.height;
			
			bitmapFillRect(group == null ? g : null, _staticRect2, section, tile, smooth, g == null ? group : null, groupIndex);
		}
	}
	
	private static function bitmapFillRect(g:BitmapData, dst:Rectangle, section:BitmapData, tile:Int=TILE_NONE, smooth_:Bool=false, group:FlxSpriteGroup=null, groupIndex:Int=-1):Void {
		
		if (group != null && groupIndex >= 0)
		{
			var sprite:FlxSprite = group.members[groupIndex];
			sprite.loadGraphic(section);
			if (tile & 0x10 == 0)
			{
				sprite.scale.set(dst.width / section.width, sprite.scale.y);
			}
			if (tile & 0x01 == 0)
			{
				sprite.scale.set(sprite.scale.x, dst.height / section.height);
			}
			sprite.antialiasing = smooth_;
			sprite.updateHitbox();
			return;
		}
		
		//temporary bitmap data, representing the area we want to fill
		var final_pixels:BitmapData = new BitmapData(Std.int(dst.width), Std.int(dst.height), true, 0x00000000);
		
		_staticMatrix.identity();
		
		//_staticRect represents the size of the section object, after any scaling is done
		_staticRect.x = 0;
		_staticRect.y = 0;
		_staticRect.width = section.width;
		_staticRect.height = section.height;
		
		if (tile & 0x10 == 0) {					//TILE H is false
			_staticMatrix.scale(dst.width / section.width, 1.0);	//scale H
			_staticRect.width = dst.width;							//_staticRect reflects scaling
		}
		if (tile & 0x01 == 0) {					//TILE V is false
			_staticMatrix.scale(1.0, dst.height / section.height);	//scale V
			_staticRect.height = dst.height;						//_staticRect reflects scaling
		}
		
		//draw the first section
		//if tiling is false, this is all that needs to be done as
		//the section's h&v will exactly equal the destination size
		//final_pixels.draw(section, _staticMatrix, null, null, null, smooth);
		
		if (section.width == dst.width && section.height == dst.height) {
			_staticPoint.x = 0;
			_staticPoint.y = 0;
			final_pixels.copyPixels(section, section.rect, _staticPoint);
		}else {
			if(smooth_){
				final_pixels.draw(section, _staticMatrix, null, null, null, true);
			}else {
				final_pixels.draw(section, _staticMatrix, null, null, null, false);
			}
		}
		
		//if we are tiling, we need to keep drawing
		if (tile != TILE_NONE) {
			
			//_staticRect currently represents rect of what we've drawn so far
			
			var th:Int = tile & 0x10;
			
			if (tile & 0x10 == 0x10) {	//TILE H is true
				
				_staticPoint.x = 0;	//drawing destination
				_staticPoint.y = 0;
				
				while (_staticPoint.x < dst.width) {		//tile across the entire width
					_staticPoint.x += _staticRect.width;	//jump to next drawing location
					
					//copy section drawn so far, re-draw at next tiling point
					final_pixels.copyPixels(final_pixels, _staticRect, _staticPoint);
					
					//NOTE:
					//This method assumes that copyPixels() will safely observe
					//buffer boundaries on all targets. If this is not true, a
					//buffer overflow vunerability could exist here and would
					//need to be fixed by checking the boundary size and using
					//a custom-sized final call to fill in the last few pixels
				}
			}
			if (tile & 0x01 == 0x01) {	//TILE V is true
				
				_staticPoint.x = 0;	//drawing destination
				_staticPoint.y = 0;
				
				//assume that the entire width has been spanned by now
				_staticRect.width = final_pixels.width;	
				
				while (_staticPoint.y < dst.height) {		//tile across the entire height
					_staticPoint.y += _staticRect.height;	//jump to next drawing location
					
					//copies section drawn so far, like above, but starts with 
					//the entire first row of drawn pixels
					final_pixels.copyPixels(final_pixels, _staticRect, _staticPoint);
					
					//NOTE: 
					//See note above, same thing applies here.
				}
			}
		}
		
		//set destination point
		_staticPoint.x = dst.x;
		_staticPoint.y = dst.y;
		
		//copy the final filled area to the original target bitmap data
		g.copyPixels(final_pixels, final_pixels.rect, _staticPoint);
		
		//now that the pixels have been copied, trash the temporary bitmap data:
		final_pixels = FlxDestroyUtil.dispose(final_pixels);
	}
}

typedef SectionCounter = 
{
	var useCount:Int;
	var subKeys:Array<String>;
}