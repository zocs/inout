; inout.nsi - NSIS Installer Script for inout
Unicode true
SetCompressor /SOLID lzma

!define APP_NAME "inout"
!define APP_VERSION "0.2.6"
!define APP_PUBLISHER "zocs"
!define APP_URL "https://github.com/zocs/inout"
!define APP_EXE "inout.exe"

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "inout-${APP_VERSION}-windows-x64-setup.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
RequestExecutionLevel admin

; Custom finish page run text
!define MUI_FINISHPAGE_RUN_TEXT "Run ${APP_NAME}"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"

; Pages
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

; Check if inout.exe is running, kill if user confirms
!macro CheckAndKillProcess
  nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq ${APP_EXE}" /FO CSV /NH'
  Pop $0
  Pop $1
  ${If} $1 != ""
    ${If} $1 != "INFO: No tasks are running which match the specified criteria.$\n"
    ${AndIf} $1 != "INFO: No tasks are running which match the specified criteria."
      MessageBox MB_YESNOCANCEL|MB_ICONEXCLAMATION \
        "${APP_NAME} 正在运行。是否关闭程序继续？$\n$\n${APP_NAME} is running. Close it to continue?$\n$\nYes=关闭并继续 / No=取消" \
        IDYES kill IDNO cancel
      cancel:
        Abort
      kill:
        nsExec::ExecToLog 'taskkill /F /IM "${APP_EXE}"'
        Sleep 1000
    ${EndIf}
  ${EndIf}
!macroend

Section "Install"
  !insertmacro CheckAndKillProcess

  SetOutPath "$INSTDIR"
  !cd ".."
  File /r "build\windows\x64\runner\Release\*.*"

  ; Create shortcuts
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"

  ; Write uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk" "$INSTDIR\Uninstall.exe"

  ; Register in Add/Remove Programs
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "URLInfoAbout" "${APP_URL}"

  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}" "EstimatedSize" $0
SectionEnd

Section "Uninstall"
  !insertmacro CheckAndKillProcess

  RMDir /r "$INSTDIR"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
SectionEnd
