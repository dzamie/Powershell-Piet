using namespace System.Drawing
using namespace System.Collections.Generic

# 

# turn image into colors (int: 0-17) for faster performance
# color as a whole will be 0-17: hue*3 + dark
# with black = -2, white = -1
# so dark = color % 3 and hue = (color - dark) / 6
# b-f vs d-f search probably doesn't matter, but keeping it in a HashSet[Coord] rather than a List[Coord] is probably easier

class Coord {
    [int]$x
    [int]$y
    Coord([int]$x, [int]$y) {
        $this.x = $x
        $this.y = $y
    }

    [boolean] Equals($other) {
        if($other -is [Coord]) {
            if(($this.x -eq $other.x) -and ($this.y -eq $other.y)) {
                return $true
            }
        } elseif(($other -is [Object[]]) -and ($other.count -eq 2)) {
            if(($this.x -eq $other[0]) -and ($this.y -eq $other[1])) {
                return $true
            }
        }
        return $false
    }

    [string] ToString() {
        return "$($this.x),$($this.y)"
    }
}

#  in: Color in, optional int default color
# out: int -2 to 17
function getColor {
    param([Color]$in, [int]$defaultClr = -2)
    switch($in.ToArgb() -band 0xffffff) { # & strips off the transparency
        0x000000 { return -2 }
        0xffffff { return -1 }
        0xffc0c0 { return 0  }
        0xff0000 { return 1  }
        0xc00000 { return 2  }
        0xffffc0 { return 3  }
        0xffff00 { return 4  }
        0xc0c000 { return 5  }
        0xc0ffc0 { return 6  }
        0x00ff00 { return 7  }
        0x00c000 { return 8  }
        0xc0ffff { return 9  }
        0x00ffff { return 10 }
        0x00c0c0 { return 11 }
        0xc0c0ff { return 12 }
        0x0000ff { return 13 }
        0x0000c0 { return 14 }
        0xffc0ff { return 15 }
        0xff00ff { return 16 }
        0xc000c0 { return 17 }
        default  { return $defaultClr }
    }
}

#  in: Bitmap img
# out: int[,]
function imgToColors {
    param([Bitmap]$img)
    $colorGrid = New-Object "int[,]" $img.Width,$img.Height
    for($i = 0; $i -lt $img.Width; $i ++) {
        for($j = 0; $j -lt $img.Height; $j ++) {
            $colorGrid[$i,$j] = getColor $img.GetPixel($i,$j)
        }
    }
    return ,$colorGrid # comma used so it remains an int[,] rather than an int[]
}

#  in: string filename
# out: int[,]
function fileToColors {
    param([string]$fname)
    $img = [Bitmap]::new($fname)
    $out = imgToColors $img
    $img.Dispose()
    return ,$out
}

#  in: int[,] grid, int x, int y
# out: List[Coord]
function getBlock {
    param([int[,]]$grid, [int]$xStart, [int]$yStart)
    # trying to make a custom IEqualityComparer keeps failing, so I'll be using strings instead
    $nextStep = [HashSet[String]]::new()
    $checked = [HashSet[String]]::new()
    $color = $grid[$xStart, $yStart] # color will be the same through the entire block, so I can define it before the loop
    $_ = $nextStep.Add("$($xStart),$($yStart)") # can be split(",") back into [int]able substrings
    # ^ don't forget to muffle the boolean!
    while($nextStep.Count -gt 0) { # while there's still things to look at...
        $currStep = $nextStep                # the future is now, old man!
        $nextStep = [HashSet[String]]::new() # probably faster than having $currstep copy and then clearing $nextstep
        foreach($s in $currStep) {
            $coords = $s.split(",")
            $x = [int]($coords[0])
            $y = [int]($coords[1])
            if(($x -gt 0) -and ($grid[($x-1),$y] -eq $color)) { # can go left
                $_ = $nextStep.Add("$($x-1),$($y)") # muffle the returned boolean
            }
            if(($x -lt $grid.GetLength(0)) -and ($grid[($x+1),$y] -eq $color)) { #can go right
                $_ = $nextStep.Add("$($x+1),$($y)")
            }
            if(($y -gt 0) -and ($grid[$x,($y-1)] -eq $color)) { # can go up
                $_ = $nextStep.Add("$($x),$($y-1)")
            }
            if(($y -lt $grid.GetLength(1)) -and ($grid[$x,($y+1)] -eq $color)) { # can go up
                $_ = $nextStep.Add("$($x),$($y+1)")
            }
        }
        # nextstep is now populated with everything currstep can reach, so...
        $checked.UnionWith($currStep)  # mark all of currstep as checked, and
        $nextStep.ExceptWith($checked) # remove anything already checked from nextStep
        # on next loop, if the block could only have expanded inwards, nextStep will be empty, and the loop will end
    }
    # but ultimately I want a sortable array of coordinates, not a set of strings
    $out = [List[Coord]]::new()
    foreach($s in $checked) {
        $c = $s.split(",")
        $out.add([Coord]::new($c[0],$c[1]))
    }
    return $out
}

#  in: int[,] grid
# out: hashtable "x,y" -> list[coord] (the block it's a part of)
function allBlocks {
    param([int[,]]$grid)
    # remember, list.contains(new coord) works by .Equals function, aka properly
    $out = @{}
    $remaining = [List[Coord]]::new()
    for($i = 0; $i -lt $grid.GetLength(0); $i ++) {
        for($j = 0; $j -lt $grid.GetLength(1); $j ++) {
            $remaining.Add([Coord]::new($i, $j))
        }
    }
    while($remaining.count -gt 0) {
        $nextCoord = $remaining[0]
        $blockList = getBlock $grid $nextCoord.x $nextCoord.y
        foreach($c in $blockList) {
            $out.Add($c.ToString(), $blockList)
            $_ = $remaining.remove($c) # I don't need to know if it succeeded
        }
    }
    return $out
}

class PietState {
    [List[int]]$stack
    [int]$dp
    [int]$cc
    [string]$out
    [bool]$muffled

    PietState() {
        $this.stack = [List[int]]::new()
        $this.dp = 0
        $this.cc = 0
        $this.out = ""
        $this.muffled = $true
    }

    PietState($muffled) {
        $this.stack = [List[int]]::new()
        $this.dp = 0
        $this.cc = 0
        $this.out = ""
        $this.muffled = [bool]$muffled
    }

    [void]Push([int]$val) {
        $this.stack.Insert(0, $val)
    }
    [int]QuietPop() {
        if($this.stack.Count -gt 0) {
            $a = $this.stack[0]
            $this.stack.RemoveAt(0)
            return $a
        } else {
            return 0
        }
    }
    [void]Pop() {
        if($this.stack.Count -gt 0) {
            $this.stack.RemoveAt(0)
        }
    }
    [void]Add() {
        if($this.stack.Count -gt 1) {
            $a = $this.QuietPop()
            $b = $this.QuietPop()
            $this.Push($b + $a)
        }
    }
    [void]Subtract() {
        if($this.stack.Count -gt 1) {
            $a = $this.QuietPop()
            $b = $this.QuietPop()
            $this.Push($b - $a)
        }
    }
    [void]Multiply() {
        if($this.stack.Count -gt 1) {
            $a = $this.QuietPop()
            $b = $this.QuietPop()
            $this.Push($b * $a)
        }
    }
    [void]Divide() {
        if($this.stack.Count -gt 1) {
            $a = $this.QuietPop()
            $b = $this.QuietPop()
            $this.Push([System.Math]::Floor($b / $a))
        }
    }
    [void]Modulo() {
        if($this.stack.Count -gt 1) {
            $a = $this.QuietPop()
            $b = $this.QuietPop()
            $this.Push($b % $a)
        }
    }
    [void]Not() {
        if($this.stack.Count -gt 0) {
            $a = $this.QuietPop()
            if($a) {
                $this.Push(0)
            } else {
                $this.Push(1)
            }
        }
    }
    [void]Greater() {
        if($this.stack.Count -gt 1) {
            $a = $this.QuietPop()
            $b = $this.QuietPop()
            if($b -gt $a) {
                $this.Push(1)
            } else {
                $this.Push(0)
            }
        }
    }
    [void]Pointer() {
        if($this.stack.Count -gt 0) {
            $a = $this.QuietPop()
            $this.dp += $a
            while($this.dp -lt 0) {
                $this.dp += 4
            }
            $this.dp %= 4
        }
    }
    [void]PSwitch() {
        if($this.stack.Count -gt 0) {
            $a = $this.QuietPop()
            $this.cc += $a
            $this.cc %= 2
            if($this.cc -lt 0) {
                $this.cc = 1
            }
        }
    }
    [void]Duplicate() {
        if($this.stack.Count -gt 0) {
            $this.Push($this.stack[0])
        }
    }
    [void]Roll() {
        if($this.stack.Count -gt 1) {
            $a = $this.QuietPop()
            $b = $this.QuietPop()
            $copy = $this.stack[0..($b-1)]
            for($i = 0; $i -lt $b; $i ++) {
                $this.stack[$i] = $copy[(($i+$a) % $b)]
            }
        }
    }
    [void]InNum() {
        $a = Read-Host "Input Number"
        $this.Push([int]$a)
    }
    [void]InChar() {
        $a = Read-Host "Input Char"
        $this.Push([int][byte][char]($a[0]))
    }
    [void]OutNum() {
        if($this.stack.Count -gt 0) {
            $midout = [string]$this.QuietPop()
            $this.out += $midout
            if(-not $this.muffled) {
                Write-Host $midout
            }
        }

    }
    [void]OutChar() {
        if($this.stack.Count -gt 0) {
            $midout = [System.Text.Encoding]::UTF8.GetChars(@([byte]$this.QuietPop()))
            $this.out += $midout
            if(-not $this.muffled) {
                Write-Host $midout
            }
        }
    }
    [string]ReturnOut() {
        return $this.out
    }
    [void]PrintOut() {
        Write-Host ($this.out)
    }
}

#  in: List[Coord] prevBlock, PietState piet
# out: "next" Coord irrespective of validity, not checking edge-of-image or black codel
# dp 0 = right, increase clockwise
# cc 0 = left, 1 = right
function nextBlockBlind {
    param([List[Coord]]$prevBlock, [PietState]$piet)
    switch(2*$piet.dp + $piet.cc) {
        0 { $next = ($prevBlock | Sort-Object -Property @{Expression = "x"; Descending = $true}, @{Expression = "y"; Descending= $false})[0];
            return ([Coord]::new($next.x + 1, $next.y))
        }
        1 { $next = ($prevBlock | Sort-Object -Property @{Expression = "x"; Descending = $true}, @{Expression = "y"; Descending= $true})[0];
            return ([Coord]::new($next.x + 1, $next.y))
        }
        2 { $next = ($prevBlock | Sort-Object -Property @{Expression = "y"; Descending = $true}, @{Expression = "x"; Descending= $true})[0];
            return ([Coord]::new($next.x, $next.y + 1))
        }
        3 { $next = ($prevBlock | Sort-Object -Property @{Expression = "y"; Descending = $true}, @{Expression = "x"; Descending= $false})[0];
            return ([Coord]::new($next.x, $next.y + 1))
        }
        4 { $next = ($prevBlock | Sort-Object -Property @{Expression = "x"; Descending = $false}, @{Expression = "y"; Descending= $true})[0];
            return ([Coord]::new($next.x - 1, $next.y))
        }
        5 { $next = ($prevBlock | Sort-Object -Property @{Expression = "x"; Descending = $false}, @{Expression = "y"; Descending= $false})[0];
            return ([Coord]::new($next.x - 1, $next.y))
        }
        6 { $next = ($prevBlock | Sort-Object -Property @{Expression = "y"; Descending = $false}, @{Expression = "x"; Descending= $false})[0];
            return ([Coord]::new($next.x, $next.y - 1))
        }
        7 { $next = ($prevBlock | Sort-Object -Property @{Expression = "y"; Descending = $false}, @{Expression = "x"; Descending= $true})[0];
            return ([Coord]::new($next.x, $next.y - 1))
        }
    }
}

#  in: @{str->List} blockMap, int[,] colorGrid, Coord prevCoord, PietState piet
# out: Coord next in codel pointer movement, (-1,-1) if halting
# dp 0 = right, increase clockwise
# cc 0 = left, 1 = right
function nextBlock {
    param([hashtable]$blockMap, [int[,]]$colors, [Coord]$prevCoord, [PietState]$piet)
    if($colors[$prevCoord.x, $prevCoord.y] -lt 0) { # codel pointer "glides" through white blocks
        $corners = [List[Coord]]::new()             # per DM's interpretation, execution only halts on retracing
        $flag = $false
        while(-not $corners.Contains($prevCoord)) { # so this keeps going until it turns on the same codel twice
            if($flag) {
                $corners.Add([Coord]::new($prevCoord.x, $prevCoord.y)) # skips the first time, when it first enters the block
            }                                                          # it's a corner-keeper, not an entrance-keeper
            $flag = $true
            switch($piet.dp) {                      # since it will always turn right - thus retracing
                0 { $dir = @(1,0); break }
                1 { $dir = @(0,1); break } # only dp matters since we're gliding, not finding a forward edge
                2 { $dir = @(-1,0); break}
                3 { $dir = @(0,-1); break}
            }
            while($blockMap.ContainsKey($prevCoord.ToString()) -and ($colors[$prevCoord.x, $prevCoord.y] -eq -1)) {
                $prevCoord.x += $dir[0] # ^ while still looking at a white codel block,
                $prevCoord.y += $dir[1] # < move the pointer in the dp's direction
            } # ends when the pointer hits image border or a nonwhite codel
            if($blockMap.ContainsKey($prevCoord.ToString()) -and ($colors[$prevCoord.x, $prevCoord.y] -ne -2)) {
                return $prevCoord # if the while-loop broke on a color codel, mission complete!
            } else {              # otherwise, it's time to turn
                $prevCoord.x -= $dir[0] # undo that last step: back onto the white block
                $prevCoord.y -= $dir[1]
                $piet.dp = ($piet.dp + 1) % 4 # turn the pointer
                $piet.cc = ($piet.cc + 1) % 2 # cc is toggled, but both values would've failed, hence the immediate turn
            }
        }
    } else {
        $prevBlock = $blockMap[$prevCoord.ToString()] # starting codel of block doesn't matter in color blocks
        for($i = 0; $i -lt 8; $i ++) { # one attempt per dp+cc state, then halt
            $test = nextBlockBlind $prevBlock $piet
            if($blockMap.ContainsKey($test.toString())) { # make sure the coord isn't OOB
                if($colors[$test.x,$test.y] -ne -2) {     # -2 is the color code for black
                    return $test
                }
            }
            # if it reaches here, $test hit a black codel or image border
            if($i % 2 -eq 0) { # first, switch the cc
                $piet.cc = ($piet.cc + 1) % 2
            } else { # if that doesn't work, rotate the dp
                $piet.dp = ($piet.dp + 1) % 4
            }
        }
    }
    # all 8 directions have failed. program halts, return invalid Coor
    return [Coord]::new(-1,-1)
}

# determines and executes command
#  in: int[,] colorGrid, List[Coord] prevBlock, List[Coord] nextBlock, PietState piet
# out: void
function pietCmd {
    param([int[,]]$grid, [List[Coord]]$prevBlock, [List[Coord]]$nextBlock, [PietState]$piet)
    $prevColor = $grid[$prevBlock[0].x,$prevBlock[0].y]
    $nextColor = $grid[$nextBlock[0].x,$nextBlock[0].y]
    if(($prevColor -lt 0) -or ($nextColor -lt 0)) { # no instructions execute on a white block
        return
    }
    $dDark = (($nextColor % 3) - ($prevColor % 3) + 3) % 3
    $dHue = ([System.Math]::Floor($nextColor / 3) - [System.Math]::Floor($prevColor / 3) + 6)  % 6
    switch($dHue * 3 + $dDark) {
         1 { $piet.Push($prevBlock.Count); break }
         2 { $piet.Pop(); break }
         3 { $piet.Add(); break }
         4 { $piet.Subtract(); break }
         5 { $piet.Multiply(); break }
         6 { $piet.Divide(); break }
         7 { $piet.Modulo(); break }
         8 { $piet.Not(); break }
         9 { $piet.Greater(); break }
        10 { $piet.Pointer(); break }
        11 { $piet.PSwitch(); break }
        12 { $piet.Duplicate(); break }
        13 { $piet.Roll(); break }
        14 { $piet.InNum(); break }
        15 { $piet.InChar(); break }
        16 { $piet.OutNum(); break }
        17 { $piet.OutChar(); break }
    }
}

# runs a piet program from a filename or image
# a "muffled" piet will only display output on halt - good for Hello World, bad for infinite loops
#  in: string filename or Bitmap image, optional boolean muffled, optional int maxCycles
# out: string (piet output)
function RunPiet {
    param([Object]$src, [bool]$muffled = $false, [int]$maxCycles = 10000)
    if($src -is [string]) {
        $grid = fileToColors ([string]$src)
    } elseif($src -is [Bitmap]) {
        $grid = imgToColors ([Bitmap]$src)
    } else {
        throw [System.ArgumentException]::new("Source object was neither a filename nor bitmap.", "src")
    }
    $piet = [PietState]::new($muffled)
    $blockMap = allBlocks $grid
    $currCoord = [Coord]::new(0,0) # keeps track of codel pointer location
    $currBlock = $blockMap[$currCoord.ToString()] # the block we'll be leaving behind
    for($i = 0; ($i -lt $maxCycles) -and ($currBlock.Count -gt 0); $i ++) {
#        if($i -eq 6) {
#            $i = $i
#        }
        $currCoord = nextBlock $blockMap $grid $currCoord $piet # move pointer to next block
        $nextBlock = $blockMap[$currCoord.toString()] # grab next block, if invalid returns null (0-count)
        if($nextBlock.Count -gt 0) {
            pietCmd $grid $currBlock $nextBlock $piet # execute cmd based on prev and next blocks
        }
        $currBlock = $nextBlock # prepare to leave next block, or prepare to check for emptiness in the for-loop
    }
    return $piet.out
}

# resizes bitmap into single-pixel codels by sampling the "middles" of codels
# assumes a square program if height not given
#  in: Bitmap img, int width, int height
# out: Bitmap img
function ResizeImage {
    param([Bitmap]$img, [int]$w, [int]$h = 0)
    if($h -lt 1) {
        $h = $w
    }
    $out = [Bitmap]::new($w, $h)
    $XCodel = $img.Width / $w
    $YCodel = $img.Height / $h
    for($i = 0; $i -lt $w; $i ++) {
        for($j = 0; $j -lt $h; $j ++) {
            $out.SetPixel($i, $j, $img.GetPixel(($i+0.5)*$XCodel, ($j+0.5)*$YCodel))
        }
    }
    return $out
}

# resizes, then runs, a filename or image
#  in: string filename or Bitmap image, int target width, optional int target height, optional bool muffled, optional int maxCycles
# out: string (piet output)
function SizeAndRun {
    param([Object]$src, [int]$w, [int]$h=0, [bool]$muffled = $false, [int]$maxCycles=10000)
    if($src -is [string]) {
        $img = [Bitmap]::new([string]$src)
    } elseif($src -is [Bitmap]) {
        $img = $src
    } else {
        throw [System.ArgumentException]::new("Source object was neither a filename nor bitmap.", "src")
    }
    $img2 = ResizeImage $img $w $h
    if($src -is [string]) {
        $img.Dispose()
    }
    RunPiet $img2 $muffled $maxCycles
}

# command help function for this script
# focused more on end-user Piet interpretation - if you're doing more scripty things, you can read the comments here
function pietHelp {
    "RunPiet `$src `$muffled? `$maxCycles?"
    "`tExecutes the given Piet program, with a codel size of 1 pixel"
    "`t`$src:       [string] file path, or [Bitmap] image object, of the Piet program image"
    "`t`$muffled:   [boolean] whether to wait until halt to output, or output mid-execution"
    "`t            defaults to `$false (prints a num/char when a Piet Out command is executed"
    "`t`$maxCycles: [int] how many Piet color blocks to pass through before halting"
    "`t            defaults to 10k. All nonblack codel blocks increment this counter"
    ""
    "SizeAndRun `$src `$w `$h? `$muffled? `$maxCycles?"
    "`tCreates a resized copy of the program image, then runs the program"
    "`t`$src:   see RunPiet above. May have codel sizes greater than 1 pixel"
    "`t`$w:     [int] width of the Piet program, in codels"
    "`t`$h:     [int] height of the Piet program, in codels"
    "`t        defaults to the value given for `$w"
    "`t`$muffled, `$maxCycles: identical functionality as for RunPiet above"
}
