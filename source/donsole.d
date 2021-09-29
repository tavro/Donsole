// Uses WinAPI to colorize and format text in console

module donsole;
import std.typecons, std.algorithm, std.array;

alias void delegate(CloseEvent) @system CloseHandler;

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

     pageUp,
     pageDown,

     end,
     delete_,
     insert,

     up,
     down,
     left,
     right,

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
	CloseHandler[] closeHandlers;
}

shared static this() {
       loadDefaultColors(OutputStream.stdout);
       SetConsoleCtrlHandler(cast(PHANDLER_ROUTINE)&defaultCloseHandler, true);
}

import std.string;

// Sets console title
void title(string title) @property {
     SetConsoleTitleA(toStringz(title));
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

// Add handler for close event
void addCloseHandler(CloseHandler closeHandler) {
     closeHandlers ~= closeHandler; // In this case ~= means append
}

// Gets input mode
InputMode mode() @property {
     InputMode im;
     DWORD m;
     GetConsoleMode(handleInput, &m);

     // !! basically converts to boolean
     im.echo = !!(m & ENABLE_ECHO_INPUT);
     im.line = !!(m & ENABLE_LINE_INPUT);
     return im;
}

// Sets input mode
void mode(InputMode im) @property {
     DWORD m;

     // m |= x is basically m = m | x (bitwise or)
     // m &= x is basically m = m & x (bitwise and)
     (im.echo) ? (m |= ENABLE_ECHO_INPUT) : (m &= ~ENABLE_ECHO_INPUT);
     (im.line) ? (m |= ENABLE_LINE_INPUT) : (m &= ~ENABLE_LINE_INPUT);
     SetConsoleMode(handleInput, m);
}

private void updateColor() {
	stdout.flush();
	SetConsoleTextAttribute(handleOutput, buildColor(fg, bg));
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

private CloseEvent idToCloseEvent(ulong i) {
	CloseEvent event;

	switch(i) {
		case 0:
		     event.type = CloseType.Interrupt;
		break;
		case 1:
		     event.type = CloseType.Stop;
		break;
		default:
		     event.type = CloseType.Other;
	}
	
	event.isBlockable = (event.type != CloseType.Other);
	return event;
}

private bool defaultCloseHandler(ulong reason) {
	foreach(closeHandler; closeHandlers) {
		closeHandler(idToCloseEvent(reason));
	}
	return true;
}

// Reads char without line buffering
int getch(bool echo = false) {
    INPUT_RECORD record;
    DWORD count;
    auto m = mode;
    mode = InputMode.None;

    do {
       ReadConsoleInputA(handleInput, &record, 1, &count);
    } // extra kbhit to ensure we're back on a fresh keydown next time this event happens
    while ((record.EventType != KEY_EVENT || !record.KeyEvent.bKeyDown) && kbhit());

    mode = m;
    return record.KeyEvent.wVirtualKeyCode;
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

struct EnumTypedef(T, string _name) if(is(T == enum)) {
       public T val = T.init;
       this(T v) {
       	  val = v;
       }

       static EnumTypedef!(T, _name) onDispatch(string n)() {
       	  return EnumTypedef!(T, _name)(__traits(getMember, val, n));
       }
}

alias EnumTypedef!(Color, "fg") Fg;
alias EnumTypedef!(Color, "bg") Bg;

struct ColorTheme(Color fg, Color bg) {
       string s;
       this(string s) {
       	  this.s = s;
       }

       void toString(scope void delegate(const(char)[]) sink) const {
       	    auto _fg = foreground;
	    auto _bg = background;

	    foreground = fg;
	    background = bg;

	    sink(s.dup);

	    foreground = _fg;
	    background = _bg;
       }
}

void resetColors() {
     foreground = Color.initial;
     background = Color.initial;
}

// Writes text to console (with color)
void writec(T...)(T params) {
     foreach(param; params) {
     	static if(is(typeof(param) == Fg)) {
	   foreground = param.val;
	}
	else static if(is(typeof(param) == Bg)) {
	   background = param.val;
	}
	else {
	     write(param);
	}
     }
}

// Writes line to console
void writecln(T...)(T params) {
     writec(params);
     writeln();
}

// Fills area with char
void fillArea(Point p1, Point p2, char fill) {
     foreach(i; p1.y .. p2.y + 1) {
         setCursorPosition(p1.x, i);
	 //[0..1] converts char to char[]
	 write(replicate((&fill)[0..1], p2.x - p1.x));
	 stdout.flush();
     }
}

// Draws box with border char
void drawBox(Point p1, Point p2, char border) {
     drawHorizontalLine(p1, p2.x - p1.x, border);

     foreach(i; p1.y + 1 .. p2.y) {
         setCursorPosition(p1.x, i);
	 write(border);
	 setCursorPosition(p2.x - 1, i);
	 write(border);
     }

     drawHorizontalLine(Point(p1.x, p2.y), p2.x - p1.x, border);
}

// Draws horizontal line
void drawHorizontalLine(Point point, int length, char fill) {
     setCursorPosition(point.x, point.y);
     write(replicate((&fill)[0..1], length));
}

// Draws vertical line
void drawVerticalLine(Point point, int length, char fill) {
     foreach(i; point.y .. length) {
         setCursorPosition(point.x, i);
	 write(fill);
     }
}

void main() {
	writeln("don Don Donsole!");
}
