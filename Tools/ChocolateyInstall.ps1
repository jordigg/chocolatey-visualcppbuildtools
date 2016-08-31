Import-Module (Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'VSModules.psm1')
 
Install-VS 'VisualCppBuildTools' 'http://download.microsoft.com/download/5/f/7/5f7acaeb-8363-451f-9425-68a90f98b238/visualcppbuildtools_full.exe' 'visualcppbuildtools_full.exe' '1E1774869ABD953D05D10372B7C08BFA0C76116F5C6DF1F3D031418CCDCD8F7B'