; Script generated by the Inno Script Studio Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

#define MyAppName "tomboy-ng"
#define MyAppVersion "REPLACEME"
#define MyAppPublisher "David Bannon"
#define MyAppURL "https://github.com/tomboy-notes/tomboy-ng"
#define MyAppExeName32 "tomboy-ng.exe"
#define MyAppExeName64 "tomboy-ng.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{913B2DAF-AAFB-451A-98B3-FAE16027E477}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={pf}\{#MyAppName}
DefaultGroupName={#MyAppName}
LicenseFile=COPYING
InfoAfterFile=AfterInstall.txt
OutputBaseFilename=tomboy-ng-setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
; VersionInfoVersion={#MyAppVersion}

; "ArchitecturesInstallIn64BitMode=x64" requests that the install be
; done in "64-bit mode" on x64, meaning it should use the native
; 64-bit Program Files directory and the 64-bit view of the registry.
; On all other architectures it will install in "32-bit mode".
ArchitecturesInstallIn64BitMode=x64


[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
;Name: associate; Description: "&Associate files"; GroupDescription: "Associate .note files with tomboy-ng:"; Flags: unchecked
; Thats a todo, see http://www.jrsoftware.org/isfaq.php - requires admin priviliges, maybe a pain to non-admin users ?

[Files]
; Install MyProg-x64.exe if running in 64-bit mode (x64; see above), MyProg.exe otherwise.
Source: "libhunspell.license"; DestDir: "{app}";  Check: Is64BitInstallMode
Source: "libhunspell.dll";     DestDir: "{app}";  Check: Is64BitInstallMode

; Source: "ssleay32.dll-64";     DestDir: "{app}";  DestName: "ssleay32.dll"; Check: Is64BitInstallMode
; Source: "libeay32.dll-64";     DestDir: "{app}";  DestName: "libeay32.dll"; Check: Is64BitInstallMode
; Source: "ssleay32.dll-32";     DestDir: "{app}";  DestName: "ssleay32.dll"; Check: not Is64BitInstallMode
; Source: "libeay32.dll-32";     DestDir: "{app}";  DestName: "libeay32.dll"; Check: not Is64BitInstallMode

Source: "tomboy-ng64.exe";     DestDir: "{app}";  DestName: "tomboy-ng.exe"; Check: Is64BitInstallMode
Source: "tomboy-ng32.exe";     DestDir: "{app}";  DestName: "tomboy-ng.exe"; Check: not Is64BitInstallMode
;Source: "C:\Users\dbann\Desktop\tomboy-ng_{#MyAppVersion}\tomboy-ng64.exe"; DestDir: "{app}"; Flags: ignoreversion

DestDir: {app}; Source: "HELP-DIR\*";  Flags: recursesubdirs

; eg DestDir: {app}; Source: Files\*; Excludes: "*.m,.svn,private"; Flags: recursesubdirs

; Source: "calculator.note";     DestDir: "{app}"; Flags: ignoreversion
; Source: "key-shortcuts.note";  DestDir: "{app}"; Flags: ignoreversion
; Source: "recover.note";        DestDir: "{app}"; Flags: ignoreversion
; Source: "sync-ng.note";        DestDir: "{app}"; Flags: ignoreversion
; Source: "tomboy-ng.note";      DestDir: "{app}"; Flags: ignoreversion
; Source: "tomdroid.note";       DestDir: "{app}"; Flags: ignoreversion
Source: "readme.txt";          DestDir: "{app}"; Flags: ignoreversion
; PUTMOLINESHERE
; Source: "tomboy-ng.es.mo";     DestDir: "{app}\locale"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName64}"; Check: Is64BitInstallMode
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName32}"; Check: not Is64BitInstallMode
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName64}"; Tasks: desktopicon; Check: Is64BitInstallMode
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName32}"; Tasks: desktopicon; Check: not Is64BitInstallMode

[Run]
Filename: "{app}\{#MyAppExeName64}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent; Check: Is64BitInstallMode
Filename: "{app}\{#MyAppExeName32}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent; Check: not Is64BitInstallMode
