import ob.gum.backends.PeoteView;
import ob.gum.Core;
import lime.ui.Window;
import ob.gum.backends.Lime;

class Main extends App {
	override function init(window:Window, ?config:GumConfig) {
		super.init(window, {
			framesPerSecond: 30,
			drawOnlyWhenRequested: true,
			displayWidth: 200,
			displayHeight: 124,
			displayIsScaled: true
		});
		
		var assets = new Assets({
			fonts: [],
			images: [
				// "assets/ldtk/monocave/bw_tiles.png",
				"assets/ldtk/monocave/bw.png",
				"assets/images/cat-sprite-sheet.png"
			]
		});
		
		// gum.changeLoop(new samples.CaveCat(assets));
		gum.changeLoop(new CaveCat(assets));
	}
}
