{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit QFIDEAssistant;

{$warn 5023 off : no warning about unused units}
interface

uses
  QFdockbknunit, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('QFdockbknunit', @QFdockbknunit.Register);
end;

initialization
  RegisterPackage('QFIDEAssistant', @Register);
end.
