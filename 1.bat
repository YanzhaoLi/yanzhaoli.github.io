@echo off  
    
rem ���õ�ǰĿ¼   
set current_dir=E:\JS\yanzhaoli.github.io
  
pushd %current_dir%    
  
rem �����ǰĿ¼ 
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