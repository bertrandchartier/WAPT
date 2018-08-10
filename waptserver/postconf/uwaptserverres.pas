unit uWaptServerRes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DefaultTranslator;

resourcestring

  { --- MESSAGES DANS WAPTSERVER - PostConf --- }
  rsWaptServiceStopping = 'Waptservice stopping';
  rsUpdatingPackageIndex = 'Updating package index';
  rsReplacingTIScertificate = 'Deleting TIS certificate and copying new certificate';
  rsSettingServerPassword = 'Setting up server password';
  rsOpeningFirewall = 'Opening firewall for WaptServer';
  rsRestartingWaptService = 'Restarting waptservice';
  rsRegisteringHostOnServer = 'Registering host on server';
  rsRetryRegisteringHostOnServer = '%D retry on registering host on server';
  rsUpdatingLocalPackages = 'Updating local packages';
  rsConfirm = 'Confirm';
  rsConfirmCancelPostConfig = 'Are you sure you want to cancel configuring WAPT server ?';
  rsInvalidDNS = 'Invalid DNS';
  rsInvalidDNSfallback = 'This DNS name is not valid, would you like to use the IP address instead ?';
  rsMongoDetect = 'Detected Mongodb Base';
  rsRunMongo2Postgresql = 'Do you want to start migrating the mongodb database to postgresql ?';

  rsCreationInProgress = 'Creation in progress.';
  rsProgressTitle = 'Started uploading to WAPT server...';  // TODO more meaningful var name
  rsWaptSetupUploadSuccess = 'WAPT agent successfully created and uploaded to the repository : %s';
  rsWaptUploadError = 'Error while uploading WAPT agent to the repository : %s';
  rsWaptSetupError = 'Error while creating agent : %s';
  rsWaptSetupDone = 'Done';
  rsWaptSetupNext = 'Next';

  rsConfigurePostgreSQL = 'Configure NGINX server and PostgreSQL database';
  rsStoppingPostgreSQL = 'Stopping PostgreSQL';
  rsStoppingNGINX = 'Stopping NGINX';
  rsStoppingWaptServer = 'Stopping WaptServer';
  rsStartingPostgreSQL = 'Starting PostgreSQL';
  rsStartingNGINX = 'Starting NGINX';
  rsStartingWaptServer = 'Starting WaptServer';
  rsCheckingWaptServer = 'Checking WaptServer';

  rsMigration15 = 'Migrate Mongodb to PostgreSQL database';

  rs_package_prefix_cannot_be_empty =  'Package prefix cannot be empty';
  rs_package_prefix_must_be_alphanum = 'Pacakge prefix must be alphanum';
  rs_create_key_dir_not_exist = 'Create directory %s ?';
  rs_create_key_select_a_valide_private_key_directory = 'A valid private key directory must be selected';
  rs_create_key_a_key_with_this_name_exist = 'A key with this name has been found, change key name and click next again';
  rs_create_key_a_certificat_this_key_name_exist = 'A certificat with key name has beenfound, change key name and click next again';
  rs_supplied_passwords_differs = 'Supplied password differs';
  rs_supplied_passwords_must_be_at_least_six_chars_length = 'Supplied passwords must be at least 6 characters length';
  rs_key_name_cannot_be_empty = 'Key name cannot be empty';


implementation

end.

