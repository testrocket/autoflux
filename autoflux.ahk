; script disables flux for processes defined in config.ini file
; (and enables flux again if processes do not exist in memory)

; ------------ globals ---------------
CONFIG_FILE := "config.ini"
LOG_FILE := "log.txt"
FLUX_PROCESS := "flux.exe"

; ------------ functions -------------
FluxLog(message)
{
  global LOG_FILE

  FormatTime, time
  FileAppend, [%time%] %message%`n, %LOG_FILE%
}

FluxSetRegKey(valueName, newValue)
{ 
  RegWrite, REG_DWORD, HKCU, Software\Michael Herf\flux\Preferences, %valueName%, %newValue%
  if ErrorLevel
  {
    FluxLog("(ERROR): Cant write to registry.")
    ExitApp
  }
  return TRUE
}

FluxGetRegKey(byref regValue, valueName)
{
  RegRead, regValue, HKCU, Software\Michael Herf\flux\Preferences, %valueName%
  if ErrorLevel
  {
    FluxLog("(ERROR): Cant read from registry.")
    ExitApp
  }
  return TRUE
}

FluxNeedsDisable()
{
  global processList

  StringSplit, processList, processList, `,  

  ; now for each process in list check if its running
  Loop, %processList0%
  {
    processName := processList%A_Index%

    ; remove white spaces just in case
    processName := RegexReplace(processName, "^\s+")
    processName := RegexReplace(processName, "\s+$")
    
    Process, Exist, %processName%.exe
    if ErrorLevel
    {
      FluxLog("Flux needs to be closed because of process: " processName)
      return processName
    }
  }
  return ""
}

FluxClose()
{
  global FLUX_PROCESS
  
  FluxLog("Closing Flux process.")
  
  Process, Close, %FLUX_PROCESS%
  if !ErrorLevel
  {
    FluxLog("(ERROR): Flux could not be closed.")
    ExitApp
  }

  timeoutInSeconds := 10
  Loop, %timeoutInSeconds%
  {
    Sleep, 1000
    
    Process, Exist, %FLUX_PROCESS%
    if !ErrorLevel
      break

    if (A_Index == timeoutInSeconds)
    {
      FluxLog("(ERROR): Timeout while closing Flux.")
      ExitApp
    }
  }
  
  FluxLog("Flux closed.")
  return TRUE
}

FluxRestart()
{
  global FLUX_PROCESS
  global fluxWorkingDir

  Run, %fluxWorkingDir%\%FLUX_PROCESS%, %fluxWorkingDir%, Hide
  if ErrorLevel
  {
    FluxLog("(ERROR): Problem while starting Flux.")
    ExitApp
  }
  
  timeoutInSeconds := 10
  Loop, %timeoutInSeconds%
  {
    Sleep, 1000
    
    Process, Exist, %FLUX_PROCESS%
    if ErrorLevel
      break
      
    if (A_Index == timeoutInSeconds)
    {
      FluxLog("(ERROR): Timeout while starting Flux.")
      ExitApp
    }
  }
  
  FluxLog("Flux started.")
  return TRUE
}

FluxSetIndoorValue(newIndoorValue)
{
  FluxGetRegKey(fluxIndoorValue, "Indoor")

  ; check if value already set
  if (fluxIndoorValue == newIndoorValue)
    return

  FluxClose()
  
  ; change Flux Indoor value to new value
  FluxSetRegKey("Indoor", newIndoorValue)

  ; restart to apply new settings
  FluxRestart()
}

; ----------------- START ------------------------

; make sure that Flux is running
Process, Exist, %FLUX_PROCESS%
if !ErrorLevel
{
  MsgBox, Flux process does not exist - stopping script.
  ExitApp
}

; read Flux installation directory from registry
RegRead, fluxWorkingDir, HKCU, Software\flux, Install_Dir
if ErrorLevel
{
  FluxLog("(ERROR): Cant read flux installation folder from registry.")
  ExitApp
}
; make sure that folder contains main executable file
IfNotExist, %fluxWorkingDir%\%FLUX_PROCESS%
{
  FluxLog("(ERROR): Flux does not exist on this machine under directory: " fluxWorkingDir)
  ExitApp
}

; remove previous logs
FileDelete, %LOG_FILE%
; read process list from INI file
IniRead, processList, %CONFIG_FILE%, settings, processList

FluxLog("Flux process list = " processList)
FluxLog("Flux installation directory = " fluxWorkingDir)

; store original values for Flux Indoor and Outdoor settings
FluxGetRegKey(fluxIndoorOriginalValue, "Indoor")
FluxGetRegKey(fluxOutdoorOriginalValue, "Outdoor")

FluxLog("Flux Indoor value = " fluxIndoorOriginalValue)
FluxLog("Flux Outdoor value = " fluxOutdoorOriginalValue)

; infinite loop
Loop
{
  Sleep, 7000

  if (FluxNeedsDisable() != "")
    FluxSetIndoorValue(fluxOutdoorOriginalValue)
  else
    FluxSetIndoorValue(fluxIndoorOriginalValue)
}
