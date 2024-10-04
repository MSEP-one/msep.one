SETLOCAL
::Standard scope
Set PWD=%cd%

C:

cd %APPDATA%/Godot\app_userdata\MSEP\msep.one

call Scripts\activate.bat
call Scripts\conda-unpack.exe

D:

cd %PWD%\..\..\godot_project\python\scripts
echo %cd%

call python openmm_server.py

ENDLOCAL
pause