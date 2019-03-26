VERSION 5.00
Begin VB.UserControl ctxWinsock 
   BackColor       =   &H80000018&
   ClientHeight    =   2880
   ClientLeft      =   0
   ClientTop       =   0
   ClientWidth     =   3840
   InvisibleAtRuntime=   -1  'True
   ScaleHeight     =   2880
   ScaleWidth      =   3840
   Begin VB.Label labLogo 
      Alignment       =   2  'Center
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   $"ctxWinsock.ctx":0000
      BeginProperty Font 
         Name            =   "Segoe UI"
         Size            =   7.8
         Charset         =   204
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   408
      Left            =   0
      TabIndex        =   0
      Top             =   0
      UseMnemonic     =   0   'False
      Width           =   576
      WordWrap        =   -1  'True
   End
End
Attribute VB_Name = "ctxWinsock"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'=========================================================================
'
' VbAsyncSocket Project (c) 2018-2019 by wqweto@gmail.com
'
' Simple and thin WinSock API wrappers for VB6
'
' This project is licensed under the terms of the MIT license
' See the LICENSE file in the project root for more information
'
'=========================================================================
Option Explicit
DefObj A-Z
Private Const MODULE_NAME As String = "ctxWinsock"

'=========================================================================
' Public events
'=========================================================================

Event Connect()
Event CloseEvent()
Event ConnectionRequest(ByVal requestID As Long)
Event DataArrival(ByVal bytesTotal As Long)
Event SendProgress(ByVal bytesSent As Long, ByVal bytesRemaining As Long)
Event SendComplete()
Event Error(ByVal Number As Long, Description As String, ByVal Scode As UcsErrorConstants, Source As String, HelpFile As String, ByVal HelpContext As Long, CancelDisplay As Boolean)

'=========================================================================
' Public enums
'=========================================================================

Public Enum UcsProtocolConstants
    sckTCPProtocol = 0
    sckUDPProtocol = 1
End Enum

Public Enum UcsStateConstants
    sckClosed = 0
    sckOpen = 1
    sckListening = 2
    sckConnectionPending = 3
    sckResolvingHost = 4
    sckHostResolved = 5
    sckConnecting = 6
    sckConnected = 7
    sckClosing = 8
    sckError = 9
End Enum

Public Enum UcsErrorConstants
    sckInvalidPropertyValue = 380
    sckGetNotSupported = 394
    sckSetNotSupported = 383
    sckOutOfMemory = 7
    sckBadState = 40006
    sckInvalidArg = 40014
    sckSuccess = 40017
    sckUnsupported = 40018
    sckInvalidOp = 40020
    sckOutOfRange = 40021
    sckWrongProtocol = 40026
    sckOpCanceled = 10004
    sckInvalidArgument = 10014
    sckWouldBlock = 10035
    sckInProgress = 10036
    sckAlreadyComplete = 10037
    sckNotSocket = 10038
    sckMsgTooBig = 10040
    sckPortNotSupported = 10043
    sckAddressInUse = 10048
    sckAddressNotAvailable = 10049
    sckNetworkSubsystemFailed = 10050
    sckNetworkUnreachable = 10051
    sckNetReset = 10052
    sckConnectAborted = 10053
    sckConnectionReset = 10054
    sckNoBufferSpace = 10055
    sckAlreadyConnected = 10056
    sckNotConnected = 10057
    sckSocketShutdown = 10058
    sckTimedout = 10060
    sckConnectionRefused = 10061
    sckNotInitialized = 10093
    sckHostNotFound = 11001
    sckHostNotFoundTryAgain = 11002
    sckNonRecoverableError = 11003
    sckNoData = 11004
End Enum

'=========================================================================
' API
'=========================================================================

Private Const DUPLICATE_SAME_ACCESS         As Long = 2

Private Declare Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (Destination As Any, Source As Any, ByVal Length As Long)
Private Declare Function DuplicateHandle Lib "kernel32" (ByVal hSourceProcessHandle As Long, ByVal hSourceHandle As Long, ByVal hTargetProcessHandle As Long, lpTargetHandle As Long, ByVal dwDesiredAccess As Long, ByVal bInheritHandle As Long, ByVal dwOptions As Long) As Long
Private Declare Function GetCurrentProcess Lib "kernel32" () As Long

'=========================================================================
' Constants and member variables
'=========================================================================

Private Const DEF_LOCALPORT         As Long = 0
Private Const DEF_PROTOCOL          As Long = 0
Private Const DEF_REMOTEHOST        As String = vbNullString
Private Const DEF_REMOTEPORT        As Long = 0
Private Const DEF_TIMEOUT           As Long = 5000

Private WithEvents m_oSocket    As cAsyncSocket
Private m_eState                As UcsStateConstants
Private m_lLocalPort            As Long
Private m_eProtocol             As UcsProtocolConstants
Private m_sRemoteHost           As String
Private m_lRemotePort           As Long
Private m_lTimeout             As Long
Private m_baRecvBuffer()        As Byte
Private m_baSendBuffer()        As Byte
Private m_lSendPos              As Long

'=========================================================================
' Error handling
'=========================================================================

Private Sub PrintError(sFunction As String)
    Debug.Print "Critical error: " & Err.Description & " [" & MODULE_NAME & "." & sFunction & "]"
End Sub

'=========================================================================
' Properties
'=========================================================================

Property Get LocalPort() As Long
    LocalPort = m_lLocalPort
End Property

Property Let LocalPort(ByVal lValue As Long)
    If m_lLocalPort <> lValue Then
        Set m_oSocket = Nothing
        pvState = sckClosed
        m_lLocalPort = lValue
        PropertyChanged
    End If
End Property

Property Get Protocol() As UcsProtocolConstants
    Protocol = m_eProtocol
End Property

Property Let Protocol(ByVal eValue As UcsProtocolConstants)
    If m_eProtocol <> eValue Then
        Set m_oSocket = Nothing
        pvState = sckClosed
        m_eProtocol = eValue
        PropertyChanged
    End If
End Property

Property Get RemoteHost() As String
    RemoteHost = m_sRemoteHost
End Property

Property Let RemoteHost(sValue As String)
    If m_sRemoteHost <> sValue Then
        m_sRemoteHost = sValue
        m_baSendBuffer = vbNullString
        PropertyChanged
    End If
End Property

Property Get RemotePort() As Long
    RemotePort = m_lRemotePort
End Property

Property Let RemotePort(ByVal lValue As Long)
    If m_lRemotePort <> lValue Then
        m_lRemotePort = lValue
        m_baSendBuffer = vbNullString
        PropertyChanged
    End If
End Property

Property Get Timeout() As Long
    Timeout = m_lTimeout
End Property

Property Let Timeout(ByVal lValue As Long)
    If m_lTimeout <> lValue Then
        m_lTimeout = lValue
        PropertyChanged
    End If
End Property

'= run-time ==============================================================

Property Get SocketHandle() As Long
    SocketHandle = pvSocket.SocketHandle
End Property

Property Get State() As UcsStateConstants
    State = m_eState
End Property

Private Property Let pvState(ByVal eValue As UcsStateConstants)
    m_eState = eValue
    m_baRecvBuffer = vbNullString
    m_baSendBuffer = vbNullString
End Property

Property Get LocalHostName() As String
    m_oSocket.GetLocalHost LocalHostName, vbNullString
End Property

Property Get LocalIP() As String
    m_oSocket.GetLocalHost vbNullString, LocalIP
End Property

Property Get RemoteHostIP() As String
    m_oSocket.GetPeerName RemoteHostIP, 0
End Property

Private Property Get pvSocket() As cAsyncSocket
    Const FUNC_NAME     As String = "pvSocket [get]"
    
    On Error GoTo EH
    If m_oSocket Is Nothing Then
        Set m_oSocket = New cAsyncSocket
        m_oSocket.Create m_lLocalPort, m_eProtocol
    End If
    Set pvSocket = m_oSocket
    Exit Property
EH:
    PrintError FUNC_NAME
    Resume Next
End Property

'=========================================================================
' Methods
'=========================================================================

Public Sub Accept(ByVal requestID As Long)
    Const FUNC_NAME     As String = "Accept"
    Dim hDuplicate      As Long
    
    On Error GoTo EH
    If DuplicateHandle(GetCurrentProcess(), requestID, GetCurrentProcess(), hDuplicate, 0, 0, DUPLICATE_SAME_ACCESS) = 0 Then
        pvSetError Err.LastDllError
        GoTo QH
    End If
    Set m_oSocket = New cAsyncSocket
    If Not m_oSocket.Attach(hDuplicate) Then
        pvSetError m_oSocket.LastError
        GoTo QH
    End If
QH:
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Public Sub Close_()
    Const FUNC_NAME     As String = "Close_"
    
    On Error GoTo EH
    If Not m_oSocket Is Nothing Then
        pvState = sckClosing
        m_oSocket.Close_
        Set m_oSocket = Nothing
    End If
    pvState = sckClosed
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Public Sub Bind(Optional ByVal LocalPort As Long, Optional LocalIP As String)
    Const FUNC_NAME     As String = "Bind"
    
    On Error GoTo EH
    Close_
    If Not pvSocket.Bind(LocalIP, LocalPort) Then
        pvSetError pvSocket.LastError
    End If
    pvState = sckOpen
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Public Sub Connect(Optional RemoteHost As String, Optional ByVal RemotePort As Long)
    Const FUNC_NAME     As String = "Connect"
    
    On Error GoTo EH
    Close_
    If LenB(RemoteHost) <> 0 Then
        m_sRemoteHost = RemoteHost
    End If
    If RemotePort <> 0 Then
        m_lRemotePort = RemotePort
    End If
    pvState = sckResolvingHost
    If Not pvSocket.Connect(m_sRemoteHost, m_lRemotePort) Then
        pvSetError pvSocket.LastError
    End If
    pvState = sckConnected
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Public Sub Listen()
    Const FUNC_NAME     As String = "Listen"
    
    On Error GoTo EH
    Close_
    If Not pvSocket.Listen() Then
        pvSetError pvSocket.LastError
    End If
    pvState = sckListening
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Public Sub PeekData(data As Variant, Optional ByVal type_ As Long, Optional ByVal maxLen As Long = -1)
    Const FUNC_NAME     As String = "PeekData"
    Dim baBuffer()      As Byte
    Dim lIdx            As Long
    
    On Error GoTo EH
    If type_ = 0 Then
        type_ = VarType(data)
    End If
    Select Case type_
    Case vbString, vbByte + vbArray
    Case Else
        Err.Raise vbObjectError, , "Unsupported data type: " & type_
    End Select
    If maxLen < 0 Then
        If pvSocket.AvailableBytes <= 0 Then
            baBuffer = vbNullString
        Else
            pvSocket.SyncReceiveArray baBuffer, Timeout:=m_lTimeout
        End If
    Else
        pvSocket.SyncReceiveArray baBuffer, maxLen, Timeout:=m_lTimeout
    End If
    Select Case type_
    Case vbString
        data = pvSocket.FromTextArray(baBuffer, ucsScpAcp)
    Case vbByte + vbArray
        data = baBuffer
    End Select
    If UBound(m_baRecvBuffer) >= 0 And UBound(baBuffer) >= 0 Then
        lIdx = UBound(m_baRecvBuffer) + 1
        ReDim Preserve m_baRecvBuffer(0 To lIdx + UBound(baBuffer))
        Call CopyMemory(m_baRecvBuffer(lIdx), baBuffer(0), UBound(baBuffer) + 1)
    Else
        m_baRecvBuffer = baBuffer
    End If
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Public Sub GetData(data As Variant, Optional ByVal type_ As Long, Optional ByVal maxLen As Long = -1)
    Const FUNC_NAME     As String = "GetData"
    Dim lIdx            As Long
    Dim baBuffer()      As Byte
    
    On Error GoTo EH
    If type_ = 0 Then
        type_ = VarType(data)
    End If
    Select Case type_
    Case vbString, vbByte + vbArray
    Case Else
        Err.Raise vbObjectError, , "Unsupported data type: " & type_
    End Select
    baBuffer = vbNullString
    If UBound(m_baRecvBuffer) >= 0 Then
        If maxLen < 0 Then
            baBuffer = m_baRecvBuffer
            m_baRecvBuffer = vbNullString
        ElseIf maxLen = 0 Then
            baBuffer = vbNullString
        Else
            baBuffer = m_baRecvBuffer
            lIdx = UBound(m_baRecvBuffer) + 1 - maxLen
            If lIdx > 0 Then
                ReDim m_baRecvBuffer(0 To lIdx - 1) As Byte
                Call CopyMemory(m_baRecvBuffer(0), baBuffer(maxLen), lIdx)
                ReDim Preserve baBuffer(0 To maxLen - 1)
            Else
                m_baRecvBuffer = vbNullString
            End If
        End If
    Else
        If maxLen < 0 Then
            If pvSocket.AvailableBytes <= 0 Then
                baBuffer = vbNullString
            Else
                pvSocket.SyncReceiveArray baBuffer, Timeout:=m_lTimeout
            End If
        Else
            pvSocket.SyncReceiveArray baBuffer, maxLen, Timeout:=m_lTimeout
        End If
    End If
    Select Case type_
    Case vbString
        data = pvSocket.FromTextArray(baBuffer, ucsScpAcp)
    Case vbByte + vbArray
        data = baBuffer
    End Select
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Public Sub SendData(data As Variant)
    Const FUNC_NAME     As String = "SendData"
    
    On Error GoTo EH
    Select Case VarType(data)
    Case vbString
        m_baSendBuffer = pvSocket.ToTextArray(CStr(data), ucsScpAcp)
    Case vbByte + vbArray
        m_baSendBuffer = data
    Case Else
        Err.Raise vbObjectError, , "Unsupported data type: " & TypeName(data)
    End Select
    If UBound(m_baSendBuffer) >= 0 Then
        m_lSendPos = 0
        m_oSocket_OnSend
    End If
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Private Sub pvSetError(ByVal lLastDllError As Long, Optional sSource As String)
    Dim bCancel         As Boolean
    
    pvState = sckError
    RaiseEvent Error(vbObjectError, pvSocket.GetErrorDescription(lLastDllError), lLastDllError, sSource, App.HelpFile, 0, bCancel)
    If Not bCancel Then
        Err.Raise vbObjectError, sSource, pvSocket.GetErrorDescription(lLastDllError), App.HelpFile, 0
    End If
End Sub

'=========================================================================
' Socket events
'=========================================================================

Private Sub m_oSocket_OnConnect()
    pvState = sckConnected
    RaiseEvent Connect
End Sub

Private Sub m_oSocket_OnClose()
    pvState = sckClosed
    RaiseEvent CloseEvent
End Sub

Private Sub m_oSocket_OnAccept()
    Const FUNC_NAME     As String = "m_oSocket_OnAccept"
    Dim oTemp           As cAsyncSocket
    
    On Error GoTo EH
    pvState = sckConnectionPending
    Set oTemp = New cAsyncSocket
    If Not m_oSocket.Accept(oTemp) Then
        pvSetError m_oSocket.LastError
        GoTo QH
    End If
    RaiseEvent ConnectionRequest(oTemp.SocketHandle)
    pvState = sckListening
QH:
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Private Sub m_oSocket_OnResolve(IpAddress As String)
    pvState = sckHostResolved
End Sub

Private Sub m_oSocket_OnReceive()
    RaiseEvent DataArrival(pvSocket.AvailableBytes)
End Sub

Private Sub m_oSocket_OnSend()
    Const FUNC_NAME     As String = "m_oSocket_OnSend"
    Dim lSent           As Long
    
    On Error GoTo EH
    Do While m_lSendPos <= UBound(m_baSendBuffer)
        lSent = pvSocket.Send(VarPtr(m_baSendBuffer(m_lSendPos)), UBound(m_baSendBuffer) + 1 - m_lSendPos, m_sRemoteHost, m_lRemotePort)
        If lSent < 0 Then
            pvSetError pvSocket.LastError
            GoTo QH
        ElseIf pvSocket.LastError = sckWouldBlock Then
            GoTo QH
        Else
            m_lSendPos = m_lSendPos + lSent
            RaiseEvent SendProgress(m_lSendPos, UBound(m_baSendBuffer) + 1)
        End If
    Loop
    If m_lSendPos > UBound(m_baSendBuffer) Then
        m_lSendPos = 0
        m_baSendBuffer = vbNullString
        RaiseEvent SendComplete
    End If
QH:
    Exit Sub
EH:
    PrintError FUNC_NAME
    Resume Next
End Sub

Private Sub m_oSocket_OnError(ByVal ErrorCode As Long, ByVal EventMask As UcsAsyncSocketEventMaskEnum)
    pvSetError ErrorCode
End Sub

'=========================================================================
' Control events
'=========================================================================

Private Sub UserControl_Resize()
    Width = ScaleX(32, vbPixels)
    Height = ScaleX(32, vbPixels)
    labLogo.Move 0, (ScaleHeight - labLogo.Height) / 2, ScaleWidth
End Sub

Private Sub UserControl_ReadProperties(PropBag As PropertyBag)
    With PropBag
        LocalPort = .ReadProperty("LocalPort", DEF_LOCALPORT)
        Protocol = .ReadProperty("Protocol", DEF_PROTOCOL)
        RemoteHost = .ReadProperty("RemoteHost", DEF_REMOTEHOST)
        RemotePort = .ReadProperty("RemotePort", DEF_REMOTEPORT)
        Timeout = .ReadProperty("Timeout", DEF_TIMEOUT)
    End With
End Sub

Private Sub UserControl_WriteProperties(PropBag As PropertyBag)
    With PropBag
        .WriteProperty "LocalPort", LocalPort, DEF_LOCALPORT
        .WriteProperty "Protocol", Protocol, DEF_PROTOCOL
        .WriteProperty "RemoteHost", RemoteHost, DEF_REMOTEHOST
        .WriteProperty "RemotePort", RemotePort, DEF_REMOTEPORT
        .WriteProperty "Timeout", Timeout, DEF_TIMEOUT
    End With
End Sub

Private Sub UserControl_Initialize()
    m_baRecvBuffer = vbNullString
    m_baSendBuffer = vbNullString
End Sub