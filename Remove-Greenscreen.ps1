<#
.SYNOPSIS
    Attempts to convert a greenscreened video into a gif sticker automatically using a number of assumptions.

.DESCRIPTION
    A more detailed description of why and how the function works.

.NOTES
    Author: Original script by Giphy, adapted to Powershell by Gwyndolyn Marchant
#>

param(
	# A video file you want turned into a sticker.
	[Parameter(Mandatory=$true)]
	[string]$Source,

	# Where you want the file to go. Should be a .gif file. Existing files at output path will be overwritten.
	[Parameter(Mandatory=$true)]
	[string]$Output,

	# How much variation in the background should be allowed. Larger values will remove more pixels that look less like the identified background. Start with a value of around 10 and increase to remove more and decrease to remove less.
	[int]$Spread = 10,

	# A string containing at least one of 1, 2, 3, and 4, representing the four corners of the image. 1 is the top left, and the rest continue clockwise. a portion of each corner is sampled to determine what is background and should be removed. Pick the corners that contain only background colors.
	[Parameter(Mandatory=$true)]
	[string]$Corners
)

# constants
$WORKDIR = ".temp"
$CROPPERCENTAGE = 10

# make a temporary working directory
if ([System.IO.File]::Exists($WORKDIR)) { rm -r $WORKDIR }
mkdir $WORKDIR

# generate a first frame:
$ff = "$WORKDIR/frame1.png"
ffmpeg.exe -i "$Source" -vframes 1 -an -ss 0.0 $ff

# get the width and height:
$width  = magick.exe identify -format '%w' $ff
$height = magick.exe identify -format '%h' $ff
$left = $width - ($CROPPERCENTAGE * $width) / 100
$bottom = $height - ($CROPPERCENTAGE * $height) / 100

$crops = "";

# depending on the corners we've selected, crop the image and make sub-images.
if ($corners -like "*1*") {
	# top left
	magick.exe convert $ff -crop "$CROPPERCENTAGE%x+0+0" "$WORKDIR/crop1.png"
	$crops += "$WORKDIR/crop1.png "
}

if ($corners -like "*2*") {
	# top right
	magick.exe convert $ff -crop "$CROPPERCENTAGE%x+$left+0" "$WORKDIR/crop2.png"
	$crops += "$WORKDIR/crop2.png "
}

if ($corners -like "*3*") {
	# bottom right
	magick.exe convert $ff -crop "$CROPPERCENTAGE%x+$left+$bottom" "$WORKDIR/crop3.png"
	$crops += "$WORKDIR/crop3.png "
}

if ($corners -like "*4*") {
	# top left
	magick.exe convert $ff -crop "$CROPPERCENTAGE%x+0+$bottom" "$WORKDIR/crop4.png"
	$crops += "$WORKDIR/crop4.png "
}

#now montage the corners into one:
"The crops are: $crops"
magick.exe montage ($crops -Split ' ') -geometry "${width}x${height}+0+0" -tile 1x "$WORKDIR/montage.png"

#get stats for the montaged image
$fmt = '%[fx:int(255*mean.r)] %[fx:int(255*standard_deviation.r)]'
$fmt += ' %[fx:int(255*mean.g)] %[fx:int(255*standard_deviation.g)]'
$fmt += ' %[fx:int(255*mean.b)] %[fx:int(255*standard_deviation.b)]'
$fmt += ' %[fx:int(255*mean)] %[fx:int(255*standard_deviation)]'
$vals = (magick.exe identify -format "$fmt" "$WORKDIR/montage.png") -Split ' ';

$ave = @(0.0, 0.0, 0.0, 0.0)
$dev = @(0.0, 0.0, 0.0, 0.0)
for ($i = 0; $i -lt 4; $i++) {
	$ave[$i] = $ave[$i] + $vals[$i*2]
	$dev[$i] = $dev[$i] + $vals[$i*2+1]
}

# now we are ready to take our original video and convert it to a transparent gif
# we do this in two passes: 1 to make a pallete, and 2 to make the actual gif.
$hexcolor = '0x{0:x2}{1:x2}{2:x2}' -f [int]$ave[0], [int]$ave[1], [int]$ave[2];
if ($dev[3] -eq 0) { $dev[3] = 1.0 }; $dev[3] * $spread;
$similarity = $dev[3] * $Spread / 255.0;

$maxw = 720
$maxh = 720

$scale = "scale='min(1,min($maxw/iw,$maxh/ih))*iw':'min(1,min($maxw/iw,$maxh/ih))*ih'"
$chromakey = "chromakey=${hexcolor}:${similarity}"
ffmpeg -v error -i "$Source" -filter_complex "[0:v]$scale,$chromakey[a];[a]palettegen[b]" -map "[b]" "$WORKDIR/pallette.png"
ffmpeg -v error -i "$Source" -i "$WORKDIR/pallette.png" -filter_complex "[0:v]$scale,$chromakey[trans];[trans][1:v]paletteuse[out]" -map "[out]" -y "$output"

# clean our working directory
rm -r $WORKDIR
