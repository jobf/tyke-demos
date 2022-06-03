import lime.ui.KeyCode;
import ob.gum.backends.PeoteView;
import tyke.Palettes;
import tyke.Layers;
import tyke.Loop;
import tyke.Glyph;

using ob.gum.backends.PeoteView.PaletteExtensions;

class Glyphs extends GlyphLoop {
	public function new(data:GlyphLoopConfig, assets:Assets, ?palette:Palette) {
		super(data, assets, palette);
		onInitComplete = begin;
	}

	function getInitFor(char:String, fg:Int, bg:Int):(Int, Int) -> GlyphModel {
		return (col, row) -> {
			var charCode = char.charCodeAt(0);
			var x = col * text.fontStyle.width;
			var y = row * text.fontStyle.height;
			return {
				char: 0,
				glyph: text.fontProgram.createGlyph(charCode, x, y, text.fontStyle),
				paletteIndexFg: fg,
				paletteIndexBg: bg,
				bgIntensity: 1.0
			};
		}
	}

	function begin() {
		var config:GlyphGridConfig = {
			numColumns: data.numCellsWide,
			numRows: data.numCellsHigh,
			cellWidth: Math.ceil(text.fontStyle.width),
			cellHeight: Math.ceil(text.fontStyle.height),
			palette: palette,
			cellInit: getInitFor(" ", 0, 3)
		}
		var infoConfig:GlyphGridConfig = {
			numColumns: data.numCellsWide,
			numRows: data.numCellsHigh,
			cellWidth: Math.ceil(text.fontStyle.width),
			cellHeight: Math.ceil(text.fontStyle.height),
			palette: palette,
			cellInit: getInitFor(" ", 0, -1)
		}

		var demo = new DemoLayer(config, text.fontProgram);
		var info = new InfoLayer(infoConfig, text.fontProgram);

		layers = [demo, info];

		keyboard.bind(KeyCode.NUMBER_1, "1", "toggle random chars", _ -> {
			demo.toggleRandomChars();
		});
		keyboard.bind(KeyCode.NUMBER_2, "2", "toggle colors cycle/random", _ -> {
			demo.togglePaletteCycle();
		});
		keyboard.bind(KeyCode.LEFT_BRACKET, "[", "decrease cycle depth", _ -> {
			demo.alterPaletteCycleLength(1);
		});
		keyboard.bind(KeyCode.RIGHT_BRACKET, "]", "increase cycle depth", _ -> {
			demo.alterPaletteCycleLength(-1);
		});
		keyboard.bind(KeyCode.EQUALS, "=", "change palette", _ -> {
			demo.cyclePalette();
		});

		for (b in keyboard.listBindings()) {
			info.addLine(b);
		}
		info.refreshDisplay();
		gum.toggleUpdate(true);
	}
}



class InfoLayer extends GlyphGrid {
	var lines:Array<Array<Int>> = [];

	public function addLine(text:String) {
		lines.push([for (c in text.split("")) c.charCodeAt(0)]);
	}

	public function refreshDisplay() {
		for (lineIndex => line in lines) {
			trace([for (c in line) String.fromCharCode(c)].join(""));
			for (charIndex => char in line) {
				this.forSingleCoOrdinate(charIndex, lineIndex, (col, row, cell) -> {
					cell.char = char;
					cell.paletteIndexFg = 14;
					cell.paletteIndexBg = 15;
				});
			}
		}
		hasChanged = true;
	}
}

class DemoLayer extends GlyphGrid {
	override public function onTick(tick:Int):Void {
		forEach((c, r, cell) -> {
			if (isPaletteCycle) {
				CellWorks.cyclePalette(cell, palette, reduceColoursBy, tick);
			}
			CellWorks.randomise(c, r, cell, palette, !isPaletteCycle, isCharsRandom);
		});
		hasChanged = true;
	}

	public function toggleRandomChars() {
		isCharsRandom = !isCharsRandom;
	}

	public function togglePaletteCycle() {
		isPaletteCycle = !isPaletteCycle;
	}

	var palettes = [Sixteen.VanillaMilkshake, Sixteen.Soldier, Sixteen.Versitle];

	var paletteIndex:Int = 0;

	public function cyclePalette() {
		paletteIndex++;
		if (paletteIndex >= palettes.length) {
			paletteIndex = 0;
		}
		palette.setColors(palettes[paletteIndex].toRGBA());
	}

	var isCharsRandom:Bool = true;

	var isPaletteCycle:Bool = false;

	var reduceColoursBy:Int = 0;

	public function alterPaletteCycleLength(changePaletteReduction:Int) {
		reduceColoursBy += changePaletteReduction;
		trace('reduce colours by $reduceColoursBy');
		if (reduceColoursBy < 0) {
			reduceColoursBy = 0;
		}
		if (reduceColoursBy > palette.colors.length - 1) {
			reduceColoursBy = palette.colors.length - 1;
		}
	}
}