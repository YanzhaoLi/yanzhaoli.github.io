@echo off  
    
rem 设置当前目录   
set current_dir=E:\JS\yanzhaoli.github.io
  
pushd %current_dir%    
  
rem 输出当前目录 
echo %cd%   
  
popd    

git status  
pause

echo "git add *"
git add *
pause

echo "git commit -m update *"
git commit -m "update" *
pause

echo "git push origin master"
git push origin master
pause