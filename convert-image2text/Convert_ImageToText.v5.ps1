#------------------------------------------------------------------------------
# Copyright 2006 Adrian Milliner (ps1 at soapyfrog dot com)
# http://ps1.soapyfrog.com
#
# Modified 2018 by RiverHeart
# Converted script to advanced function. Tested on Powershell v5
#
# This work is licenced under the Creative Commons
# Attribution-NonCommercial-ShareAlike 2.5 License
# To view a copy of this licence, visit
# http://creativecommons.org/licences/by-nc-sa/2.5/
# or send a letter to
# Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
#------------------------------------------------------------------------------

<#
 .Synopsis
    Loads the specified image, converts pixels to ASCII and outputs to the terminal.
 .EXAMPLE
    Convert-ImageToText image.jpg
 .EXAMPLE
    # Pipeline Usage
    ls PictureFolder | Convert-ImageToText
 .EXAMPLE
    # Saving output to a single file
    Convert-ImageToText pic1.jpg, pic2.jpg | Set-Content art.txt
 .EXAMPLE
    # Saving output to multiple files
    Convert-ImageToText pic1.jpg, pic2.png | % {$i = 1} { Set-Content -Value $_ "art_$i.txt"; $i++ }
#>
function Convert-ImageToText
{
    [CmdletBinding()]
    [Alias("img2txt")]
    [OutputType([string])]
    Param
    (
        # Images to process
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [String[]] $Path,
 
        # Type of ASCII characters to use.
        [Parameter(Mandatory=$false)]
        [ValidateSet("ascii", "shade")]
        [string] $Palette = "ascii",

        # 1.5 means char height is 1.5 x width
        [Parameter(Mandatory=$false)]
        [float] $Ratio = 1.5,

        # Determines how much terminal space is used.
        [Parameter(Mandatory=$false)]
        [int] $MaxWidth = 100,

        [Parameter(Mandatory=$false)]
        [switch] $NoNewLine
    )
 
    Begin
    {
        $Palettes = @{
            "ascii" = " .,:;=|iI+hHOE#`$"
            "shade" = " " + [char]0x2591 + [char]0x2592 + [char]0x2593 + [char]0x2588
            "bw"    = [char]0x2588
        }
        $CharPalette = $Palettes[$Palette].ToCharArray()
    }
    Process
    {
        foreach ($Item in $Path) 
        {
            $FullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPsPath($Item)
            $Image    = [System.Drawing.Image]::FromFile($FullPath)
            $sb       = [System.Text.StringBuilder]::new()

            # Resize image by converting to bitmap
            $MaxHeight = $Image.Height / ($Image.Width / $MaxWidth) / $Ratio
            $Bitmap    = [System.Drawing.Bitmap]::new($Image, $MaxWidth, $MaxHeight)
            $BWidth    = $Bitmap.Width
            $BHeight   = $Bitmap.Height

            # Convert pixels to ASCII
            $cplen = $CharPalette.count
            for ($y = 0; $y -lt $BHeight; $y++)
            {
                for ($x = 0; $x -lt $BWidth; $x++)
                {
                    $Color      = $Bitmap.GetPixel($x,$y)
                    $Brightness = $Color.GetBrightness()
                    $Offset     = [Math]::Floor($Brightness * $cplen)
                    $ch         = $CharPalette[$Offset]

                    # Handle overflow
                    if (-not $ch) { $ch = $CharPalette[-1] }
                    
                    [void] $sb.Append($ch)
                }
                [void] $sb.Append("`n")    # Add newline. Good for outputing multiple images to terminal.
            }

            if ($NoNewLine) { $sb.Length -= 1 }    # Remove last character

            # Draw Image
            $sb.ToString()

            # Clean up
            $Image.Dispose()
            $Bitmap.Dispose()
        }
    }
    End
    {
    }
}
