@echo off  
  
rem �����ǰ����Ŀ¼  
echo %cd%  
  
rem ���õ�ǰĿ¼   
set current_dir=E:\JS\yanzhaoli.github.io
  
pushd %current_dir%    
  
rem �����ǰĿ¼ 
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