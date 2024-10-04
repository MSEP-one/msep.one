@REM # This script uses ImageMagick
@REM # https://imagemagick.org/
@REM # magic.exe should be on the PATH environment variable

magick.exe  convert icon_16px.png icon_32px.png icon_48px.png icon_64px.png icon_96px.png icon_128px.png icon_256px.png icon_1024px.png ../icon.ico
pause