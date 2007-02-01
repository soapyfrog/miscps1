#------------------------------------------------------------------------------
# Copyright 2006-2007 Adrian Milliner (ps1 at soapyfrog dot com)
# http://ps1.soapyfrog.com
#
# This work is licenced under the Creative Commons 
# Attribution-NonCommercial-ShareAlike 2.5 License. 
# To view a copy of this licence, visit 
# http://creativecommons.org/licenses/by-nc-sa/2.5/ 
# or send a letter to 
# Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#------------------------------------------------------------------------------
#
# $Id$
#
#------------------------------------------------------------------------------
# This script takes text or pipeline input and surrounds it in a box
# using line drawing characters or ascii (if -ascii switch supplied).
#
# When using the pipeline for input, note that the whole pipe is read
# so it can figure out how wide to make the box.
#
param(
  [string[]]$text,        # The text to box. If ommitted, uses pipeline
  [switch]$ascii,         # box in ascii chars only
  [switch]$trim           # trim white space from end of lines
)

# substitute pipe with text, if supplied
$inp = $( if ($text) { $text } else { $input } )

# turn them in to formatted strings (if not already)
[string[]]$lines = out-string -input $inp -stream

if ($lines -eq $null) {
  write-warning "No input supplied (with -text param or in pipe)" 
  return
}

# trim in neccessary
if ($trim) {
  # first, end of lines
  $lines = ($lines | % { $_.TrimEnd() }) 
  # now leading and trailing lines
  [Collections.ArrayList]$lines = $lines # change its type for easier manipulation
  while ($lines.Count -gt 0 -and $lines[0] -eq "") { $lines.RemoveAt(0) }
  while ($($n=$lines.LastIndexOf(""); $n) -ge 0) {$lines.RemoveAt($n) }
}

# find out max width (for sizing)
$maxwidth = ($lines | foreach{$m=0}{$m=[Math]::Max($m,$_.Length)}{$m} )

# define graphics for ascii and line drawing chars
$gfxascii = @{top="-";left="|";right="|";bottom="-"
              topleft="+";topright="+";bottomleft="+";bottomright="+"}

$ud=[string][char]0x2502
$lr=[string][char]0x2500
$gfxline = @{top=$lr;bottom=$lr;left=$ud;right=$ud
      topleft=[string][char]0x250c;topright=[string][char]0x2510
      bottomleft=[string][char]0x2514;bottomright=[string][char]0x2518}

# pick one
$gfx= $(if ($ascii) { $gfxascii } else { $gfxline } )

# output the box
$gfx.topleft + $gfx.top*$maxwidth + $gfx.topright
foreach ($line in $lines) {
  $gfx.left + $line.PadRight($maxwidth," ") + $gfx.right
}
$gfx.bottomleft + $gfx.bottom*$maxwidth + $gfx.bottomright
