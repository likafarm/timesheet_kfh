

; Версия передаётся из build_installer.ps1 (берётся из pubspec.yaml)
#ifndef AppVer
  #define AppVer "0.0.0"
#endif

[Setup]
AppId={{8F3A1B62-9C47-4D0E-B2A1-6E5C8D90F3A1}
AppName=Учёт рабочего времени КФХ
AppVersion={#AppVer}
AppPublisher=Иван Лопатин
AppPublisherURL=mailto:iilopatin@ya.ru
AppSupportURL=mailto:iilopatin@ya.ru
AppContact=iilopatin@ya.ru
LicenseFile=LICENSE.txt
DefaultDirName={autopf}\KFH Time Tracking
DefaultGroupName=Учёт рабочего времени КФХ
OutputDir=installer_output
OutputBaseFilename=KFH_TimeTracking_Setup_{#AppVer}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\timesheet_kfh.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Учёт рабочего времени КФХ"; Filename: "{app}\timesheet_kfh.exe"
Name: "{autodesktop}\Учёт рабочего времени КФХ"; Filename: "{app}\timesheet_kfh.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на &рабочем столе"; GroupDescription: "Дополнительные ярлыки:"

[Run]
Filename: "{app}\timesheet_kfh.exe"; Description: "Запустить Учёт рабочего времени КФХ"; Flags: nowait postinstall skipifsilent