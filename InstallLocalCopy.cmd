@echo off
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-File','\"%~dp0scripts\SearchDesktopShortcut.ps1\"','-Action','InstallSystem'"
