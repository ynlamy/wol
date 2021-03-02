program wol;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  IdUDPClient, IdGlobal, IdGlobalProtocols;

type

  { TMyWol }

  TMyWol = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteVersion; virtual;
    procedure WriteLicense; virtual;
    procedure WriteHelp; virtual;
    procedure WriteFileNotFound; virtual;
    procedure WriteInvalidIp; virtual;
    procedure WriteInvalidPort; virtual;
    procedure WriteInvalidMac(MacAddress: String); virtual;
  end;

{ TMyWol }

function isValidPort(Port: String): Boolean;
begin
  if IsNumeric(Port) = True then
  begin
    if (StrToInt(Port) >= 0) and (StrToInt(Port)<= 65535) then
      isValidPort := True
    else
      isValidPort := False;
  end
  else
    isValidPort := False;
end;

function isValidMac(MacAddress: String): Boolean;
begin
  MacAddress := StringReplace(MacAddress, '-', '', [rfReplaceAll]);
  MacAddress := StringReplace(MacAddress, ':', '', [rfReplaceAll]);

  if Length(MacAddress) = 12 then
    isValidMac := IsHexidecimal(MacAddress)
  else
    isValidMac := False;
end;

function WakeOnLan(MacAddress, IPAddress, Port: String): String;
var
  MacAddressFormat: String;
  Buffer: TIdBytes;
  i: Integer;
  IdUDPClient: TIdUDPClient;
begin
  // format mac address
  MacAddressFormat := MacAddress;
  MacAddressFormat := StringReplace(MacAddressFormat, '-', '', [rfReplaceAll]);
  MacAddressFormat := StringReplace(MacAddressFormat, ':', '', [rfReplaceAll]);

  // create the magic packet
  SetLength(Buffer, 102); // 6 (FF FF FF FF FF FF) + 6 (MacAddress) * 16 = 102 Bytes

  // FF * 6
  for i := 0 to 5 do
    Buffer[i] := $FF;

  // MacAddress * 16
  for i := 1 to 16 do
  begin
    Buffer[i * 6] := StrToInt('$' + MacAddressFormat[1] + MacAddressFormat[2]);
    Buffer[i * 6 + 1] := StrToInt('$' + MacAddressFormat[3] + MacAddressFormat[4]);
    Buffer[i * 6 + 2] := StrToInt('$' + MacAddressFormat[5] + MacAddressFormat[6]);
    Buffer[i * 6 + 3] := StrToInt('$' + MacAddressFormat[7] + MacAddressFormat[8]);
    Buffer[i * 6 + 4] := StrToInt('$' + MacAddressFormat[9] + MacAddressFormat[10]);
    Buffer[i * 6 + 5] := StrToInt('$' + MacAddressFormat[11] + MacAddressFormat[12]);
  end;

  // send the magic packet
  idUDPClient := TIdUDPClient.Create(nil);
  try
    IdUDPClient.BroadcastEnabled := True;
    IdUDPClient.SendBuffer(IPAddress, StrToInt(Port), Buffer);
  finally
    IdUDPClient.Free;
  end;

  WakeOnLan := MacAddress;
end;

procedure TMyWol.DoRun;
var
  ErrorMsg, FileName, MacAddress, IPAddress, Port: String;
  MacAddressList: TStringList;
  i: Integer;
begin
  // check parameters
  ErrorMsg := CheckOptions('f:i:p:hv', 'file: ip: port: help version');
  if ErrorMsg <> '' then
  begin
    WriteVersion;
    WriteHelp;
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then
  begin
    WriteVersion;
    WriteHelp;
    Terminate;
    Exit;
  end;

  if (HasOption('v', 'version')) then
  begin
    WriteVersion;
    WriteLicense;
    Terminate;
    Exit;
  end;

  MacAddressList := TStringList.Create;

  // get values in parameters
  GetNonOptions('f:i:p:hv', ['file:', 'ip:', 'port:', 'help', 'version'], MacAddressList);
  FileName := GetOptionValue('f', 'file');
  IPAddress := GetOptionValue('i', 'ip');
  Port := GetOptionValue('p', 'port');

  // check file is used
  if FileName <> '' then
  begin
    // check file exist
    if FileExists(FileName) = False then
    begin
      WriteFileNotFound;
      Terminate;
      ExitCode := 2;
      Exit;
   end
    else
      MacAddressList.LoadFromFile(FileName);
  end;

  // check that at least one mac address
  if MacAddressList.Count = 0 then
  begin
    WriteVersion;
    WriteHelp;
    Terminate;
    ExitCode := 13;
    Exit;
  end;

  // set default ip address
  if IPAddress = '' then
    IPAddress := '255.255.255.255';

  // set default port
  if Port = '' then
    Port := '9';

  // check ip address
  if IsValidIP(IPAddress) = False then
  begin
    WriteInvalidIp;
    Terminate;
    ExitCode := 13;
    Exit;
  end;

  // check port
  if IsValidPort(Port) = False then
  begin
    WriteInvalidPort;
    Terminate;
    ExitCode := 13;
    Exit;
  end;

  // wol (Wake On LAN)
  for i := 0 to MacAddressList.Count-1 do
  begin
    // check mac address
    MacAddress := MacAddressList[i];
    if IsValidMac(MacAddress) = True then
      writeln('Trying to wake up : ' + WakeOnLan(MacAddress, IPAddress, Port))
    else
      WriteInvalidMac(MacAddress);
  end;

  MacAddressList.Free;

  Terminate;
end;

constructor TMyWol.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException := True;
end;

destructor TMyWol.Destroy;
begin
  inherited Destroy;
end;

procedure TMyWol.WriteVersion;
begin
  writeln('wol 1.0 : Copyright (c) 2021 Yoann LAMY');
  writeln();
end;

procedure TMyWol.WriteLicense;
begin
  writeln('You may redistribute copies of the program under the terms of the GNU General Public License v3 : https://github.com/ynlamy/wol.');
  writeln('This program come with ABSOLUTELY NO WARRANTY.');
  writeln('Portions of this program are Copyright (c) 1993 - 2018, Chad Z. Hower (Kudzu) and the Indy Pit Crew - http://www.indyproject.org/.');
end;

procedure TMyWol.WriteHelp;
begin
  writeln('Usage : ', ExeName, ' [<macaddress> <macaddress>] [-f <filename>] [-i <ipaddress>] [-p <port>]');
  writeln();
  writeln('<macaddress> : MAC addresses to wake up (multiple MAC addresses allowed)');
  writeln('-f <filename>, --file=<filename> : A Text file containing MAC addresses to wake up (one MAC address per line)');
  writeln('-i <ipaddress>, --ip=<ipaddress> : The Destination IP address, usually a broadcast address (default : 255.255.255.255)');
  writeln('-p <port>, --port=<port>: The destination UDP port number, usually 7 or 9 (default : 9)');
  writeln('-h, --help : Print this help screen');
  writeln('-v, --version : Print the version of the program and exit');
end;

procedure TMyWol.WriteFileNotFound;
begin
  writeln('file not found');
end;

procedure TMyWol.WriteInvalidIp;
begin
  writeln('invalid ip address');
end;

procedure TMyWol.WriteInvalidPort;
begin
  writeln('invalid port');
end;

procedure TMyWol.WriteInvalidMac(MacAddress: String);
begin
  writeln(MacAddress + ' : invalid mac address');
end;

var
  Application: TMyWol;

{$R *.res}

begin
  Application := TMyWol.Create(nil);
  Application.Run;
  Application.Free;
end.

