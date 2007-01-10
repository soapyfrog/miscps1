#------------------------------------------------------------------------------
# Copyright 2006 Adrian Milliner (ps1 at soapyfrog dot com)
# http://ps1.soapyfrog.com
#
# This work is licenced under the Creative Commons 
# Attribution-NonCommercial-ShareAlike 2.5 License. 
# To view a copy of this licence, visit 
# http://creativecommons.org/licenses/by-nc-sa/2.5/ 
# or send a letter to 
# Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#------------------------------------------------------------------------------

# $Id$

#------------------------------------------------------------------------------
# Sudoku Solver! In PowerShell!
#------------------------------------------------------------------------------

# name the file parameter
param($puzzleFile)

#------------------------------------------------------------------------------
# Read a puzzle into a 81 byte int array from a file containing 81
# numbers separated by white space (or anything else for that matter)
#
function get-puzzle {
  param(
    $filename = $(throw "supply a file name")
    )
  [int[]]$puzzle = @()
  get-content -erroraction "stop" $filename | foreach {  # for each line
    ([char[]]$_) | foreach {  # for each character
      if ($_ -ge [char]"0" -and $_ -le [char]"9") {
        [int]$num = [int][string]$_
        $puzzle += $num
      }
    }
  }
  $c = $puzzle.length
  if ($c -ne 81) { throw "puzzle should have 81 numbers, found $c" }
  return $puzzle
}

#------------------------------------------------------------------------------
# format-puzzle
#
function format-puzzle {
  param([int[]]$puzzle = $(throw "supply a puzzle"))
  $out = ""
  $pos = 0
  [string]$blank = "."
  foreach ($row in 0..8) {
    foreach ($col in 0..8) {
      $v = $puzzle[$pos++]
      if ($v) { $out += "$v" }
      else { $out += $blank }
      $out += " "
      if (2,5 -eq $col) { $out += " " }
    }
    $out += "`n"
    if (2,5 -eq $row) { $out += "`n" }
  }
  return $out
}


#------------------------------------------------------------------------------
# For a given position, find which values are valid and which are not.
# Returned is an array of booleans where the index is the 1..9 value
# and the true/false bit indicates if it's invalid (true) or not
#
function find-invalidvalues {
  param($puzzle,[int]$pos)
  $invalid = new-object boolean[](10) # we only use 1..9
  $tocheck = $script:positionCache[$pos].Keys
  foreach ($o in $tocheck) {
    $inv = $puzzle[$o]
    $invalid[$inv] = $true
  }
  return $invalid
}

#------------------------------------------------------------------------------
# Recursive solve method, called by the public solve-puzzle
#
function _solve {
  param($result=$(throw "supply a result hash"))

  $puzzle = $result.puzzle # get it out for perf reasons
  # iterate over all positions
  for ([int]$ipos=0; $ipos -lt 81; $ipos++) {
    if ($puzzle[$ipos]) { continue } # already got a solution for this pos
    # find numbers that cannot go in this position
    $invalidNums = find-invalidvalues $puzzle $ipos
    # for each value that is possible, set the value then try to
    # solve recursively
    for ([int]$v = 1; $v -le 9; $v++ ) {
      if (-not $invalidNums[$v] ) {
        $puzzle[$ipos] = $v
        $result.guesses++
        if (_solve $result) { return $true } # solved, unwind
      }
    }
    # if we get here, we're not solved, so reset value to 0 and return false
    $puzzle[$ipos] = 0
    $result.wrongGuesses++
    return $false
  }
  # if we ever get here, we're solved!
  return $true
}

#------------------------------------------------------------------------------
# Build caches for performance reasons.
# positionCache is an array of array of positions where for each
# cache entry includes the positions of the corresponding row,col and 3x3 grid
#
function _build-positioncache {
  $script:positionCache = 0..80  # create an array of correct size
  foreach ($i in 0..80) {
    [int]$keyrow = [Math]::Floor($i/9)
    [int]$keycol = $i % 9
    $pos = @{} # hash of positions to whatever (.net doesn't seem to have sets)
    foreach ($o in 0..8) { # add same row and col
      $pos[$keyrow * 9 + $o] = $true
      $pos[$o * 9 + $keycol] = $true
    }
    # now work out same square
    [int]$srow = 3 * [Math]::Floor($keyrow/3)
    [int]$scol = 3 * [Math]::Floor($keycol/3)
    foreach ($row in $srow..($srow+2)) {
      foreach ($col in $scol..($scol+2)) {
        $pos[$row*9+$col] = $true
      }
    }
    $pos.remove($i) # don't need own position
    $script:positionCache[$i] = $pos
  }
}

#------------------------------------------------------------------------------
# Solve the supplied puzzle.
# puzzle param is an int[81]
# The return value is a hash with keys:
#     original     - original puzzle
#     puzzle       - solved puzzle (or as solved as can be)
#     solved       - $true if solved, $false if not
#     guesses      - number of guesses the solver made
#     wrongguesses - the number of guesses that were wrong
function solve-puzzle {
  param(
    [int[]]$puzzle = $(throw "supply a puzzle")
    )

  $result = @{
    "original"      = $puzzle.Clone()
    "puzzle"        = $puzzle
    "guesses"       = 0
    "solved"        = $false
    "wrongguesses"  = 0
  }

  _build-positioncache

  $result.solved = _solve $result
  return $result
}



#------------------------------------------------------------------------------
# Here we go!
$puzzle = get-puzzle $puzzleFile
write-host "Going to to try to solve this puzzle:`n$(format-puzzle $puzzle)"
$dur = measure-command { $result = solve-puzzle $puzzle }

if ($result.solved) {
  write-host "Solved!"
  write-host "Guesses $($result.guesses) ($($result.wrongguesses) were wrong)"
  write-host "Elapsed time $dur"
  write-host "Result:`n$(format-puzzle $result.puzzle)"
}
else {
  write-host "Failed to solve the puzzle :-("
}

