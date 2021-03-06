unit waptconsolepostconfres;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DefaultTranslator;

resourcestring
  rs_finished = 'Finished';
  rs_package_prefix_cannot_be_empty = 'Package prefix cannot be empty';
  rs_package_prefix_must_be_alphanum = 'Pacakge prefix must be alphanum';
  rs_create_key_dir_not_exist = 'Create directory %s ?';
  rs_create_key_dir_cannot_be_created = 'Cannot create directory %s';
  rs_create_key_select_a_valide_private_key_directory = 'A valid private key directory must be selected';
  rs_create_key_a_key_with_this_name_exist = 'A key with this name has been found, change key name and click next again';
  rs_create_key_a_certificat_this_key_name_exist = 'A certificat with key name has beenfound, change key name and click next again';
  rs_supplied_passwords_differs = 'Supplied password differs';
  rs_supplied_passwords_must_be_at_least_six_chars_length = 'Supplied passwords must be at least 6 characters length';
  rs_key_name_cannot_be_empty = 'Key name cannot be empty';
  rs_key_filename_cannot_be_empty = 'Key filename cannot be empty';
  rs_certificate_filename_cannot_be_empty = 'Certificate filename cannot be empty';
  rs_key_filename_is_invalid = 'Key filename ''%s'' is invalid';
  rs_no_key_password = 'Please provide the private key password first';
  rs_no_matching_key = 'No private key has been found in certificate directory with this password';
  rs_certificate_filename_is_invalid = 'Certificate filename ''%s'' is invalid';
  rs_an_error_has_occured_while_to_validate_key_password = 'An unexpected error has occured while validating key password';
  rs_wrong_key_password = 'Wrong key password';
  rs_other_process_has_been_found = 'An instance of %s has been found.' + #13#10 + 'The program cannot continue unitl this process has terminated.' + #13#10 + #13#10  + 'Click on Yes to kill all the process named %s' + #13#10 + 'Click on Retry to recheck processes satus' + #13#10 +  'Click on Cancel to abort';
  rs_iscc_instance_found = 'A instance of ISCC as been found, cannot continue.';
  rs_compilation_failed = 'Compilation Failed';
  rs_upload_to_server = 'Upload to server %d%%';
  rs_wapt_sever_url_is_invalid = 'Wapt server url is invalid';
  rs_waptserver_not_found_or_down = 'Wapt server not found or down';
  rs_a_problem_has_occured_while_trying_to_login_server =  'A problem has occured when trying to login to server';
  rs_wapt_server_installation_may_be_broken = 'Wapt server installation may be broken';
  rs_bad_login_password = 'Bad login password';
  rs_wapt_agent_has_been_found_on_server_confirm_create_package_key = 'Wapt agent has been found on the server' + #13#10 + 'Are you sure you want to recreate a new package key ?';
  rs_wapt_agent_has_been_found_on_server_overwrite_agent =  'Wapt agent has been found on the server' + #13#10 + 'Build and overwrite agent ?';
  rs_confirm_cancel_post_config = 'Are you sure you want to abort wapt console post configuration ?';
  rs_confirm = 'Confirm';
  rs_you_wapt_agent_version_mismatch = 'Wapt agent version exception (%s) Post configuration tool cannot continue, please follow tutorial at : http://wapt.fr';
  rs_post_conf_will_now_exit = 'Post configuration tool will now exit';
implementation

end.

