# Powershell-Piet
Interpreter for [DangerMouse's Piet language](https://www.dangermouse.net/esoteric/piet.html)

# How to Use
In a Powershell console window, run the file `PSPiet.ps1`. This defines a suite of functions that can be used to execute Piet programs:

* `RunPiet [src] [muffled?] [maxCycles?]` - runs the Piet program given by `src`, with a codel size of 1 pixel. If `muffled` is set to `$true`, no output will be displayed until the Piet program halts. The Piet program will run for `maxCycles` Piet codel blocks (commands, including white codel "nop" areas), unless it halts earlier from the codel pointer getting trapped as described by DangerMouse. `maxCycles` defaults to 10k.
* `SizeAndRun [src] [w] [h?] [muffled?] [maxCycles?]` - runs a resized copy of the Piet program given by `src`. `w` and `h` define the size of the program, measured in codels; if `h` is not given, the interpreter will assume the program is a square - that is, that `h` should be equal to `w`. `muffled` and `maxCycles` act identically to their use in `RunPiet` above.

## Possible runtime issues/heads-ups

Program size: This program processes the entire image before running it; as such, programs with a higher codel count will take longer to load. Anything 2500 codels or smaller is pretty doable, but it hung on a 10000-codel program for a while before it could be executed. I've theorized some optimizations for this, but as it stands, they would require a near-full rewrite, so they've not been implemented yet.

Obstructed white codels: When the codel pointer encounters a black codel or image border while gliding across white codels, it will switch the CC, turn right, and attempt to continue; if it enters an infinite loop without exiting the white block, execution of the Piet program will halt. Some Piet programs may assume a different interpretation, and if they do, may exhibit unexpected behavior.

Image resizing: The resizing in `SizeAndRun` uses a single pixel from roughly the middle of the expected codel to determine the color of the entire codel. It does not assume codels are necessarily squares in the input image. Attempting to use `SizeAndRun` to *increase* the size of an image before running is untested behavior.

Image colors: Transparency is ignored; a codel with ARGB 0xffff0000 and one with ARGB 0x33ff0000 are considered the same red and, if adjacent to each other, will be considered as parts of the same block. Additionally, any color whose RGB is not one of the 20 in DangerMouse's documentation is treated as black.
