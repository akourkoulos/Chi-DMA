@echo off
REM ****************************************************************************
REM Vivado (TM) v2019.2 (64-bit)
REM
REM Filename    : simulate.bat
REM Simulator   : Xilinx Vivado Simulator
REM Description : Script for simulating the design by launching the simulator
REM
REM Generated by Vivado on Tue Nov 01 12:35:02 +0200 2022
REM SW Build 2708876 on Wed Nov  6 21:40:23 MST 2019
REM
REM Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
REM
REM usage: simulate.bat
REM
REM ****************************************************************************
echo "xsim TestBarrelShifte_behav -key {Behavioral:sim_1:Functional:TestBarrelShifte} -tclbatch TestBarrelShifte.tcl -view C:/Users/Aggelos/Desktop/github/Chi-DMA/CHI-DMA/TestRegSpaceAndSched_behav.wcfg -view C:/Users/Aggelos/Desktop/github/Chi-DMA/CHI-DMA/TestCHIConverter_behav.wcfg -log simulate.log"
call xsim  TestBarrelShifte_behav -key {Behavioral:sim_1:Functional:TestBarrelShifte} -tclbatch TestBarrelShifte.tcl -view C:/Users/Aggelos/Desktop/github/Chi-DMA/CHI-DMA/TestRegSpaceAndSched_behav.wcfg -view C:/Users/Aggelos/Desktop/github/Chi-DMA/CHI-DMA/TestCHIConverter_behav.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
