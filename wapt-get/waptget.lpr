program waptget;
{ -----------------------------------------------------------------------
#    This file is part of WAPT
#    Copyright (C) 2013  Tranquil IT Systems http://www.tranquil.it
#    WAPT aims to help Windows systems administrators to deploy
#    setup and update applications on users PC.
#
#    WAPT is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    WAPT is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with WAPT.  If not, see <http://www.gnu.org/licenses/>.
#
# -----------------------------------------------------------------------
}

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  { you can add units after this }
  Interfaces, Windows, PythonEngine, VarPyth, superobject, soutils, tislogging, uWaptRes,
  waptcommon, waptwinutils, tiscommon, tisstrings, LazFileUtils,
  IdAuthentication, IdExceptionCore, Variants, IniFiles,uwaptcrypto,uWaptPythonUtils,
  tisinifiles;

type
  { PWaptGet }

  PWaptGet = class(TCustomApplication)
  private
    localuser,localpassword:AnsiString;
    FRepoURL: String;
    function GetIsEnterpriseEdition: Boolean;
    function GetPythonEngine: TPythonEngine;
    function GetRepoURL: String;
    function Getwaptcrypto: Variant;
    function Getwaptpackage: Variant;
    function Getwaptdevutils: Variant;
    procedure HTTPLogin(Sender: TObject; Authentication: TIdAuthentication; var Handled: Boolean);
    procedure SetRepoURL(AValue: String);
  protected
    FPythonEngine: TPythonEngine;
    Fwaptcrypto,
    fwaptpackage,
    Fwaptdevutils: Variant;
    procedure DoRun; override;
  public
    Action : String;
    RegWaptBaseDir:String;
    check_thread:TThread;
    lock:TRTLCriticalSection;
    tasks:ISuperObject;
    lastMessageTime : TDateTime;

    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    property RepoURL:String read GetRepoURL write SetRepoURL;
    procedure pollerEvent(Events:ISuperObject);
    function remainingtasks:ISuperObject;

    function BuildWaptUpgrade(SetupFilename: String): String;
    function CreateWaptAgent(TargetDir: String; Edition: String='waptagent'
      ): String;

    function CreateKeycert(commonname: String; basedir: String='';keypassword: String='';CodeSigning:Boolean=True): String;

    function GetCAKeyPassword(crtname:String): String;
    function GetPrivateKeyPassword(crtname:String=''): String;
    function GetWaptServerPassword: String;
    function GetWaptServerUser: String;

    property PythonEngine:TPythonEngine read GetPythonEngine;
    property waptdevutils:Variant read Getwaptdevutils;
    property waptcrypto:Variant read Getwaptcrypto;
    property waptpackage:Variant read Getwaptpackage;

    property IsEnterpriseEdition:Boolean read GetIsEnterpriseEdition;
  end;

  { TPollThread }

  TPollThread = Class(TThread)
    procedure HandleMessage;

  public
    PollTimeout:Integer;

    App:PWaptGet;
    Events: ISuperObject;
    LastReadEventId: Integer;

    constructor Create(anapp:PWaptGet);
    procedure Execute; override;
  end;

  { TPollThread }

  procedure TPollThread.HandleMessage;
  begin
    if Assigned(app) then
      app.pollerEvent(Events);
  end;

  constructor TPollThread.Create(anapp:PWaptGet);
  begin
    inherited Create(True);
    app := anapp;
    PollTimeout:=1000;
    LastReadEventId := MaxInt;
  end;

  procedure TPollThread.Execute;
  begin
    while not Terminated do
    try
      try
        Events := WAPTLocalJsonGet(Format('events?last_read=%d',[LastReadEventId]),'','',-1,Nil,0);
        If (Events.AsArray <> Nil) and (Events.AsArray.Length>0) then
          LastReadEventId := Events.AsArray.O[Events.AsArray.Length-1].I['id'];
      except
        on e:EIdReadTimeout do
          Events := Nil;
      end;
      Synchronize(@HandleMessage);
    except
      on e:Exception do
      begin
        WriteLn('exception '+e.Message );
        if not Terminated then
          Sleep(PollTimeout);
      end;
    end;
  end;


{ PWaptGet }

var
  Application: PWaptGet;

  function GetPassword(const InputMask: Char = '*'): string;
  var
    OldMode: Cardinal;
    c: char;
  begin
    Result:='';
    GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), OldMode);
    SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), OldMode and not (ENABLE_LINE_INPUT or ENABLE_ECHO_INPUT));
    try
      while not Eof do
      begin
        Read(c);
        if c = #13 then // Carriage Return
          Break;
        if (c = #8) then  // Back Space
        begin
          if (Length(Result) > 0) then
          begin
            Delete(Result, Length(Result), 1);
            Write(#8);
          end;
        end
        else
        begin
          Result := Result + c;
          Write(InputMask);
        end;
      end;
    finally
      SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), OldMode);
    end;
  end;

procedure PWaptGet.HTTPLogin(Sender: TObject; Authentication: TIdAuthentication; var Handled: Boolean);
var
  newuser:AnsiString;
begin
  if (localuser<>'') and (localpassword<>'') then
  begin
    Authentication.Username:=localuser;
    Authentication.Password:=localpassword;
  end
  else
  begin
    Write('Waptservice User ('+localuser+') :');
    readln(newuser);
    if newuser<>'' then
      Authentication.Username:=newuser;
    if Authentication.Username='' then
      raise Exception.Create('Empty user');
    Write('Password: ');
    Authentication.Password := GetPassword;
    WriteLn;
    Handled := (Authentication.Password='');
    // cache for next use
    localuser := Authentication.Username;
    localpassword := Authentication.Password;
  end;
end;

function PWaptGet.GetWaptServerUser: String;
begin
  Result := GetCmdParams('WaptServerUser','');
  while Result='' do
  begin
    Write('Waptserver '+GetWaptServerURL+' Admin User ('+WaptServerUser+') :');
    readln(Result);
    if result = '' then
      Result := WaptServerUser;
    WaptServerUser := Result;
  end;
  WaptServerUser := Result;
end;

function PWaptGet.GetWaptServerPassword: String;
begin
  if WaptServerPassword='' then
    WaptServerPassword :=   GetCmdParams('WaptServerPassword','');
  while WaptServerPassword='' do
  begin
    Write('Waptserver Password: ');
    WaptServerPassword := GetPassword;
    WriteLn;
  end;
  Result := WaptServerPassword;
end;

function PWaptGet.GetPrivateKeyPassword(crtname:String=''): String;
begin
  if crtname ='' then
    crtname:=WaptPersonalCertificatePath;
  result := GetCmdParams('PrivateKeyPassword','');
  while Result='' do
  begin
    Write('Private key Password for '+crtname+' : ');
    Result := GetPassword;
    WriteLn;
  end;
end;


function PWaptGet.GetCAKeyPassword(crtname:String): String;
begin
  result := GetCmdParams('CAKeyPassword','');
  while Result='' do
  begin
    Write('CA key Password for '+crtname+' : ');
    Result := GetPassword;
    WriteLn;
  end;
end;


function PWaptGet.GetRepoURL: String;
begin
  if FRepoURL='' then
    FRepoURL:=GetMainWaptRepoURL;
  result := FRepoURL;
end;

function PWaptGet.Getwaptcrypto: Variant;
begin
  if not Assigned(PythonEngine) then
    Raise Exception.Create('No python engine available');
  if VarIsEmpty(Fwaptcrypto) or VarIsNull(Fwaptcrypto) then
    Fwaptcrypto:= VarPyth.Import('waptcrypto');
  Result := Fwaptcrypto;
end;


function PWaptGet.Getwaptpackage: Variant;
begin
  if not Assigned(PythonEngine) then
    Raise Exception.Create('No python engine available');
  if VarIsEmpty(Fwaptpackage) or VarIsNull(Fwaptpackage) then
    Fwaptpackage:= VarPyth.Import('waptpackage');
  Result := Fwaptpackage;
end;

function PWaptGet.GetIsEnterpriseEdition: Boolean;
begin
  {$ifdef ENTERPRISE}
  Result := True;
  {$else}
  Result := False;
  {$endif}
end;

function PWaptGet.GetPythonEngine: TPythonEngine;
begin
  if not Assigned(FPythonEngine) then
  begin
    // Running python stuff
    FPythonEngine := TPythonEngine.Create(Nil);

    RegWaptBaseDir:=WaptBaseDir();
    if not FileExists(AppendPathDelim(RegWaptBaseDir)+'python27.dll') then
      RegWaptBaseDir:=RegisteredAppInstallLocation('wapt_is1');

    if RegWaptBaseDir='' then
      RegWaptBaseDir:=RegisteredExePath('wapt-get.exe');

    with FPythonEngine do
    begin
      AutoLoad:=False;
      DllPath := RegWaptBaseDir;
      DllName := 'python27.dll';
      UseLastKnownVersion := False;
      LoadDll;
    end;
  end;
  result := FPythonEngine;
end;

procedure PWaptGet.SetRepoURL(AValue: String);
begin
  if FRepoURL=AValue then Exit;
  FRepoURL:=AValue;
end;

procedure PWaptGet.DoRun;
var
  MainModule : TStringList;
  WaptAgentTargetDir, WaptAgentFilename, logleveloption : String;
  Res,task:ISuperobject;
  package,sopackages:ISuperObject;

  procedure SetFlag( AFlag: PInt; AValue : Boolean );
  begin
    if AValue then
      AFlag^ := 1
    else
      AFlag^ := 0;
  end;

var
  i:integer;
  NextIsParamValue:Boolean;
begin
  Action:='';
  sopackages  := TSuperObject.Create(stArray);

  NextIsParamValue := False;

  for i:=1 to ParamCount do
  begin
    if (Pos('-',Params[i])<>1) and not NextIsParamValue then
    begin
      if (action='') then
        Action := lowercase(Params[i])
      else
        sopackages.AsArray.Add(Params[i]);
      NextIsParamValue := False;
    end
    else
      NextIsParamValue := StrIsOneOf(Params[i],['-c','-r','-l','-p','-s','-e','-k','-w','-U','-g','-t','-L'])
  end;

  // parse parameters
  if HasOption('?') or HasOption('h','help') then
  begin
    writeln(utf8decode(rsOptRepo));
    writeln(utf8decode(rsWaptgetHelp));
  end;

  if HasOption('c','config') then
    ReadWaptConfig(GetOptionValue('c','config'))
  else
    ReadWaptConfig();

  if HasOption('r','repo') then
    RepoURL := GetOptionValue('r','repo');

  if HasOption('l','loglevel') then
  begin
    logleveloption := UpperCase(GetOptionValue('l','loglevel'));
    if logleveloption = 'DEBUG' then
      currentLogLevel := DEBUG
    else if logleveloption = 'INFO' then
      currentLogLevel := INFO
    else if logleveloption = 'WARNING' then
      currentLogLevel := WARNING
    else if logleveloption = 'ERROR' then
      currentLogLevel := ERROR
    else if logleveloption = 'CRITICAL' then
      currentLogLevel := CRITICAL;
    Logger('Current loglevel : '+StrLogLevel[currentLogLevel],DEBUG);
  end;

  if HasOption('v','version') then
    writeln(format(rsWin32exeWrapper, [ApplicationName, GetApplicationVersion]));

  if (action = 'create-keycert') then
  begin
    ReadWaptConfig(AppIniFilename('waptconsole'));
    CreateKeycert(GetCmdParams('CommonName'),'','',GetCmdParams('CodeSigning','1')='1');
  end
  else
  if (action = 'build-waptagent') then
  begin
    ReadWaptConfig(AppIniFilename('waptconsole'));
    Writeln(rsBuildWaptAgent);
    WaptAgentTargetDir := WaptBaseDir+'\waptupgrade';
    WaptAgentFilename := CreateWaptagent(WaptAgentTargetDir);
    //else
    //  Writeln('Using already built waptagent in '+WAPTSetupPath);
    Writeln(rsBuildWaptUpgradePackage);
    GetWaptServerUser;
    GetWaptServerPassword;
    BuildWaptUpgrade(WaptAgentFilename);
    Writeln(rsUploadWaptAgent);
    Res := WAPTServerJsonMultipartFilePost(
      GetWaptServerURL, 'upload_waptsetup', [], 'file', WaptAgentFilename,
      WaptServerUser, WaptServerPassword, Nil,GetWaptServerCertificateFilename);
    if Res.S['status'] = 'OK' then
      Writeln('OK')
    else
      Writeln('ERROR: '+Res.S['message']);
    Terminate;
    Exit;
  end
  else
  if (action = 'waptupgrade') then
  begin
    Writeln(format(rsWaptGetUpgrade, [RepoURL]));
    UpdateApplication(RepoURL+'/waptagent.exe','waptagent.exe','/VERYSILENT','wapt-get.exe','');
    Terminate;
    Exit;
  end
  else
  if (action = 'dnsdebug') then
  begin
    WriteLn(format(rsDNSserver, [Join(',',GetDNSServers)]));
    WriteLn(format(rsDNSdomain, [GetDNSDomain]));
    Writeln(utf8decode(format(rsMainRepoURL, [RepoURL])));
    Writeln(format(rsSRVwapt, [DNSSRVQuery('_wapt._tcp.'+GetDNSDomain).AsJSon(True)]));
    Writeln(format(rsSRVwaptserver, [DNSSRVQuery('_waptserver._tcp.'+GetDNSDomain).AsJSon(True)]));
    Writeln(format(rsCNAME, [DNSCNAMEQuery('wapt.'+GetDNSDomain).AsJSon(True)]));
    Terminate;
    Exit;
  end
  else
  // use http service mode if --service or not --direct or not (--service and isadmin
  if  ((not IsAdminLoggedOn or HasOption('S','service')) and not HasOption('D','direct')) and
      StrIsOneOf(action,['update','upgrade','register','install','remove','forget',
                        'longtask','cancel','cancel-all','tasks',
                        'wuascan','wuadownload','wuainstall','audit']) and
      CheckOpenPort(waptservice_port,'127.0.0.1',waptservice_timeout) then
  begin
    writeln('About to speak to waptservice...');
    // launch task in waptservice, waits for its termination
    check_thread :=TPollThread.Create(Self);
    check_thread.Start;
    lastMessageTime := Now;
    tasks := TSuperObject.create(stArray);
    try
      try
        res := Nil;
        //test longtask
        if action='longtask' then
        begin
          Logger('Call longtask URL...',DEBUG);
          res := WAPTLocalJsonGet('longtask.json?notify_user=1','admin','',-1,@HTTPLogin);
          tasks.AsArray.Add(res);
          Logger('Task '+res.S['id']+' added to queue',DEBUG);
        end
        else
        if action='tasks' then
        begin
          res := WAPTLocalJsonGet('tasks.json');
          if res['running'].DataType<>stNull then
            writeln(utf8decode(format(rsRunningTask,[ res['running'].I['id'],res['running'].S['description'],res['running'].S['runstatus']])))
          else
            writeln(utf8decode(rsNoRunningTask));
          if res['pending'].AsArray.length>0 then
            writeln(utf8decode(rsPending));
            for task in res['pending'] do
              writeln(utf8decode('  '+task.S['id']+' '+task.S['description']));
        end
        else
        if action='cancel' then
        begin
          res := WAPTLocalJsonGet('cancel_running_task.json');
          if res.DataType<>stNull then
            writeln(utf8decode(format(rsCanceledTask, [res.S['description']])))
          else
            writeln(rsNoRunningTask);
        end
        else
        if (action='cancel-all') or (action='cancelall') then
        begin
          res := WAPTLocalJsonGet('cancel_all_tasks.json');
          if res.DataType<>stNull then
          begin
            for task in res do
              writeln(utf8decode(format(rsCanceledTask, [task.S['description']])))
          end
          else
            writeln(utf8decode(rsNoRunningTask));
        end
        else
        if action='update' then
        begin
          Logger('Call update URL...',DEBUG);
          if HasOption('f','force') then
            res := WAPTLocalJsonGet('update.json?notify_user=0&force=1')
          else
            res := WAPTLocalJsonGet('update.json?notify_user=0');
          tasks.AsArray.Add(res);
          Logger('Task '+res.S['id']+' added to queue',DEBUG);
        end
        else
        if action='audit' then
        begin
          Logger('Call audit URL...',DEBUG);
          if HasOption('f','force') then
            res := WAPTLocalJsonGet('audit.json?notify_user=0&force=1')
          else
            res := WAPTLocalJsonGet('audit.json?notify_user=0');
          WriteLn(utf8decode(res.S['message']));
          for task in res['content'] do
          begin
            tasks.AsArray.Add(task);
            Logger('Task '+task.S['id']+' added to queue',DEBUG);
          end;
        end
        else
        if action='register' then
        begin
          Logger('Call register URL...',DEBUG);
          res := WAPTLocalJsonGet('register.json?notify_user=0&notify_server=1','admin','',-1,@HTTPLogin);
          tasks.AsArray.Add(res);
          Logger('Task '+res.S['id']+' added to queue',DEBUG);
        end
        else
        if (action='install') or (action='remove') or (action='forget') then
        begin
          for package in sopackages do
          begin
            Logger('Call '+action+'?package='+package.AsString,DEBUG);
            if HasOption('f','force') then
              res := WAPTLocalJsonGet(Action+'.json?package='+package.AsString+'&force=1&notify_user=0','admin','',-1,@HTTPLogin)
            else
              res := WAPTLocalJsonGet(Action+'.json?package='+package.AsString+'&notify_user=0','admin','',-1,@HTTPLogin);
            if (action='install') or (action='forget')  then
            begin
              // single action
              if (res.AsObject=Nil) or not res.AsObject.Exists('id') then
                WriteLn(utf8decode(format(rsErrorWithMessage, [res.AsString])))
              else
                tasks.AsArray.Add(res);
            end
            else
            if (action='remove') then
            begin
              // list of actions..
              if (res.AsArray=Nil) then
                WriteLn(utf8decode(format(rsErrorWithMessage, [res.AsString])))
              else
              for task in res do
              begin
                tasks.AsArray.Add(task);
                Logger('Task '+task.S['id']+' added to queue',DEBUG);
              end;
            end;
          end;
        end
        else if action='upgrade' then
        begin
          Logger('Call upgrade URL...',DEBUG);
          res := WAPTLocalJsonGet('upgrade.json?notify_user=0');
          if res.S['result']<>'OK' then
            WriteLn(utf8decode(format(rsErrorLaunchingUpgrade, [res.S['message']])))
          else
            for task in res['content'] do
            begin
              tasks.AsArray.Add(task);
              Logger('Task '+task.S['id']+' added to queue',DEBUG);
            end;
        end
        else
        if action='wuascan' then
        begin
          res := WAPTLocalJsonGet('waptwua_scan?notify_user=1');
          tasks.AsArray.Add(res);
          Logger('Task '+res.S['id']+' added to queue',DEBUG);
        end
        else
        if action='wuadownload' then
        begin
          res := WAPTLocalJsonGet('waptwua_download?notify_user=1');
          tasks.AsArray.Add(res);
          Logger('Task '+res.S['id']+' added to queue',DEBUG);
        end
        else
        if action='wuainstall' then
        begin
          res := WAPTLocalJsonGet('waptwua_install?notify_user=1');
          tasks.AsArray.Add(res);
          Logger('Task '+res.S['id']+' added to queue',DEBUG);
        end;

        while (remainingtasks.AsArray.Length>0)  and  not check_thread.Finished do
        try
          //if no message from service since more that 1 min, check if remaining tasks in queue...
          if (now-lastMessageTime>1*1/24/60) then
            raise Exception.create('Timeout waiting for events')
          else
          begin
            While CheckSynchronize(100) do;
            sleep(1000)
          end;
        except
          on E:Exception do
            begin
              writeln(Format(rsCanceledTask,[E.Message]));
              for task in tasks do
                WAPTLocalJsonGet('cancel_task.json?id='+task.S['id']);
            end;
        end;

        while CheckSynchronize(1000) do;

      except
        localpassword := '';
        ExitCode:=3;
        raise;
      end;
    finally
      for task in tasks do
        WAPTLocalJsonGet('cancel_task.json?id='+task.S['id']);
    end;
  end
  else
  begin
    // Load main python application
    try
      MainModule:=TStringList.Create;
      MainModule.LoadFromFile(ExtractFilePath(ParamStr(0))+'wapt-get.py');
      PythonEngine.ExecStrings(MainModule);
    finally
      MainModule.Free;
    end;
  end;
  // stop program loop
  Terminate;
end;

constructor PWaptGet.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
  InitializeCriticalSection(lock);

end;

destructor PWaptGet.Destroy;
begin
  Fwaptdevutils := Nil;
  if Assigned(check_thread) then
    check_thread.Free;
  if Assigned(FPythonEngine) then
    FPythonEngine.Free;
  DeleteCriticalSection(lock);
  inherited Destroy;
end;

procedure PWaptGet.WriteHelp;
begin
  { add your help code here }
  writeln(utf8decode(format(rsUsage, [ExeName])));
  writeln(rsInstallOn);
end;

procedure PWaptGet.pollerEvent(Events:ISuperObject);
var
  Step,EventType:String;
  taskresult : ISuperObject;
  Event,EventData:ISuperObject;

  //check if task with id id is in tasks list
  function isInTasksList(id:integer):boolean;
  var
    t:ISuperObject;
  begin
    //writeln('check '+IntToStr(id)+' in '+tasks.AsJSon());
    result := False;
    for t in tasks do
      if t.I['id'] = id then
      begin
        result := True;
        break;
      end;
  end;

  //remove task with id id from tasks list
  procedure removeTask(id:integer);
  var
    i:integer;
  begin
    for i:=0 to tasks.AsArray.Length-1 do
      if tasks.AsArray[i].I['id'] = id then
      begin
        tasks.AsArray.Delete(i);
        break;
      end;
  end;

begin
  EnterCriticalSection(lock);
  try
    lastMessageTime := Now;
    If Events <> Nil then
    begin
      //if Event.AsArray.Length>0 then
      begin
        for Event in Events do
        try
          EventType := Event.S['event_type'];
          EventData := Event['data'];
          if EventType.StartsWith('TASK_') then
          begin
            Step := EventType.Substring(5);
            taskresult := EventData;
            //Writeln(EventType,' ',taskresult.S['id'],' ',taskresult.S['summary']);
            if isInTasksList(taskresult.I['id']) then
            begin
              //writeln(taskresult.AsString);
              if (Step = 'START') then
                writeln(#13+UTF8Encode(taskresult.S['description']));
              if (Step = 'PROGRESS') then
                write(#13+utf8Encode(format(rsCompletionProgress,[taskresult.S['runstatus'], taskresult.D['progress']])+#13));
              if (Step = 'STATUS') then
                write(#13+utf8Encode(format(rsCompletionProgress,[taskresult.S['runstatus'], taskresult.D['progress']])+#13));
              //catch finish of task
              if (Step = 'FINISH') or (Step = 'ERROR') or (Step = 'CANCEL') then
              begin
                WriteLn(UTF8Encode(taskresult.S['summary']));
                if (Step = 'ERROR') or (Step = 'CANCEL') then
                  ExitCode:=3;
                removeTask(taskresult.I['id']);
              end;
            end;
          end
          else if (EventType = 'PRINT') then
            Writeln(#13+UTF8Encode(EventData.AsString));
        except
          on E:Exception do WriteLn(#13+Format('Error listening to events: %s',[e.Message]));
        end;
      end
      //else
      //  Write('.');
    end
    else
      Write('.');
  finally
    LeaveCriticalSection(lock);
  end;
end;

function PWaptGet.remainingtasks: ISuperObject;
var
  task,pending,res:ISuperObject;
begin
  res := WAPTLocalJsonGet('tasks.json');
  pending := res['pending'];
  if res['running'] <> Nil then
    pending.AsArray.Add(res['running']);

  Result := TSuperObject.Create(stArray);
  if pending.AsArray.Length > 0 then
    for task in Self.tasks do
      if SOArrayFindFirst(task,pending,['id']) <> Nil then
        Result.AsArray.Add(task);
end;

function PWaptGet.CreateWaptAgent(TargetDir:String;Edition:String='waptagent'): String;
var
  Ini:TInifile;
begin
  try
    ini := TIniFile.Create(AppIniFilename('waptconsole'));
    Result := CreateWaptSetup(UTF8Encode(AuthorizedCertsDir),
      ini.ReadString('global', 'repo_url', ''),
      ini.ReadString('global', 'wapt_server', ''),
      TargetDir,
      'Wapt', Nil, Edition,
      ini.ReadString('global', 'verify_cert', '0'),
      ini.ReadBool('global', 'use_kerberos', False ),
      ini.ReadBool('global', 'check_certificates_validity',True ),
      IsEnterpriseEdition,
      True,
      True,
      ini.ReadBool('global', 'use_fqdn_as_uuid',False),
      ''
      );

  finally
    ini.Free;
  end;
end;

function PWaptGet.CreateKeycert(commonname: String; basedir:String=''; keypassword: String='';CodeSigning:Boolean=True): String;
var
    keyfilename,
    crtbasename,
    country,
    locality,
    organization,
    orgunit,
    email,
    CACertFilename,
    CAKeyFilename,
    CAKeyPassword:String;
    PrintPwd: Boolean;

begin
  if basedir = '' then
    basedir:=GetCmdParams('BaseDir',ExtractFilePath(WaptPersonalCertificatePath));
  if basedir = '' then
    basedir:=AppendPathDelim(GetPersonalFolder)+'private';
  WriteLn('Key and certificate will be created in '+basedir);

  if not DirectoryExistsUTF8(basedir) then
    mkdir(basedir);

  keyfilename := AppendPathDelim(basedir)+commonname+'.pem';
  if commonname = '' then
  begin
    Write('Common name of certificate to create:');
    readln(commonname);
  end;
  if commonname='' then
    Raise Exception.Create('No common name for certificate');

  if (keypassword='') and not FileExistsUTF8(keyfilename) then
  begin
    printPwd := True;
    keypassword := RandomPassword(12);
  end
  else
    printPwd := False;

  if keypassword='' then
    keypassword:=GetPrivateKeyPassword(keyfilename);

  crtbasename := commonname;

  country := GetCmdParams('Country',Language);
  locality := GetCmdParams('Locality','');
  organization := GetCmdParams('Organization','');
  orgunit := GetCmdParams('OrgUnit','');
  email := GetCmdParams('Email','');

  CAKeyFilename := GetCmdParams('CAKeyFilename',WaptCAKeyFilename);
  CACertFilename := GetCmdParams('CACertFilename',WaptCACertFilename);
  if CAKeyFilename<>'' then
  begin
    if (CACertFilename<>'') and FileExistsUTF8(CACertFilename) then
      Writeln('Certificate will be issued and signed by '+CACertFilename)
    else
      Raise Exception.Create('No CA Certificate to issue the new certificate');

    CAKeyPassword := GetCmdParams('CAKeyPassword',GetCAKeyPassword(CAKeyFilename));
  end;

  result := CreateSignedCert(waptcrypto,
        keyfilename,
        crtbasename,
        basedir,
        country,
        locality,
        organization,
        orgunit,
        commonname,
        email,
        keypassword,
        codesigning,
        False,
        CACertFilename,
        CAKeyFilename,
        CAKeyPassword);

  WriteLn(Result);
  if PrintPwd then
    WriteLn(keypassword);
end;

function PWaptGet.BuildWaptUpgrade(SetupFilename: String): String;
var
  BuildDir: String;
  BuildResult: Variant;
  KeyPassword:String;
begin
  // create waptupgrade package (after waptagent as we need the updated waptagent.sha1 file)
  BuildResult := Nil;
  BuildDir := GetTempDir(False);

  if RightStr(buildDir,1) = '\' then
    buildDir := copy(buildDir,1,length(buildDir)-1);
  KeyPassword := GetPrivateKeyPassword;

  //BuildResult is a PackageEntry instance
  BuildResult := waptdevutils.build_waptupgrade_package(
      waptconfigfile := AppIniFilename('waptconsole'),
      wapt_server_user := WaptServerUser,
      wapt_server_passwd := WaptServerPassword,
      key_password := KeyPassword,
      sign_digests := 'sha256'
      );

  if not VarPyth.VarIsNone(BuildResult) and FileExistsUTF8(VarPythonAsString(BuildResult.get('localpath'))) then
  begin
    Result := BuildResult.get('filename');
    DeleteFileUTF8(VarPythonAsString(BuildResult.get('localpath')));
  end
  else
    Result := '';
end;


function PWaptGet.Getwaptdevutils: Variant;
begin
  if not Assigned(PythonEngine) then
    Raise Exception.Create('No python engine available');
  if VarIsEmpty(Fwaptdevutils) or VarIsNull(Fwaptdevutils) then
    Fwaptdevutils:= VarPyth.Import('waptdevutils');
  Result := Fwaptdevutils;
end;

{$R *.res}

begin
  Application:=PWaptGet.Create(nil);
  Application.Title:='wapt-get';
  Application.Run;
  Application.Free;
end.

