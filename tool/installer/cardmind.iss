; CardMind Windows 安装脚本 (Inno Setup 6)
; 产物: build/installer/CardMind-Setup.exe

#define MyAppName "CardMind"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0.10001"
#endif
#define MyAppPublisher "CardMind"
#define MyAppExeName "cardmind.exe"
#ifndef SourceDir
  #define SourceDir "build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "build\installer"
#endif

[Setup]
AppId={{B6F3A9D2-4C7E-4E8A-9F3B-2D5C7E1A8B40}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\CardMind
DefaultGroupName=CardMind
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=CardMind-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; 安装不需要管理员（装到用户目录则不需要；此处默认 Program Files 需要提权）
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; 中文界面
; （Default.isl 为英文，用户可用官方简体中文语言文件替换）

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\CardMind"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\CardMind"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
