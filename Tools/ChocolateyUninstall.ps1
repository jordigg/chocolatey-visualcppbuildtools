﻿Import-Module (Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'VSModules.psm1')
 
Uninstall-VS 'VisualCppBuildTools' 'Microsoft Visual C++ Build Tools' 'visualcppbuildtools_full.exe'