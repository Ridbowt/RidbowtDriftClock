unit Settings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, IniFiles, LCLType, Windows,
  ExtCtrls, Graphics, Types;

const
  APP_NAME    = 'RidbowtDriftClock';
  APP_VERSION = '1.0.0';
  APP_DATE    = '2026-11-24';
  APP_URL     = 'https://github.com/Ridbowt/RidbowtDriftClock';

  { веб-ссылки на лицензии; пока заглушки, заработают после загрузки файлов в репозиторий }
  APP_LICENSE_DSEG = 'https://github.com/Ridbowt/RidbowtDriftClock/blob/main/LICENSES/DSEG7/OFL.txt';
  APP_LICENSE_NOTO = 'https://github.com/Ridbowt/RidbowtDriftClock/blob/main/LICENSES/NotoSans/OFL.txt';

  { имя файла настроек оставлено прежним для совместимости со старыми конфигами }
  INI_NAME = 'ClockSaver.ini';
  CLOCK_COLOR_COUNT = 8;
  CLOCK_COLOR_TRAFFIC = 7;
  DATE_FORMAT_COUNT = 5;

function ClockColorName(AIndex: Integer): string;
function ClockColorRGB(AIndex: Integer): TColor;
function ClockColorIndexByName(const AName: string): Integer;
function TrafficLightColor(APart: Integer): TColor;

type
  TSettings = class
  private
    FStamp: TDateTime;
  public
    ShowSeconds: Boolean;
    BlinkColons: Boolean;
    ShowFps: Boolean;
    Use12Hour: Boolean;
    DateFormat: Integer;
    UseRussian: Boolean;
    CenterLocked: Boolean;
    FastMovement: Boolean;
    UseAtmosphericBackground: Boolean;
    DimBrightness: Boolean;
    ClockColor: Integer;
    WinWidth: Integer;
    WinHeight: Integer;
    FilePath: string;
    LastError: string;
    constructor Create;
    procedure Load;
    function Save: Boolean;
    function FileChanged: Boolean;
    function InWindowsFolder: Boolean;
  end;

var
  Cfg: TSettings;

procedure ShowSettingsDialog(AOwnerWnd: HWND = 0);

implementation

const
  COL_BG       = TColor($00262220);
  COL_BLOCK    = TColor($00322D2A);
  COL_FIELD    = TColor($003F3834);
  COL_FIELD_HI = TColor($004B433E);
  COL_LINE     = TColor($00473F3A);
  COL_TEXT     = TColor($00E5E5E5);
  COL_MUTED    = TColor($00A6A09A);
  COL_AMBER    = TColor($00009DFF);
  COL_AMBER_HI = TColor($0033B7FF);

  DEF_CLIENT_W = 960;
  DEF_CLIENT_H = 520;
  MIN_CLIENT_W = 900;
  MIN_CLIENT_H = 500;

  ROW_H = 28;

function ShellExecuteA(hWnd: THandle; lpOperation, lpFile, lpParameters,
  lpDirectory: PChar; nShowCmd: LongInt): THandle; stdcall;
  external 'shell32.dll' name 'ShellExecuteA';

function CreateMutexW(lpMutexAttributes: Pointer; bInitialOwner: LongBool;
  lpName: PWideChar): THandle; stdcall; external 'kernel32.dll' name 'CreateMutexW';

function ReleaseMutex(hMutex: THandle): LongBool; stdcall;
  external 'kernel32.dll' name 'ReleaseMutex';

function FindWindowW(lpClassName, lpWindowName: PWideChar): THandle; stdcall;
  external 'user32.dll' name 'FindWindowW';

type
  TPickEvent = procedure(AIndex: Integer) of object;

  TGBlock = class(TCustomControl)
  private
    FTitle: string;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Title: string read FTitle write FTitle;
  end;

  TGCheck = class(TCustomControl)
  private
    FChecked: Boolean;
    FCaption: string;
    FHover: Boolean;
    FOnChange: TNotifyEvent;
    procedure SetChecked(AValue: Boolean);
    procedure Toggle;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Checked: Boolean read FChecked write SetChecked;
    property CaptionText: string read FCaption write FCaption;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TGList = class(TCustomControl)
  private
    FItems: TStringList;
    FHover: Integer;
    FSelected: Integer;
    FOnPick: TPickEvent;
    FOnCancel: TNotifyEvent;
    function RowAt(Y: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Items: TStringList read FItems write FItems;
    property Selected: Integer read FSelected write FSelected;
    property OnPick: TPickEvent read FOnPick write FOnPick;
    property OnCancel: TNotifyEvent read FOnCancel write FOnCancel;
  end;

  TGCombo = class(TCustomControl)
  private
    FItems: TStringList;
    FIndex: Integer;
    FHover: Boolean;
    FOnChange: TNotifyEvent;
    FPopup: TForm;
    procedure SetIndex(AValue: Integer);
    procedure OpenPopup;
    procedure ClosePopup;
    procedure Pick(AIndex: Integer);
    procedure PopupDeactivate(Sender: TObject);
    procedure PopupCancel(Sender: TObject);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Items: TStringList read FItems;
    property ItemIndex: Integer read FIndex write SetIndex;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TGButton = class(TCustomControl)
  private
    FCaption: string;
    FHover: Boolean;
    FOnClick: TNotifyEvent;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    property CaptionText: string read FCaption write FCaption;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  TGSwatch = class(TCustomControl)
  private
    FIndex: Integer;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property ColorIndex: Integer read FIndex write FIndex;
  end;

  TGSettingsForm = class(TForm)
  private
    pnlLed: TPanel;
    lblTitle: TLabel;
    lblSub: TLabel;
    lblVersion: TLabel;
    lblUrl: TLabel;
    lblLicDseg: TLabel;
    lblLicNoto: TLabel;
    blkTime: TGBlock;
    blkDate: TGBlock;
    blkMove: TGBlock;
    blkLook: TGBlock;
    blkColor: TGBlock;
    blkDiag: TGBlock;
    lblTimeFmt: TLabel;
    cmbTime: TGCombo;
    chkSeconds: TGCheck;
    chkBlink: TGCheck;
    lblDateFmt: TLabel;
    cmbDate: TGCombo;
    chkRussian: TGCheck;
    lblDateHint: TLabel;
    chkCenter: TGCheck;
    chkFast: TGCheck;
    lblMoveHint: TLabel;
    chkAtmo: TGCheck;
    chkDim: TGCheck;
    lblLookHint: TLabel;
    lblColor: TLabel;
    cmbColor: TGCombo;
    swatch: TGSwatch;
    lblColorHint: TLabel;
    chkFps: TGCheck;
    lblDiagHint: TLabel;
    lblFooter: TLabel;
    btnClose: TGButton;
    FUpdating: Boolean;
    FSavedSeconds: Boolean;
    FSavedBlink: Boolean;
    FSavedFps: Boolean;
    FSaved12Hour: Boolean;
    FSavedDateFormat: Integer;
    FSavedRussian: Boolean;
    FSavedCenter: Boolean;
    FSavedFast: Boolean;
    FSavedAtmos: Boolean;
    FSavedDim: Boolean;
    FSavedColor: Integer;
    procedure Changed(Sender: TObject);
    procedure CommitChanges;
    procedure UpdateHints;
    procedure Layout;
    procedure Resized(Sender: TObject);
    procedure CloseClicked(Sender: TObject);
    procedure UrlClick(Sender: TObject);
    procedure LicenseClick(Sender: TObject);
    function MakeLabel(AParent: TWinControl; const AText: string; AMuted: Boolean): TLabel;
  public
    procedure Build;
  end;

{ ================= palette ================= }

function ClockColorName(AIndex: Integer): string;
begin
  case AIndex of
    1: Result := 'Yellow';
    2: Result := 'Cyan';
    3: Result := 'Purple';
    4: Result := 'Red';
    5: Result := 'Green';
    6: Result := 'White';
    7: Result := 'Traffic Light (Bonus)';
  else
    Result := 'Amber';
  end;
end;

function ClockColorRGB(AIndex: Integer): TColor;
begin
  case AIndex of
    1: Result := RGBToColor($FF, $FF, $00);
    2: Result := RGBToColor($00, $CF, $FF);
    3: Result := RGBToColor($A8, $55, $F7);
    4: Result := RGBToColor($FF, $30, $4F);
    5: Result := RGBToColor($39, $E8, $75);
    6: Result := RGBToColor($F5, $F5, $F5);
    7: Result := RGBToColor($FF, $FF, $00);
  else
    Result := RGBToColor($FF, $9D, $00);
  end;
end;

function ClockColorIndexByName(const AName: string): Integer;
var
  s: string;
begin
  s := LowerCase(Trim(AName));
  if s = 'yellow' then Result := 1
  else if s = 'cyan' then Result := 2
  else if s = 'purple' then Result := 3
  else if s = 'red' then Result := 4
  else if s = 'green' then Result := 5
  else if s = 'white' then Result := 6
  else if (s = 'traffic light (bonus)') or (s = 'traffic light') or (s = 'traffic') then
    Result := CLOCK_COLOR_TRAFFIC
  else Result := 0;
end;

function TrafficLightColor(APart: Integer): TColor;
begin
  case APart of
    0: Result := RGBToColor($FF, $30, $30);
    2: Result := RGBToColor($39, $E8, $75);
  else
    Result := RGBToColor($FF, $FF, $00);
  end;
end;

function DateFormatName(AIndex: Integer): string;
begin
  case AIndex of
    1: Result := 'ISO';
    2: Result := 'European';
    3: Result := 'American';
    4: Result := 'Short';
  else
    Result := 'None';
  end;
end;

function DateFormatIndexByName(const AName: string): Integer;
var
  s: string;
begin
  s := LowerCase(Trim(AName));
  if s = 'iso' then Result := 1
  else if s = 'european' then Result := 2
  else if s = 'american' then Result := 3
  else if s = 'short' then Result := 4
  else Result := 0;
end;

{ ================= storage ================= }

constructor TSettings.Create;
begin
  inherited Create;
  FilePath := ExtractFilePath(ParamStr(0)) + INI_NAME;
  ShowSeconds := True;
  BlinkColons := True;
  ShowFps := False;
  Use12Hour := False;
  DateFormat := 4;
  UseRussian := False;
  CenterLocked := False;
  FastMovement := False;
  UseAtmosphericBackground := False;
  DimBrightness := True;
  ClockColor := CLOCK_COLOR_TRAFFIC;
  WinWidth := DEF_CLIENT_W;
  WinHeight := DEF_CLIENT_H;
  LastError := '';
  FStamp := 0;
end;

procedure TSettings.Load;
var
  ini: TMemIniFile;
  sFmt: string;
  oldInt: Integer;
begin
  ShowSeconds := True;
  BlinkColons := True;
  ShowFps := False;
  Use12Hour := False;
  DateFormat := 4;
  UseRussian := False;
  CenterLocked := False;
  FastMovement := False;
  UseAtmosphericBackground := False;
  DimBrightness := True;
  ClockColor := CLOCK_COLOR_TRAFFIC;
  WinWidth := DEF_CLIENT_W;
  WinHeight := DEF_CLIENT_H;
  FStamp := 0;
  if FileExists(FilePath) then
  try
    ini := TMemIniFile.Create(FilePath);
    try
      ShowSeconds := ini.ReadBool('Clock', 'ShowSeconds', True);
      BlinkColons := ini.ReadBool('Clock', 'BlinkColons', True);
      ShowFps := ini.ReadBool('Clock', 'ShowFps', False);
      Use12Hour := ini.ReadBool('Clock', 'Time12Hour', False);
      sFmt := Trim(ini.ReadString('Clock', 'DateFormat', ''));
      if sFmt = '' then
        DateFormat := 4
      else if TryStrToInt(sFmt, oldInt) then
      begin
        DateFormat := oldInt + 1;
        if (DateFormat < 1) or (DateFormat >= DATE_FORMAT_COUNT) then
          DateFormat := 1;
      end
      else
        DateFormat := DateFormatIndexByName(sFmt);
      UseRussian := ini.ReadBool('Clock', 'UseRussian', False);
      CenterLocked := ini.ReadBool('Clock', 'CenterLocked', False);
      FastMovement := ini.ReadBool('Clock', 'FastMovement', False);
      UseAtmosphericBackground := ini.ReadBool('Clock', 'UseAtmosphericBackground', False);
      DimBrightness := ini.ReadBool('Clock', 'DimBrightness', True);
      ClockColor := ClockColorIndexByName(ini.ReadString('Clock', 'ClockColor', 'Traffic Light (Bonus)'));
      WinWidth := ini.ReadInteger('Window', 'Width', DEF_CLIENT_W);
      WinHeight := ini.ReadInteger('Window', 'Height', DEF_CLIENT_H);
    finally
      ini.Free;
    end;
  except
    on E: Exception do LastError := E.Message;
  end;

  if (DateFormat < 0) or (DateFormat >= DATE_FORMAT_COUNT) then DateFormat := 0;
  if (WinWidth < MIN_CLIENT_W) or (WinWidth > 10000) then WinWidth := DEF_CLIENT_W;
  if (WinHeight < MIN_CLIENT_H) or (WinHeight > 10000) then WinHeight := DEF_CLIENT_H;

  FileAge(FilePath, FStamp);
end;

function TSettings.Save: Boolean;
var
  ini: TMemIniFile;
begin
  Result := False;
  LastError := '';
  try
    ini := TMemIniFile.Create(FilePath);
    try
      ini.WriteBool('Clock', 'ShowSeconds', ShowSeconds);
      ini.WriteBool('Clock', 'BlinkColons', BlinkColons);
      ini.WriteBool('Clock', 'ShowFps', ShowFps);
      ini.WriteBool('Clock', 'Time12Hour', Use12Hour);
      ini.WriteString('Clock', 'DateFormat', DateFormatName(DateFormat));
      ini.WriteBool('Clock', 'UseRussian', UseRussian);
      ini.WriteBool('Clock', 'CenterLocked', CenterLocked);
      ini.WriteBool('Clock', 'FastMovement', FastMovement);
      ini.WriteBool('Clock', 'UseAtmosphericBackground', UseAtmosphericBackground);
      ini.WriteBool('Clock', 'DimBrightness', DimBrightness);
      ini.WriteString('Clock', 'ClockColor', ClockColorName(ClockColor));
      ini.WriteInteger('Window', 'Width', WinWidth);
      ini.WriteInteger('Window', 'Height', WinHeight);
      ini.UpdateFile;
    finally
      ini.Free;
    end;
    FileAge(FilePath, FStamp);
    Result := True;
  except
    on E: Exception do LastError := E.Message;
  end;
end;

function TSettings.FileChanged: Boolean;
var
  dt: TDateTime;
begin
  Result := False;
  if not FileAge(FilePath, dt) then Exit;
  if dt <> FStamp then
  begin
    FStamp := dt;
    Result := True;
  end;
end;

function TSettings.InWindowsFolder: Boolean;
var
  w: string;
begin
  w := LowerCase(SysUtils.GetEnvironmentVariable('WINDIR'));
  Result := (w <> '') and (Pos(w, LowerCase(FilePath)) = 1);
end;

{ ================= TGBlock ================= }

constructor TGBlock.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Color := COL_BLOCK;
  FTitle := '';
end;

procedure TGBlock.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := COL_BLOCK;
  Canvas.FillRect(ClientRect);

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := COL_MUTED;
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(16, 13, FTitle);

  Canvas.Pen.Color := COL_LINE;
  Canvas.Pen.Width := 1;
  Canvas.MoveTo(16, 34);
  Canvas.LineTo(Width - 16, 34);
end;

{ ================= TGCheck ================= }

constructor TGCheck.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csClickEvents];
  DoubleBuffered := True;
  TabStop := True;
  Cursor := crHandPoint;
  Color := COL_BLOCK;
  FChecked := False;
  FHover := False;
  FCaption := '';
  Height := 26;
  Width := 200;
end;

procedure TGCheck.SetChecked(AValue: Boolean);
begin
  if FChecked = AValue then Exit;
  FChecked := AValue;
  Invalidate;
end;

procedure TGCheck.Toggle;
begin
  FChecked := not FChecked;
  Invalidate;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TGCheck.Paint;
var
  by, ty: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := COL_BLOCK;
  Canvas.FillRect(ClientRect);

  by := (Height - 18) div 2;

  if FChecked then
  begin
    Canvas.Brush.Color := COL_AMBER;
    Canvas.Pen.Color := COL_AMBER;
  end
  else
  begin
    Canvas.Brush.Color := COL_FIELD;
    if FHover then Canvas.Pen.Color := COL_AMBER else Canvas.Pen.Color := COL_LINE;
  end;
  Canvas.Pen.Width := 1;
  Canvas.RoundRect(0, by, 18, by + 18, 5, 5);

  if FChecked then
  begin
    Canvas.Pen.Color := COL_BG;
    Canvas.Pen.Width := 2;
    Canvas.Polyline([Point(4, by + 9), Point(7, by + 12), Point(13, by + 5)]);
    Canvas.Pen.Width := 1;
  end;

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [];
  Canvas.Font.Color := COL_TEXT;
  Canvas.Brush.Style := bsClear;
  ty := (Height - Canvas.TextHeight('Ag')) div 2;
  Canvas.TextOut(28, ty, FCaption);

  if Focused then
    Canvas.DrawFocusRect(Rect(26, 1, Width - 1, Height - 1));
end;

procedure TGCheck.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    SetFocus;
    Toggle;
  end;
end;

procedure TGCheck.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TGCheck.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  Invalidate;
end;

procedure TGCheck.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = VK_SPACE then
  begin
    Toggle;
    Key := 0;
  end;
end;

procedure TGCheck.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TGCheck.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

{ ================= TGList ================= }

constructor TGList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csClickEvents];
  DoubleBuffered := True;
  TabStop := True;
  Color := COL_BLOCK;
  FHover := -1;
  FSelected := 0;
  FItems := nil;
end;

function TGList.RowAt(Y: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  if FItems = nil then Exit;
  i := (Y - 4) div ROW_H;
  if (i >= 0) and (i < FItems.Count) and (Y >= 4) then
    Result := i;
end;

procedure TGList.Paint;
var
  i, y: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := COL_BLOCK;
  Canvas.FillRect(ClientRect);

  Canvas.Pen.Color := COL_LINE;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);

  if FItems = nil then Exit;

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [];
  Canvas.Brush.Style := bsClear;

  for i := 0 to FItems.Count - 1 do
  begin
    y := 4 + i * ROW_H;
    if i = FHover then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := COL_FIELD_HI;
      Canvas.FillRect(Rect(3, y, Width - 3, y + ROW_H));
      Canvas.Brush.Style := bsClear;
    end;
    if i = FSelected then
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := COL_AMBER;
      Canvas.FillRect(Rect(8, y + 11, 12, y + 15));
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := COL_AMBER;
    end
    else
      Canvas.Font.Color := COL_TEXT;
    Canvas.TextOut(20, y + (ROW_H - Canvas.TextHeight('Ag')) div 2, FItems[i]);
  end;
end;

procedure TGList.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  i := RowAt(Y);
  if i <> FHover then
  begin
    FHover := i;
    Invalidate;
  end;
end;

procedure TGList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  i := RowAt(Y);
  if (i >= 0) and Assigned(FOnPick) then FOnPick(i);
end;

procedure TGList.MouseLeave;
begin
  inherited MouseLeave;
  if FHover <> -1 then
  begin
    FHover := -1;
    Invalidate;
  end;
end;

procedure TGList.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = VK_ESCAPE then
  begin
    if Assigned(FOnCancel) then FOnCancel(Self);
    Key := 0;
  end
  else if Key = VK_RETURN then
  begin
    if Assigned(FOnPick) then
    begin
      if FHover >= 0 then FOnPick(FHover) else FOnPick(FSelected);
    end;
    Key := 0;
  end
  else if (Key = VK_DOWN) and (FItems <> nil) then
  begin
    if FHover < FItems.Count - 1 then Inc(FHover);
    Invalidate;
    Key := 0;
  end
  else if (Key = VK_UP) then
  begin
    if FHover > 0 then Dec(FHover);
    Invalidate;
    Key := 0;
  end;
end;

{ ================= TGCombo ================= }

constructor TGCombo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csClickEvents];
  DoubleBuffered := True;
  TabStop := True;
  Cursor := crHandPoint;
  Color := COL_BLOCK;
  FItems := TStringList.Create;
  FIndex := 0;
  FHover := False;
  FPopup := nil;
  Height := 30;
  Width := 200;
end;

destructor TGCombo.Destroy;
begin
  ClosePopup;
  FItems.Free;
  inherited Destroy;
end;

procedure TGCombo.SetIndex(AValue: Integer);
begin
  if AValue < 0 then AValue := 0;
  if AValue >= FItems.Count then AValue := FItems.Count - 1;
  if AValue < 0 then AValue := 0;
  if FIndex = AValue then Exit;
  FIndex := AValue;
  Invalidate;
end;

procedure TGCombo.ClosePopup;
begin
  if FPopup <> nil then
  begin
    FPopup.OnDeactivate := nil;
    FPopup.Release;
    FPopup := nil;
  end;
end;

procedure TGCombo.PopupDeactivate(Sender: TObject);
begin
  ClosePopup;
end;

procedure TGCombo.PopupCancel(Sender: TObject);
begin
  ClosePopup;
  SetFocus;
end;

procedure TGCombo.Pick(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FItems.Count) then
  begin
    SetIndex(AIndex);
    if Assigned(FOnChange) then FOnChange(Self);
  end;
  ClosePopup;
  SetFocus;
end;

procedure TGCombo.OpenPopup;
var
  lst: TGList;
  p: TPoint;
  h, px, py: Integer;
begin
  if FPopup <> nil then
  begin
    ClosePopup;
    Exit;
  end;
  if FItems.Count = 0 then Exit;

  h := 8 + FItems.Count * ROW_H;
  FPopup := TForm.CreateNew(nil);
  FPopup.BorderStyle := bsNone;
  FPopup.FormStyle := fsStayOnTop;
  FPopup.ShowInTaskBar := stNever;
  FPopup.Color := COL_BLOCK;
  FPopup.OnDeactivate := @PopupDeactivate;

  lst := TGList.Create(FPopup);
  lst.Parent := FPopup;
  lst.Align := alClient;
  lst.Items := FItems;
  lst.Selected := FIndex;
  lst.OnPick := @Pick;
  lst.OnCancel := @PopupCancel;

  p := ClientToScreen(Point(0, Height + 2));
  px := p.X;
  py := p.Y;
  if py + h > Screen.Height then
    py := ClientToScreen(Point(0, 0)).Y - h - 2;
  if px + Width > Screen.Width then
    px := Screen.Width - Width - 4;
  if px < 0 then px := 0;
  if py < 0 then py := 0;
  FPopup.SetBounds(px, py, Width, h);
  FPopup.Show;
  lst.SetFocus;
end;

procedure TGCombo.Paint;
var
  ty, ax: Integer;
  txt: string;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := COL_BLOCK;
  Canvas.FillRect(ClientRect);

  Canvas.Brush.Color := COL_FIELD;
  if FHover or Focused then Canvas.Pen.Color := COL_AMBER else Canvas.Pen.Color := COL_LINE;
  Canvas.Pen.Width := 1;
  Canvas.RoundRect(0, 0, Width, Height, 6, 6);

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [];
  Canvas.Font.Color := COL_TEXT;
  Canvas.Brush.Style := bsClear;
  txt := '';
  if (FIndex >= 0) and (FIndex < FItems.Count) then txt := FItems[FIndex];
  ty := (Height - Canvas.TextHeight('Ag')) div 2;
  Canvas.TextOut(12, ty, txt);

  ax := Width - 20;
  Canvas.Pen.Color := COL_MUTED;
  Canvas.Pen.Width := 2;
  Canvas.MoveTo(ax, (Height div 2) - 2);
  Canvas.LineTo(ax + 5, (Height div 2) + 3);
  Canvas.LineTo(ax + 10, (Height div 2) - 2);
  Canvas.Pen.Width := 1;
end;

procedure TGCombo.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    SetFocus;
    OpenPopup;
  end;
end;

procedure TGCombo.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TGCombo.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  Invalidate;
end;

procedure TGCombo.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = VK_RETURN) or (Key = VK_SPACE) or (Key = VK_DOWN) then
  begin
    OpenPopup;
    Key := 0;
  end;
end;

procedure TGCombo.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TGCombo.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

{ ================= TGButton ================= }

constructor TGButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csClickEvents];
  DoubleBuffered := True;
  TabStop := True;
  Cursor := crHandPoint;
  Color := COL_BG;
  FCaption := '';
  FHover := False;
  Height := 32;
  Width := 120;
end;

procedure TGButton.Paint;
var
  tw, th: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := COL_BG;
  Canvas.FillRect(ClientRect);

  if FHover then Canvas.Brush.Color := COL_AMBER_HI else Canvas.Brush.Color := COL_AMBER;
  Canvas.Pen.Color := Canvas.Brush.Color;
  Canvas.RoundRect(0, 0, Width, Height, 7, 7);

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := COL_BG;
  Canvas.Brush.Style := bsClear;
  tw := Canvas.TextWidth(FCaption);
  th := Canvas.TextHeight('Ag');
  Canvas.TextOut((Width - tw) div 2, (Height - th) div 2, FCaption);

  if Focused then
    Canvas.DrawFocusRect(Rect(2, 2, Width - 2, Height - 2));
end;

procedure TGButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    SetFocus;
    if Assigned(FOnClick) then FOnClick(Self);
  end;
end;

procedure TGButton.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TGButton.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  Invalidate;
end;

procedure TGButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = VK_RETURN) or (Key = VK_SPACE) then
  begin
    if Assigned(FOnClick) then FOnClick(Self);
    Key := 0;
  end;
end;

procedure TGButton.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TGButton.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

{ ================= TGSwatch ================= }

constructor TGSwatch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Color := COL_BLOCK;
  FIndex := 0;
end;

procedure TGSwatch.Paint;
var
  w3: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := COL_BLOCK;
  Canvas.FillRect(ClientRect);

  if FIndex = CLOCK_COLOR_TRAFFIC then
  begin
    w3 := (Width - 2) div 3;
    Canvas.Brush.Color := TrafficLightColor(0);
    Canvas.FillRect(Rect(1, 1, 1 + w3, Height - 1));
    Canvas.Brush.Color := TrafficLightColor(1);
    Canvas.FillRect(Rect(1 + w3, 1, 1 + 2 * w3, Height - 1));
    Canvas.Brush.Color := TrafficLightColor(2);
    Canvas.FillRect(Rect(1 + 2 * w3, 1, Width - 1, Height - 1));
  end
  else
  begin
    Canvas.Brush.Color := ClockColorRGB(FIndex);
    Canvas.FillRect(Rect(1, 1, Width - 1, Height - 1));
  end;

  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := COL_LINE;
  Canvas.Pen.Width := 1;
  Canvas.RoundRect(0, 0, Width, Height, 6, 6);
end;

{ ================= form ================= }

function TGSettingsForm.MakeLabel(AParent: TWinControl; const AText: string; AMuted: Boolean): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Caption := AText;
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 9;
  Result.Font.Style := [];
  if AMuted then Result.Font.Color := COL_MUTED else Result.Font.Color := COL_TEXT;
  Result.AutoSize := False;
  Result.WordWrap := True;
end;

procedure TGSettingsForm.UrlClick(Sender: TObject);
begin
  ShellExecuteA(0, 'open', PChar(APP_URL), nil, nil, 1);
end;

procedure TGSettingsForm.LicenseClick(Sender: TObject);
var
  u: string;
begin
  if Sender = lblLicDseg then u := APP_LICENSE_DSEG else u := APP_LICENSE_NOTO;
  ShellExecuteA(0, 'open', PChar(u), nil, nil, 1);
end;

procedure TGSettingsForm.Build;
var
  i, w, h: Integer;
begin
  Caption := APP_NAME + ' — Settings';
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  FormStyle := fsStayOnTop;
  ShowInTaskBar := stAlways;
  Color := COL_BG;
  DoubleBuffered := True;
  Font.Name := 'Segoe UI';
  Font.Size := 9;

  w := Cfg.WinWidth;
  h := Cfg.WinHeight;
  if w > Screen.Width - 40 then w := Screen.Width - 40;
  if h > Screen.Height - 80 then h := Screen.Height - 80;
  if w < MIN_CLIENT_W then w := MIN_CLIENT_W;
  if h < MIN_CLIENT_H then h := MIN_CLIENT_H;
  ClientWidth := w;
  ClientHeight := h;

  Constraints.MinWidth := MIN_CLIENT_W + 16;
  Constraints.MinHeight := MIN_CLIENT_H + 40;
  OnResize := @Resized;

  FUpdating := True;
  try
    pnlLed := TPanel.Create(Self);
    pnlLed.Parent := Self;
    pnlLed.BevelOuter := bvNone;
    pnlLed.Color := COL_AMBER;
    pnlLed.Caption := '';

    lblTitle := MakeLabel(Self, APP_NAME, False);
    lblTitle.Font.Size := 14;
    lblTitle.Font.Style := [fsBold];
    lblTitle.WordWrap := False;

    lblSub := MakeLabel(Self, 'Screensaver settings · changes apply instantly', True);
    lblSub.WordWrap := False;

    lblVersion := MakeLabel(Self, 'v' + APP_VERSION + ' (' + APP_DATE + ')', True);
    lblVersion.WordWrap := False;
    lblVersion.Alignment := taRightJustify;

    lblUrl := MakeLabel(Self, APP_URL, False);
    lblUrl.Font.Color := COL_AMBER;
    lblUrl.Font.Style := [fsUnderline];
    lblUrl.WordWrap := False;
    lblUrl.Alignment := taRightJustify;
    lblUrl.Cursor := crHandPoint;
    lblUrl.OnClick := @UrlClick;

    lblLicDseg := MakeLabel(Self, 'DSEG7 license', True);
    lblLicDseg.Font.Style := [fsUnderline];
    lblLicDseg.WordWrap := False;
    lblLicDseg.Alignment := taRightJustify;
    lblLicDseg.Cursor := crHandPoint;
    lblLicDseg.OnClick := @LicenseClick;

    lblLicNoto := MakeLabel(Self, 'Noto Sans license', True);
    lblLicNoto.Font.Style := [fsUnderline];
    lblLicNoto.WordWrap := False;
    lblLicNoto.Alignment := taRightJustify;
    lblLicNoto.Cursor := crHandPoint;
    lblLicNoto.OnClick := @LicenseClick;

    blkTime := TGBlock.Create(Self);
    blkTime.Parent := Self;
    blkTime.Title := 'Time';

    blkDate := TGBlock.Create(Self);
    blkDate.Parent := Self;
    blkDate.Title := 'Date';

    blkMove := TGBlock.Create(Self);
    blkMove.Parent := Self;
    blkMove.Title := 'Movement';

    blkLook := TGBlock.Create(Self);
    blkLook.Parent := Self;
    blkLook.Title := 'Background & brightness';

    blkColor := TGBlock.Create(Self);
    blkColor.Parent := Self;
    blkColor.Title := 'Clock color';

    blkDiag := TGBlock.Create(Self);
    blkDiag.Parent := Self;
    blkDiag.Title := 'Diagnostics';

    lblTimeFmt := MakeLabel(blkTime, 'Time format', True);
    cmbTime := TGCombo.Create(Self);
    cmbTime.Parent := blkTime;
    cmbTime.Items.Add('24-hour');
    cmbTime.Items.Add('12-hour (AM/PM)');
    if Cfg.Use12Hour then cmbTime.ItemIndex := 1 else cmbTime.ItemIndex := 0;
    cmbTime.OnChange := @Changed;

    chkSeconds := TGCheck.Create(Self);
    chkSeconds.Parent := blkTime;
    chkSeconds.CaptionText := 'Show seconds';
    chkSeconds.Checked := Cfg.ShowSeconds;
    chkSeconds.OnChange := @Changed;

    chkBlink := TGCheck.Create(Self);
    chkBlink.Parent := blkTime;
    chkBlink.CaptionText := 'Blink colons each second';
    chkBlink.Checked := Cfg.BlinkColons;
    chkBlink.OnChange := @Changed;

    lblDateFmt := MakeLabel(blkDate, 'Date format', True);
    cmbDate := TGCombo.Create(Self);
    cmbDate.Parent := blkDate;
    cmbDate.Items.Add('Hidden');
    cmbDate.Items.Add('ISO');
    cmbDate.Items.Add('European');
    cmbDate.Items.Add('American');
    cmbDate.Items.Add('Short text');
    cmbDate.ItemIndex := Cfg.DateFormat;
    cmbDate.OnChange := @Changed;

    chkRussian := TGCheck.Create(Self);
    chkRussian.Parent := blkDate;
    chkRussian.CaptionText := 'Show date in Russian';
    chkRussian.Checked := Cfg.UseRussian;
    chkRussian.OnChange := @Changed;

    lblDateHint := MakeLabel(blkDate, '', True);
    lblDateHint.WordWrap := False;

    chkCenter := TGCheck.Create(Self);
    chkCenter.Parent := blkMove;
    chkCenter.CaptionText := 'Keep clock centered (no movement)';
    chkCenter.Checked := Cfg.CenterLocked;
    chkCenter.OnChange := @Changed;

    chkFast := TGCheck.Create(Self);
    chkFast.Parent := blkMove;
    chkFast.CaptionText := 'Fast movement (×2)';
    chkFast.Checked := Cfg.FastMovement;
    chkFast.OnChange := @Changed;
    lblMoveHint := MakeLabel(blkMove, 'The clock drifts smoothly and bounces off screen edges.', True);

    chkAtmo := TGCheck.Create(Self);
    chkAtmo.Parent := blkLook;
    chkAtmo.CaptionText := 'Use atmospheric background';
    chkAtmo.Checked := Cfg.UseAtmosphericBackground;
    chkAtmo.OnChange := @Changed;

    chkDim := TGCheck.Create(Self);
    chkDim.Parent := blkLook;
    chkDim.CaptionText := 'Dim clock brightness (30%)';
    chkDim.Checked := Cfg.DimBrightness;
    chkDim.OnChange := @Changed;
    lblLookHint := MakeLabel(blkLook, 'Glow and brightness apply to all elements.', True);

    lblColor := MakeLabel(blkColor, 'Color scheme', True);
    cmbColor := TGCombo.Create(Self);
    cmbColor.Parent := blkColor;
    for i := 0 to CLOCK_COLOR_COUNT - 1 do
      cmbColor.Items.Add(ClockColorName(i));
    cmbColor.ItemIndex := Cfg.ClockColor;
    cmbColor.OnChange := @Changed;

    swatch := TGSwatch.Create(Self);
    swatch.Parent := blkColor;
    swatch.ColorIndex := Cfg.ClockColor;
    lblColorHint := MakeLabel(blkColor, 'Glow is derived automatically from the base color.', True);

    chkFps := TGCheck.Create(Self);
    chkFps.Parent := blkDiag;
    chkFps.CaptionText := 'Show FPS counter';
    chkFps.Checked := Cfg.ShowFps;
    chkFps.OnChange := @Changed;
    lblDiagHint := MakeLabel(blkDiag, 'Frame counter in the top-left corner of the screensaver.', True);

    lblFooter := MakeLabel(Self, 'All changes are saved instantly to ' + INI_NAME, True);
    lblFooter.WordWrap := False;

    btnClose := TGButton.Create(Self);
    btnClose.Parent := Self;
    btnClose.CaptionText := 'Close';
    btnClose.OnClick := @CloseClicked;
  finally
    FUpdating := False;
  end;

  FSavedSeconds := Cfg.ShowSeconds;
  FSavedBlink := Cfg.BlinkColons;
  FSavedFps := Cfg.ShowFps;
  FSaved12Hour := Cfg.Use12Hour;
  FSavedDateFormat := Cfg.DateFormat;
  FSavedRussian := Cfg.UseRussian;
  FSavedCenter := Cfg.CenterLocked;
  FSavedFast := Cfg.FastMovement;
  FSavedAtmos := Cfg.UseAtmosphericBackground;
  FSavedDim := Cfg.DimBrightness;
  FSavedColor := Cfg.ClockColor;

  UpdateHints;
  Layout;
end;

procedure TGSettingsForm.Layout;
var
  m, g, cw, y1, y2, h1, h2, bw: Integer;
begin
  m := 20;
  g := 16;
  cw := (ClientWidth - 2 * m - 2 * g) div 3;
  if cw < 200 then cw := 200;
  y1 := 78;
  h1 := 182;
  y2 := y1 + h1 + g;
  h2 := 150;
  bw := cw - 32;

  pnlLed.SetBounds(m, 26, 8, 8);
  lblTitle.SetBounds(m + 16, 14, 320, 26);
  lblSub.SetBounds(m + 16, 42, 460, 18);
  lblVersion.SetBounds(ClientWidth - m - 340, 18, 340, 18);
  lblUrl.SetBounds(ClientWidth - m - 340, 40, 340, 18);
  lblLicNoto.SetBounds(ClientWidth - m - 100, 60, 100, 16);
  lblLicDseg.SetBounds(ClientWidth - m - 206, 60, 90, 16);

  blkTime.SetBounds(m, y1, cw, h1);
  blkDate.SetBounds(m, y2, cw, h2);
  blkMove.SetBounds(m + cw + g, y1, cw, h1);
  blkLook.SetBounds(m + cw + g, y2, cw, h2);
  blkColor.SetBounds(m + 2 * (cw + g), y1, cw, h1);
  blkDiag.SetBounds(m + 2 * (cw + g), y2, cw, h2);

  lblTimeFmt.SetBounds(16, 42, bw, 16);
  cmbTime.SetBounds(16, 60, bw, 30);
  chkSeconds.SetBounds(16, 102, bw, 26);
  chkBlink.SetBounds(16, 132, bw, 26);

  lblDateFmt.SetBounds(16, 42, bw, 16);
  cmbDate.SetBounds(16, 60, bw, 30);
  chkRussian.SetBounds(16, 96, bw, 26);
  lblDateHint.SetBounds(16, 126, bw, 18);

  chkCenter.SetBounds(16, 46, bw, 26);
  chkFast.SetBounds(16, 78, bw, 26);
  lblMoveHint.SetBounds(16, 114, bw, 44);

  chkAtmo.SetBounds(16, 46, bw, 26);
  chkDim.SetBounds(16, 78, bw, 26);
  lblLookHint.SetBounds(16, 114, bw, 30);

  lblColor.SetBounds(16, 42, bw, 16);
  cmbColor.SetBounds(16, 60, bw - 56, 30);
  swatch.SetBounds(16 + bw - 44, 60, 44, 30);
  lblColorHint.SetBounds(16, 102, bw, 44);

  chkFps.SetBounds(16, 46, bw, 26);
  lblDiagHint.SetBounds(16, 82, bw, 50);

  lblFooter.SetBounds(m, ClientHeight - 34, ClientWidth - 2 * m - 150, 18);
  btnClose.SetBounds(ClientWidth - m - 120, ClientHeight - 46, 120, 32);
end;

procedure TGSettingsForm.Resized(Sender: TObject);
begin
  if FUpdating then Exit;
  if ClientWidth < MIN_CLIENT_W then ClientWidth := MIN_CLIENT_W;
  if ClientHeight < MIN_CLIENT_H then ClientHeight := MIN_CLIENT_H;
  Layout;
end;

procedure TGSettingsForm.UpdateHints;
var
  ru: Boolean;
begin
  ru := chkRussian.Checked;
  case cmbDate.ItemIndex of
    1: if ru then lblDateHint.Caption := 'Пример: ПН · 2026-11-23'
         else lblDateHint.Caption := 'Example: MON · 2026-11-23';
    2: if ru then lblDateHint.Caption := 'Пример: ПН · 23.11.2026'
         else lblDateHint.Caption := 'Example: MON · 23.11.2026';
    3: if ru then lblDateHint.Caption := 'Пример: ПН · 11/23/2026'
         else lblDateHint.Caption := 'Example: MON · 11/23/2026';
    4: if ru then lblDateHint.Caption := 'Пример: ПН · 23 НОЯ 2026'
         else lblDateHint.Caption := 'Example: MON · 23 NOV 2026';
  else
    if ru then lblDateHint.Caption := 'Дата скрыта — только часы.'
    else lblDateHint.Caption := 'Date hidden — clock only.';
  end;
  swatch.ColorIndex := cmbColor.ItemIndex;
  swatch.Invalidate;
end;

procedure TGSettingsForm.Changed(Sender: TObject);
begin
  CommitChanges;
end;

procedure TGSettingsForm.CloseClicked(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TGSettingsForm.CommitChanges;
var
  idx, idxDate: Integer;
begin
  if FUpdating then Exit;

  idx := cmbColor.ItemIndex;
  if (idx < 0) or (idx >= CLOCK_COLOR_COUNT) then idx := 0;
  idxDate := cmbDate.ItemIndex;
  if (idxDate < 0) or (idxDate >= DATE_FORMAT_COUNT) then idxDate := 0;

  Cfg.ShowSeconds := chkSeconds.Checked;
  Cfg.BlinkColons := chkBlink.Checked;
  Cfg.ShowFps := chkFps.Checked;
  Cfg.Use12Hour := cmbTime.ItemIndex = 1;
  Cfg.DateFormat := idxDate;
  Cfg.UseRussian := chkRussian.Checked;
  Cfg.CenterLocked := chkCenter.Checked;
  Cfg.FastMovement := chkFast.Checked;
  Cfg.UseAtmosphericBackground := chkAtmo.Checked;
  Cfg.DimBrightness := chkDim.Checked;
  Cfg.ClockColor := idx;

  UpdateHints;

  if Cfg.Save then
  begin
    FSavedSeconds := Cfg.ShowSeconds;
    FSavedBlink := Cfg.BlinkColons;
    FSavedFps := Cfg.ShowFps;
    FSaved12Hour := Cfg.Use12Hour;
    FSavedDateFormat := Cfg.DateFormat;
    FSavedRussian := Cfg.UseRussian;
    FSavedCenter := Cfg.CenterLocked;
    FSavedFast := Cfg.FastMovement;
    FSavedAtmos := Cfg.UseAtmosphericBackground;
    FSavedDim := Cfg.DimBrightness;
    FSavedColor := Cfg.ClockColor;
    Exit;
  end;

  Application.MessageBox(
    PChar('Could not save settings.' + LineEnding + LineEnding +
      'File: ' + Cfg.FilePath + LineEnding +
      'Reason: ' + Cfg.LastError + LineEnding + LineEnding +
      'Settings were NOT saved and have been reverted.' + LineEnding +
      'Usually this means the folder is write-protected. Move the program ' +
      'to your own folder (e.g. C:\Tools\' + APP_NAME + ') or run as administrator.'),
    PChar(APP_NAME + ' — save error'), MB_OK or MB_ICONERROR);

  FUpdating := True;
  try
    chkSeconds.Checked := FSavedSeconds;
    chkBlink.Checked := FSavedBlink;
    chkFps.Checked := FSavedFps;
    cmbTime.ItemIndex := Ord(FSaved12Hour);
    cmbDate.ItemIndex := FSavedDateFormat;
    chkRussian.Checked := FSavedRussian;
    chkCenter.Checked := FSavedCenter;
    chkFast.Checked := FSavedFast;
    chkAtmo.Checked := FSavedAtmos;
    chkDim.Checked := FSavedDim;
    cmbColor.ItemIndex := FSavedColor;
    Cfg.ShowSeconds := FSavedSeconds;
    Cfg.BlinkColons := FSavedBlink;
    Cfg.ShowFps := FSavedFps;
    Cfg.Use12Hour := FSaved12Hour;
    Cfg.DateFormat := FSavedDateFormat;
    Cfg.UseRussian := FSavedRussian;
    Cfg.CenterLocked := FSavedCenter;
    Cfg.FastMovement := FSavedFast;
    Cfg.UseAtmosphericBackground := FSavedAtmos;
    Cfg.DimBrightness := FSavedDim;
    Cfg.ClockColor := FSavedColor;
    UpdateHints;
  finally
    FUpdating := False;
  end;
end;

procedure ShowSettingsDialog(AOwnerWnd: HWND);
var
  F: TGSettingsForm;
  hMutex: THandle;
  hwndExisting: THandle;
  capW: WideString;
  i: Integer;
begin
  hMutex := CreateMutexW(nil, True,
    PWideChar(UTF8Decode('Local\RidbowtDriftClockSettings')));

  if (hMutex <> 0) and (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    // окно настроек уже открыто в другом процессе — активируем его
    capW := UTF8Decode(APP_NAME + ' — Settings');
    hwndExisting := 0;
    for i := 0 to 20 do
    begin
      hwndExisting := FindWindowW(nil, PWideChar(capW));
      if hwndExisting <> 0 then Break;
      Sleep(50);
    end;
    if hwndExisting <> 0 then
    begin
      if IsIconic(hwndExisting) then
        ShowWindow(hwndExisting, SW_RESTORE);
      SetForegroundWindow(hwndExisting);
      BringWindowToTop(hwndExisting);
    end;
    if hMutex <> 0 then CloseHandle(hMutex);
    Exit;
  end;

  Cfg.Load;

  if Cfg.InWindowsFolder then
    Application.MessageBox(
      PChar('The program is running from a Windows system folder.' + LineEnding +
        'Settings will not be saved here (or will silently go to VirtualStore).' + LineEnding +
        'Keep the .scr and .ini in a separate folder so everything stays portable.'),
      PChar(APP_NAME), MB_OK or MB_ICONWARNING);

  F := TGSettingsForm.CreateNew(nil);
  try
    F.Build;
    if (AOwnerWnd <> 0) and Windows.IsWindow(AOwnerWnd) then
      Windows.SetWindowLongPtr(F.Handle, GWLP_HWNDPARENT, AOwnerWnd);
    F.ShowModal;

    if (F.ClientWidth <> Cfg.WinWidth) or (F.ClientHeight <> Cfg.WinHeight) then
    begin
      Cfg.WinWidth := F.ClientWidth;
      Cfg.WinHeight := F.ClientHeight;
      Cfg.Save;
    end;
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
  Cfg := TSettings.Create;
  Cfg.Load;

finalization
  Cfg.Free;

end.
