# Сценарий Inno Setup для создания установщика приложения «Учёт рабочего времени КФХ»
# Требуется Inno Setup 6 (https://jrsoftware.org/isinfo.php)
# Сборка: iscc installer.iss

[Setup]
AppName=Учёт рабочего времени КФХ
AppVersion=1.0.0
AppPublisher=КФХ
DefaultDirName={autopf}\KFH Time Tracking
DefaultGroupName=Учёт рабочего времени КФХ
OutputDir=installer_output
OutputBaseFilename=KFH_TimeTracking_Setup_1.0.0
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

[Icons]
Name: "{group}\Учёт рабочего времени КФХ"; Filename: "{app}\timesheet_kfh.exe"
Name: "{autodesktop}\Учёт рабочего времени КФХ"; Filename: "{app}\timesheet_kfh.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на &рабочем столе"; GroupDescription: "Дополнительные ярлыки:"

[Run]
Filename: "{app}\timesheet_kfh.exe"; Description: "Запустить Учёт рабочего времени КФХ"; Flags: nowait postinstall skipifsilent