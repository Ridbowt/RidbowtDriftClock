unit background;

{$mode objfpc}{$H+}

interface

uses
  Graphics, Controls, Math, LCLType;

type
  TBackground = class
  private
    FBitmap: TBitmap;
    FWidth, FHeight: Integer;
    procedure Generate(AWidth, AHeight: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Resize(AWidth, AHeight: Integer);
    procedure Draw(Canvas: TCanvas; X, Y: Integer);
  end;

implementation

type
  TRGBQuad = packed record
    rgbBlue: Byte;
    rgbGreen: Byte;
    rgbRed: Byte;
    rgbReserved: Byte;
  end;
  PRGBQuad = ^TRGBQuad;

constructor TBackground.Create;
begin
  inherited Create;
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;
  FWidth := 0;
  FHeight := 0;
end;

destructor TBackground.Destroy;
begin
  FBitmap.Free;
  inherited Destroy;
end;

procedure TBackground.Generate(AWidth, AHeight: Integer);
var
  x, y, cx, cy: Integer;
  maxR, dist, a: Double;
  r, g, b: Double;
  baseR, baseG, baseB: Integer;
  amberR, amberG, amberB: Integer;
  ScanLine: PRGBQuad;
begin
  if (AWidth <= 0) or (AHeight <= 0) then Exit;

  FBitmap.SetSize(AWidth, AHeight);

  // Базовый тёмно-графитовый
  baseR := 30;
  baseG := 30;
  baseB := 30;

  // Янтарный
  amberR := 255;
  amberG := 140;
  amberB := 0;

  cx := AWidth div 2;
  cy := AHeight div 2;
  maxR := 0.8 * Max(AWidth, AHeight);

  FBitmap.BeginUpdate;
  try
    for y := 0 to AHeight - 1 do
    begin
      ScanLine := FBitmap.ScanLine[y];

      for x := 0 to AWidth - 1 do
      begin
        // Расстояние от центра
        dist := Sqrt(Sqr(x - cx) + Sqr(y - cy));

        // Базовый цвет
        r := baseR;
        g := baseG;
        b := baseB;

        // Янтарное свечение (радиальный градиент)
        if dist < maxR * 0.5 then
        begin
          a := 1 - (dist / (maxR * 0.5));
          a := a * a * a;  // кубическое затухание
          r := r + (amberR - r) * a * 0.25;
          g := g + (amberG - g) * a * 0.25;
          b := b + (amberB - b) * a * 0.25;
        end;

        // Виньетка (радиальный градиент затемнения)
        if dist > maxR * 0.4 then
        begin
          a := (dist - maxR * 0.4) / (maxR * 0.6);
          if a > 1 then a := 1;
          a := a * a;  // квадратичное усиление
          r := r * (1 - a * 0.9);
          g := g * (1 - a * 0.9);
          b := b * (1 - a * 0.9);
        end;

        // Записать пиксель напрямую в память (BGR формат)
        ScanLine^.rgbRed := Round(r);
        ScanLine^.rgbGreen := Round(g);
        ScanLine^.rgbBlue := Round(b);
        ScanLine^.rgbReserved := 0;

        Inc(ScanLine);
      end;
    end;
  finally
    FBitmap.EndUpdate;
  end;

  FWidth := AWidth;
  FHeight := AHeight;
end;

procedure TBackground.Resize(AWidth, AHeight: Integer);
begin
  if (AWidth <> FWidth) or (AHeight <> FHeight) then
    Generate(AWidth, AHeight);
end;

procedure TBackground.Draw(Canvas: TCanvas; X, Y: Integer);
begin
  Canvas.Draw(X, Y, FBitmap);
end;

end.
