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
# This script takes a string and outputs it in banner form.
#

param([string[]]$inputtext,[char]$fg=0x2588,[char]$bg=" ")

# if input text supplied, use it instead of default pipeline
if ($inputtext) { $input = $inputtext }

function create-cache {
# do not change the formatting of this script as trailing spaces are important
$digits=@"
 www    w    www   www  w  w  wwww   www  wwwww  www   www   
w  ww  ww       w w   w w  w  w     w         w w   w w   w  
w w w   w    www    ww  wwwww wwww  wwww     w   www   wwww  
ww  w   w   w     w   w    w      w w   w   w   w   w     w  
 www   www  wwwww  www     w  wwww   www   w     www   www   
"@

$a2j=@"
 www  wwww   www  wwww  wwwww wwwww  www  w   w  www      w  
w   w w   w w   w w   w w     w     w     w   w   w       w  
wwwww wwww  w     w   w www   www   w  ww wwwww   w       w  
w   w w   w w   w w   w w     w     w   w w   w   w       w  
w   w wwww   www  wwww  wwwww w      www  w   w  www   www   
"@

$k2t=@"
w   w w     w   w w   w  www  wwww   www  wwww   www  wwwww  
w  w  w     ww ww ww  w w   w w   w w   w w   w w       w    
www   w     w w w w w w w   w wwww  w   w wwww   www    w    
w  w  w     w   w w  ww w   w w     w  w  w   w     w   w    
w   w wwwww w   w w   w  www  w      ww w w   w  www    w    
"@
$u2z=@"
w   w w   w w   w w   w w   w wwwww                          
w   w w   w w   w  w w   w w     w                           
w   w w   w w w w   w     w     w                            
w   w  w w  ww ww  w w    w    w                             
 www    w   w   w w   w   w   wwwww                          
"@
$bang2star=@"
  w    w w   w w   www  w   w  ww      w     w   w     w w   
  w    w w  wwwww w w   w  w  w  w     w    w     w     w    
  w          w w   www    w    ww     w     w     w   wwwww  
            wwwww   w w  w  w w  w          w     w     w    
  w          w w   www  w   w  ww w          w   w     w w   
"@
$plus2rangle=@"
  w                         w                w          w    
  w                        w    w      w    w   wwwww    w   
wwwww    w  wwwww         w                w              w  
  w      w          ww   w             w    w   wwwww    w   
  w     w           ww  w       w     w      w          w    
"@
$queryat=@"
 www   www  
w   w w   w 
   w  w  ww 
      w     
  w    www  
"@
$lsquiggle2tilde=@"
  www   w   www         
  w     w     w    ww w 
ww      w      ww w ww  
  w     w     w         
  www   w   www         
"@
$lsquare2rsquare=@"
 www  w      www  
 w     w       w  
 w      w      w  
 w       w     w  
 www      w  www  
"@
$caret2backtick=@"
  w          w    
 w w         w    
w   w         w   
                  
      wwwww       
"@
$currency=@"
  www   w     www w   w 
 w     wwww  w     w w  
www   w w   wwww    w   
 w     wwww  w     www  
wwwww   w     www   w   
"@
$space=@"
      
      
      
      
      
"@
# parse the above in to an internal per-char hash
  function parsePatterns {
    param (
      [string]$pattern,           # a multiline pattern
      [string]$codes              # array of codes represented by pattern
      )
    $outhash = @{}
    [string[]]$lines = $pattern.split("`n")
    [int]$offset = 0
    foreach ($code in [char[]]$codes) {
      $charlines = @()
      foreach ($n in 0..4) {
        $charlines += $lines[$n].substring($offset,6)
      }
      $outhash[[char]$code] = $charlines
      $offset += 6
    }
    $outhash
  }


  $script:charmap = @{}
  $script:charmap += parsePatterns $digits "0123456789"
  $script:charmap += parsePatterns $a2j "abcdefghij"
  $script:charmap += parsePatterns $k2t "klmnopqrst"
  $script:charmap += parsePatterns $u2z "uvwxyz"
  $script:charmap += parsePatterns $bang2star "!`"#$%&'()*"
  $script:charmap += parsePatterns $plus2rangle "+,-./:;<=>"
  $script:charmap += parsePatterns $queryat "?@"
  $script:charmap += parsePatterns $lsquiggle2tilde "{|}~"
  $script:charmap += parsePatterns $lsquare2rsquare "[\]"
  $script:charmap += parsePatterns $caret2backtick "^_``"
  $script:charmap += parsePatterns $currency ([string]([char]0xa3 + [char]0xa2 +[char]0x20ac +[char]0xa5))
  $script:charmap += parsePatterns $space " "
} # end of create-cache


function process-line([string]$text) {

  # now write out the text
  $output = @("")*5
  $text = $text.ToLower()
  foreach ($char in [char[]]$text) {
    $c = $charmap[$char]
    if ($c -eq $null) { $c = $charmap[[char]"?"] }
    if ($c -eq $null) { $charmap.count; throw "oh dear" }
    foreach ($n in 0..4) {
      $output[$n] = $output[$n] + $c[$n]
    }
  }
  foreach ($line in $output) {
    # apply foreground and background
    # first move the existing chars out the way in case of clashes
    # TODO: do this a bit more intelligently
    $line = $line.replace("w",[char]0xf001).replace(" ",[char]0xf002)
    $line = $line.replace([char]0xf001,$fg).replace([char]0xf002,$bg)
    $line
  }
}

# Here we go!
if (! (test-path variable:charmap)) { create-cache }
foreach ($c in $input) {
  process-line $c
  ""
}
