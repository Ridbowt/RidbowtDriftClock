unit Launcher;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics, Windows,
  Registry, Settings;

procedure ShowControlPanel;
procedure RunInstallWorker;
procedure RunUninstallWorker(ADeleteSettings: Boolean);

implementation

const
  PANEL_CAPTION = 'Ridbowt Drift Clock — Control Panel';
  SCR_FILE = 'RidbowtDriftClock.scr';

  COL_BG       = TColor($00262220);
  COL_FIELD    = TColor($003F3834);
  COL_FIELD_HI = TColor($004B433E);
  COL_TEXT     = TColor($00E5E5E5);
  COL_MUTED    = TColor($00A6A09A);
  COL_AMBER    = TColor($00009DFF);

  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  STILL_ACTIVE_CODE = 259;
  SEE_MASK_NOCLOSEPROCESS = $00000040;

type
  TShellExecInfoW = record
    cbSize: DWord;
    fMask: DWord;
    Wnd: THandle;
    lpVerb: PWideChar;
    lpFile: PWideChar;
    lpParameters: PWideChar;
    lpDirectory: PWideChar;
    nShow: LongInt;
    hInstApp: THandle;
    lpIDList: Pointer;
    lpClass: PWideChar;
    hkeyClass: THandle;
    dwHotKey: DWord;
    hIcon: THandle;
    hProcess: THandle;
  end;

  TPidList = record
    Count: Integer;
    Pids: array[0..63] of DWord;
  end;
  PPidList = ^TPidList;

function ShellExecuteExW(var Info: TShellExecInfoW): LongBool; stdcall;
  external 'shell32.dll' name 'ShellExecuteExW';
function ShellExecuteW(hWnd: THandle; lpOp, lpFile, lpParam, lpDir: PWideChar;
  nShow: LongInt): THandle; stdcall; external 'shell32.dll' name 'ShellExecuteW';
function QueryFullProcessImageNameW(h: THandle; flags: DWord; buf: PWideChar;
  var size: DWord): LongBool; stdcall; external 'kernel32.dll' name 'QueryFullProcessImageNameW';
function CreateMutexW(a: Pointer; initial: LongBool; name: PWideChar): THandle; stdcall;
  external 'kernel32.dll' name 'CreateMutexW';
function ReleaseMutex(h: THandle): LongBool; stdcall; external 'kernel32.dll' name 'ReleaseMutex';
function FindWindowW(cls, title: PWideChar): THandle; stdcall; external 'user32.dll' name 'FindWindowW';

const
  TH32CS_SNAPPROCESS = $00000002;

type
  TProcEntry32W = record
    dwSize: DWord;
    cntUsage: DWord;
    th32ProcessID: DWord;
    th32DefaultHeapID: PtrUInt;
    th32ModuleID: DWord;
    cntThreads: DWord;
    th32ParentProcessID: DWord;
    pcPriClassBase: LongInt;
    dwFlags: DWord;
    szExeFile: array[0..259] of WideChar;
  end;

function CreateToolhelp32Snapshot(dwFlags: DWord; th32ProcessID: DWord): THandle;
  stdcall; external 'kernel32.dll' name 'CreateToolhelp32Snapshot';
function Process32FirstW(hSnapshot: THandle; var lppe: TProcEntry32W): LongBool;
  stdcall; external 'kernel32.dll' name 'Process32FirstW';
function Process32NextW(hSnapshot: THandle; var lppe: TProcEntry32W): LongBool;
  stdcall; external 'kernel32.dll' name 'Process32NextW';

const
  TOKEN_ADJUST_PRIVS = $0020;
  TOKEN_QUERY_PRIV   = $0008;
  SE_PRIV_ENABLED    = $00000002;

type
  TMyLuid = record
    LowPart: DWord;
    HighPart: LongInt;
  end;
  TMyLuidAttr = record
    Luid: TMyLuid;
    Attributes: DWord;
  end;
  TMyTokenPriv = record
    PrivilegeCount: DWord;
    Privileges: array[0..0] of TMyLuidAttr;
  end;

function OpenProcessToken(h: THandle; access: DWord; var token: THandle): LongBool;
  stdcall; external 'advapi32.dll' name 'OpenProcessToken';
function LookupPrivilegeValueW(sys: PWideChar; name: PWideChar; var luid: TMyLuid): LongBool;
  stdcall; external 'advapi32.dll' name 'LookupPrivilegeValueW';
function AdjustTokenPrivileges(token: THandle; disableAll: LongBool;
  var newState: TMyTokenPriv; bufLen: DWord; prev: Pointer; retLen: PDWord): LongBool;
  stdcall; external 'advapi32.dll' name 'AdjustTokenPrivileges';

procedure EnableDebugPrivilege;
var
  tok: THandle;
  luid: TMyLuid;
  tp: TMyTokenPriv;
  w: WideString;
begin
  tok := 0;
  if not OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVS or TOKEN_QUERY_PRIV, tok) then Exit;
  try
    w := UTF8Decode('SeDebugPrivilege');
    if not LookupPrivilegeValueW(nil, PWideChar(w), luid) then Exit;
    tp.PrivilegeCount := 1;
    tp.Privileges[0].Luid := luid;
    tp.Privileges[0].Attributes := SE_PRIV_ENABLED;
    AdjustTokenPrivileges(tok, False, tp, SizeOf(tp), nil, nil);
  finally
    CloseHandle(tok);
  end;
end;

{ ---------- пути и состояние ---------- }

function SystemDir: string;
var
  buf: array[0..4095] of WideChar;
  n: DWord;
  w: WideString;
begin
  FillChar(buf, SizeOf(buf), 0);
  n := GetSystemDirectoryW(@buf[0], 4096);
  if (n > 0) and (n < 4096) then
  begin
    w := PWideChar(@buf[0]);
    Result := UTF8Encode(w);
  end
  else
    Result := SysUtils.GetEnvironmentVariable('WINDIR') + '\System32';
end;

function TargetPath: string;
begin
  Result := IncludeTrailingPathDelimiter(SystemDir) + SCR_FILE;
end;

function AppDataSettingsDir: string;
begin
  Result := IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('APPDATA'))
    + 'RidbowtDriftClock';
end;

function NormPath(const S: string): string;
begin
  Result := LowerCase(Trim(StringReplace(S, '"', '', [rfReplaceAll])));
end;

function RegScreenSaverValue: string;
var
  r: TRegistry;
begin
  Result := '';
  r := TRegistry.Create(KEY_READ);
  try
    r.RootKey := HKEY_CURRENT_USER;
    if r.OpenKey('Control Panel\Desktop', False) then
      if r.ValueExists('SCRNSAVE.EXE') then
        Result := r.ReadString('SCRNSAVE.EXE');
  finally
    r.Free;
  end;
end;

function FileInstalled: Boolean;
begin
  Result := FileExists(TargetPath);
end;

function IsRegistered: Boolean;
begin
  Result := FileInstalled and (NormPath(RegScreenSaverValue) = NormPath(TargetPath));
end;

procedure RefreshSystemParams;
begin
  ShellExecuteW(0, 'open', 'rundll32.exe',
    PWideChar(UTF8Decode('user32.dll,UpdatePerUserSystemParameters')), nil, 0);
end;

procedure OpenScreenSaverSettings(const ATarget: string);
var
  wFile, wPar: WideString;
begin
  wFile := UTF8Decode('rundll32.exe');
  wPar := UTF8Decode('desk.cpl,InstallScreenSaver "' + ATarget + '"');
  ShellExecuteW(0, 'open', PWideChar(wFile), PWideChar(wPar), nil, 1);
end;

procedure RegisterScreenSaver(const APath: string);
var
  r: TRegistry;
begin
  r := TRegistry.Create(KEY_WRITE);
  try
    r.RootKey := HKEY_CURRENT_USER;
    if r.OpenKey('Control Panel\Desktop', True) then
    begin
      r.WriteString('SCRNSAVE.EXE', APath);
      r.WriteString('ScreenSaveActive', '1');
    end;
  finally
    r.Free;
  end;
  RefreshSystemParams;
end;

procedure ResetRegistrationIfOurs(const APath: string);
var
  r: TRegistry;
begin
  if NormPath(RegScreenSaverValue) <> NormPath(APath) then Exit;
  r := TRegistry.Create(KEY_WRITE);
  try
    r.RootKey := HKEY_CURRENT_USER;
    if r.OpenKey('Control Panel\Desktop', True) then
    begin
      r.WriteString('SCRNSAVE.EXE', '(none)');
      r.WriteString('ScreenSaveActive', '0');
    end;
  finally
    r.Free;
  end;
  RefreshSystemParams;
end;

{ ---------- безопасное завершение своих процессов ---------- }

function EnumCloseProc(W: THandle; L: LPARAM): LongBool; stdcall;
var
  pid: DWord;
  pl: PPidList;
  i: Integer;
begin
  Result := True;
  pl := PPidList(PtrUInt(L));
  if pl = nil then Exit;
  pid := 0;
  GetWindowThreadProcessId(W, @pid);
  for i := 0 to pl^.Count - 1 do
    if pl^.Pids[i] = pid then
    begin
      PostMessage(W, WM_CLOSE, 0, 0);
      Break;
    end;
end;

function PidAlive(APid: DWord): Boolean;
var
  h: THandle;
  code: DWord;
begin
  Result := False;
  h := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, APid);
  if h = 0 then Exit;
  try
    code := 0;
    if GetExitCodeProcess(h, code) then
      Result := (code = STILL_ACTIVE_CODE);
  finally
    CloseHandle(h);
  end;
end;

procedure FindOurProcesses(const ATarget: string; var pl: TPidList);
var
  snap: THandle;
  pe: TProcEntry32W;
  h: THandle;
  buf: array[0..4095] of WideChar;
  n: DWord;
  w: WideString;
  want: string;
begin
  pl.Count := 0;
  want := NormPath(ATarget);

  snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if snap = INVALID_HANDLE_VALUE then Exit;
  try
    FillChar(pe, SizeOf(pe), 0);
    pe.dwSize := SizeOf(pe);
    if Process32FirstW(snap, pe) then
    repeat
      if (pe.th32ProcessID <> 0) and (pe.th32ProcessID <> GetCurrentProcessId) then
      begin
        h := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pe.th32ProcessID);
        if h <> 0 then
        begin
          n := 4096;
          FillChar(buf, SizeOf(buf), 0);
          if QueryFullProcessImageNameW(h, 0, @buf[0], n) then
          begin
            w := PWideChar(@buf[0]);
            if NormPath(UTF8Encode(w)) = want then
              if pl.Count <= High(pl.Pids) then
              begin
                pl.Pids[pl.Count] := pe.th32ProcessID;
                Inc(pl.Count);
              end;
          end;
          CloseHandle(h);
        end;
      end;
    until not Process32NextW(snap, pe);
  finally
    CloseHandle(snap);
  end;
end;

procedure StopOurProcesses(const ATarget: string);
const
  SYNCHRONIZE_ACCESS = $00100000;
var
  pl: TPidList;
  h: THandle;
  i, waited: Integer;
  any: Boolean;
  code: DWord;
begin
  EnableDebugPrivilege;
  FindOurProcesses(ATarget, pl);
  if pl.Count = 0 then Exit;

  // 1) штатное закрытие всех своих окон
  EnumWindows(@EnumCloseProc, LPARAM(PtrUInt(@pl)));

  // 2) ждём до 3 секунд
  waited := 0;
  while waited < 3000 do
  begin
    any := False;
    for i := 0 to pl.Count - 1 do
      if PidAlive(pl.Pids[i]) then any := True;
    if not any then Break;
    Sleep(100);
    Inc(waited, 100);
  end;

  // 3) крайняя мера: только PROCESS_TERMINATE
  for i := 0 to pl.Count - 1 do
  begin
    h := OpenProcess(PROCESS_TERMINATE, False, pl.Pids[i]);
    if h <> 0 then
    begin
      TerminateProcess(h, 0);
      CloseHandle(h);
    end;
  end;

  // ждём реального исчезновения процессов
  waited := 0;
  while waited < 3000 do
  begin
    any := False;
    for i := 0 to pl.Count - 1 do
      if PidAlive(pl.Pids[i]) then any := True;
    if not any then Break;
    Sleep(100);
    Inc(waited, 100);
  end;

  Sleep(300);
end;

{ ---------- elevation ---------- }

function RunElevated(const AFile, AParams: string; AWait: Boolean): Boolean;
var
  info: TShellExecInfoW;
  wVerb, wFile, wPar: WideString;
begin
  Result := False;
  FillChar(info, SizeOf(info), 0);
  info.cbSize := SizeOf(info);
  info.fMask := SEE_MASK_NOCLOSEPROCESS;
  wVerb := UTF8Decode('runas');
  wFile := UTF8Decode(AFile);
  wPar := UTF8Decode(AParams);
  info.lpVerb := PWideChar(wVerb);
  info.lpFile := PWideChar(wFile);
  info.lpParameters := PWideChar(wPar);
  info.nShow := 1;
  if not ShellExecuteExW(info) then Exit;
  Result := True;
  if info.hProcess <> 0 then
  begin
    if AWait then
      WaitForSingleObject(info.hProcess, INFINITE);
    CloseHandle(info.hProcess);
  end;
end;

procedure InfoMsg(const S: string; AError: Boolean);
begin
  if AError then
    Application.MessageBox(PChar(S), PChar(PANEL_CAPTION), MB_OK or MB_ICONERROR)
  else
    Application.MessageBox(PChar(S), PChar(PANEL_CAPTION), MB_OK or MB_ICONINFORMATION);
end;

{ ---------- воркеры ---------- }

procedure RunInstallWorker;
var
  src, dst, ini: string;
begin
  src := ParamStr(0);
  dst := TargetPath;
  StopOurProcesses(dst);
  if not CopyFileW(PWideChar(UTF8Decode(src)), PWideChar(UTF8Decode(dst)), False) then
  begin
    InfoMsg('Install failed: could not copy the file.' + LineEnding + dst, True);
    Exit;
  end;
  if not FileExists(dst) then
  begin
    InfoMsg('Install failed: verification error.', True);
    Exit;
  end;
  RegisterScreenSaver(dst);
  ini := ExtractFilePath(ParamStr(0)) + 'ClockSaver.ini';
  if NormPath(ExtractFilePath(ParamStr(0))) <> NormPath(ExtractFilePath(dst)) then
    if FileExists(ini) then DeleteFileW(PWideChar(UTF8Decode(ini)));
  InfoMsg('Installed successfully.' + LineEnding + dst, False);
end;

procedure RunUninstallWorker(ADeleteSettings: Boolean);
var
  dst, ini: string;
  removed: Boolean;
  attempts, lastErr, i, cnt: Integer;
  pl: TPidList;
  h: THandle;
  detail: string;
begin
  dst := TargetPath;
  if not FileExists(dst) then
  begin
    InfoMsg('The screensaver is not installed.', False);
    Exit;
  end;

  StopOurProcesses(dst);
  ResetRegistrationIfOurs(dst);

  removed := False;
  attempts := 0;
  lastErr := 0;
  repeat
    Inc(attempts);
    StopOurProcesses(dst);
    if DeleteFileW(PWideChar(UTF8Decode(dst))) then
      removed := True
    else
      lastErr := GetLastError;
    if removed then Break;
    if not FileExists(dst) then begin removed := True; Break; end;
    Sleep(500);

    if attempts >= 3 then
    begin
      FindOurProcesses(dst, pl);
      cnt := 0;
      detail := '';
      for i := 0 to pl.Count - 1 do
        if PidAlive(pl.Pids[i]) then
        begin
          Inc(cnt);
          h := OpenProcess(PROCESS_TERMINATE, False, pl.Pids[i]);
          if h = 0 then
            detail := detail + IntToStr(pl.Pids[i]) + ' [open err ' +
              IntToStr(GetLastError) + ']  '
          else
          begin
            detail := detail + IntToStr(pl.Pids[i]) + ' [terminable]  ';
            CloseHandle(h);
          end;
        end;

      if Application.MessageBox(
        PChar('The file is still in use:' + LineEnding + dst + LineEnding + LineEnding +
          'Windows error code: ' + IntToStr(lastErr) + LineEnding +
          'Our running instances still alive: ' + IntToStr(cnt) + LineEnding +
          'PIDs: ' + detail + LineEnding + LineEnding +
          'If the Windows "Screen Saver Settings" window or its preview is open, ' +
          'please close it, then press Retry.'),
        PChar(PANEL_CAPTION), MB_RETRYCANCEL or MB_ICONWARNING) <> IDRETRY then Break;
      attempts := 0;
      StopOurProcesses(dst);
    end;
  until False;

  if not removed then
  begin
    InfoMsg('Uninstall aborted: the file could not be removed.' + LineEnding +
      'Your settings were not touched.', True);
    Exit;
  end;

  if ADeleteSettings then
  begin
    ini := IncludeTrailingPathDelimiter(AppDataSettingsDir) + 'ClockSaver.ini';
    if FileExists(ini) then DeleteFileW(PWideChar(UTF8Decode(ini)));
    RemoveDir(AppDataSettingsDir);
    InfoMsg('Screensaver removed. User settings deleted.', False);
  end
  else
    InfoMsg('Screensaver removed. User settings preserved.', False);

  ini := ExtractFilePath(ParamStr(0)) + 'ClockSaver.ini';
  if NormPath(ExtractFilePath(ParamStr(0))) <> NormPath(ExtractFilePath(dst)) then
    if FileExists(ini) then DeleteFileW(PWideChar(UTF8Decode(ini)));
end;

procedure RequestUninstall;
var
  ans: Integer;
  tmp, par: string;
begin
  if not FileInstalled then
  begin
    InfoMsg('The screensaver is not installed.', False);
    Exit;
  end;

  ans := Application.MessageBox(
    PChar('Uninstall the system copy of Ridbowt Drift Clock?' + LineEnding + LineEnding +
      'Yes    - remove the screensaver AND delete user settings' + LineEnding +
      'No     - remove the screensaver and KEEP user settings' + LineEnding +
      'Cancel - do nothing'),
    PChar(PANEL_CAPTION), MB_YESNOCANCEL or MB_ICONQUESTION);
  if ans = IDCANCEL then Exit;
  if ans = IDYES then par := '/uninstall-delete' else par := '/uninstall-keep';

  tmp := IncludeTrailingPathDelimiter(GetTempDir) + 'RidbowtDriftClock_setup.exe';
  if not CopyFileW(PWideChar(UTF8Decode(ParamStr(0))), PWideChar(UTF8Decode(tmp)), False) then
  begin
    InfoMsg('Could not prepare the uninstall helper.', True);
    Exit;
  end;
  if not RunElevated(tmp, par, True) then
    InfoMsg('Uninstall was cancelled or could not start.', True);
end;

{ ---------- панель ---------- }

type
  TPanelForm = class(TForm)
  private
    lblTitle, lblVer, lblStatus, lblTarget, lblSettings, lblHint: TLabel;
    bInstall, bRun, bSettings, bUninstall, bClose: TPanel;
    function MkLabel(const S: string; X, Y, W, H: Integer; Muted: Boolean): TLabel;
    function MkButton(const S: string; X, Y, W, H: Integer; E: TNotifyEvent): TPanel;
    procedure BtnEnter(Sender: TObject);
    procedure BtnLeave(Sender: TObject);
    procedure SetBtn(B: TPanel; AEnabled: Boolean);
    procedure RefreshState;
    procedure DoInstall(Sender: TObject);
    procedure DoRun(Sender: TObject);
    procedure DoSettings(Sender: TObject);
    procedure DoUninstall(Sender: TObject);
    procedure CloseClicked(Sender: TObject);
  public
    procedure Build;
  end;

function TPanelForm.MkLabel(const S: string; X, Y, W, H: Integer; Muted: Boolean): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := Self;
  Result.Caption := S;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 9;
  if Muted then Result.Font.Color := COL_MUTED else Result.Font.Color := COL_TEXT;
  Result.AutoSize := False;
  Result.WordWrap := True;
  Result.SetBounds(X, Y, W, H);
end;

function TPanelForm.MkButton(const S: string; X, Y, W, H: Integer; E: TNotifyEvent): TPanel;
begin
  Result := TPanel.Create(Self);
  Result.Parent := Self;
  Result.BevelOuter := bvNone;
  Result.Caption := S;
  Result.Color := COL_FIELD;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 9;
  Result.Font.Color := COL_TEXT;
  Result.Cursor := crHandPoint;
  Result.SetBounds(X, Y, W, H);
  Result.OnClick := E;
  Result.OnMouseEnter := @BtnEnter;
  Result.OnMouseLeave := @BtnLeave;
end;

procedure TPanelForm.BtnEnter(Sender: TObject);
begin
  if (Sender is TPanel) and TPanel(Sender).Enabled then
    TPanel(Sender).Color := COL_FIELD_HI;
end;

procedure TPanelForm.BtnLeave(Sender: TObject);
begin
  if (Sender is TPanel) and TPanel(Sender).Enabled then
    TPanel(Sender).Color := COL_FIELD;
end;

procedure TPanelForm.SetBtn(B: TPanel; AEnabled: Boolean);
begin
  B.Enabled := AEnabled;
  if AEnabled then
  begin
    B.Color := COL_FIELD;
    B.Font.Color := COL_TEXT;
  end
  else
  begin
    B.Color := COL_BG;
    B.Font.Color := COL_MUTED;
  end;
end;

procedure TPanelForm.RefreshState;
var
  f, r: Boolean;
begin
  f := FileInstalled;
  r := IsRegistered;
  if f and r then
    lblStatus.Caption := 'Status: installed and registered'
  else if f then
    lblStatus.Caption := 'Status: file present, not registered'
  else
    lblStatus.Caption := 'Status: not installed (portable)';

  lblTarget.Caption := 'System copy: ' + TargetPath;
  lblSettings.Caption := 'Settings file: ' + Cfg.FilePath;

  SetBtn(bInstall, not (f and r));
  SetBtn(bUninstall, f);
  SetBtn(bRun, True);
  SetBtn(bSettings, True);

  if f and r then
    lblHint.Caption := 'Run starts the full-screen clock. Uninstall removes the system copy.'
  else
    lblHint.Caption := 'Portable mode: Run and Settings work from this folder. ' +
      'Install copies the screensaver to the Windows system folder.';
end;

procedure TPanelForm.DoInstall(Sender: TObject);
var
  tmp: string;
begin
  // .scr не имеет глагола runas — повышаем права через .exe-копию
  tmp := IncludeTrailingPathDelimiter(GetTempDir) + 'RidbowtDriftClock_setup.exe';
  if not CopyFileW(PWideChar(UTF8Decode(ParamStr(0))), PWideChar(UTF8Decode(tmp)), False) then
  begin
    InfoMsg('Could not prepare the install helper.', True);
    Exit;
  end;
  if not RunElevated(tmp, '/install', True) then
    InfoMsg('Installation was cancelled or could not start.' + LineEnding +
      'Helper: ' + tmp, True);
  Cfg.Load;
  RefreshState;

  if FileInstalled and IsRegistered then
    OpenScreenSaverSettings(TargetPath);
end;

procedure TPanelForm.DoRun(Sender: TObject);
var
  wFile, wPar: WideString;
begin
  wFile := UTF8Decode(ParamStr(0));
  wPar := UTF8Decode('/s');
  ShellExecuteW(0, 'open', PWideChar(wFile), PWideChar(wPar), nil, 1);
  Close;
end;

procedure TPanelForm.DoSettings(Sender: TObject);
begin
  ShowSettingsDialog(0);
  Cfg.Load;
  RefreshState;
end;

procedure TPanelForm.DoUninstall(Sender: TObject);
begin
  RequestUninstall;
  Cfg.Load;
  RefreshState;
end;

procedure TPanelForm.CloseClicked(Sender: TObject);
begin
  Close;
end;

procedure TPanelForm.Build;
begin
  Caption := PANEL_CAPTION;
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Color := COL_BG;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  ClientWidth := 560;
  ClientHeight := 290;

  lblTitle := MkLabel('Ridbowt Drift Clock', 16, 12, 320, 26, False);
  lblTitle.Font.Size := 14;
  lblTitle.Font.Style := [fsBold];
  lblVer := MkLabel('v' + APP_VERSION + ' (' + APP_DATE + ')', 380, 18, 164, 18, True);
  lblVer.Alignment := taRightJustify;

  lblStatus := MkLabel('', 16, 46, 528, 18, False);
  lblTarget := MkLabel('', 16, 68, 528, 18, True);
  lblSettings := MkLabel('', 16, 88, 528, 18, True);

  bInstall := MkButton('Install', 16, 120, 126, 36, @DoInstall);
  bRun := MkButton('Run', 150, 120, 126, 36, @DoRun);
  bSettings := MkButton('Settings', 284, 120, 126, 36, @DoSettings);
  bUninstall := MkButton('Uninstall', 418, 120, 126, 36, @DoUninstall);

  lblHint := MkLabel('', 16, 170, 528, 44, True);
  bClose := MkButton('Close', 418, 232, 126, 32, @CloseClicked);

  RefreshState;
end;

procedure ShowControlPanel;
var
  F: TPanelForm;
  hMutex, hwnd: THandle;
  capW: WideString;
  i: Integer;
begin
  hMutex := CreateMutexW(nil, True, PWideChar(UTF8Decode('Local\RidbowtDriftClockPanel')));
  if (hMutex <> 0) and (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    capW := UTF8Decode(PANEL_CAPTION);
    hwnd := 0;
    for i := 0 to 20 do
    begin
      hwnd := FindWindowW(nil, PWideChar(capW));
      if hwnd <> 0 then Break;
      Sleep(50);
    end;
    if hwnd <> 0 then
    begin
      if IsIconic(hwnd) then ShowWindow(hwnd, SW_RESTORE);
      SetForegroundWindow(hwnd);
      BringWindowToTop(hwnd);
    end;
    if hMutex <> 0 then CloseHandle(hMutex);
    Exit;
  end;

  Cfg.Load;
  F := TPanelForm.CreateNew(nil);
  try
    F.Build;
    F.ShowModal;
  finally
    F.Free;
  end;

  if hMutex <> 0 then
  begin
    ReleaseMutex(hMutex);
    CloseHandle(hMutex);
  end;
end;

initialization
  UninstallRequest := @RequestUninstall;

end.

end.

