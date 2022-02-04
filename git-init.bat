@echo off

rem Initialize local git repository
git init
git add .
git update-index --chmod=+x ./*.sh
git commit -m "Initial commit"
git branch -m master
git branch staging
git branch production
