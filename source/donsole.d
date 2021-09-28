import std.stdio;

enum OutputStream {
     stdout, // Standard output
     stderr  // Error output
}

enum CloseType {
     Interrupt, // Ctrl+C
     Stop,	// Ctrl+Break
     Other	// Other
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

void main() {
	writeln("Console Console Console");
}
