# Green-Remover-Powershell
This is a proof of concept of a green screen remover using FFMPEG and ImageMagic. It is functionally the same as GIPHY's bash script, but remade to work in Powershell Core.

Requires:
 * PowerShell 7.x
 * Recent version of FFMPEG
 * ImageMagick
 
This script will analyze video and produce a GIF with transparency. It is neither robust nor well tested.

More information [on their blog](https://engineering.giphy.com/modifying-ffmpeg-to-support-transparent-gifs/).