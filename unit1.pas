unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, LCLType, Windows,
  Settings, background, Launcher;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    FStarted: Boolean;
    FTimer: TTimer;
    FX, FY: Double;
    FVX, FVY: Double;
    FMaxX, FMaxY: Double;
    FInited: Boolean;
    FStartX, FStartY: Integer;
    FPreview: Boolean;
    FPreviewWnd: HWND;
    FConfigMode: Boolean;
    FStartupAction: Integer;
    FOwnerWnd: HWND;
    FReloadMs: Integer;
    FBackground: TBackground;
    FSprite: Graphics.TBitmap;
    FSpriteKey: string;
    FSpriteDC: THandle;
    FSpriteSec: THandle;
    FSpriteW: Integer;
    FSpriteH: Integer;
    FFpsFrames: Integer;
    FFpsLast: Int64;
    FFpsText: string;

    procedure StartClockSaver;
    procedure SetupSaverMode;
    procedure ApplySpeed;
    procedure SafeFallback;
    procedure FormShown(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure SetupPreview;
    procedure Quit;
    procedure DrawLedText(ACanvas: TCanvas; X, Y: Integer; const S: string);
    procedure DrawLedPart(ACanvas: TCanvas; X, Y: Integer; const S: string;
      ABase: TColor; AMode: Integer);
    procedure DrawFontHint(AX, AY: Integer);
    procedure EnsureBackground;
    procedure ReleaseBackground;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

const
  DIVIDER    = 4;
  MOUSE_SENS = 20;

  TIMER_MS = 30;
  SPEED_X  = 55;
  SPEED_Y  = 37;
  SPEED_X_FAST = 110;
  SPEED_Y_FAST = 74;

  DIM_FACTOR = 0.7;

  FONT_FILE  = 'dseg7-classic-latin-700-normal.ttf';
  FONT_FILE2 = 'NotoSans-SemiBold.ttf';
  FR_PRIVATE = $10;

  DATE_SIZE_PERCENT = 30;
  AMPM_SIZE_PERCENT = 25;

  SPRITE_PAD = 4;

type
  TRGBQuad = packed record
    rgbBlue: Byte;
    rgbGreen: Byte;
    rgbRed: Byte;
    rgbReserved: Byte;
  end;
  PRGBQuad = ^TRGBQuad;

  TMyBlendFunc = packed record
    BlendOp: Byte;
    BlendFlags: Byte;
    SourceConstantAlpha: Byte;
    AlphaFormat: Byte;
  end;

  TMyBmiHeader = packed record
    biSize: DWord;
    biWidth: LongInt;
    biHeight: LongInt;
    biPlanes: Word;
    biBitCount: Word;
    biCompression: DWord;
    biSizeImage: DWord;
    biXPelsPerMeter: LongInt;
    biYPelsPerMeter: LongInt;
    biClrUsed: DWord;
    biClrImportant: DWord;
  end;

  TMyBmi = packed record
    bmiHeader: TMyBmiHeader;
    bmiColors: array[0..0] of DWord;
  end;

{ ================= WinAPI ================= }

function AddFontResourceExW(AFileName: PWideChar; AFlags: LongWord;
  AReserved: Pointer): LongInt; stdcall; external 'gdi32.dll' name 'AddFontResourceExW';

function RemoveFontResourceExW(AFileName: PWideChar; AFlags: LongWord;
  AReserved: Pointer): LongBool; stdcall; external 'gdi32.dll' name 'RemoveFontResourceExW';

function AddFontMemResourceEx(pbFont: Pointer; cjSize: DWord; pvReserved: Pointer;
  pNumFonts: PDWord): THandle; stdcall; external 'gdi32.dll' name 'AddFontMemResourceEx';

function RemoveFontMemResourceEx(fh: THandle): LongBool; stdcall;
  external 'gdi32.dll' name 'RemoveFontMemResourceEx';

function GetModuleFileNameW(AModule: THandle; ABuffer: PWideChar;
  ASize: LongWord): LongWord; stdcall; external 'kernel32.dll' name 'GetModuleFileNameW';

function GetFileAttributesW(AFileName: PWideChar): LongWord;
  stdcall; external 'kernel32.dll' name 'GetFileAttributesW';

function CreateFontW(AHeight, AWidth, AEscapement, AOrientation, AWeight: LongInt;
  AItalic, AUnderline, AStrikeOut, ACharSet, AOutPrecision, AClipPrecision,
  AQuality, APitchAndFamily: LongWord; AFaceName: PWideChar): THandle;
  stdcall; external 'gdi32.dll' name 'CreateFontW';

function GetTextFaceW(ADC: THandle; ACount: LongInt; ABuffer: PWideChar): LongInt;
  stdcall; external 'gdi32.dll' name 'GetTextFaceW';

function GetDC(AXWnd: THandle): THandle; stdcall; external 'user32.dll' name 'GetDC';

function ReleaseDC(AXWnd: THandle; ADC: THandle): LongInt;
  stdcall; external 'user32.dll' name 'ReleaseDC';

function SelectObject(ADC: THandle; AObj: THandle): THandle;
  stdcall; external 'gdi32.dll' name 'SelectObject';

function DeleteObject(AObj: THandle): LongBool;
  stdcall; external 'gdi32.dll' name 'DeleteObject';

function RedrawWindow(hWnd: THandle; lprcUpdate: Pointer; hrgnUpdate: THandle;
  flags: LongWord): LongBool; stdcall; external 'user32.dll' name 'RedrawWindow';

function GetTickCount64: Int64; stdcall; external 'kernel32.dll' name 'GetTickCount64';

type
  TABCWidths = record
    abcA: LongInt;
    abcB: LongInt;
    abcC: LongInt;
  end;

function GetCharABCWidthsW(DC: THandle; cFirst, cLast: LongWord;
  var lpABC: TABCWidths): LongBool; stdcall; external 'gdi32.dll' name 'GetCharABCWidthsW';

function ExtAlphaBlend(hdcDest: THandle; xDest, yDest, wDest, hDest: LongInt;
  hdcSrc: THandle; xSrc, ySrc, wSrc, hSrc: LongInt;
  fn: TMyBlendFunc): LongBool; stdcall; external 'msimg32.dll' name 'AlphaBlend';

function GetDIBits(ADC: THandle; hbmp: THandle; uStart, cLines: LongWord;
  lpvBits: Pointer; var bmi: TMyBmi; uUsage: LongWord): LongInt;
  stdcall; external 'gdi32.dll' name 'GetDIBits';

function CreateDIBSection(ADC: THandle; const bmi: TMyBmi; uUsage: LongWord;
  var ppvBits: Pointer; hSection: THandle; dwOffset: DWord): THandle;
  stdcall; external 'gdi32.dll' name 'CreateDIBSection';

function CreateCompatibleDC(ADC: THandle): THandle;
  stdcall; external 'gdi32.dll' name 'CreateCompatibleDC';

function DeleteDC(ADC: THandle): LongBool;
  stdcall; external 'gdi32.dll' name 'DeleteDC';

{ ================= приватные шрифты ================= }

var
  GFontLoaded: Boolean = False;
  GFontPathW: WideString = '';
  GFontFamily: string = '';
  GFontMem1: THandle = 0;
  GFont2Loaded: Boolean = False;
  GFont2PathW: WideString = '';
  GFont2Family: string = '';
  GFontMem2: THandle = 0;

function ExeFolderW: WideString;
var
  buf: array[0..4095] of WideChar;
  n: LongWord;
  s: WideString;
  i: Integer;
begin
  Result := '';
  FillChar(buf, SizeOf(buf), 0);
  n := GetModuleFileNameW(0, @buf[0], 4096);
  if (n = 0) or (n >= 4096) then Exit;
  s := PWideChar(@buf[0]);
  i := Length(s);
  while (i > 0) and (Ord(s[i]) <> 92) and (Ord(s[i]) <> 47) do Dec(i);
  Result := Copy(s, 1, i);
end;

function FaceAvailable(const AFamily: string): Boolean;
var
  dc, hf, oldf: THandle;
  buf: array[0..255] of WideChar;
  n: LongInt;
  want, got: WideString;
begin
  Result := False;
  want := UTF8Decode(AFamily);
  dc := GetDC(0);
  if dc = 0 then Exit;
  try
    hf := CreateFontW(-16, 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 0, 0,
      PWideChar(want));
    if hf = 0 then Exit;
    oldf := SelectObject(dc, hf);
    FillChar(buf, SizeOf(buf), 0);
    n := GetTextFaceW(dc, 256, @buf[0]);
    if n > 0 then
    begin
      got := PWideChar(@buf[0]);
      Result := LowerCase(string(got)) = LowerCase(AFamily);
    end;
    if oldf <> 0 then SelectObject(dc, oldf);
    DeleteObject(hf);
  finally
    ReleaseDC(0, dc);
  end;
end;

function TryLoadMemFont(const AResName: string; out AMem: THandle;
  out AFamily: string; const ACandidates: array of string): Boolean;
var
  hMod, hRes, hLoad: THandle;
  p: Pointer;
  sz, n: DWord;
  i: Integer;
begin
  Result := False;
  AMem := 0;
  AFamily := '';
  hMod := GetModuleHandleW(nil);
  hRes := FindResourceW(hMod, PWideChar(UTF8Decode(AResName)), PWideChar(PtrUInt(10)));
  if hRes = 0 then Exit;
  sz := SizeofResource(hMod, hRes);
  hLoad := LoadResource(hMod, hRes);
  if (sz = 0) or (hLoad = 0) then Exit;
  p := LockResource(hLoad);
  if p = nil then Exit;
  n := 0;
  AMem := AddFontMemResourceEx(p, sz, nil, @n);
  if AMem = 0 then Exit;
  for i := 0 to High(ACandidates) do
    if FaceAvailable(ACandidates[i]) then
    begin
      AFamily := ACandidates[i];
      Break;
    end;
  if AFamily = '' then AFamily := ACandidates[0];
  Result := True;
end;

procedure LoadClockFont;
begin
  if GFontLoaded then Exit;
  GFontFamily := '';
  if TryLoadMemFont('DSEG7_TTF', GFontMem1, GFontFamily,
    ['DSEG7 Classic', 'DSEG7 Classic Bold', 'DSEG7Classic']) then
  begin
    GFontLoaded := True;
    GFontPathW := '';
    Exit;
  end;
  GFontPathW := ExeFolderW + FONT_FILE;
  if GFontPathW = FONT_FILE then Exit;
  if GetFileAttributesW(PWideChar(GFontPathW)) = High(LongWord) then Exit;
  if AddFontResourceExW(PWideChar(GFontPathW), FR_PRIVATE, nil) <= 0 then Exit;
  GFontLoaded := True;
  if FaceAvailable('DSEG7 Classic') then GFontFamily := 'DSEG7 Classic'
  else if FaceAvailable('DSEG7 Classic Bold') then GFontFamily := 'DSEG7 Classic Bold'
  else if FaceAvailable('DSEG7Classic') then GFontFamily := 'DSEG7Classic'
  else GFontFamily := 'DSEG7 Classic';
end;

procedure LoadDateFont;
begin
  if GFont2Loaded then Exit;
  GFont2Family := '';
  if TryLoadMemFont('NOTO_TTF', GFontMem2, GFont2Family,
    ['Noto Sans SemiBold', 'Noto Sans']) then
  begin
    GFont2Loaded := True;
    GFont2PathW := '';
    Exit;
  end;
  GFont2PathW := ExeFolderW + FONT_FILE2;
  if GFont2PathW = FONT_FILE2 then Exit;
  if GetFileAttributesW(PWideChar(GFont2PathW)) = High(LongWord) then Exit;
  if AddFontResourceExW(PWideChar(GFont2PathW), FR_PRIVATE, nil) <= 0 then Exit;
  GFont2Loaded := True;
  if FaceAvailable('Noto Sans SemiBold') then GFont2Family := 'Noto Sans SemiBold'
  else if FaceAvailable('Noto Sans') then GFont2Family := 'Noto Sans'
  else GFont2Family := 'Noto Sans';
end;

procedure UnloadClockFont;
begin
  if GFontMem1 <> 0 then
  begin
    RemoveFontMemResourceEx(GFontMem1);
    GFontMem1 := 0;
  end
  else if GFontLoaded and (GFontPathW <> '') then
    RemoveFontResourceExW(PWideChar(GFontPathW), FR_PRIVATE, nil);
  GFontLoaded := False;
  GFontFamily := '';
  GFontPathW := '';

  if GFontMem2 <> 0 then
  begin
    RemoveFontMemResourceEx(GFontMem2);
    GFontMem2 := 0;
  end
  else if GFont2Loaded and (GFont2PathW <> '') then
    RemoveFontResourceExW(PWideChar(GFont2PathW), FR_PRIVATE, nil);
  GFont2Loaded := False;
  GFont2Family := '';
  GFont2PathW := '';
end;

procedure SetupClockFont(ACanvas: TCanvas; AHeight: Integer);
begin
  if GFontLoaded and (GFontFamily <> '') then
    ACanvas.Font.Name := GFontFamily
  else
    ACanvas.Font.Name := 'default';
  ACanvas.Font.Style  := [fsBold];
  ACanvas.Font.Height := AHeight;
  ACanvas.Font.Quality := fqAntialiased;
end;

procedure SetupAuxFont(ACanvas: TCanvas; AHeight: Integer);
begin
  if GFont2Loaded and (GFont2Family <> '') then
    ACanvas.Font.Name := GFont2Family
  else
    ACanvas.Font.Name := 'default';
  ACanvas.Font.Style  := [];
  ACanvas.Font.Height := AHeight;
  ACanvas.Font.Quality := fqAntialiased;
end;

function LightenColor(C: TColor; AAmount: Double): TColor;
var
  r, g, b: Integer;
begin
  r := C and $FF;
  g := (C shr 8) and $FF;
  b := (C shr 16) and $FF;
  r := Round(r + (255 - r) * AAmount);
  g := Round(g + (255 - g) * AAmount);
  b := Round(b + (255 - b) * AAmount);
  Result := RGBToColor(r, g, b);
end;

function ScaleColor(C: TColor; AFactor: Double): TColor;
var
  r, g, b: Integer;
begin
  r := C and $FF;
  g := (C shr 8) and $FF;
  b := (C shr 16) and $FF;
  r := Round(r * AFactor);
  g := Round(g * AFactor);
  b := Round(b * AFactor);
  Result := RGBToColor(r, g, b);
end;

{ ================= время и дата ================= }

function BuildTimeStr(out AAmPm: string): string;
var
  hh, mm, ss, ms: Word;
  h12: Word;
begin
  DecodeTime(Now, hh, mm, ss, ms);
  if Cfg.Use12Hour then
  begin
    if hh >= 12 then AAmPm := 'PM' else AAmPm := 'AM';
    h12 := hh mod 12;
    if h12 = 0 then h12 := 12;
    if Cfg.ShowSeconds then
      Result := Format('%d:%.2d:%.2d', [h12, mm, ss])
    else
      Result := Format('%d:%.2d', [h12, mm]);
  end
  else
  begin
    AAmPm := '';
    if Cfg.ShowSeconds then
      Result := FormatDateTime('hh:nn:ss', Now)
    else
      Result := FormatDateTime('hh:nn', Now);
  end;
end;

function WeekDayName(ADay: Word; ARussian: Boolean): string;
begin
  if ARussian then
  begin
    case ADay of
      2: Result := 'ПН';
      3: Result := 'ВТ';
      4: Result := 'СР';
      5: Result := 'ЧТ';
      6: Result := 'ПТ';
      7: Result := 'СБ';
    else
      Result := 'ВС';
    end;
  end
  else
  begin
    case ADay of
      2: Result := 'MON';
      3: Result := 'TUE';
      4: Result := 'WED';
      5: Result := 'THU';
      6: Result := 'FRI';
      7: Result := 'SAT';
    else
      Result := 'SUN';
    end;
  end;
end;

function MonthName(AMonth: Word; ARussian: Boolean): string;
begin
  if ARussian then
  begin
    case AMonth of
      1:  Result := 'ЯНВ';
      2:  Result := 'ФЕВ';
      3:  Result := 'МАР';
      4:  Result := 'АПР';
      5:  Result := 'МАЙ';
      6:  Result := 'ИЮН';
      7:  Result := 'ИЮЛ';
      8:  Result := 'АВГ';
      9:  Result := 'СЕН';
      10: Result := 'ОКТ';
      11: Result := 'НОЯ';
      12: Result := 'ДЕК';
    else
      Result := '';
    end;
  end
  else
  begin
    case AMonth of
      1:  Result := 'JAN';
      2:  Result := 'FEB';
      3:  Result := 'MAR';
      4:  Result := 'APR';
      5:  Result := 'MAY';
      6:  Result := 'JUN';
      7:  Result := 'JUL';
      8:  Result := 'AUG';
      9:  Result := 'SEP';
      10: Result := 'OCT';
      11: Result := 'NOV';
      12: Result := 'DEC';
    else
      Result := '';
    end;
  end;
end;

function DateText(AFormat: Integer; ARussian: Boolean): string;
var
  y, m, d: Word;
  wd: string;
begin
  DecodeDate(Now, y, m, d);
  wd := WeekDayName(DayOfWeek(Now), ARussian);
  case AFormat of
    2: Result := Format('%s · %.2d.%.2d.%d', [wd, d, m, y]);
    3: Result := Format('%s · %.2d/%.2d/%d', [wd, m, d, y]);
    4: Result := Format('%s · %.2d %s %d', [wd, d, MonthName(m, ARussian), y]);
  else
    Result := Format('%s · %d-%.2d-%.2d', [wd, y, m, d]);
  end;
end;

{ ================= форма ================= }

constructor TForm1.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  StartClockSaver;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  StartClockSaver;
end;

procedure TForm1.StartClockSaver;
begin
  if FStarted then Exit;
  FStarted := True;

  try
    SetupSaverMode;
  except
    SafeFallback;
  end;
end;

procedure TForm1.ApplySpeed;
var
  sx, sy: Integer;
begin
  if Cfg.FastMovement then
  begin
    sx := SPEED_X_FAST;
    sy := SPEED_Y_FAST;
  end
  else
  begin
    sx := SPEED_X;
    sy := SPEED_Y;
  end;

  if FVX < 0 then
    FVX := -sx * TIMER_MS / 1000
  else
    FVX := sx * TIMER_MS / 1000;

  if FVY < 0 then
    FVY := -sy * TIMER_MS / 1000
  else
    FVY := sy * TIMER_MS / 1000;
end;

procedure TForm1.SafeFallback;
begin
  try
    BorderStyle := bsNone;
    Color := clBlack;
    DoubleBuffered := True;
    KeyPreview := True;
    ShowInTaskBar := stNever;
    FormStyle := fsStayOnTop;
    WindowState := wsMaximized;
    SetBounds(0, 0, Screen.Width, Screen.Height);
    Cursor := crNone;

    OnPaint := @FormPaint;
    OnResize := @FormResize;
    OnKeyDown := @FormKeyDown;
    OnMouseMove := @FormMouseMove;
    OnMouseDown := @FormMouseDown;
    OnShow := @FormShown;

    ReleaseBackground;

    if FTimer = nil then
    begin
      FTimer := TTimer.Create(Self);
      FTimer.Interval := TIMER_MS;
      FTimer.OnTimer := @Tick;
      FTimer.Enabled := True;
    end;

    FInited := False;
  except
  end;
end;

procedure TForm1.SetupSaverMode;
var
  i: Integer;
  p: string;
  cfgMode: Boolean;
begin
  FPreview    := False;
  FPreviewWnd := 0;
  FOwnerWnd   := 0;
  FBackground := nil;
  cfgMode := False;

  i := 1;
  while i <= ParamCount do
  begin
    p := LowerCase(ParamStr(i));

    if (p = '/c') or (p = '-c') then
    begin
      cfgMode := True;
      if i + 1 <= ParamCount then
      begin
        p := LowerCase(ParamStr(i + 1));
        if (Length(p) > 0) and (p[1] <> '/') and (p[1] <> '-') then
        begin
          FOwnerWnd := HWND(StrToIntDef(Trim(ParamStr(i + 1)), 0));
          Inc(i);
        end;
      end;
    end
    else if (Copy(p, 1, 3) = '/c:') or (Copy(p, 1, 3) = '-c:') then
    begin
      cfgMode := True;
      FOwnerWnd := HWND(StrToIntDef(Trim(Copy(p, 4, Length(p) - 3)), 0));
    end
    else if (p = '/p') or (p = '-p') then
    begin
      FPreview := True;
      if i + 1 <= ParamCount then
      begin
        p := LowerCase(ParamStr(i + 1));
        if (Length(p) > 0) and (p[1] <> '/') and (p[1] <> '-') then
        begin
          FPreviewWnd := HWND(StrToIntDef(Trim(ParamStr(i + 1)), 0));
          Inc(i);
        end;
      end;
    end
    else if (Copy(p, 1, 3) = '/p:') or (Copy(p, 1, 3) = '-p:') then
    begin
      FPreview := True;
      FPreviewWnd := HWND(StrToIntDef(Trim(Copy(p, 4, Length(p) - 3)), 0));
    end;

    Inc(i);
  end;

  if ParamCount >= 1 then
  begin
    p := LowerCase(ParamStr(1));
    if p = '/install' then FStartupAction := 2
    else if p = '/uninstall-keep' then FStartupAction := 3
    else if p = '/uninstall-delete' then FStartupAction := 4;
  end;

  if ParamCount = 0 then
    FStartupAction := 1;

  if (not cfgMode) and FPreview and not Windows.IsWindow(FPreviewWnd) then
  begin
    Application.ShowMainForm := False;
    BorderStyle := bsNone;
    ShowInTaskBar := stNever;
    SetBounds(0, 0, 1, 1);
    Visible := False;
    Application.Terminate;
    Exit;
  end;

  if cfgMode then
    FStartupAction := 5;

  if FStartupAction <> 0 then
  begin
    FConfigMode := cfgMode;
    Application.ShowMainForm := False;
    BorderStyle   := bsNone;
    ShowInTaskBar := stNever;
    SetBounds(0, 0, 1, 1);
    Visible := False;

    FTimer := TTimer.Create(Self);
    FTimer.Interval := 10;
    FTimer.OnTimer := @Tick;
    FTimer.Enabled := True;
    Exit;
  end;

  LoadClockFont;
  LoadDateFont;

  Caption        := 'ClockSaver';
  BorderStyle    := bsNone;
  Color          := clBlack;
  KeyPreview     := True;
  ShowInTaskBar  := stNever;
  DoubleBuffered := True;

  OnPaint     := @FormPaint;
  OnResize    := @FormResize;
  OnDestroy   := @FormDestroy;
  OnKeyDown   := @FormKeyDown;
  OnMouseMove := @FormMouseMove;
  OnMouseDown := @FormMouseDown;
  OnShow      := @FormShown;

  if FPreview then
    SetupPreview
  else
  begin
    FormStyle   := fsStayOnTop;
    WindowState := wsMaximized;
    Cursor      := crNone;
    SetBounds(0, 0, Screen.Width, Screen.Height);
    FStartX := Mouse.CursorPos.X;
    FStartY := Mouse.CursorPos.Y;
  end;

  Randomize;
  FVX := SPEED_X * TIMER_MS / 1000;
  FVY := SPEED_Y * TIMER_MS / 1000;
  if Random(2) = 0 then FVX := -FVX;
  if Random(2) = 0 then FVY := -FVY;
  ApplySpeed;

  FInited := False;
  FFpsFrames := 0;
  FFpsLast := 0;
  FFpsText := '';

  if Cfg.UseAtmosphericBackground then
    EnsureBackground;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := TIMER_MS;
  FTimer.OnTimer := @Tick;
  FTimer.Enabled := True;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if FSpriteDC <> 0 then DeleteDC(FSpriteDC);
  if FSpriteSec <> 0 then DeleteObject(FSpriteSec);
  FSpriteDC := 0;
  FSpriteSec := 0;
  if FSprite <> nil then
  begin
    FSprite.Free;
    FSprite := nil;
  end;
  ReleaseBackground;
  UnloadClockFont;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  if (FBackground <> nil) and (ClientWidth > 0) and (ClientHeight > 0) then
    FBackground.Resize(ClientWidth, ClientHeight);
end;

procedure TForm1.FormShown(Sender: TObject);
const
  GWL_STYLE        = -16;
  WS_POPUP         = LongWord($80000000);
  WS_VISIBLE       = LongWord($10000000);
  WS_CLIPCHILDREN  = LongWord($02000000);
  SWP_SHOWWINDOW   = LongWord($0040);
  SWP_FRAMECHANGED = LongWord($0020);
  RDW_FLAGS        = LongWord($0185);
var
  st: LongInt;
begin
  if FPreview or FConfigMode then Exit;
  try
    st := LongInt(WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN);
    Windows.SetWindowLong(Handle, GWL_STYLE, st);
    if WindowState <> wsMaximized then
      WindowState := wsMaximized;
    SetBounds(0, 0, Screen.Width, Screen.Height);
    Windows.SetWindowPos(Handle, 0, 0, 0, Screen.Width, Screen.Height,
      SWP_SHOWWINDOW or SWP_FRAMECHANGED);
    Windows.SetForegroundWindow(Handle);
    RedrawWindow(Handle, nil, 0, RDW_FLAGS);
  except
  end;
end;

procedure TForm1.SetupPreview;
var
  R: TRect;
  st: LongInt;
begin
  R.Left := 0; R.Top := 0; R.Right := 0; R.Bottom := 0;
  if not Windows.IsWindow(FPreviewWnd) then
  begin
    Application.Terminate;
    Exit;
  end;

  Windows.GetClientRect(FPreviewWnd, @R);
  FormStyle := fsNormal;
  st := Windows.GetWindowLong(Handle, -16);
  st := (st and not WS_POPUP) or WS_CHILD;
  Windows.SetWindowLong(Handle, -16, st);
  Windows.SetParent(Handle, FPreviewWnd);
  SetBounds(0, 0, R.Right - R.Left, R.Bottom - R.Top);
end;

procedure TForm1.Tick(Sender: TObject);
begin
  if FStartupAction <> 0 then
  begin
    FTimer.Enabled := False;
    case FStartupAction of
      1: ShowControlPanel;
      2: RunInstallWorker;
      3: RunUninstallWorker(False);
      4: RunUninstallWorker(True);
      5: ShowSettingsDialog(FOwnerWnd);
    end;
    Application.Terminate;
    Exit;
  end;

  Inc(FReloadMs, TIMER_MS);
  if FReloadMs >= 1000 then
  begin
    FReloadMs := 0;
    if Cfg.FileChanged then
    begin
      Cfg.Load;
      ApplySpeed;
      if Cfg.UseAtmosphericBackground then
        EnsureBackground
      else
        ReleaseBackground;
      Invalidate;
    end;
  end;

  if not FInited then Exit;

  if FPreview or Cfg.CenterLocked then
  begin
    Invalidate;
    Exit;
  end;

  FX := FX + FVX;
  FY := FY + FVY;

  if FX <= 0 then
  begin
    FX := 0;
    FVX := Abs(FVX);
  end
  else if FX >= FMaxX then
  begin
    FX := FMaxX;
    FVX := -Abs(FVX);
  end;

  if FY <= 0 then
  begin
    FY := 0;
    FVY := Abs(FVY);
  end
  else if FY >= FMaxY then
  begin
    FY := FMaxY;
    FVY := -Abs(FVY);
  end;

  Invalidate;
end;

procedure TForm1.EnsureBackground;
begin
  if FBackground = nil then
  begin
    FBackground := TBackground.Create;
    if (ClientWidth > 0) and (ClientHeight > 0) then
      FBackground.Resize(ClientWidth, ClientHeight);
  end;
end;

procedure TForm1.ReleaseBackground;
begin
  if FBackground <> nil then
  begin
    FBackground.Free;
    FBackground := nil;
  end;
end;

procedure TForm1.DrawLedPart(ACanvas: TCanvas; X, Y: Integer; const S: string;
  ABase: TColor; AMode: Integer);
var
  dx, dy: Integer;
  mainC, glowC: TColor;
begin
  if S = '' then Exit;

  mainC := ABase;
  glowC := LightenColor(mainC, 0.45);

  ACanvas.Brush.Style := bsClear;

  if AMode <> 2 then
  begin
    ACanvas.Font.Color := glowC;
    for dx := -1 to 1 do
      for dy := -1 to 1 do
        if (dx <> 0) or (dy <> 0) then
          ACanvas.TextOut(X + dx, Y + dy, S);
  end;

  if AMode <> 1 then
  begin
    ACanvas.Font.Color := mainC;
    ACanvas.TextOut(X, Y, S);
  end;
end;

procedure TForm1.DrawLedText(ACanvas: TCanvas; X, Y: Integer; const S: string);
var
  i, j, len, part, segX, pass, digitIdx, colonIdx: Integer;
  seg: string;
  baseC: TColor;
  blinkOff: Boolean;
  hh, mm, ss, ms: Word;
begin
  DecodeTime(Now, hh, mm, ss, ms);
  blinkOff := Cfg.BlinkColons and Odd(ss);
  len := Length(S);
  baseC := ClockColorRGB(Cfg.ClockColor);

  if Cfg.ClockColor = CLOCK_COLOR_TRAFFIC then
  begin
    for pass := 1 to 2 do
    begin
      i := 1; segX := X; digitIdx := 0; colonIdx := 0;
      while i <= len do
      begin
        if S[i] = ':' then
        begin
          seg := ':';
          part := colonIdx;
          Inc(colonIdx);
        end
        else
        begin
          j := i;
          while (j <= len) and (S[j] <> ':') do Inc(j);
          seg := Copy(S, i, j - i);
          part := digitIdx;
          Inc(digitIdx);
        end;

        if not ((seg = ':') and blinkOff) then
        begin
          if pass = 1 then
            DrawLedPart(ACanvas, segX, Y, seg, TrafficLightColor(part), 1)
          else
            DrawLedPart(ACanvas, segX, Y, seg, TrafficLightColor(part), 2);
        end;

        segX := segX + ACanvas.TextWidth(seg);
        i := i + Length(seg);
      end;
    end;
  end
  else
  begin
    i := 1; segX := X;
    while i <= len do
    begin
      if S[i] = ':' then
      begin
        seg := ':';
      end
      else
      begin
        j := i;
        while (j <= len) and (S[j] <> ':') do Inc(j);
        seg := Copy(S, i, j - i);
      end;

      if not ((seg = ':') and blinkOff) then
        DrawLedPart(ACanvas, segX, Y, seg, baseC, 0);

      segX := segX + ACanvas.TextWidth(seg);
      i := i + Length(seg);
    end;
  end;
end;

procedure TForm1.DrawFontHint(AX, AY: Integer);
var
  msg: string;
  fh, tw, th: Integer;
begin
  if FPreview then Exit;

  msg := '';
  if not GFontLoaded then msg := FONT_FILE;
  if not GFont2Loaded then
  begin
    if msg <> '' then msg := msg + ', ';
    msg := msg + FONT_FILE2;
  end;
  msg := 'Шрифты не загружены: ' + msg + '  (положи .ttf рядом с ClockSaver.scr)';

  fh := ClientHeight div 60;
  if fh < 12 then fh := 12;

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name   := 'default';
  Canvas.Font.Style  := [];
  Canvas.Font.Height := -fh;
  Canvas.Font.Color  := RGBToColor(200, 130, 50);

  tw := Canvas.TextWidth(msg);
  th := Canvas.TextHeight(msg);
  Inc(AY, 6);
  if AX + tw > ClientWidth then AX := ClientWidth - tw - 4;
  if AX < 4 then AX := 4;
  if AY + th > ClientHeight then AY := ClientHeight - th - 4;
  Canvas.TextOut(AX, AY, msg);
end;

procedure TForm1.FormPaint(Sender: TObject);
var
  s, ampm, dateStr, key: string;
  clockPx, ampmPx, datePx, gapH, gapV: Integer;
  clockW, clockH, ampmW, ampmH, dateW, dateH: Integer;
  leftPad, rightPad, clockInkW, clockBlockW, compW, compH: Integer;
  clockInkX0, ampmX0, ampmY0, dateX0, dateY0: Integer;
  dx, dy, sx, sy, sw, sh: Integer;
  attempt: Integer;
  k: Double;
  baseC: TColor;
  use12: Boolean;
  showDate: Boolean;
  tNow: Int64;
  fh: Integer;
  abc: TABCWidths;
  bf: TMyBlendFunc;
  hh, mm, ss, ms: Word;
  blinkPhase: Integer;

  procedure Measure;
  begin
    SetupClockFont(Canvas, -clockPx);
    Canvas.Brush.Style := bsClear;
    clockW := Canvas.TextWidth(s);
    clockH := Canvas.TextHeight(s);

    leftPad := 0;
    rightPad := 0;
    if Length(s) > 0 then
    begin
      if GetCharABCWidthsW(Canvas.Handle, Ord(s[1]), Ord(s[1]), abc) then
      begin
        leftPad := abc.abcA;
        if leftPad < 0 then leftPad := 0;
      end;
      if GetCharABCWidthsW(Canvas.Handle, Ord(s[Length(s)]), Ord(s[Length(s)]), abc) then
      begin
        rightPad := abc.abcC;
        if rightPad < 0 then rightPad := 0;
      end;
    end;
    clockInkW := clockW - leftPad - rightPad;
    if clockInkW < 0 then clockInkW := 0;

    ampmPx := clockPx * AMPM_SIZE_PERCENT div 100;
    datePx := clockPx * DATE_SIZE_PERCENT div 100;
    if ampmPx < 8 then ampmPx := 8;
    if datePx < 8 then datePx := 8;

    if use12 then
    begin
      SetupAuxFont(Canvas, -ampmPx);
      ampmW := Canvas.TextWidth(ampm);
      ampmH := Canvas.TextHeight(ampm);
    end
    else
    begin
      ampmW := 0;
      ampmH := 0;
    end;

    if showDate then
    begin
      SetupAuxFont(Canvas, -datePx);
      dateW := Canvas.TextWidth(dateStr);
      dateH := Canvas.TextHeight(dateStr);
    end
    else
    begin
      dateW := 0;
      dateH := 0;
    end;

    gapH := clockPx div 10;
    if gapH < 4 then gapH := 4;
    gapV := clockPx div 8;
    if gapV < 4 then gapV := 4;

    clockBlockW := clockInkW;
    if use12 then clockBlockW := clockInkW + gapH + ampmW;

    compW := clockBlockW;
    if dateW > compW then compW := dateW;
    compH := clockH;
    if showDate then compH := clockH + gapV + dateH;
  end;

  procedure RenderSprite;
  var
    bmi: TMyBmi;
    bits: Pointer;
    prow: PRGBQuad;
    total, n, rr, gg, bb, mm: Integer;
    hr, hg, hb: Integer;
  begin
    if FSprite = nil then
    begin
      FSprite := Graphics.TBitmap.Create;
      FSprite.PixelFormat := pf32bit;
    end;
    FSprite.SetSize(compW + 2 * SPRITE_PAD, compH + 2 * SPRITE_PAD);

    FSprite.Canvas.Brush.Style := bsSolid;
    FSprite.Canvas.Brush.Color := clBlack;
    FSprite.Canvas.FillRect(0, 0, FSprite.Width, FSprite.Height);

    SetupClockFont(FSprite.Canvas, -clockPx);
    DrawLedText(FSprite.Canvas, SPRITE_PAD + clockInkX0 - leftPad, SPRITE_PAD, s);

    if use12 then
    begin
      SetupAuxFont(FSprite.Canvas, -ampmPx);
      DrawLedPart(FSprite.Canvas, SPRITE_PAD + ampmX0, SPRITE_PAD + ampmY0, ampm, baseC, 0);
    end;

    if showDate then
    begin
      SetupAuxFont(FSprite.Canvas, -datePx);
      DrawLedPart(FSprite.Canvas, SPRITE_PAD + dateX0, SPRITE_PAD + dateY0, dateStr, baseC, 0);
    end;

    // забираем пиксели из битмапа в собственный DIB и проставляем альфу там
    if FSpriteDC <> 0 then DeleteDC(FSpriteDC);
    if FSpriteSec <> 0 then DeleteObject(FSpriteSec);
    FSpriteDC := 0;
    FSpriteSec := 0;

    FillChar(bmi, SizeOf(bmi), 0);
    bmi.bmiHeader.biSize := SizeOf(TMyBmiHeader);
    bmi.bmiHeader.biWidth := FSprite.Width;
    bmi.bmiHeader.biHeight := -FSprite.Height;   // строки сверху вниз
    bmi.bmiHeader.biPlanes := 1;
    bmi.bmiHeader.biBitCount := 32;
    bmi.bmiHeader.biCompression := 0;

    FSpriteSec := CreateDIBSection(FSprite.Canvas.Handle, bmi, 0, bits, 0, 0);
    if FSpriteSec = 0 then Exit;

    if GetDIBits(FSprite.Canvas.Handle, FSprite.Handle, 0, FSprite.Height,
         bits, bmi, 0) = 0 then
    begin
      DeleteObject(FSpriteSec);
      FSpriteSec := 0;
      Exit;
    end;

    prow := PRGBQuad(bits);
    total := FSprite.Width * FSprite.Height;
    n := 0;
    while n < total do
    begin
      bb := prow^.rgbBlue;
      gg := prow^.rgbGreen;
      rr := prow^.rgbRed;
      mm := rr;
      if gg > mm then mm := gg;
      if bb > mm then mm := bb;
      if mm = 0 then
      begin
        prow^.rgbRed := 0;
        prow^.rgbGreen := 0;
        prow^.rgbBlue := 0;
        prow^.rgbReserved := 0;
      end
      else
      begin
        hr := rr * 255 div mm;
        hg := gg * 255 div mm;
        hb := bb * 255 div mm;
        // затемнение запекаем в RGB: оно не может потеряться при смешивании
        if Cfg.DimBrightness then
        begin
          hr := Round(hr * DIM_FACTOR);
          hg := Round(hg * DIM_FACTOR);
          hb := Round(hb * DIM_FACTOR);
        end;
        prow^.rgbRed := hr;
        prow^.rgbGreen := hg;
        prow^.rgbBlue := hb;
        prow^.rgbReserved := mm;   // альфа = форма свечения, без затемнения
      end;
      Inc(prow);
      Inc(n);
    end;

    FSpriteDC := CreateCompatibleDC(0);
    SelectObject(FSpriteDC, FSpriteSec);
    FSpriteW := FSprite.Width;
    FSpriteH := FSprite.Height;
    FSpriteKey := key;
  end;

begin
  if Cfg.UseAtmosphericBackground then
  begin
    if FBackground <> nil then
      FBackground.Draw(Canvas, 0, 0)
    else
    begin
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := clBlack;
      Canvas.FillRect(0, 0, ClientWidth, ClientHeight);
    end;
  end
  else
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := clBlack;
    Canvas.FillRect(0, 0, ClientWidth, ClientHeight);
  end;

  use12    := Cfg.Use12Hour;
  showDate := Cfg.DateFormat <> 0;
  s        := BuildTimeStr(ampm);
  if showDate then
        dateStr := DateText(Cfg.DateFormat, Cfg.UseRussian)
  else
    dateStr := '';
  baseC    := ClockColorRGB(Cfg.ClockColor);

  clockPx := ClientHeight div DIVIDER;
  if clockPx < 10 then clockPx := 10;

  for attempt := 1 to 2 do
  begin
    Measure;
    if attempt = 1 then
    begin
      k := 1.0;
      if (clockBlockW > ClientWidth) and (clockBlockW > 0) then
        k := ClientWidth / clockBlockW;
      if (compH > ClientHeight) and (compH > 0) then
        if ClientHeight / compH < k then k := ClientHeight / compH;
      if k < 1 then
      begin
        clockPx := Round(clockPx * k);
        if clockPx < 10 then clockPx := 10;
      end
      else
        Break;
    end;
  end;

  clockInkX0 := (compW - clockBlockW) div 2;
  dateX0     := (compW - dateW) div 2;
  ampmX0     := clockInkX0 + clockInkW + gapH;
  ampmY0     := (clockH - ampmH) div 2;
  dateY0     := clockH + gapV;

  FMaxX := ClientWidth - compW;
  FMaxY := ClientHeight - compH;
  if FMaxX < 0 then FMaxX := 0;
  if FMaxY < 0 then FMaxY := 0;

  if (not FInited) or Cfg.CenterLocked then
  begin
    FX := FMaxX / 2;
    FY := FMaxY / 2;
    FInited := True;
  end;

  if FX < 0 then FX := 0;
  if FY < 0 then FY := 0;
  if FX > FMaxX then FX := FMaxX;
  if FY > FMaxY then FY := FMaxY;

  DecodeTime(Now, hh, mm, ss, ms);
  if Cfg.BlinkColons then
    blinkPhase := ss mod 2
  else
    blinkPhase := 0;

  key := s + '|' + dateStr + '|' + ampm + '|' + IntToStr(clockPx) + '|' +
         IntToStr(Cfg.ClockColor) + '|' + BoolToStr(Cfg.DimBrightness, True) + '|' +
         BoolToStr(use12, True) + '|' + BoolToStr(showDate, True) + '|' +
         IntToStr(blinkPhase);

  if (FSpriteDC = 0) or (FSpriteKey <> key) then
    RenderSprite;

  dx := Round(FX) - SPRITE_PAD;
  dy := Round(FY) - SPRITE_PAD;
  sx := 0;
  sy := 0;
  sw := FSpriteW;
  sh := FSpriteH;
  if dx < 0 then
  begin
    sx := -dx;
    sw := sw - sx;
    dx := 0;
  end;
  if dy < 0 then
  begin
    sy := -dy;
    sh := sh - sy;
    dy := 0;
  end;
  if dx + sw > ClientWidth then sw := ClientWidth - dx;
  if dy + sh > ClientHeight then sh := ClientHeight - dy;

  if FSpriteDC <> 0 then
  begin
    if (sw > 0) and (sh > 0) then
    begin
      bf.BlendOp := 0;
      bf.BlendFlags := 0;
      bf.SourceConstantAlpha := 255;
      bf.AlphaFormat := 1;
      ExtAlphaBlend(Canvas.Handle, dx, dy, sw, sh, FSpriteDC, sx, sy, sw, sh, bf);
    end;
  end;

  if (not GFontLoaded) or (not GFont2Loaded) then
    DrawFontHint(Round(FX), Round(FY) + compH);

  if Cfg.ShowFps and not FPreview then
  begin
    Inc(FFpsFrames);
    tNow := GetTickCount64;
    if FFpsLast = 0 then FFpsLast := tNow;
    if tNow - FFpsLast >= 500 then
    begin
      FFpsText := Format('%d FPS', [Round(FFpsFrames * 1000 / (tNow - FFpsLast))]);
      FFpsFrames := 0;
      FFpsLast := tNow;
    end;
    if FFpsText <> '' then
    begin
      fh := ClientHeight div 60;
      if fh < 12 then fh := 12;
      if fh > 26 then fh := 26;
      SetupAuxFont(Canvas, -fh);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := ScaleColor(baseC, 0.6);
      Canvas.TextOut(16, 10, FFpsText);
    end;
  end
  else
  begin
    FFpsFrames := 0;
    FFpsLast := 0;
    FFpsText := '';
  end;
end;

procedure TForm1.Quit;
begin
  if not FPreview then Close;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  Key := 0;
  Quit;
end;

procedure TForm1.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Quit;
end;

procedure TForm1.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FPreview then Exit;
  if (Abs(Mouse.CursorPos.X - FStartX) > MOUSE_SENS) or
     (Abs(Mouse.CursorPos.Y - FStartY) > MOUSE_SENS) then
    Quit;
end;

end.
