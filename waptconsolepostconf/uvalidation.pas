unit uvalidation;

{$mode objfpc}{$H+}

interface

uses

  Controls,
  uvisconsolepostconf,
  Classes, SysUtils;



function wizard_validate_package_prefix( w : TVisWAPTConsolePostConf; c: TControl; const prefix: String): boolean;
function wizard_validate_key_name( w : TVisWAPTConsolePostConf; c : TControl; const key_name : String ) :boolean;
function wizard_validate_str_password_are_not_empty_and_equals( w: TVisWAPTConsolePostConf; c: TControl; const s1: String; const s2: String ): Boolean;
function wizard_validate_key_password( w : TVisWAPTConsolePostConf; c : TControl; const key_filename : String; const key_password : String ) : boolean;
function wizard_validate_no_innosetup_process_running(w: TVisWAPTConsolePostConf; c : TControl ): Boolean;
function wizard_validate_waptserver_login(w: TVisWAPTConsolePostConf; c : TControl; const server_url: String; const login: String; const password: String ): boolean;
function wizard_validate_waptserver_waptagent_is_not_present( w : TVisWAPTConsolePostConf; c : TControl; const server_url: String; var rc : integer ): Boolean;

implementation

uses
  superobject,
  uutil,
  udefault,
  waptconsolepostconfres;





function wizard_validate_package_prefix(w: TVisWAPTConsolePostConf; c: TControl; const prefix: String): boolean;
begin

  if str_is_empty_when_trimmed(prefix) then
  begin
    w.show_validation_error( c, rs_package_prefix_cannot_be_empty );
    exit(false);
  end;

  if not str_is_alphanum(prefix) then
  begin
    w.show_validation_error( c, rs_package_prefix_must_be_alphanum );
    exit( false );
  end;

  exit(true);
end;

function wizard_validate_key_name(w: TVisWAPTConsolePostConf; c: TControl; const key_name: String): boolean;
begin

  if str_is_empty_when_trimmed(key_name) then
  begin
    w.show_validation_error( c, rs_key_name_cannot_be_empty  );
    exit(false);
  end;

  exit( true );
end;

function wizard_validate_str_password_are_not_empty_and_equals(w: TVisWAPTConsolePostConf; c: TControl; const s1: String; const s2: String ): Boolean;
begin

  if s1 <> s2 then
  begin
    w.show_validation_error( c, rs_supplied_passwords_differs );
    exit(false);
  end;

  if Length(Trim(s1)) < DEFAULT_MINIMUN_PASSWORD_LENGTH then
  begin
    w.show_validation_error( c, rs_supplied_passwords_must_be_at_least_six_chars_length );
    exit(false);
  end;


  exit( true) ;
end;

function wizard_validate_key_password( w : TVisWAPTConsolePostConf; c : TControl; const key_filename : String; const key_password : String ) : boolean;
var
  r : integer;
begin

  try
  r := crypto_check_key_password( result, key_filename, key_password );
  except on E : Exception do
    begin
      w.show_validation_error( c, E.Message );
      exit(false);
    end;
  end;

  if r <> 0 then
  begin
    w.show_validation_error( c, rs_an_error_has_occured_while_to_validate_key_password );
    exit(false);
  end;

  if not result then
  begin
    w.show_validation_error( c, rs_wrong_key_password );
    exit(false);
  end;
end;


function wizard_validate_no_innosetup_process_running(w: TVisWAPTConsolePostConf; c : TControl ): Boolean;
begin
  if not ensure_process_not_running(ISCC_EXE) then
  begin
    w.show_validation_error( c, rs_iscc_instance_found );
    exit( false);
  end;
  exit(true);
end;



function wizard_validate_waptserver_login(w: TVisWAPTConsolePostConf; c : TControl; const server_url: String; const login: String; const password: String ): boolean;
var
  so  : ISuperObject;
  r   : integer;
  s   : String;
  b   : boolean;
  url : String;
begin

  so := TSuperObject.ParseString( '{}', false );
  so.S['user'] := UTF8decode(login);
  so.S['password'] := UTF8Decode(password);



  url := url_concat( server_url , '/api/v3/login' );
  r := http_post( s, url, MIME_APPLICATION_JSON, UTF8Encode(so.AsJSon(false)) );
  if r <> 0 then
  begin
    w.show_validation_error( c,  rs_waptserver_not_found_or_down );
    exit( false  );
  end;

  r := wapt_json_response_is_success( b, s );
  if r <> 0 then
  begin
    w.show_validation_error( nil,   rs_a_problem_has_occured_while_trying_to_login_server );
    exit( false  );
  end;

  if not b then
  begin
    w.show_validation_error( c, rs_bad_login_password);
    exit(false);
  end;

  exit( true );
end;


function wizard_validate_waptserver_waptagent_is_not_present( w : TVisWAPTConsolePostConf; c : TControl; const server_url: String; var rc : integer ): Boolean;
var
  r  : integer;
  url : String;
begin
  url := url_concat( server_url, '/wapt/waptagent.exe' );
  r := http_reponse_code( rc, url );
  if r <> 0 then
  begin
    w.show_validation_error( c, 'An problem has occured while try to download wapt agent' );
    exit( false );
  end;

  if 200 = rc then
    exit( false );

  if 404 <> rc then
  begin
    w.show_validation_error( c, 'An problem has occured while try to download wapt agent' );
    exit( false  );
  end;


  exit( true );
end;

end.

