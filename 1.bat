@echo off  
  
rem 输出当前工作目录  
echo %cd%  
  
rem 设置当前目录   
set current_dir=E:\JS\yanzhaoli.github.io
  
pushd %current_dir%    
  
rem 输出当前目录 
echo %cd%   
  
popd    

git status  
pause

git add *
pause

git commit -m "update" *
pause

git push origin master
pause