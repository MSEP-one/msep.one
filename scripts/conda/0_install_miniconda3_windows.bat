curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe
Miniconda3-latest-Windows-x86_64.exe /InstallationType=JustMe /RegisterPython=0 /S /D=%HOMEPATH%\miniconda3
%HOMEDRIVE%
cd %HOMEPATH%\miniconda3\Scripts
conda.exe init --all
echo TERMINAL NEEDS TO CLOSE IN ORDER FOR CHANGES TO TAKE EFFECT
pause
exit