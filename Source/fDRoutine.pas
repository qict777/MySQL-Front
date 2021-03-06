unit fDRoutine;

interface {********************************************************************}

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Menus,
  Dialogs, StdCtrls, ComCtrls, ExtCtrls,
  Forms_Ext, StdCtrls_Ext,
  SynEdit, SynMemo,
  fSession,
  fBase;

type
  TDRoutine = class(TForm_Ext)
    FBCancel: TButton;
    FBHelp: TButton;
    FBOk: TButton;
    FComment: TEdit;
    FCreated: TLabel;
    FDefiner: TLabel;
    FLComment: TLabel;
    FLCreated: TLabel;
    FLDefiner: TLabel;
    FLName: TLabel;
    FLSecurity: TLabel;
    FLSize: TLabel;
    FLUpdated: TLabel;
    FName: TEdit;
    FSecurityDefiner: TRadioButton;
    FSecurityInvoker: TRadioButton;
    FSize: TLabel;
    FSource: TSynMemo;
    FUpdated: TLabel;
    GBasics: TGroupBox_Ext;
    GDates: TGroupBox_Ext;
    GDefiner: TGroupBox_Ext;
    GSize: TGroupBox_Ext;
    msCopy: TMenuItem;
    msCut: TMenuItem;
    msDelete: TMenuItem;
    MSource: TPopupMenu;
    msPaste: TMenuItem;
    msSelectAll: TMenuItem;
    msUndo: TMenuItem;
    N1: TMenuItem;
    N2: TMenuItem;
    PageControl: TPageControl;
    PSQLWait: TPanel;
    TSBasics: TTabSheet;
    TSInformations: TTabSheet;
    TSSource: TTabSheet;
    procedure FBHelpClick(Sender: TObject);
    procedure FBOkCheckEnabled(Sender: TObject);
    procedure FCommentChange(Sender: TObject);
    procedure FNameChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FSecurityClick(Sender: TObject);
    procedure FSecurityKeyPress(Sender: TObject; var Key: Char);
    procedure FSourceChange(Sender: TObject);
  private
    procedure Built();
    procedure FormSessionEvent(const Event: TSSession.TEvent);
    procedure UMChangePreferences(var Message: TMessage); message UM_CHANGEPREFERENCES;
  public
    Database: TSDatabase;
    Routine: TSRoutine;
    RoutineType: TSRoutine.TRoutineType;
    function Execute(): Boolean;
  end;

function DRoutine(): TDRoutine;

implementation {***************************************************************}

{$R *.dfm}

uses
  StrUtils,
  SQLUtils,
  fPreferences;

var
  FRoutine: TDRoutine;

function DRoutine(): TDRoutine;
begin
  if (not Assigned(FRoutine)) then
  begin
    Application.CreateForm(TDRoutine, FRoutine);
    FRoutine.Perform(UM_CHANGEPREFERENCES, 0, 0);
  end;

  Result := FRoutine;
end;

{ TDRoutine *******************************************************************}

procedure TDRoutine.Built();
begin
  FName.Text := Routine.Name;

  case (Routine.Security) of
    seDefiner: FSecurityDefiner.Checked := True;
    seInvoker: FSecurityInvoker.Checked := True;
  end;
  FComment.Text := SQLUnwrapStmt(Routine.Comment, Database.Session.Connection.ServerVersion);

  if (Double(Routine.Created) = 0) then FCreated.Caption := '???' else FCreated.Caption := SysUtils.DateTimeToStr(Routine.Created, LocaleFormatSettings);
  if (Double(Routine.Modified) = 0) then FUpdated.Caption := '???' else FUpdated.Caption := SysUtils.DateTimeToStr(Routine.Modified, LocaleFormatSettings);
  FDefiner.Caption := Routine.Definer;

  FSize.Caption := FormatFloat('#,##0', Length(Routine.Source), LocaleFormatSettings);

  FSource.Text := Trim(Routine.Source) + #13#10;

  TSSource.TabVisible := Routine.Source <> '';

  FName.Enabled := False; FLName.Enabled := FName.Enabled;

  PageControl.Visible := True;
  PSQLWait.Visible := not PageControl.Visible;

  ActiveControl := FBCancel;
  if (PageControl.Visible) then
  begin
    PageControl.ActivePage := TSBasics;
    ActiveControl := FComment;
  end;
end;

function TDRoutine.Execute(): Boolean;
begin
  ShowModal();
  Result := ModalResult = mrOk;
end;

procedure TDRoutine.FBHelpClick(Sender: TObject);
begin
  Application.HelpContext(HelpContext);
end;

procedure TDRoutine.FBOkCheckEnabled(Sender: TObject);
var
  DDLStmt: TSQLDDLStmt;
  SQL: string;
begin
  SQL := Trim(FSource.Text);

  FBOk.Enabled := (not Assigned(Routine) or Assigned(Routine) and (Routine.Source <> ''))
    and (not TSBasics.Visible or not Assigned(Routine) or (FName.Text <> '') and ((lstrcmpi(PChar(FName.Text), PChar(Routine.Name)) = 0) or ((Routine.RoutineType = rtProcedure) and not Assigned(Database.ProcedureByName(FName.Text)) or ((Routine.RoutineType = rtFunction) and not Assigned(Database.FunctionByName(FName.Text))))))
    and (not TSSource.Visible or SQLSingleStmt(FSource.Text) and SQLParseDDLStmt(DDLStmt, PChar(FSource.Text), Length(FSource.Text), Database.Session.Connection.ServerVersion) and (DDLStmt.DefinitionType = dtCreate) and (DDLStmt.ObjectType in [otProcedure, otFunction]) and ((DDLStmt.DatabaseName = '') or (Database.Session.DatabaseByName(DDLStmt.DatabaseName) = Database)));

  TSInformations.TabVisible := False;
end;

procedure TDRoutine.FCommentChange(Sender: TObject);
begin
  TSSource.TabVisible := False;

  FBOkCheckEnabled(Sender);
end;

procedure TDRoutine.FNameChange(Sender: TObject);
begin
  TSSource.TabVisible := False;

  FBOkCheckEnabled(Sender);
end;

procedure TDRoutine.FormSessionEvent(const Event: TSSession.TEvent);
begin
  if ((Event.EventType = etItemValid) and (Event.SItem = Routine)) then
    Built()
  else if ((Event.EventType in [etItemCreated, etItemAltered]) and (Event.SItem is TSRoutine)) then
    Close()
  else if ((Event.EventType = etAfterExecuteSQL) and (Event.Session.Connection.ErrorCode <> 0)) then
  begin
    PageControl.Visible := True;
    PSQLWait.Visible := not PageControl.Visible;
  end;
end;

procedure TDRoutine.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  NewRoutine: TSRoutine;
begin
  if ((ModalResult = mrOk) and PageControl.Visible) then
  begin
    if (not Assigned(Routine)) then
    begin
      if (RoutineType = rtProcedure) then
        NewRoutine := TSProcedure.Create(Database.Routines)
      else
        NewRoutine := TSFunction.Create(Database.Routines);
      NewRoutine.Source := Trim(FSource.Text);

      CanClose := Database.AddRoutine(NewRoutine);

      NewRoutine.Free();
    end
    else if (TSSource.Visible) then
    begin
      if (RoutineType = rtProcedure) then
        NewRoutine := TSProcedure.Create(Database.Routines)
      else
        NewRoutine := TSFunction.Create(Database.Routines);
      NewRoutine.Source := Trim(FSource.Text);

      CanClose := Database.UpdateRoutine(Routine, NewRoutine);

      NewRoutine.Free();
    end
    else
    begin
      NewRoutine := TSRoutine.Create(Database.Routines);
      if (Assigned(Routine)) then
        NewRoutine.Assign(Routine);

      NewRoutine.Name := Trim(FName.Text);
      if (FSecurityDefiner.Checked) then
        NewRoutine.Security := seDefiner
      else if (FSecurityInvoker.Checked) then
        NewRoutine.Security := seInvoker;
      if (not Assigned(Routine) or (Trim(FComment.Text) <> SQLUnwrapStmt(Routine.Comment, Database.Session.Connection.ServerVersion))) then
        NewRoutine.Comment := Trim(FComment.Text);

      CanClose := Database.UpdateRoutine(Routine, NewRoutine);

      NewRoutine.Free();
    end;

// UpdateRoutine uses ExecuteSQL (not SendSQL). Because of this,
// FormSessionEvent will be called inside UpdateRoutine - and this code is
// hided the PageControl permanentely
//    if (not CanClose) then
//    begin
//      ModalResult := mrNone;
//      PageControl.Visible := CanClose;
//      PSQLWait.Visible := not PageControl.Visible;
//    end;

    FBOk.Enabled := False;
  end;
end;

procedure TDRoutine.FormCreate(Sender: TObject);
begin
  Constraints.MinWidth := Width;
  Constraints.MinHeight := Height;

  BorderStyle := bsSizeable;

  FSource.Highlighter := MainHighlighter;
end;

procedure TDRoutine.FormHide(Sender: TObject);
begin
  Database.Session.UnRegisterEventProc(FormSessionEvent);

  Preferences.Routine.Width := Width;
  Preferences.Routine.Height := Height;
end;

procedure TDRoutine.FormShow(Sender: TObject);
var
  I: Integer;
  RoutineName: string;
begin
  Database.Session.RegisterEventProc(FormSessionEvent);

  if ((Preferences.Routine.Width >= Width) and (Preferences.Routine.Height >= Height)) then
  begin
    Width := Preferences.Routine.Width;
    Height := Preferences.Routine.Height;
  end;

  if (not Assigned(Routine)) then
  begin
    Caption := Preferences.LoadStr(775);
    Preferences.SmallImages.GetIcon(iiProcedure, Icon);
    HelpContext := 1097;
  end
  else if (Routine.RoutineType = rtProcedure) then
  begin
    Caption := Preferences.LoadStr(842, Routine.Name);
    Preferences.SmallImages.GetIcon(iiProcedure, Icon);
    HelpContext := 1099;
  end
  else if (Routine.RoutineType = rtFunction) then
  begin
    Caption := Preferences.LoadStr(842, Routine.Name);
    Preferences.SmallImages.GetIcon(iiFunction, Icon);
    HelpContext := 1099;
  end;

  FName.Enabled := False; FLName.Enabled := FName.Enabled;
  FComment.Enabled := True; FLComment.Enabled := FComment.Enabled;

  if (not Assigned(Routine)) then
  begin
    if (RoutineType = rtProcedure) then
    begin
      RoutineName := Preferences.LoadStr(863);
      I := 2;
      while (Assigned(Database.ProcedureByName(RoutineName))) do
      begin
        RoutineName := Preferences.LoadStr(863) + IntToStr(I);
        Inc(I);
      end;

      FSource.Lines.Clear();
      FSource.Lines.Add('CREATE PROCEDURE ' + Database.Session.Connection.EscapeIdentifier(RoutineName) + '(' + Database.Session.Connection.EscapeIdentifier('Param') + ' int(11))');
      FSource.Lines.Add('BEGIN');
      FSource.Lines.Add('END;');
    end
    else if (RoutineType = rtFunction) then
    begin
      RoutineName := Preferences.LoadStr(864);
      I := 2;
      while (Assigned(Database.FunctionByName(RoutineName))) do
      begin
        RoutineName := Preferences.LoadStr(864) + IntToStr(I);
        Inc(I);
      end;

      FSource.Lines.Clear();
      FSource.Lines.Add('CREATE FUNCTION ' + Database.Session.Connection.EscapeIdentifier(RoutineName) + '(' + Database.Session.Connection.EscapeIdentifier('Param') + ' int(11)) RETURNS int(11)');
      FSource.Lines.Add('BEGIN');
      FSource.Lines.Add('  RETURN Param;');
      FSource.Lines.Add('END;');
    end
    else
      FSource.Lines.Clear();

    TSSource.TabVisible := True;

    PageControl.Visible := True;
    PSQLWait.Visible := not PageControl.Visible;
  end
  else
  begin
    PageControl.Visible := Routine.Update();
    PSQLWait.Visible := not PageControl.Visible;

    if (PageControl.Visible) then
      Built();
  end;

  TSBasics.TabVisible := Assigned(Routine);
  TSInformations.TabVisible := Assigned(Routine);

  FBOk.Enabled := PageControl.Visible and not Assigned(Routine);

  ActiveControl := FBCancel;
  if (PageControl.Visible) then
    if (TSBasics.TabVisible) then
    begin
      PageControl.ActivePage := TSBasics;
      ActiveControl := FComment;
    end
    else if (TSSource.TabVisible) then
    begin
      PageControl.ActivePage := TSSource;
      ActiveControl := FSource;
    end;
end;

procedure TDRoutine.FSecurityClick(Sender: TObject);
begin
  TSSource.TabVisible := False;

  FBOkCheckEnabled(Sender);
end;

procedure TDRoutine.FSecurityKeyPress(Sender: TObject;
  var Key: Char);
begin
  FBOkCheckEnabled(Sender);
end;

procedure TDRoutine.FSourceChange(Sender: TObject);
begin
  MainAction('aECopyToFile').Enabled := FSource.SelText <> '';

  FName.Enabled := False; FLName.Enabled := FName.Enabled;
  FComment.Enabled := False; FLComment.Enabled := FComment.Enabled;

  TSBasics.TabVisible := False;
  TSInformations.TabVisible := False;

  FBOkCheckEnabled(Sender);
end;

procedure TDRoutine.UMChangePreferences(var Message: TMessage);
begin
  PSQLWait.Caption := Preferences.LoadStr(882);

  TSBasics.Caption := Preferences.LoadStr(108);
  GBasics.Caption := Preferences.LoadStr(85);
  FLName.Caption := Preferences.LoadStr(35) + ':';
  FLSecurity.Caption := Preferences.LoadStr(798) + ':';
  FSecurityDefiner.Caption := Preferences.LoadStr(799);
  FSecurityInvoker.Caption := Preferences.LoadStr(561);
  FLComment.Caption := Preferences.LoadStr(111) + ':';

  TSInformations.Caption := Preferences.LoadStr(121);
  GDates.Caption := Preferences.LoadStr(122);
  FLCreated.Caption := Preferences.LoadStr(118) + ':';
  FLUpdated.Caption := Preferences.LoadStr(119) + ':';
  GDefiner.Caption := Preferences.LoadStr(561);
  FLDefiner.Caption := Preferences.LoadStr(799) + ':';
  GSize.Caption := Preferences.LoadStr(67);
  FLSize.Caption := Preferences.LoadStr(67) + ':';

  TSSource.Caption := Preferences.LoadStr(198);
  if (not Preferences.Editor.CurrRowBGColorEnabled) then
    FSource.ActiveLineColor := clNone
  else
    FSource.ActiveLineColor := Preferences.Editor.CurrRowBGColor;
  FSource.Font.Name := Preferences.SQLFontName;
  FSource.Font.Style := Preferences.SQLFontStyle;
  FSource.Font.Color := Preferences.SQLFontColor;
  FSource.Font.Size := Preferences.SQLFontSize;
  FSource.Font.Charset := Preferences.SQLFontCharset;
  if (Preferences.Editor.LineNumbersForeground = clNone) then
    FSource.Gutter.Font.Color := clWindowText
  else
    FSource.Gutter.Font.Color := Preferences.Editor.LineNumbersForeground;
  if (Preferences.Editor.LineNumbersBackground = clNone) then
    FSource.Gutter.Color := clBtnFace
  else
    FSource.Gutter.Color := Preferences.Editor.LineNumbersBackground;
  FSource.Gutter.Font.Style := Preferences.Editor.LineNumbersStyle;
  FSource.Gutter.Visible := Preferences.Editor.LineNumbers;
  if (Preferences.Editor.AutoIndent) then
    FSource.Options := FSource.Options + [eoAutoIndent, eoSmartTabs]
  else
    FSource.Options := FSource.Options - [eoAutoIndent, eoSmartTabs];
  if (Preferences.Editor.TabToSpaces) then
    FSource.Options := FSource.Options + [eoTabsToSpaces]
  else
    FSource.Options := FSource.Options - [eoTabsToSpaces];
  FSource.TabWidth := Preferences.Editor.TabWidth;
  FSource.RightEdge := Preferences.Editor.RightEdge;
  FSource.WantTabs := Preferences.Editor.TabAccepted;
  FSource.WordWrap := Preferences.Editor.WordWrap;

  msUndo.Action := MainAction('aEUndo'); msCut.ShortCut := 0;
  msCut.Action := MainAction('aECut'); msCut.ShortCut := 0;
  msCopy.Action := MainAction('aECopy'); msCopy.ShortCut := 0;
  msPaste.Action := MainAction('aEPaste'); msPaste.ShortCut := 0;
  msDelete.Action := MainAction('aEDelete'); msDelete.ShortCut := 0;
  msSelectAll.Action := MainAction('aESelectAll'); msSelectAll.ShortCut := 0;

  FBHelp.Caption := Preferences.LoadStr(167);
  FBOk.Caption := Preferences.LoadStr(29);
  FBCancel.Caption := Preferences.LoadStr(30);
end;

initialization
  FRoutine := nil;
end.
