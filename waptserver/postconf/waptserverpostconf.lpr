program waptserverpostconf;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Translations, LCLProc,

  Interfaces, // this includes the LCL widgetset
  Forms, uVisServerPostconf, uwaptserverres,
  waptcommon, uvisloading, UScaleDPI,
  { you can add units after this }
  DefaultTranslator, indylaz, FrameViewer09, uvalidation;

{$R *.res}
{$R languages.rc}

begin
  // we use wapt-get.ini global config
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TVisWAPTServerPostConf, VisWAPTServerPostConf);
  Application.Run;
end.

