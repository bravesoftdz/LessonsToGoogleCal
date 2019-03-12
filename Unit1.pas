unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.OleCtrls, SHDocVw, Vcl.StdCtrls,
  GoogleOAuth, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, DBXJSON,
  IdHTTP, IdIOHandler, IdStack, IdException, IdIOHandlerSocket, IdIOHandlerStack, IdSSL, IdSSLOpenSSL,
  Vcl.ExtCtrls, IdCoder, IdCoder3to4, IdCoderMIME, ComObj, ActiveX, Registry,
 Vcl.ComCtrls, Grids, inifiles, Vcl.Menus;

 const MY_MESSAGE = WM_USER + 4242;

type

   TGoogleAuthThread = class(TThread)
    private
    { Private declarations }
  protected
    procedure Execute; override;
  public
      FormHandle: HWND;
      procedure IsTerminate(Sender : TObject);
  end;



  TMyGrid = class (TStringGrid);

  TForm1 = class(TForm)
    OAuth1: TOAuth;
    edToken: TEdit;
    IdHTTP1: TIdHTTP;
    IdSSLIOHandlerSocketOpenSSL1: TIdSSLIOHandlerSocketOpenSSL;
    Calendars: TComboBox;
    OpenXls: TOpenDialog;
    btnOpenXls: TButton;
    PageControl1: TPageControl;
    btnSendEvents: TButton;
    btnGetGoogleCalendars: TButton;
    btnConfirm: TButton;
    btnClearCalendar: TButton;
    StatusBar1: TStatusBar;
    lbEventsCount: TLabel;
    ComboBox1: TComboBox;
    ComboBox2: TComboBox;
    Label1: TLabel;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Optios1: TMenuItem;
    Info1: TMenuItem;
    Exit1: TMenuItem;
    Panel1: TPanel;
    Timer1: TTimer;
    cbSetAllAtendeers: TCheckBox;
    Label3: TLabel;



    procedure Button5Click(Sender: TObject);
    procedure btnOpenXlsClick(Sender: TObject);
    procedure btnSendEventsClick(Sender: TObject);
    procedure InsertEvent(Source:TStringStream);
    procedure btnGetGoogleCalendarsClick(Sender: TObject);
    procedure getCalendarsList;
    procedure btnConfirmClick(Sender: TObject );
    procedure CalendarsChange(Sender: TObject);
    procedure btnClearCalendarClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure AddRegistry;
    procedure MessageReceiver(var msg: TMessage); message MY_MESSAGE;
    procedure Optios1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure cbSetAllAtendeersClick(Sender: TObject);
    



  private
     procedure OnClickCb(Sender: TObject);
    { Private declarations }
  public
     FJSONObject: TJSONObject;
     GoogleAuthThread: TGoogleAuthThread;
    { Public declarations }
  end;



var
  Form1: TForm1;
  GoogleAuthThread: TGoogleAuthThread;
  Token:string;
  MyExcel: OleVariant;
  Cb:TCheckBox;
  Te:TEdit;
  ApplicationPath,ApplicationName, calendarID:string;
   ExcelStatus, GAuothStatus:boolean;
  const ExcelApp = 'Excel.Application';


implementation
   uses  Unit2, Unit3, Unit4, Unit5;
{$R *.dfm}


procedure TForm1.OnClickCb(Sender: TObject);
    var tab:string;
    begin
      tab:=IntToStr(PageControl1.ActivePageIndex);
     if (Sender as TCheckBox).Checked
       then (PageControl1.Pages[PageControl1.ActivePageIndex].Components[2] as TEdit).Visible := true
       else (PageControl1.Pages[PageControl1.ActivePageIndex].Components[2] as TEdit).Visible := false;
    end;



procedure TForm1.Optios1Click(Sender: TObject);
begin
 Form2.Show;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Form1.StatusBar1.Panels[3].Text:='';
  Timer1.Enabled:=false;
  Timer1.Interval:=5000;
end;

// display popup messages
procedure ShowNotification(NotifMessage: string);
begin
  //TNotification.Create(Self);
  //Notification.NotifMessage.Caption:=NotifMessage;
  Form1.StatusBar1.Panels[3].Text:=NotifMessage;
  Form1.Timer1.Enabled:=true;
  //Notification.Show;

end;

//�������� �������� ������������� Excel
function CheckExcelInstall:boolean;
var
  ClassID: TCLSID;
  Rez : HRESULT;
begin
// ���� CLSID OLE-�������
  Rez := CLSIDFromProgID(PWideChar(WideString(ExcelApp)), ClassID);
  if Rez = S_OK then  // ������ ������
    Result := true
  else
    Result := false;
end;

//�������� �� ��������� Excel
function CheckExcelRun: boolean;
begin
  try
    MyExcel:=GetActiveOleObject(ExcelApp);
    Result:=True;
  except
    Result:=false;
  end;
end;

//������ Excel
function RunExcel(DisableAlerts:boolean=true; Visible: boolean=false): boolean;
begin
  try
{��������� ���������� �� Excel}
    if CheckExcelInstall then
      begin
        MyExcel:=CreateOleObject(ExcelApp);
//����������/�� ���������� ��������� ��������� Excel (����� �� ����������)
        MyExcel.Application.EnableEvents:=DisableAlerts;
        MyExcel.Visible:=Visible;
        Result:=true;

      end
    else
      begin
        MessageBox(0,'���������� MS Excel �� ����������� �� ���� ����������','������',MB_OK+MB_ICONERROR);
        Result:=false;
      end;
  except
    Result:=false;
  end;
end;

// ��������� Excel
function StopExcel:boolean;
begin
  try
    if MyExcel.Visible then MyExcel.Visible:=false;
    MyExcel.Quit;
    MyExcel:=Unassigned;
    Result:=True;
  except
    Result:=false;
  end;
end;




procedure xls_open(FileName:WideString);
var Rows, TotalRows, Cols, i,j,z,m: integer;
    WorkSheet: OLEVariant;
    FData: OLEVariant;
    d: TDateTime;
    NPageControl: TPageControl;
    NTab: TTabSheet;
    Sg: TStringGrid;
    Cb:TCheckBox;
    Te:TEdit;

  key:string;
  buf, attendee:string;
  SaveSettings:TextFile;
  s1: TStringList;

begin
    Settings:=TiniFile.Create(extractfilepath(paramstr(0))+'Settings.ini');
    if (Settings.SectionExists('Attendees')) then
   begin
     s1 := TStringList.Create;
     Settings.ReadSectionValues('Attendees',s1);
  end;
   // AssignFile(SettingsFile,extractfilepath(paramstr(0))+'Settings.ini');
      RunExcel;
  //��������� �����
  MyExcel.Workbooks.Open(FileName);
//������� ������ � �������
 TotalRows:=0;
for i :=1  to MyExcel.Sheets.Count do
  begin
  //�������� �������� ����
  WorkSheet:=MyExcel.ActiveWorkbook.Worksheets.Item[i];
  //���������� ���������� ����� � �������� �������
  Rows:=WorkSheet.UsedRange.Rows.Count;
  Cols:=WorkSheet.UsedRange.Columns.Count;
  NTab := TTabSheet.Create(Form1.PageControl1);
   with NTab do
    begin
      PageControl:= Form1.PageControl1;
      Form1.PageControl1.Brush.Color  := RGB(211,231,232);
      Form1.PageControl1.Pages[PageIndex].Brush.Color:=clYellow;
      PageControl.ClientWidth:=475;
      Ntab.ClientWidth:=470;
     // Caption := String(MyExcel.Sheets.Item[i].Name);
      caption:=String(MyExcel.ActiveWorkbook.Worksheets.Item[i].Name);
      Sg:=TStringGrid.Create(NTab);
      Sg.Parent:=NTab;
      Sg.FixedCols:=0;Sg.FixedRows:=0;
      Sg.Clientwidth:=PageControl.ClientWidth-25;
      Sg.ShowHint:=True;
      Sg.DefaultColWidth := 80;
      Sg.ColWidths[0] := 25; //   index column
      Sg.ColWidths[1] := 70; //   date column
      Sg.ColWidths[2] := 30; //   lesson order colum
      Sg.ColWidths[3] := 42; //   cabinet number
      Sg.ColWidths[4] := 100; //   index column
      Sg.Height:=220;
      Sg.ScrollBars:=ssBoth;

      Cb:=TCheckBox.Create(NTab);
      Cb.Parent:=NTab;
      TCheckBox(Cb).OnClick:=Form1.OnClickCb;
      Cb.Caption:='���������...';
      Cb.Top:=225;

      Te:=TEdit.Create(NTab);
      Te.Parent:=NTab;
      Te.Visible:=true;
      Te.Text:='email';
      //set attendee emails
      if (Settings.SectionExists('Attendees')) then
        for m:=1 to s1.Count do
        begin
          attendee:=UTF8ToString(s1[m-1]);
          key:=Copy(attendee, 1, Pos('=',attendee)-1);
        if ((Pos('=',attendee) <> 0) and (key=MyExcel.ActiveWorkbook.Worksheets.Item[i].Name))
          then begin
          Te.Text:=(String(Copy(attendee, Pos( '=',attendee) + 1, Length(attendee) - Pos('=',attendee) ) ));
          Cb.Checked:=true;
          end;
        end;

      Te.Top:=225;
      Te.Left:=150;


     end;
      Sg.RowCount:=Rows;
      //TotalRows:=TotalRows+Rows;
      Sg.ColCount:=Cols;
    z:=0;
     (Form1.PageControl1.Pages[0].Components[0] as TStringGrid).Width := 470;
    //Form1.ProgressBar1.Max:=ProgressBar1.Max+(Sg.ColCount+Sg.RowCount);
    FData:=WorkSheet.UsedRange.Value;
            while (z<=sg.RowCount-1) do begin
            for j := 0 to Cols-1 do
              sg.Cells[j,z]:=FData[z+1,j+1];
              if Trim(Sg.Rows[z].Text) = '' then begin
                TMyGrid(Sg).DeleteRow(z);
                z:=z-1;
                //TotalRows:=TotalRows-1;
                end;   //��������� ������ �����
              z:=z+1;
            end;
            TotalRows:=TotalRows+z-1;
                     end;


   Form1.StatusBar1.Panels[0].width:=150;
   Form1.StatusBar1.Panels[0].text:='Excel'+'�����:'+String(MyExcel.Sheets.Count)+'  �����:-'+IntToStr(TotalRows);
   s1.Free;
   Settings.Free;
   StopExcel;
   ShowNotification('Excel file is loaded');
   ExcelStatus:=true;
   Form1.Height:=415;
   Form1.PageControl1.Visible:=true;


end;


//take path of xls-file from open-dialog
procedure TForm1.btnOpenXlsClick(Sender: TObject);
var FileName:string;
begin
 OpenXls.Filter :=' ����� MS Excel|*.xls;*.xlsx|';
  if OpenXls.InitialDir = '' then
    OpenXls.InitialDir := ExtractFilePath(Application.ExeName);
  if not OpenXls.Execute then Exit;
  FileName := OpenXls.FileName;
  xls_open (WideString(FileName));
  //Label1.Caption:=String('����: ')+string(FileName);
  if not FileExists(FileName) then begin
    ShowMessage('�����! ���� � �������� ������ ��������. ĳ� ���������.');
    Exit;
  end;
end;






procedure TForm1.btnSendEventsClick(Sender: TObject);
 var
  tabs, i,j,z:integer;
  summary, color_id, dtstart, dtend, capt, desc,event, tab, guest,mail_guest:string;
 //JSON
    JSONObject, InnerObject : TJSONObject;
    Pair : TJSONPair;
    JsonArray: TJSONArray;
    S:TStringList;
    Source1: TStringStream;
  begin
    S:=TStringList.Create;
        //  Memo4.Clear;
          {������� ������ �������� ������}
  try
     for tabs:=0 to PageControl1.PageCount-1 do
    begin
   if ((PageControl1.Pages[tabs].Components[1] as TCheckBox).Checked = True) then
      mail_guest:=(PageControl1.Pages[tabs].Components[2] as TEdit).Text;
    for z:=0 to PageControl1.Pages[tabs].ComponentCount-1 do
      if  PageControl1.Pages[tabs].Components[z] is TStringGrid then
        begin

         for i:=1 to (PageControl1.Pages[tabs].Components[z] as TStringGrid).RowCount-1 do
      begin
         if True then
           begin
         //if (StrToDate((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[1,i]))<Now
         //then label1.Caption:=DateToStr((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[1,i]);
         JSONObject:=TJSONObject.Create;
         // Memo4.Clear;

         {������� ����}
          Pair:=TJSONPair.Create('summary',(PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[2,i]+' ����: '+String(PageControl1.Pages[tabs].Caption));
          {�������� ���� � ������}
          JSONObject.AddPair(Pair);

          {���������� � ������ ������}
          //������� ������ ������
          JsonArray:=TJSONArray.Create();
          dtstart:=Copy((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[1,i], 7, 4)+'-'+Copy((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[1,i], 4, 2)+'-'+Copy((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[1,i], 1, 2)+'T'+Form2.StringGrid1.Cells[1,StrToInt((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[2,i])]+':00+02:00';
          label1.Caption:=dtstart;
          JsonArray.AddElement(TJSONObject.Create(TJSONPair.Create('dateTime',dtstart)));
          JsonArray.AddElement(TJSONObject.Create(TJSONPair.Create('timeZone','Europe/Kiev')));
          //�������� ������ � ������
          JSONObject.AddPair('start',JsonArray);

          JsonArray:=TJSONArray.Create();
          dtend:=Copy((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[1,i], 7, 4)+'-'+Copy((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[1,i], 4, 2)+'-'+Copy((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[1,i], 1, 2)+'T'+Form2.StringGrid1.Cells[2,StrToInt((PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[2,i])]+':00+02:00';
          JsonArray.AddElement(TJSONObject.Create(TJSONPair.Create('dateTime',dtend)));
          JsonArray.AddElement(TJSONObject.Create(TJSONPair.Create('timeZone','Europe/Kiev')));
          //�������� ������ � ������
          JSONObject.AddPair('end',JsonArray);
        //  JsonArray.Destroy;

          if (mail_guest<>'') then
          begin
          JsonArray:=TJSONArray.Create();
          JsonArray.AddElement(TJSONObject.Create(TJSONPair.Create('email',mail_guest)));
          //�������� ������ � ������
          JSONObject.AddPair('attendees',JsonArray);
          end;
           {������� ����}
          desc:='���� �'+(PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[0,i]+': '+(PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[4,i]+'\n�/�: � ���������:'+(PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[5,i]+'\n��������:'+(PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[6,i];
          Pair:=TJSONPair.Create('description',desc);
          {�������� ���� � ������}
          JSONObject.AddPair(Pair);

          Pair:=TJSONPair.Create('location','������ '+(PageControl1.Pages[tabs].Components[z] as TStringGrid).Cells[3,i]);
          JSONObject.AddPair(Pair);


          color_id:=String(PageControl1.Pages[tabs].Caption);
          delete(color_id, length(color_id), 1);

          Pair:=TJSONPair.Create('colorId',string(color_id));
          JSONObject.AddPair(Pair);

            Source1:=TStringStream.Create;
            S.Add(JSONObject.ToString);
            S.SaveToStream(Source1);
            //ShowMessage(Source1.DataString);
            InsertEvent(Source1);
           // memo4.Lines.Add(Source1.DataString);
            JsonObject.Destroy;
            Source1.Destroy;
            S.Clear;
       end;
      end;

    end;
      // Source:=S;
      // Memo4.Text:=S.Text;

       S.Clear;

       //ShowMessage(S.Text);
    end;
     finally
           S.Free;
           ShowNotification('Events is added to GCalendar');
          // JSONObject.Destroy;


  end;


end;



procedure TForm1.btnGetGoogleCalendarsClick(Sender: TObject);
begin
//GetSecretCode;
Form3.Show;
Form3.PopupBrowser.Navigate(OAuth1.AccessURL);
//Token.Visible:=true;
edToken.Text:=access;
//nConfirm.Visible:=true;
end;


// ������� Token: ������� �������� ��������� ����
function getToken(SecretCode:string):string;
begin
Form1.OAuth1.ResponseCode:=SecretCode;
Token:=Form1.OAuth1.GetAccessToken;
Token:=Trim(Token);
Result:=Token;
end;

procedure TForm1.getCalendarsList;
 var URL:string;
      i:integer;
      JsonArray: TJSONArray;
     begin
  URL:='https://www.googleapis.com/calendar/v3/users/me/calendarList?access_token='+Token;
  {�������}
 FJSONObject:=TJSONObject.ParseJSONValue(Form1.IdHTTP1.Get(URL))as TJSONObject;
 Calendars.Clear;
 Calendars.Text:='Select the calendar...';
 {�������� ������ �� �������� ���� � ��������� "items"}
  JsonArray:=FJSONObject.Get('items').JsonValue as TJSONArray;
  for I := 0 to JsonArray.Size-1 do
      Calendars.Items.Add((JsonArray.Get(i) as TJSONObject).Get('summary').JsonValue.Value);
 {����: ���� �����}
  end;
// ������
procedure TGoogleAuthThread.Execute;
begin
  OnTerminate := IsTerminate;
  Token:=getToken(Form1.edToken.Text);
  //if Token<>'' then Terminated:=true;

end;

procedure TGoogleAuthThread.IsTerminate(Sender : TObject);
begin
  with Sender as TGoogleAuthThread do begin
    //��� ���������� ������ ��������� ������� ������� �� �������.
    Form1.getCalendarsList;
    ShowNotification('������ �� ��������� Google ��������');
    //SendMessage(Form1.Handle,MY_MESSAGE,0,DWORD(PChar('������ �� ��������� Google ��������')));
    GAuothStatus:=true;
    Form1.Calendars.Visible:=true;
    Form1.StatusBar1.Panels[1].text:='Google: ������ ��������';
     end;
//    Form1.Width:=Form1.Width+100;
    //Form1.Panel1.Left:=Form1.PageControl1.Left+Form1.PageControl1.Width+10;
    //Form1.Panel1.Top:=Form1.PageControl1.Top+10;
    Form1.Panel1.Top:=Form1.btnGetGoogleCalendars.Top;
    Form1.Panel1.Left:=Form1.btnGetGoogleCalendars.Left+120;
    Form1.Panel1.Visible:=true;
    Form1.cbSetAllAtendeers.Visible:=true;
end;
// ������




procedure TForm1.btnClearCalendarClick(Sender: TObject);
var URL, id:string;
  i:integer;
  JsonArrayEvents: TJSONArray;
  FJSONObjectCalendar:TJSONObject;
begin
{IdHTTP1.HandleRedirects := true;}
 ComboBox2.Clear;
 ComboBox2.Text:='Not Deleted....';
 URL:='https://www.googleapis.com/calendar/v3/calendars/'+calendarId+'/events/?access_token='+Token+'&maxResults=2500';
 //URL:='https://www.googleapis.com/calendar/v3/users/me/calendarList?access_token='+Token;
 {�������}
 FJSONObjectCalendar:=TJSONObject.ParseJSONValue(IdHTTP1.Get(URL))as TJSONObject;
// FJSONObject:=TJSONObject.ParseJSONValue(Form1.IdHTTP1.Get(URL))as TJSONObject;
 {�������� ������ �� �������� ���� � ��������� "items"}
  JsonArrayEvents:=FJSONObjectCalendar.Get('items').JsonValue as TJSONArray;
  for I := 0 to JsonArrayEvents.Size-1 do
  begin
      id:=(JsonArrayEvents.Get(i) as TJSONObject).Get('id').JsonValue.Value;
      if ((JsonArrayEvents.Get(i) as TJSONObject).Get('status').JsonValue.Value)='confirmed' then
        begin
        URL:='https://www.googleapis.com/calendar/v3/calendars/'+calendarId+'/events/'+id+'/?access_token='+Token;
        IdHTTP1.Delete(URL);
        end
      else ComboBox2.Items.Add(Id);
     end;
  JsonArrayEvents.Free;
  {����: ���� �����}

end;

procedure TForm1.btnConfirmClick(Sender: TObject);
begin
  btnConfirm.Enabled:=false;
  GoogleAuthThread:=TGoogleAuthThread.Create(true);
  GoogleAuthThread.Priority:=tpNormal;
  GoogleAuthThread.FormHandle := Self.Handle;
  GoogleAuthThread.FreeOnTerminate := false;
  GoogleAuthThread.Resume;
 //Memo1.Lines.Add('Access Token = '+Token);//�������� �����
end;



procedure TForm1.InsertEvent(Source:TStringStream);
var Response: TStringStream;
URL:string;
begin
    Token:=UTF8Encode(Token);
    URL:='https://www.googleapis.com/calendar/v3/calendars/'+calendarID+'/events?access_token='+Token;
    idHTTP1.Request.ContentType := 'application/json';
    idHTTP1.Request.CharSet := 'windows-1251';
    IdHTTP1.HandleRedirects := True;
  try
  //Source:=TStringStream.Create;
  try
    Response:=TStringStream.Create;
    try
       //Memo4.Lines.SaveToStream(Source);
       //ShowMessage(Source.DataString);
       idHTTP1.Post(URL,Source,Response);
      // memo6.Clear;
      // memo6.Lines.Add(Response.DataString);
      // memo6.Text:=(UTF8Decode(Memo6.Text));
    finally
     Response.Free
    end;
  finally
    //Source.Free;
  end;
except
  on E:EIdHTTPProtocolException do
    begin
    //  memo6.Clear;
      showmessage(E.ErrorMessage);
    //  memo6.Lines.Add('-------------Error-------------');
    //  memo6.Lines.Add('-------------ErrorMessage-------------');
          end
  else
    raise;
end;
end;




// !!!!DELETE ??????????





procedure TForm1.Button5Click(Sender: TObject);
var JsonArray: TJSONArray;
    i: integer;
begin
  {�������� ������ �� �������� ���� � ��������� "items"}
  JsonArray:=FJSONObject.Get('items').JsonValue as TJSONArray;
  for I := 0 to JsonArray.Size-1 do
    // Memo2.Lines.Add((JsonArray.Get(i) as TJSONObject).Get('summary').JsonValue.Value)
end;

procedure TForm1.CalendarsChange(Sender: TObject);
var i:integer; JsonArray,JsonArrayEvents: TJSONArray;
  URL, EventId:string;
  Events:TJSONObject;
begin
  btnClearCalendar.Visible:=true;
  Form1.Panel1.Width:=235;
  if (ExcelStatus and GAuothStatus) then btnSendEvents.Visible:=true;
  lbEventsCount.Caption:='������ ����: ';
  ComboBox1.Clear;
  ComboBox1.Text:='Events ID....';
//Memo4.Clear;
 {�������� ������ �� �������� ���� � ��������� "items"}
  JsonArray:=FJSONObject.Get('items').JsonValue as TJSONArray;
  for I := 0 to JsonArray.Size-1 do begin
    if((JsonArray.Get(i) as TJSONObject).Get('summary').JsonValue.Value=Calendars.Text)
      then
      begin
  //    Memo4.Text := (JsonArray.Get(i) as TJSONObject).Get('id').JsonValue.Value;
      calendarID := (JsonArray.Get(i) as TJSONObject).Get('id').JsonValue.Value;
      end;
     end;

   URL:='https://www.googleapis.com/calendar/v3/calendars/'+calendarId+'/events/?access_token='+Token+'&maxResults=2500';
   Events:=TJSONObject.ParseJSONValue(IdHTTP1.Get(URL))as TJSONObject;
   JsonArrayEvents:=Events.Get('items').JsonValue as TJSONArray;
  for I := 0 to JsonArrayEvents.Size-1 do
  begin
      EventId:=(JsonArrayEvents.Get(i) as TJSONObject).Get('id').JsonValue.Value;
      ComboBox1.Items.Add(EventId);
  end;
   lbEventsCount.Caption:=lbEventsCount.Caption+IntTostr(i);
   end;





procedure TForm1.cbSetAllAtendeersClick(Sender: TObject);
  var tabs:integer;
begin
for tabs:=0 to PageControl1.PageCount-1 do
    begin
 if cbSetAllAtendeers.Checked then
       (PageControl1.Pages[tabs].Components[1] as TCheckBox).Checked := True
      //mail_guest:=(PageControl1.Pages[tabs].Components[2] as TEdit).Text;
 else  (PageControl1.Pages[tabs].Components[1] as TCheckBox).Checked := False
     end;
end;

procedure TForm1.Exit1Click(Sender: TObject);
begin
Form1.Close;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
Form1.Height:=160;
Form1.Width:=600;
Form1.PageControl1.Width:=510;
Form1.PageControl1.Top:=Form1.PageControl1.Top+20;

Form1.Left:= (Screen.WorkAreaWidth - Form1.Width) div 2;
Form1.Top:= (Screen.WorkAreaHeight - Form1.Height) div 2 - Screen.WorkAreaHeight div 4;

PageControl1.Visible:=false;
ExcelStatus:=false;
GAuothStatus:=false;
edToken.Visible:=false;
btnConfirm.Visible:=false;
Calendars.Visible:=false;
btnSendEvents.Visible:=false;
btnClearCalendar.Visible:=false;
StatusBar1.Width:=Form1.Width;
StatusBar1.Panels[0].width:=150;
StatusBar1.Panels[0].text:='Excel: �� �������';
StatusBar1.Panels[1].width:=150;
StatusBar1.Panels[1].text:='Google: ���� �������';

StatusBar1.Panels[3].width:=200;

 //�������� ��� ������������ ����� ��������� (��� ���� � ����).
  ApplicationName := ExtractFileName( ParamStr(0) );
  //���� � �����, � ������� ����� ����������� ���� ���������.
  ApplicationPath := ExtractFilePath( ParamStr(0) );
  AddRegistry;




end;


procedure TForm1.AddRegistry;
var
  Reg: TRegistry;
  RegKey: DWORD;
begin
  Reg := TRegistry.Create;
  try
     Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('SOFTWARE\Wow6432Node\Microsoft\Internet Explorer\MAIN\FeatureControl\FEATURE_BROWSER_EMULATION\', True) then
    begin
      if Reg.ValueExists(ApplicationName) then
        begin
         RegKey := Reg.ReadInteger(ApplicationName);
         if RegKey<8000 then Reg.WriteInteger(ApplicationName, 8000);
        end
      else Reg.WriteInteger(ApplicationName, 8000);
      Reg.CloseKey;
    end;
  finally
    Reg.Free
  end;
end;

 procedure TForm1.MessageReceiver(var msg: TMessage);
 var
   txt: PChar;
 begin
   txt := PChar(msg.lParam);
   msg.Result := 1;
   ShowMessage(txt);
 end;


end.
