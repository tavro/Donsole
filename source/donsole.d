import std.typecons, std.algorithm;

enum OutputStream {
     stdout, // Standard output
     stderr  // Error output
}

enum CloseType {
     Interrupt, // Ctrl+C
     Stop,	// Ctrl+Break
     Other	// Other
}

struct CloseEvent {
     CloseType type;
     bool isBlockable; // Can block close event
}

struct InputMode {
     bool echo = true; // Echo printed chars
     bool line = true; // Line buffering

     //Constructor
     this(bool echo, bool line) {
     	       this.echo = echo;
	       this.line = line;
     }

     static InputMode None = InputMode(false, false); //No feature
}

enum SpecialKey {
     home = 512,
     escape = 27,
     tab = 9,
}

// Position in console
alias Tuple!(int, "x", int, "y") Point;

//START

import core.sys.windows.windows, std.stdio;

private enum BG_MASK = 0xf0;
private enum FG_MASK = 0x0f;

enum Color : ushort {
     black = 0,
     blue = 1,
     green = 2,
     cyan = 3,
     red = 4,
     magenta = 5,
     yellow = 6,
     lightGray = 7,
     gray = 8,
     lightBlue = 9,
     lightGreen = 10,
     lightCyan = 11,
     lightRed = 12,
     lightMagenta = 13,
     lightYellow = 14,
     white = 15,

     bright = 8,
     initial = 256 // Default
}

// __gshared implies static
private __gshared {
	CONSOLE_SCREEN_BUFFER_INFO info;
	HANDLE handleOutput = null, handleInput = null;

	Color fg, bg, defFg, defBg;
}

private void loadDefaultColors(OutputStream os) {
	uint handle;

	if(os == OutputStream.stdout) {
	      handle = STD_OUTPUT_HANDLE;
	}
	else if(os == OutputStream.stderr) {
	      handle = STD_ERROR_HANDLE;
	}
	else {
	     assert(0, "Invalid output stream");
	}

	handleOutput = GetStdHandle(handle);
	handleInput = GetStdHandle(STD_INPUT_HANDLE);

	// Get current console colors
	GetConsoleScreenBufferInfo(handleOutput, &info);

	// First 4 bits = bg
	defBg = cast(Color)((info.wAttributes & (BG_MASK)) >> 4);
	// Last 4 bits = fg
	defFg = cast(Color)(info.wAttributes & (FG_MASK));

	fg = Color.initial;
	bg = Color.initial;
}

// Sets output stream
void outputStream(OutputStream os) @property {
     loadDefaultColors(os);
}

// Get console size
Point size() @property {
      GetConsoleScreenBufferInfo(handleOutput, &info);

      int cols, rows;
      cols = (info.srWindow.Right - info.srWindow.Left + 1);
      rows = (info.srWindow.Bottom - info.srWindow.Top + 1);

      return Point(cols, rows);
}

// Get cursor position
Point cursorPos() @property {
      GetConsoleScreenBufferInfo(handleOutput, &info);
      return Point(info.dwCursorPosition.X, min(info.dwCursorPosition.Y, height));
}

private ushort buildColor(Color fg, Color bg) {
	if(fg == Color.initial) {
	      fg = defFg;
	}
	if(bg == Color.initial) {
	      bg = defBg;
	}
	return cast(ushort)(fg | bg << 4);
}

private void updateColor() {
	stdout.flush();
	SetConsoleTextAttribute(handleOutput, buildColor(fg, bg));
}

// Get current console font color
Color foreground() @property {
      return fg;
}

// Get current console background color 
Color background() @property {
      return bg;
}

// Set console font color and flush stdout
void foreground(Color color) @property {
     fg = color;
     updateColor();
}

// Set console background color and flush stdout
void background(Color color) @property {
     bg = color;
     updateColor();
}

// Sets console cursor position
void setCursorPosition(int x, int y) {
     COORD coord = {
     	   cast(short)min(width, max(0, x)),
	   cast(short)max(0, y)
     };
     stdout.flush();
     SetConsoleCursorPosition(handleOutput, coord);
}

private void moveCursor(int x, int y) {
	stdout.flush();
	auto pos = cursorPos();
	setCursorPosition(max(pos.x + x, 0), max(0, pos.y + y));
}

// Moves cursor up n rows
void moveCursorUp(int n = 1) {
     moveCursor(0, -n);
}

// Moves cursor down n rows
void moveCursorDown(int n = 1) {
     moveCursor(0, n);
}

// Move cursor left n columns
void moveCursorLeft(int n = 1) {
     moveCursor(-n, 0);
}

// Move cursor right n columns
void moveCursorRight(int n = 1) {
     moveCursor(n, 0);
}

// Check if (any) key is pressed
bool kbhit() {
     return WaitForSingleObject(handleInput, 0) == WAIT_OBJECT_0;
}

// Set cursor visibility
void cursorVisible(bool visible) @property {
     CONSOLE_CURSOR_INFO i;
     GetConsoleCursorInfo(handleOutput, &i);
     i.bVisible = visible;
     SetConsoleCursorInfo(handleOutput, &i);
}

//END

// Writes at data to given point
void writeAt(T)(Point point, T data) {
     setCursorPosition(point.x, point.y);
     write(data);
     stdout.flush();
}

// Clears console
void clearScreen() {
     auto size = size;
     short length = cast(short)(size.x * size.y); //num of chars to write
     setCursorPosition(0, 0);

     import std.array : replicate;
     write(replicate(" ", length));
     stdout.flush();
}

// Get console width
@property int width() {
	return size.x;
}

// Get console height
@property int height() {
	return size.y;
}

// alias EnumTypedef!(Color, "fg") Fg;
// alias EnumTypedef!(Color, "bg") Bg;

void main() {
	writeln("Console Console Console");
}
