package flixel.addons.ui.interfaces;

/**
 * ...
 * @author 
 */
interface IHasParams
{
	public var params(default, set):Array<Dynamic>;
	private function set_params(p:Array<Dynamic>):Array<Dynamic>;
}
