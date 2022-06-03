// package;

import peote.text.FontProgram;
import ob.gum.backends.PeoteView;
import tyke.Grid;
import tyke.Palettes;
import tyke.Layers;
import tyke.Loop;
import tyke.Glyph;

// todo ! drop Text and just use FontProgram

@:structInit
class ScreenGeometry {
	public var displayColumns:Int;
	public var displayRows:Int;
	public var playableColumnsWidth:Int;
	public var displayPixelsWide:Int;
	public var displayPixelsHigh:Int;

	public var playBoundsLeft:Int;
	public var playBoundsRight:Int;
	public var playBoundsTop:Int;
	public var playBoundsBottom:Int;
}

class Cascade extends GlyphLoop {
	public function new(data:GlyphLoopConfig, assets:Assets, ?palette:Palette) {
		super(data, assets, palette);
		
		onInitComplete = begin;
	}

	function getInitFor(char:String, fg:Int, bg:Int, geometry:ScreenGeometry):(Int, Int) -> GlyphModel {
		final options:String = "ABCDEFGHIJKLMNOPQRSTUVWYZ";
		final reduceAvailableCharsBy = 17;
		final maxIndex:Int = options.length - reduceAvailableCharsBy;

		var defaultFg = fg;
		return (col, row) -> {
			var x = col * text.fontStyle.width;
			var y = row * text.fontStyle.height;
			var charCode:Int = " ".charCodeAt(0);
			if (col < geometry.playBoundsLeft || col > geometry.playBoundsRight) {
				charCode = " ".charCodeAt(0);
			} else if (row < geometry.playBoundsTop) {
				charCode = "0".charCodeAt(0);
				fg = 7;
			} else if (row < geometry.playBoundsBottom) {
				fg = defaultFg;
				charCode = options.charCodeAt(randomInt(maxIndex) - 1);
			}

			return {
				char: charCode,
				glyph: text.fontProgram.createGlyph(charCode, x, y, text.fontStyle),
				paletteIndexFg: fg,
				paletteIndexBg: bg,
				bgIntensity: 1.0
			};
		}
	}

	function begin() {
		var doubleSpeed = gum.config.framesPerSecond * 2;
		gum.setTickDuration(Math.floor(1000 / doubleSpeed));
		final numColumns = 19;
		// final numRows = 16;
		var numColumnsInDisplay = Math.ceil(display.width / text.fontStyle.width);
		var border = numColumnsInDisplay - numColumns;
		var boundaryLeft = Std.int(border * 0.5);
		var boundarRight = numColumnsInDisplay - boundaryLeft;
		geometry = {
			playableColumnsWidth: numColumns,
			displayRows: Math.ceil(display.height / text.fontStyle.height),
			displayColumns: numColumnsInDisplay,
			displayPixelsWide: display.width,
			displayPixelsHigh: display.height,
			playBoundsRight: boundarRight,
			playBoundsLeft: boundaryLeft - 1,
			playBoundsTop: 3,
			playBoundsBottom: 12
		}

		var config:GlyphGridConfig = {
			numColumns: geometry.displayColumns,
			numRows: geometry.displayRows,
			// numColumns: 19,
			// numRows: 16,
			cellWidth: Math.ceil(text.fontStyle.width),
			cellHeight: Math.ceil(text.fontStyle.height),
			palette: palette,
			cellInit: getInitFor(" ", 1, 3, geometry)
		}
		playWidth = config.numColumns * config.cellWidth;
		playHeight = config.numRows * config.cellHeight;
		cascade = new CascadeLayer(config, text.fontProgram, geometry);
		layers = [cascade];
		isPlayerOnLeft = true;
		mouse.onDown = (x, y, button) -> {
			if (isCascading)
				return;
			var pointUnderMouse:Point = cascade.screenToGrid(x, y, playWidth, playHeight);
			// if (pointUnderMouse.x < geometry.playBoundsLeft || pointUnderMouse.x > geometry.playBoundsRight)
			// 	// mouse click is out of clickable area
			// 	return;

			var underMouse = cascade.get(pointUnderMouse.x, pointUnderMouse.y);
			var scrunitizedChar = underMouse.char;
			var isClickable = scrunitizedChar != cascade.emptyChar && underMouse.char >= cascade.minChar;
			if (isClickable) {
				// trace('$c $r ${underMouse.char}');
				cascade.clearAllMatching(underMouse.char);
				isCascading = true;
			}
		}

		gum.toggleUpdate(true);
	}

	var isCascading:Bool;

	override function onTick(tick:Int):Bool {
		if (isCascading) {
			if (cascade.changed(isPlayerOnLeft)) {
				cascade.hasChanged = true;
			} else {
				isCascading = false;
				swapPlayer();
				cascade.showPlayerTurn(isPlayerOnLeft);
			}
		}
		return super.onTick(tick);
	}

	var geometry:ScreenGeometry;

	var cascade:CascadeLayer;

	var isPlayerOnLeft:Bool;

	var playWidth:Int;

	var playHeight:Int;

	function swapPlayer() {
		isPlayerOnLeft = !isPlayerOnLeft;
	}
}

class Overlay extends GlyphGrid {
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

class CacadeArea {
	public function new() {}
}

class CascadeLayer extends GlyphGrid {
	public function new(config:GlyphGridConfig, fontProgram:FontProgram<FontStyle>, geometry:ScreenGeometry) {
		super(config, fontProgram);

		this.geometry = geometry;
		// todo - why is this this.geometry.playableColumnsWidth + 2 ?
		clickableIndexes = indexesInSection(this.geometry.playBoundsLeft, this.geometry.playBoundsTop, this.geometry.playableColumnsWidth + 3,
			this.geometry.playBoundsBottom - this.geometry.playBoundsTop);

		initModifiers();
		initPlayers();
		showPlayerTurn(true);
	}

	function setupPlayer(name:String):Player {
		return {
			score: 0,
			name: name,
			modifiers: []
		};
	}

	function setupScoreBoard(column:Int, row:Int, width:Int):ScoreBoard {
		return {
			width: width,
			position: {
				x: column,
				y: row
			},
			nameRow: 0,
			turnIndicatorRow: 1,
			modsRow: 5,
			scoreRow: 3,
		};
	}

	public final emptyChar = " ".charCodeAt(0);
	public final minChar = "A".charCodeAt(0);
	public final treasureChar = "0".charCodeAt(0);

	final threshold:Int = 12;

	// var palettes = [Sixteen.VanillaMilkshake, Sixteen.Soldier, Sixteen.Versitle];
	// var paletteIndex:Int = 0;

	public function clearAllMatching(charCode:Int) {
		var numRemoved = 0;
		for (index in clickableIndexes) {
			var cell = cells[index];
			if (cell.char == charCode) {
				cell.char = emptyChar;
				numRemoved++;
				hasChanged = true;
			}
		}
	}

	final canFallTo:Array<Point> = [
		{
			x: 0,
			y: 1
		},
		{
			x: 1,
			y: 1
		},
		{
			x: -1,
			y: 1
		}
	];

	final modAdd:Int = "+".charCodeAt(0);
	final modRemove:Int = "-".charCodeAt(0);

	function moved(from:GlyphModel, column:Int, row:Int, isPlayerOnLeft:Bool):Bool {
		var to = get(column, row);
		var destinationIsEmpty = to.char == emptyChar;
		var destinationIsModifier = to.char == modAdd || to.char == modRemove;
		if (destinationIsEmpty || destinationIsModifier) {
			if (destinationIsModifier) {
				var player = isPlayerOnLeft ? player1 : player2;
				var modifyBy = to.char == modAdd ? 1 : -1;
				player.modifiers.push({
					scoreMod: i -> i * modifyBy,
					charCode: to.char
				});
			}
			to.char = from.char;
			to.paletteIndexFg = from.paletteIndexFg;
			from.char = emptyChar;
			// trace('moved');
			return true;
		}
		return false;
	}

	public function isInPlayableBounds(column:Int, row:Int):Bool {
		return column >= geometry.playBoundsLeft && row >= 0 && column <= geometry.playBoundsRight && row < numRows;
	}

	var player1:Player;
	var player1ScoreBoard:ScoreBoard;
	var player2:Player;
	var player2ScoreBoard:ScoreBoard;

	public function changed(isPlayerOnLeft:Bool):Bool {
		var somethingMoved = false;
		final isReversed = true;
		final updatingIndidivually = true;
		final isCancelable = updatingIndidivually;
		var player = isPlayerOnLeft ? player1 : player2;
		var scoreBoard = isPlayerOnLeft ? player1ScoreBoard : player2ScoreBoard;
		var score = 5;
		forEachCanExitEarly((c, r, each) -> {
			if (each.char == treasureChar) {
				var isGrounded = r == numRows - 1;
				if (!isGrounded) {
					// can fall so  will try various destinations
					for (o in canFallTo) {
						var column = o.x + c;
						var row = o.y + r;
						if (!isInPlayableBounds(column, row)) {
							continue;
						}
						if (moved(each, column, row, isPlayerOnLeft)) {
							somethingMoved = true;
							break;
						}
					}
				} else {
					// is on ground so exit the treasure
					var groundedDirection = isPlayerOnLeft ? -1 : 1;
					var column = c + groundedDirection;
					var row = r;
					final isFastExit = true;
					var reachedEdge = column >= geometry.playBoundsRight || column <= geometry.playBoundsLeft;
					var isExiting = isFastExit || reachedEdge;
					if (isExiting) {
						// trace('score!');
						each.char = emptyChar;
						somethingMoved = true;

						
						player.score += score;
						for (i => mod in player.modifiers) {
							player.score += mod.scoreMod(score);
							// writeText(0, 0, String.fromCharCode(mod.charCode), scoreBoard.width);
							// trace(scoreBoard.position.x);
							// writeText(scoreBoard.position.x + (i * 2), scoreBoard.position.y, String.fromCharCode(mod.charCode), scoreBoard.width);
						}
						writeText(scoreBoard.position.x, scoreBoard.scoreRow, '# ${player.score}', scoreBoard.width);
					} else {
						if (moved(each, column, row, isPlayerOnLeft)) {
							// trace('exiting');
							somethingMoved = true;
						}
					}
				}
			}
			if (somethingMoved) {
				updateModText(player, scoreBoard, score);
			}
			return isCancelable && somethingMoved;
		}, isReversed);

		return somethingMoved;
	}

	var geometry:ScreenGeometry;

	var clickableIndexes:Array<Int>;

	function initModifiers() {
		var top = this.geometry.playBoundsTop + 1;
		var height = this.geometry.playBoundsBottom - top - 1;
		var vailidModifierIndexes = indexesInSection(this.geometry.playBoundsLeft, top, this.geometry.playableColumnsWidth + 2, height);
		for (mod in [modRemove, modAdd, modRemove, modAdd]) {
			// for(mod in ["-","+","-","+","*","*"]){
			var index = vailidModifierIndexes[randomInt(vailidModifierIndexes.length) - 1];
			cells[index].char = mod;
			cells[index].paletteIndexFg = 15;
		}
	}

	function initPlayers() {
		final score = 5;
		player1 = setupPlayer("Player 1");
		player2 = setupPlayer("Player 2");
		player1ScoreBoard = setupScoreBoard(0, 2, this.geometry.playBoundsLeft);
		player2ScoreBoard = setupScoreBoard(this.geometry.playBoundsRight + 1, 2, this.geometry.playBoundsLeft);
		writeText(player1ScoreBoard.position.x, player1ScoreBoard.nameRow, player1.name, player1ScoreBoard.width);
		writeText(player2ScoreBoard.position.x, player2ScoreBoard.nameRow, player2.name, player2ScoreBoard.width);
		updateModText(player1, player1ScoreBoard, score);
		updateModText(player2, player2ScoreBoard, score);
	}

	public function showPlayerTurn(isPlayerOnLeft:Bool) {
		var currentBoard = isPlayerOnLeft ? player1ScoreBoard : player2ScoreBoard;
		var otherBoard = isPlayerOnLeft ? player2ScoreBoard : player1ScoreBoard;
		writeText(currentBoard.position.x, currentBoard.turnIndicatorRow, "-------^", currentBoard.width);
		writeText(otherBoard.position.x, otherBoard.turnIndicatorRow, "        ", otherBoard.width);
	}

	function updateModText(player:Player, scoreBoard:ScoreBoard, score:Int) {
		final margin = 1;
		var x = scoreBoard.position.x + margin;
		var width = scoreBoard.width - margin;

		writeText(x, scoreBoard.modsRow, '+$score', width);
		for (i => m in player.modifiers) {
			writeText(x, scoreBoard.modsRow + i + 1, '${String.fromCharCode(m.charCode)}$score', width);
		}
	}
}

typedef PointsModifier = Int->Int;

@:structInit
class Player {
	public var name:String;
	public var score:Int;
	public var modifiers:Array<Modifier>;
}

@:structInit
class ScoreBoard {
	public var position:Point;
	public var width:Int;

	public var nameRow:Int;
	public var scoreRow:Int;
	public var modsRow:Int;
	public var turnIndicatorRow:Int;
}

@:structInit
class Modifier {
	public var charCode:Int;
	public var scoreMod:PointsModifier;
}
