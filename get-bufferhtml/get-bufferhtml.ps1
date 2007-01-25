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

# $id$

#------------------------------------------------------------------------------
# This script grabs text from the console buffer and outputs to the pipeline
# lines of HTML that represent it.
#
# Usage: get-bufferhtml [args]
#
# Where args are:
#
# -last n       - how many lines back from current line to grab
#                 default is (effectively) everything
# -all          - grab all lines in console, overrides -last
# -trim         - trims blank space from the right of each line
#                 this is ok unless you have lots of text with
#                 varying background colours
# -font s       - optional css font name. default is nothing which
#                 means the browser will use whatever is default for a
#                 <pre> tag. "Courier New" is quite a good alternative
# -fontsize s   - optional css font size, eg "9pt" or "80%"
# -style s      - optional addition css, eg "overflow:hidden"
# -palette p    - choose a colour palette, one of:
#                 "powershell" normal for a PowerShell window (ie with
#                              strange colours for darkmagenta and darkyellow
#                 "standard"   normal ansi colours as used by a standard
#                              cmd.exe session
#                 "print"      like powershell, but with colours handy
#                              for printing where you want to save ink.
#
# The output is one large wrapped <pre> tag to keep whitespace intact.
#

param(
  [int]$last = 50000,             
  [switch]$all,                   
  [switch]$trim,                  
  [string]$font=$null,            
  [string]$fontsize=$null,        
  [string]$style="",              
  [string]$palette="powershell"   
  )
$ui = $host.ui.rawui
[int]$start = 0
if ($all) { 
  [int]$end = $ui.BufferSize.Height  
  [int]$start = 0
}
else { 
  [int]$end = ($ui.CursorPosition.Y - 1)
  [int]$start = $end - $last
  if ($start -le 0) { $start = 0 }
}
$height = $end - $start
if ($height -le 0) {
  write-warning "There must be one or more lines to get"
  return
}
$width = $ui.BufferSize.Width
$dims = 0,$start,($width-1),($end-1)
$rect = new-object Management.Automation.Host.Rectangle -argumentList $dims
$cells = $ui.GetBufferContents($rect)

# set default colours
$fg = $ui.ForegroundColor; $bg = $ui.BackgroundColor
$defaultfg = $fg; $defaultbg = $bg

# character translations
# wordpress weirdness means I do special stuff for < and \
$cmap = @{
    [char]"<" = "<span>&lt;</span>"
    [char]"\" = "&#x5c;"
    [char]">" = "&gt;"
#      [char]"'" = "&apos;" # IE7 doesn't like this for some reason
    [char]"`"" = "&quot;"
    [char]"&" = "&amp;"
}

# console colour mapping
# the powershell console has some odd colour choices, 
# marked with a 6-char hex codes below
$palettes = @{}
$palettes.powershell = @{
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
# now a variation for the standard console (used by cmd.exe) based
# on ansi colours
$palettes.standard = ($palettes.powershell).Clone()
$palettes.standard.DarkMagenta = "#808"
$palettes.standard.DarkYellow = "#880"

# this is a weird one... takes the normal powershell one and
# inverts a few colours so normal ps1 output would save ink when
# printed (eg from a web page).
$palettes.print = ($palettes.powershell).Clone()
$palettes.print.DarkMagenta = "#eee"
$palettes.print.DarkYellow = "#000"
$palettes.print.Yellow = "#440"
$palettes.print.Black = "#fff"
$palettes.print.White = "#000"

$comap = $palettes[$palette]

# inner function to translate a console colour to an html/css one
function c2h{return $comap[[string]$args[0]]}
$f=""
if ($font) { $f += " font-family: `"$font`";" }
if ($fontsize) { $f += " font-size: $fontsize;" }
$line  = "<pre style='color: $(c2h $fg); background-color: $(c2h $bg);$f $style'>" 
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
  if ($trim) { $line = $Line.TrimEnd() }
  $line
  $line=""
}
if ($fg -ne $defaultfg -or $bg -ne $defaultbg) { "</span>" } # close off any specialisation of colour
"</pre>"

