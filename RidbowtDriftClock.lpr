program RidbowtDriftClock;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  Unit1;

{$R *.res}
{$R version.res}
{$R fonts.res}

{ Переход на видимый пользователю рабочий стол ДО создания любых окон. }
function OpenInputDesktop(dwFlags: LongWord; fInherit: LongBool;
  dwDesiredAccess: LongWord): THandle; stdcall;
  external 'user32.dll' name 'OpenInputDesktop';
function SetThreadDesktop(hDesk: THandle): LongBool; stdcall;
  external 'user32.dll' name 'SetThreadDesktop';

var
  hInputDesktop: THandle;
begin
  hInputDesktop := OpenInputDesktop(0, False, $01FF);
  if hInputDesktop <> 0 then
    SetThreadDesktop(hInputDesktop);

  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.