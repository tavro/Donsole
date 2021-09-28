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

//START

import core.sys.windows.windows, std.stdio, std.string;

private enum BG = 0xf0;
private enum FG = 0x0f;

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

//END

void main() {
	writeln("Console Console Console");
}
