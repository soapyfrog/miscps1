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
# Simple function to get the contents of the console buffer as a series of
# lines of text
#
function get-bufferhtml {
  param(
    [int]$last = 50000,             # how many lines to get, back from current position
    [switch]$all,                   # if true, get all lines in buffer
    [switch]$trim,                  # if true, trim trailing spaces
    [string]$font="9pt courier new",# default is "9pt courier new"
    [string]$style=""               # extra css style for pre tag - def is blank
    )
  $ui = $host.ui.rawui
  [int]$start = 0
  if ($all) { 
    [int]$end = $ui.BufferSize.Height  
    [int]$start = 0
  }
  else { 
    [int]$end = $ui.CursorPosition.Y 
    [int]$start = $end - $last
    if ($start -le 0) { $start = 0 }
  }
  $width = $ui.BufferSize.Width
  $height = $end - $start
  $dims = 0,$start,($width-1),($end-1)
  $rect = new-object Management.Automation.Host.Rectangle -argumentList $dims
  $cells = $ui.GetBufferContents($rect)

  # set default colours
  $fg = $ui.ForegroundColor; $bg = $ui.BackgroundColor
  $defaultfg = $fg; $defaultbg = $bg
  
  # character translations
  $cmap = @{
      [char]"<" = "&lt;"
      [char]">" = "&gt;"
      [char]"'" = "&apos;" # my IE7 doesn't like this for some reason
      [char]"`"" = "&quot;"
      [char]"&" = "&amp;"
  }

  # console colour mapping
  # the windows console has some odd colour choices, 
  # marked with a 6-char hex codes below
  $comap = @{
      "Black"       ="#000"
      "DarkBlue"    ="#008"
      "DarkGreen"   ="#080"
      "DarkCyan"    ="#088"
      "DarkRed"     ="#800"
      "DarkMagenta" ="#012456"
      "DarkYellow"  ="#eeedf0"
      "Gray"        ="#ccc"
      "DarkGray"    ="#888"
      "Blue"        ="#00f"
      "Green"       ="#0f0"
      "Cyan"        ="#0ff"
      "Red"         ="#f00"
      "Magenta"     ="#f0f"
      "Yellow"      ="#ff0"
      "White"       ="#fff"
  }
  # inner function to translate a console colour to an html/css one
  function c2h{return $comap[[string]$args[0]]}
  $line  = "<pre style='color: $(c2h $fg); background-color: $(c2h $bg); font: $font ; $style'>" 
  for ([int]$row=0; $row -lt $height; $row++ ) {
    for ([int]$col=0; $col -lt $width; $col++ ) {
      $cell = $cells[$row,$col]
      # do we need to change colours?
      $cfg = [string]$cell.ForegroundColor
      $cbg = [string]$cell.BackgroundColor
      if ($fg -ne $cfg -or $bg -ne $cbg) {
        if ($fg -ne $defaultfg -or $bg -ne $defaultbg) { 
          $line += "</span>" # remove any specialisation
          $fg = $defaultfg; $bg = $defaultbg;
        }
        if ($cfg -ne $defaultfg -or $cbg -ne $defaultbg) { 
          # start a new colour span
          $line += "<span style='color: $(c2h $cfg); background-color: $(c2h $cbg)'>" 
        }
        $fg = $cfg
        $bg = $cbg
      }
      $ch = $cell.Character
      $ch2 = $cmap[$ch]; if ($ch2) { $ch = $ch2 }
      $line += $ch
    }
    $line#.TrimEnd() # dump the line in the output pipe
    $line=""
  }
  if ($fg -ne $defaultfg -or $bg -ne $defaultbg) { "</span>" } # close off any specialisation of colour
  "</pre>"
}
 

function colour-pattern {
  $f = $host.ui.rawui.foregroundcolor
  $b = $host.ui.rawui.backgroundcolor
  $rnd = new-object Random ((get-date).millisecond)
  for ($i=0; $i -lt 30; $i++) {
    $host.ui.rawui.backgroundcolor = $rnd.next(16)
    $host.ui.rawui.foregroundcolor = $rnd.next(16)
    write-host -noNewLine " $($rnd.next(10000)) "
  }
  $host.ui.rawui.backgroundcolor = $b
  write-host "`n"
  foreach ($i in 0..15) {
    $host.ui.rawui.backgroundcolor = $i
    $host.ui.rawui.foregroundcolor = $( if ($i) {0} else {7} )
    $cn = $host.ui.rawui.backgroundcolor.ToString()
    write-host -noNewLine ("  $cn  ".padright(20))
  }
  $host.ui.rawui.foregroundcolor = $f
  $host.ui.rawui.backgroundcolor = $b
  write-host

}


