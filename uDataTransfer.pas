unit uDataTransfer;
/// <author>kami</author>
/// <summary>
/// Classes - wrappers arount TClient|TServerSocket, works in Delphi5 - RAD X
///  Tested only in D2010, XE7, RAD X.
///  =============================================================================
///  Capabilities:
///  - transfer / receive data over a network with automated processing of
///    the splitting/gluing packets
///  - data Queuing. ie, attempt to transfer large TStream
///    will not lead to the transmission failure of the second and subsequent
///    as with TClient/TServerSocket
///  - TDataTransferClient - handling the disconnection
///    with the resumption of data transfer after the connection is restored
///  - the data sent will come either FULLY (in ONE OnReceiveData event) or not coming at all
///  =============================================================================
///  Specific:
///  - when transferring, component becomes the owner of TStream and destroy it if necessary
///  - when receiving, the owner must destroy the received stream in OnReceiveData event
/// </summary>
{
  ��� ������������� ����� ������ ������ �� ������ �� �����������.

  ================================================================================
  ������-������� ��� TClient|TServerSocket, �������������� Delphi 2009 � ����.
  ������������� �� D2010, XE7, RAD X.
  ��� �������� ������ ��� ������������ � ����� (TStream), ��������� ������� WriteStringToStream
  ��� �������������� TStream>string ������������ �������������
  ������������ �������� ReadStringFromStream.
  ================================================================================
  �����������:
  - �����/�������� ���������� �� ���� � �������������� ����������
  ���������/������� �������
  - ���������� ������ � ������� �� �������� (�.�. ������� �������� � ������� �������
  TStream �� �������� � ������ �������� ������� � �����������,
  ��� ��� ���� �� � TClient|ServerSocket
  - TDataTransferClient ������������ ��������� ������� ����������
  � �������������� �������� ������ ����� �������������� ����������.
  - ������������ ������ ���� ������ ��������� (�� ���� �������
  ������) ���� �� ������ ������.
  ================================================================================
  �������� ������ �������������� �������������� ����������� ��������
  (�����, ������, TStream). ����� - ������ TStream. ��� "��������" �� ������
  � ������ ��������� ��������� ReadStringFromStream.
  ��� ������������� - ��������� �� ������� � ��������� �������� ������ �����
  ��������. � ������� ���� ������ "�������� ����" � "�������� �����������".
  ================================================================================
  �����������:
  �� ����� (�� �� ������, ��� ������) ���������� ������ � ��������� ����� ��������
  �� ������� �������� - ���������� ��������� ������ �������� �� TMemoryStream,
  ��� ��� ������� �������� ����������� (��� ������������� ������� "�������� ����")
  �������� � �������������� ������ SourceSize*ClientCount.
  ================================================================================
  �����������:
  ��� �������� ������ ����� TStream ������� ��������� ���������� ��� ����������
  � ��� ��������� ���. ������ - �������� Stream � ����� � ������ ��� ����.
  ��� ������ - ��������. ������� TStream �� �������� ����������,
  �������� ������ ��� ����������.
  ================================================================================
  � ���������, ������� ������� aka kami.
  http://www.zapravila.ucoz.ru
}
{$I SimpleTCPComponents.inc}

interface

uses
  Messages,
  Classes,
  Contnrs,
  SysUtils,
  ScktComp,
  uPacketStream,
  uAbstractDataTransfer;

type
  TDataTransferClient = class(TAbstractDataTransfer)
  private
    FClientSocket: TClientSocket;

    FInStream: TAbstractInPacketStream;
    FOutDataList: TObjectList; // yes, I know about Generics.Collections
    // but this declaration only for partial compatibility with old Delphi versions

    FCanAutoRecreateSocket: Boolean;
    FIP: string;
    FHost: string;
    FContinueSendingAfterReconnect: Boolean;

    procedure CreateClientSocket;

    procedure TimerProc(Sender: TObject);
    function GetConnected: Boolean;
    function GetOutDataCount: Integer;
    procedure SendOutStream(Stream: TAbstractOutPacketStream; InsertFirst: Boolean);
  protected
    procedure WndProc(var message: TMessage); override;
    procedure SetActive(const Value: Boolean); override;

    procedure OnDisconnect(Sender: TObject; Socket: TCustomWinSocket); override;

    function GetOutDataList(Socket: TCustomWinSocket): TObjectList; override;
    procedure SetCurrentInStream(Socket: TCustomWinSocket; Stream: TAbstractInPacketStream); override;
    function GetCurrentInStream(Socket: TCustomWinSocket): TAbstractInPacketStream; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SendData(const Data; DataLength: Int64; InsertFirst: Boolean = False); overload;
    procedure SendData(const Data: string; InsertFirst: Boolean = False{$IFDEF EncodingPresented}; Encoding: TEncoding = nil{$ENDIF}); overload;
    procedure SendData(Data: TStream; InsertFirst: Boolean = False); overload;

    procedure DeleteAllOutData;
    procedure RecreateSocket;

    property Connected: Boolean read GetConnected;
    property OutDataCount: Integer read GetOutDataCount;
  published
    property CanAutoRecreateSocket: Boolean read FCanAutoRecreateSocket write FCanAutoRecreateSocket;
    property ContinueSendingAfterReconnect: Boolean read FContinueSendingAfterReconnect write FContinueSendingAfterReconnect;
    property IP: string read FIP write FIP;
    property Host: string read FHost write FHost;
  end;

  TDataTransferServer = class(TAbstractDataTransfer)
  private
    FServerSocket: TServerSocket;

    procedure CreateSocketData(Socket: TCustomWinSocket);
    procedure FreeSocketData(Socket: TCustomWinSocket);

    function GetConnection(Index: Integer): TCustomWinSocket;
    function GetConnectionCount: Integer;

    procedure SendOutStreamToSingleConnection(ConnectionIndex: Integer; Data: TAbstractOutPacketStream; InsertFirst: Boolean);
    function GetConnectionTag(Index: Integer): Integer;
    procedure SetConnectionTag(Index: Integer; const Value: Integer);
    function GetConnectionObjectTag(Index: Integer): TObject;
    procedure SetConnectionObjectTag(Index: Integer; const Value: TObject);
  protected
    procedure SetActive(const Value: Boolean); override;
    procedure SetTCPPort(const Value: Integer); override;

    procedure OnConnect(Sender: TObject; Socket: TCustomWinSocket); override;
    procedure OnDisconnect(Sender: TObject; Socket: TCustomWinSocket); override;

    function GetOutDataList(Socket: TCustomWinSocket): TObjectList; override;
    procedure SetCurrentInStream(Socket: TCustomWinSocket; Stream: TAbstractInPacketStream); override;
    function GetCurrentInStream(Socket: TCustomWinSocket): TAbstractInPacketStream; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function SocketIndex(Socket: TCustomWinSocket): Integer;

    procedure SendToAll(const Data; DataLength: Int64; InsertFirst: Boolean = False); overload;
    procedure SendToAll(const Data: string; InsertFirst: Boolean = False{$IFDEF EncodingPresented}; Encoding: TEncoding = nil{$ENDIF}); overload;
    procedure SendToAll(Data: TStream; InsertFirst: Boolean = False); overload;

    procedure SendToSingleConnection(ConnectionIndex: Integer; const Data; DataLength: Int64; InsertFirst: Boolean = False); overload;
    procedure SendToSingleConnection(ConnectionIndex: Integer; const Data: string; InsertFirst: Boolean = False{$IFDEF EncodingPresented};
      Encoding: TEncoding = nil{$ENDIF}); overload;
    procedure SendToSingleConnection(ConnectionIndex: Integer; Data: TStream; InsertFirst: Boolean = False); overload;

    property Connection[index: Integer]: TCustomWinSocket read GetConnection;
    property ConnectionCount: Integer read GetConnectionCount;
    property ConnectionTag[index: Integer]: Integer read GetConnectionTag write SetConnectionTag;
    property ConnectionObjectTag[index: Integer]: TObject read GetConnectionObjectTag write SetConnectionObjectTag;
  end;

function ReadStringFromStream(Stream: TStream{$IFDEF EncodingPresented}; Encoding: TEncoding = nil{$ENDIF}): string;
procedure WriteStringToStream(const s: string; Stream: TStream{$IFDEF EncodingPresented}; Encoding: TEncoding = nil{$ENDIF});

procedure Register;

implementation

uses
  Windows, WinSock;

procedure Register;
begin
  RegisterComponents('Kami-Soft', [TDataTransferClient, TDataTransferServer]);
end;

const
  WM_DELAYED_RECREATE_SOCKET = WM_USER + 1; // WM_USER ordered by AbstractDataTransfer

type
  { ��������� �������� ������ ��� ��������� �������.
    ������������ � �������� TServerSocket.Socket.Connection[i].Data }
  TServerSideSocketData = record
    InStream: TAbstractInPacketStream; // ����� �������� ������. ��� ��������� ���������� ��. ������ uPacketStream
    // �������� ����� ����, ����� ����� ��� ������ �� �������� � �������
    // � ����� ����� "����������", ������� ����� ����� ����������� ������.
    // ���������� ������ ������ ���������� ���������, ����������� ������� ������.

    OutDataList: TObjectList; // ������� �� ��������. ��������� ��� ������� ���������� ��� �������������
    // ��������, ������ ��� ��������� ����� �� ����� � �� ����� ����� � ���,
    // ��� ����� ������������� ���������� - ��� ������ ��� �����������.
    // � ���������� ����� �������� ������ �������������� ��� ��������������
    // ����������.

    Tag: Integer;

    ObjectTag: TObject;
  end;

  pServerSideSocketData = ^TServerSideSocketData;

function ReadStringFromStream(Stream: TStream{$IFDEF EncodingPresented}; Encoding: TEncoding = nil{$ENDIF}): string;
var
{$IFDEF EncodingPresented}b: TBytes; {$ENDIF}
  Len: Integer;
begin
{$IFDEF EncodingPresented}
  if not Assigned(Encoding) then
    Encoding := TEncoding.UTF8;
  Stream.Read(Len, SizeOf(Integer));
  SetLength(b, Len);
  if Len <> 0 then
    Stream.Read(b[0], Len);
  Result := Encoding.GetString(b);
{$ELSE}
  Stream.Read(Len, SizeOf(Integer));
  SetLength(Result, Len div SizeOf(Char));
  if Len <> 0 then
    Stream.Read(Result[1], Len);
{$ENDIF}
end;

procedure WriteStringToStream(const s: string; Stream: TStream{$IFDEF EncodingPresented}; Encoding: TEncoding = nil{$ENDIF});
var
{$IFDEF EncodingPresented}b: TBytes; {$ENDIF}
  Len: Integer;
begin
{$IFDEF EncodingPresented}
  if not Assigned(Encoding) then
    Encoding := TEncoding.UTF8;
  b := Encoding.GetBytes(s);
  Len := Length(b);
  Stream.Write(Len, SizeOf(Integer));
  if Len <> 0 then
    Stream.Write(b[0], Length(b));
{$ELSE}
  Len := Length(s) * SizeOf(Char);
  Stream.Write(Len, SizeOf(Integer));
  if Len <> 0 then
    Stream.Write(s[1], Len);
{$ENDIF}
end;

{ TDataTransferClient }

constructor TDataTransferClient.Create(AOwner: TComponent);
begin
  inherited;

  FIP := '127.0.0.1';
  FCanAutoRecreateSocket := False;

  FOutDataList := TObjectList.Create;

  CreateClientSocket;
end;

procedure TDataTransferClient.CreateClientSocket;
begin
  FClientSocket.Free;

  FClientSocket := TClientSocket.Create(nil);
  FClientSocket.OnConnect := OnConnect;
  FClientSocket.OnDisconnect := OnDisconnect;
  FClientSocket.OnRead := OnRead;
  FClientSocket.OnWrite := OnWrite;
  FClientSocket.OnError := OnError;
  FClientSocket.Address := FIP;
  FClientSocket.Host := FHost;
{$IFDEF ExtScktComp}
  FClientSocket.BindTo(FBindIP, 0);
{$ENDIF}
  FClientSocket.Port := TCPPort;

  FClientSocket.Active := Active;
end;

procedure TDataTransferClient.DeleteAllOutData;
var
  i: Integer;
  s: TStream;
begin
  if FOutDataList.Count <> 0 then
    begin
      for i := OutDataCount - 1 downto 1 do
        FOutDataList.Delete(i);
      s := TStream(FOutDataList[0]);
      if s.Position = 0 then
        FOutDataList.Delete(0);
    end;
end;

destructor TDataTransferClient.Destroy;
begin
  KillTimer(FWndHandle, 1);
  FClientSocket.Free;

  FreeAndNil(FInStream);
  FreeAndNil(FOutDataList);

  inherited;
end;

function TDataTransferClient.GetConnected: Boolean;
begin
  Result := False;
  if Assigned(FClientSocket) then
    if Assigned(FClientSocket.Socket) then
      Result := FClientSocket.Socket.Connected;
end;

function TDataTransferClient.GetCurrentInStream(Socket: TCustomWinSocket): TAbstractInPacketStream;
begin
  Result := FInStream;
end;

function TDataTransferClient.GetOutDataCount: Integer;
begin
  Result := FOutDataList.Count;
end;

function TDataTransferClient.GetOutDataList(Socket: TCustomWinSocket): TObjectList;
begin
  Result := FOutDataList;
end;

procedure TDataTransferClient.OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  PostMessage(FWndHandle, WM_DELAYED_RECREATE_SOCKET, 0, 0);
  {
    ��������������� ���������� ��������� (TClientSocket) ����� ������ - ��� �������
    ���������� �� ��� "�������������". ������ - ����� �������� ������ ��� ���������
    � ��� ������������� ����� ������ - ��������� "����������" ��������.
    ��. ������� ��������� TDataTransferClient.WndProc
  }

  // ���� ��� �������� ���� �� ���-�� ���������,
  // ������ ����� �������� ������ ������� ���������� ����������� � ������
  if ContinueSendingAfterReconnect then
    begin
      if FOutDataList.Count <> 0 then
        TStream(FOutDataList[0]).Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
      // ������� ��������� �������� �������� ������
    end
  else
    FOutDataList.Clear;
  FreeAndNil(FInStream); // � �������� ��������� ����� ���������� - ������ �������� ����� �� ��������
  // ������ ��� ������ �������� ���������� � ������.

  inherited;
end;

procedure TDataTransferClient.RecreateSocket;
begin
  PostMessage(FWndHandle, WM_DELAYED_RECREATE_SOCKET, 0, 0);
end;

procedure TDataTransferClient.SendData(const Data; DataLength: Int64; InsertFirst: Boolean);
var
  Stream: TAbstractOutPacketStream;
begin
  Stream := CreateOutStream;
  try
    Stream.Write(Data, DataLength);
    Stream.FillHeader(0, False);
    Stream.Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
    SendOutStream(Stream, InsertFirst);
    Stream := nil;
  finally
    Stream.Free;
  end;
end;

procedure TDataTransferClient.SendData(const Data: string; InsertFirst: Boolean{$IFDEF EncodingPresented}; Encoding: TEncoding{$ENDIF});
var
  Stream: TAbstractOutPacketStream;
begin
  Stream := CreateOutStream;
  try
    WriteStringToStream(Data, Stream{$IFDEF EncodingPresented}, Encoding{$ENDIF});
    Stream.FillHeader(0, False);
    Stream.Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
    SendOutStream(Stream, InsertFirst);
    Stream := nil;
  finally
    Stream.Free;
  end;
end;

procedure TDataTransferClient.SendData(Data: TStream; InsertFirst: Boolean);
var
  Stream: TAbstractOutPacketStream;
begin
  {
    �������� ����� ��������. ������� TOutPacketStream (��� ��������������
    ���������� - ��. ������ uPacketStream) � ���������� ���������
    ������ ������, ������� ������� ������� OnWrite. �������������� �����
    ����� ������� ��������� �� ��������� ������������:
    ���������� Windows ��� ������� ���������� ����������, ����� ����� �������� ������
    ����. ���� ��� ������� ���� ��������, ����� � ����� ������� �� ��������
    ������ �� ����, �� ������� ���������� ����� � ������� ������ �� ����.
    � �� �� �����, ���� ����� "�����" �������, �� ������ ������� ���� �� �������� -
    ������ �� ����� "������", ���� �������������� ����� ����������, �����
    ����� ������ �����������.
    ��������: ���� ������ ��������� �������, ��� ����������, ���� ������� �� �������� ����� ���������,
    ��� � �������� ����� ����� �������� � EOutOfMemory. ���� �������� �������� � ������
    ��������� �� ���������, �� �������� ����� �������� �������� �� �����������
    ���������� ������ � ������� �� ��������. }
  try
    Stream := CreateOutStream;
    try
      Stream.CopyFrom(Data, 0);
      Stream.FillHeader(0, False);
      Stream.Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});

      SendOutStream(Stream, InsertFirst);
      Stream := nil;
    finally
      Stream.Free;
    end;
  finally
    Data.Free;
  end;
end;

procedure TDataTransferClient.SendOutStream(Stream: TAbstractOutPacketStream; InsertFirst: Boolean);
var
  InsertIndex: Integer;
begin
  if FOutDataList.Count >= MaxQueueCount then
    FOutDataList.Delete(0);
  if not InsertFirst then
    InsertIndex := FOutDataList.Count
  else
    begin
      InsertIndex := 0;
      if FOutDataList.Count <> 0 then
        if TStream(FOutDataList[0]).Position <> 0 then
          InsertIndex := 1;
    end;
  FOutDataList.Insert(InsertIndex, Stream);
  if Assigned(FClientSocket) then
    PostMessage(FClientSocket.Socket.Handle, CM_SOCKETMESSAGE, FClientSocket.Socket.SocketHandle, MakeLParam(FD_WRITE, 0));
end;

procedure TDataTransferClient.SetActive(const Value: Boolean);
begin
  if Active <> Value then
    begin
      inherited;
      CreateClientSocket;
    end;
end;

procedure TDataTransferClient.SetCurrentInStream(Socket: TCustomWinSocket; Stream: TAbstractInPacketStream);
begin
  FInStream := Stream;
end;

procedure TDataTransferClient.TimerProc(Sender: TObject);
begin
  // ������ ������ ��� ����������� �������� ������.
  // � ��������, ����� ���� �� �������� � ��� ����, �������� ����� ���������������
  // � ��������� WndProc, �� ����� �� ��������� ��������� ��������:
  // ����/����, � �������� �������� ������������ ���������� (�� ����� �������� -
  // ����. ��������, �������� ���������... ����� ������� ����������� �����
  // ��������� ��� �� �������, "�������" ������� �������� � ��������� SYN_SENT
  CreateClientSocket;
  KillTimer(FWndHandle, 1);
end;

procedure TDataTransferClient.WndProc(var message: TMessage);
begin
  case message.Msg of
    WM_TIMER:
      begin
        TimerProc(nil);
      end;
    WM_DELAYED_RECREATE_SOCKET:
      begin
        if message.WParam = 0 then
          begin
            // ��� ��������� ���������� ��� �� OnDisconnect.
            // ��������� �������� � ���������� �������� ������ ������,
            // ���� ��� ��������� ��������� CanAutoRecreateSocket
            KillTimer(FWndHandle, 1);
            FreeAndNil(FClientSocket);
            if FCanAutoRecreateSocket and Active then
              SetTimer(FWndHandle, 1, 500, nil);
          end;
      end;
  else
    inherited WndProc(Message);
  end;
end;

{ TDataTransferServer }

{
  ��� ����������� � TDataTransferClient � ������ ���� ��������� � TDataTransferServer,
  �� ����������� 2� ��������:
  1. ��� ������/�������� ���������� ����� ������������ ��������� pServerSideSocketData,
  �������� ��� ������� ������ ��������.
  2. ��� ������� ���������� ������ �� ������� �� �������� ������������, � ��
  ������������ �������� ���� ��� �������������� ����������, ��� � TDataTransferClient.
  ��� �������� - ����������� ������ ���������� ������.
  � ��������, ���� ������������, ����� ���� �� ������� ���� �����������
  ������ ������������ ������, �� - ����. ����,��� ����� ������ - ���������� � ���
  ������ �� ������������� (������� ����� - �������, � publuc - �������)
}

constructor TDataTransferServer.Create(AOwner: TComponent);
begin
  inherited;

  FServerSocket := TServerSocket.Create(nil);
  FServerSocket.Active := False;
  FServerSocket.OnClientRead := OnRead;
  FServerSocket.OnClientWrite := OnWrite;
  FServerSocket.OnClientConnect := OnConnect;
  FServerSocket.OnClientDisconnect := OnDisconnect;
  FServerSocket.OnClientError := OnError;
end;

procedure TDataTransferServer.CreateSocketData(Socket: TCustomWinSocket);
var
  SocketData: pServerSideSocketData;
begin
  New(SocketData);
  SocketData.InStream := nil;
  SocketData.OutDataList := TObjectList.Create;
  SocketData.Tag := 0;
  Socket.Data := SocketData;
end;

destructor TDataTransferServer.Destroy;
var
  i: Integer;
  Socket: TCustomWinSocket;
begin
  for i := 0 to FServerSocket.Socket.ActiveConnections - 1 do
    begin
      Socket := FServerSocket.Socket.Connections[i];
      // FreeSocketData(Socket);
      Socket.Close;
    end;

  FServerSocket.Free;
  inherited;
end;

procedure TDataTransferServer.FreeSocketData(Socket: TCustomWinSocket);
var
  SocketData: pServerSideSocketData;
begin
  SocketData := Socket.Data;
  if not Assigned(SocketData) then
    exit;
  FreeAndNil(SocketData.InStream);
  FreeAndNil(SocketData.OutDataList);
  Dispose(SocketData);
  Socket.Data := nil;
end;

procedure TDataTransferServer.SendToAll(const Data; DataLength: Int64; InsertFirst: Boolean);
var
  i: Integer;
begin
  for i := 0 to FServerSocket.Socket.ActiveConnections - 1 do
    SendToSingleConnection(i, Data, DataLength, InsertFirst);
end;

procedure TDataTransferServer.SendToAll(const Data: string; InsertFirst: Boolean{$IFDEF EncodingPresented}; Encoding: TEncoding{$ENDIF});
var
  i: Integer;
begin
  for i := 0 to FServerSocket.Socket.ActiveConnections - 1 do
    SendToSingleConnection(i, Data, InsertFirst{$IFDEF EncodingPresented}, Encoding{$ENDIF});
end;

procedure TDataTransferServer.SendToAll(Data: TStream; InsertFirst: Boolean);
var
  Stream: TAbstractOutPacketStream;
  i: Integer;
begin
  try
    for i := 0 to FServerSocket.Socket.ActiveConnections - 1 do
      begin
        Stream := CreateOutStream;
        try
          Stream.CopyFrom(Data, 0);
          Stream.FillHeader(0, False);
          Stream.Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
          SendOutStreamToSingleConnection(i, Stream, InsertFirst);
          Stream := nil;
        finally
          Stream.Free;
        end;
      end;
  finally
    Data.Free;
  end;
end;

procedure TDataTransferServer.SendOutStreamToSingleConnection(ConnectionIndex: Integer; Data: TAbstractOutPacketStream; InsertFirst: Boolean);
var
  SocketData: pServerSideSocketData;
  Socket: TCustomWinSocket;
  InsertIndex: Integer;
begin
  Socket := Connection[ConnectionIndex];
  SocketData := Socket.Data;

  if SocketData.OutDataList.Count >= MaxQueueCount then
    SocketData.OutDataList.Delete(0);
  if not InsertFirst then
    InsertIndex := SocketData.OutDataList.Count
  else
    begin
      InsertIndex := 0;
      if SocketData.OutDataList.Count <> 0 then
        if TStream(SocketData.OutDataList[0]).Position <> 0 then
          InsertIndex := 1;
    end;
  SocketData.OutDataList.Insert(InsertIndex, Data);
  if Socket.Connected then
    PostMessage(Socket.Handle, CM_SOCKETMESSAGE, Socket.SocketHandle, MakeLParam(FD_WRITE, 0));
end;

procedure TDataTransferServer.OnConnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  CreateSocketData(Socket);
  inherited;
end;

procedure TDataTransferServer.OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  inherited;
  FreeSocketData(Socket);
end;

procedure TDataTransferServer.SetActive(const Value: Boolean);
begin
  inherited;
  FServerSocket.Active := Value;
end;

procedure TDataTransferServer.SetConnectionObjectTag(Index: Integer; const Value: TObject);
begin
  pServerSideSocketData(Connection[index].Data).ObjectTag := Value;
end;

procedure TDataTransferServer.SetConnectionTag(Index: Integer; const Value: Integer);
begin
  pServerSideSocketData(Connection[index].Data).Tag := Value;
end;

procedure TDataTransferServer.SetCurrentInStream(Socket: TCustomWinSocket; Stream: TAbstractInPacketStream);
begin
  pServerSideSocketData(Socket.Data).InStream := Stream;
end;

function TDataTransferServer.GetConnection(Index: Integer): TCustomWinSocket;
begin
  Result := FServerSocket.Socket.Connections[index];
end;

function TDataTransferServer.GetConnectionCount: Integer;
begin
  Result := FServerSocket.Socket.ActiveConnections;
end;

function TDataTransferServer.GetConnectionObjectTag(Index: Integer): TObject;
begin
  Result := pServerSideSocketData(Connection[index].Data).ObjectTag;
end;

function TDataTransferServer.GetConnectionTag(Index: Integer): Integer;
begin
  Result := pServerSideSocketData(Connection[index].Data).Tag;
end;

function TDataTransferServer.GetCurrentInStream(Socket: TCustomWinSocket): TAbstractInPacketStream;
begin
  Result := pServerSideSocketData(Socket.Data).InStream;
end;

function TDataTransferServer.GetOutDataList(Socket: TCustomWinSocket): TObjectList;
begin
  Result := pServerSideSocketData(Socket.Data).OutDataList;
end;

procedure TDataTransferServer.SendToSingleConnection(ConnectionIndex: Integer; const Data; DataLength: Int64; InsertFirst: Boolean);
var
  Stream: TAbstractOutPacketStream;
begin
  Stream := CreateOutStream;
  try
    Stream.Write(Data, DataLength);
    Stream.FillHeader(0, False);
    Stream.Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
    SendOutStreamToSingleConnection(ConnectionIndex, Stream, InsertFirst);
    Stream := nil;
  finally
    Stream.Free;
  end;
end;

procedure TDataTransferServer.SendToSingleConnection(ConnectionIndex: Integer; const Data: string; InsertFirst: Boolean{$IFDEF EncodingPresented};
  Encoding: TEncoding{$ENDIF});
var
  Stream: TAbstractOutPacketStream;
begin
  Stream := CreateOutStream;
  try
    WriteStringToStream(Data, Stream{$IFDEF EncodingPresented}, Encoding{$ENDIF});
    Stream.FillHeader(0, False);
    Stream.Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
    SendOutStreamToSingleConnection(ConnectionIndex, Stream, InsertFirst);
    Stream := nil;
  finally
    Stream.Free;
  end;
end;

procedure TDataTransferServer.SendToSingleConnection(ConnectionIndex: Integer; Data: TStream; InsertFirst: Boolean);
var
  Stream: TAbstractOutPacketStream;
begin
  try
    Stream := CreateOutStream;
    try
      Stream.CopyFrom(Data, 0);
      Stream.FillHeader(0, False);
      Stream.Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
      SendOutStreamToSingleConnection(ConnectionIndex, Stream, InsertFirst);
      Stream := nil;
    finally
      Stream.Free;
    end;
  finally
    Data.Free;
  end;
end;
{$IFDEF ExtScktComp}

procedure TDataTransferServer.SetBindIP(const Value: string);
begin
  FBindIP := Value;
  FServerSocket.BindAddress := Value;
end;
{$ENDIF}

procedure TDataTransferServer.SetTCPPort(const Value: Integer);
begin
  inherited;
  FServerSocket.Port := Value;
end;

function TDataTransferServer.SocketIndex(Socket: TCustomWinSocket): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to ConnectionCount - 1 do
    if Connection[i] = Socket then
      begin
        Result := i;
        break;
      end;
end;

end.
