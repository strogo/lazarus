{  $Id$  }
{
 /***************************************************************************
                            makerestrdlg.pas
                            ----------------


 ***************************************************************************/

 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************
 
 Author: Mattias Gaertner
 
 Abstract:
   TMakeResStrDialog is the dialog to setup how to convert a string constant
   into a pascal resourcestring.
 
}
unit MakeResStrDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Buttons, ComCtrls, StdCtrls, Dialogs,
  ExtCtrls, LResources, LazarusIDEStrConsts, IDEOptionDefs, CodeToolManager,
  CodeAtom, CodeToolsStructs, CodeCache, SynHighlighterPas, SynEdit,
  EditorOptions, InputHistory;
  
type
  TResourcestringInsertPolicy = (rsipAppend, rsipAlphabetically);

  TMakeResStrDialog = class(TForm)
    // source synedit
    StringConstGroupBox: TGroupBox;
    StringConstSynEdit: TSynEdit;
    
    // options
    ConversionGroupBox: TGroupBox;
    // identifier prefix
    IdentPrefixLabel: TLabel;
    IdentPrefixComboBox: TComboBox;
    // identifier length
    IdentLengthLabel: TLabel;
    IdentLengthComboBox: TComboBox;
    // identifier
    CustomIdentifierCheckBox: TCheckBox;
    IdentifierEdit: TEdit;
    // resourcestring section
    ResStrSectionLabel: TLabel;
    ResStrSectionComboBox: TComboBox;
    // insert position type
    AppendResStrRadioButton: TRadioButton;
    InsertAlphabeticallyResStrRadioButton: TRadioButton;
    
    // preview
    SrcPreviewGroupBox: TGroupBox;
    SrcPreviewSynEdit: TSynEdit;

    // ok+cancel buttons
    OkButton: TButton;
    CancelButton: TButton;

    // highlighter
    SynPasSyn: TSynPasSyn;
    
    procedure CancelButtonClick(Sender: TObject);
    procedure ConversionGroupBoxResize(Sender: TObject);
    procedure CustomIdentifierCheckBoxClick(Sender: TObject);
    procedure IdentLengthComboBoxChange(Sender: TObject);
    procedure IdentPrefixComboBoxChange(Sender: TObject);
    procedure IdentifierEditChange(Sender: TObject);
    procedure MakeResStrDialogResize(Sender: TObject);
    procedure OkButtonClick(Sender: TObject);
    procedure ResStrSectionComboBoxChange(Sender: TObject);
  private
    procedure SetupComponents;
  public
    DefaultIdentifier: string;
    Code: TCodeBuffer;
    StartPos, EndPos: TPoint;
    Positions: TCodeXYPositions;
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure FillResourceStringSections(NewPositions: TCodeXYPositions);
    procedure FillIdentPrefixes;
    procedure FillIdentLengths;
    procedure UpdateIdentifier;
    procedure UpdateSourcePreview;
    function GetIdentifier: string;
    function GetDefaultIdentifier: string;
    procedure SetSource(NewCode: TCodeBuffer;
      const NewStartPos, NewEndPos: TPoint);
    function ResourceStringExists(const Identifier: string): boolean;
    procedure GetNewSource(var NewSource, ResourceStringValue: string);
    procedure Init;
    procedure SaveHistories;
    procedure SaveIdentPrefixes;
    procedure SaveIdentLengths;
  end;
  
function ShowMakeResStrDialog(
  const StartPos, EndPos: TPoint; Code: TCodeBuffer;
  Positions: TCodeXYPositions;
  var NewIdentifier, NewIdentifierValue: string;
  var NewSourceLines: string;
  var ResStrSectionCode: TCodeBuffer;
  var ResStrSectionXY: TPoint;
  var InsertPolicy: TResourcestringInsertPolicy): TModalResult;


implementation

uses
  Math;

function ShowMakeResStrDialog(
  const StartPos, EndPos: TPoint; Code: TCodeBuffer;
  Positions: TCodeXYPositions;
  var NewIdentifier, NewIdentifierValue: string;
  var NewSourceLines: string;
  var ResStrSectionCode: TCodeBuffer;
  var ResStrSectionXY: TPoint;
  var InsertPolicy: TResourcestringInsertPolicy): TModalResult;
var
  MakeResStrDialog: TMakeResStrDialog;
  Section: PCodeXYPosition;
  ResourcestringSectionID: Integer;
begin
  MakeResStrDialog:=TMakeResStrDialog.Create(Application);
  MakeResStrDialog.Positions:=CodeToolBoss.Positions;
  MakeResStrDialog.SetSource(Code,StartPos,EndPos);
  MakeResStrDialog.Init;

  // show dialog
  Result:=MakeResStrDialog.ShowModal;
  if Result=mrOk then begin
    // return results
    NewIdentifier:=MakeResStrDialog.GetIdentifier;
    MakeResStrDialog.GetNewSource(NewSourceLines,NewIdentifierValue);
    if MakeResStrDialog.InsertAlphabeticallyResStrRadioButton.Checked then
      InsertPolicy:=rsipAlphabetically
    else
      InsertPolicy:=rsipAppend;
    ResourcestringSectionID:=MakeResStrDialog.ResStrSectionComboBox.ItemIndex;
    Section:=CodeToolBoss.Positions[ResourcestringSectionID];
    ResStrSectionCode:=Section^.Code;
    ResStrSectionXY:=Point(Section^.X,Section^.Y);
  end;

  // save settings and clean up
  IDEDialogLayoutList.SaveLayout(MakeResStrDialog);

  MakeResStrDialog.Free;
end;

{ TMakeResStrDialog }

procedure TMakeResStrDialog.CancelButtonClick(Sender: TObject);
begin
  ModalResult:=mrCancel;
end;

procedure TMakeResStrDialog.ConversionGroupBoxResize(Sender: TObject);
begin
  // identifier prefix
  with IdentPrefixLabel do begin
    SetBounds(2,6,150,Height);
  end;

  with IdentPrefixComboBox do begin
    SetBounds(IdentPrefixLabel.Left+IdentPrefixLabel.Width+5,
              IdentPrefixLabel.Top-4,
              100,Height);
  end;

  // identifier length
  with IdentLengthLabel do begin
    SetBounds(IdentPrefixComboBox.Left+IdentPrefixComboBox.Width+60,
              IdentPrefixLabel.Top,100,Height);
  end;

  with IdentLengthComboBox do begin
    SetBounds(IdentLengthLabel.Left+IdentLengthLabel.Width+5,
              IdentPrefixComboBox.Top,
              Min(Parent.ClientWidth-Left-5,50),Height);
  end;

  // identifier
  with CustomIdentifierCheckBox do begin
    SetBounds(IdentPrefixLabel.Left,
              IdentPrefixComboBox.Top+IdentPrefixComboBox.Height+5,
              150,Height);
  end;

  with IdentifierEdit do begin
    SetBounds(CustomIdentifierCheckBox.Left+CustomIdentifierCheckBox.Width+5,
              CustomIdentifierCheckBox.Top,
              Parent.ClientWidth-Left-5,Height);
  end;

  // resourcestring section
  with ResStrSectionLabel do begin
    SetBounds(IdentPrefixLabel.Left,
              IdentifierEdit.Top+IdentifierEdit.Height+9,
              150,Height);
  end;

  with ResStrSectionComboBox do begin
    SetBounds(ResStrSectionLabel.Left+ResStrSectionLabel.Width+5,
              IdentifierEdit.Top+IdentifierEdit.Height+5,
              Parent.ClientWidth-Left-5,Height);
  end;

  // insert position type
  with AppendResStrRadioButton do begin
    SetBounds(IdentPrefixLabel.Left,
              ResStrSectionComboBox.Top+ResStrSectionComboBox.Height+7,
              Min((Parent.ClientWidth-3*Left) div 2,150),Height);
  end;

  with InsertAlphabeticallyResStrRadioButton do begin
    SetBounds(AppendResStrRadioButton.Left+AppendResStrRadioButton.Width+5,
              AppendResStrRadioButton.Top,
              Parent.ClientWidth-Left-5,Height);
  end;
end;

procedure TMakeResStrDialog.CustomIdentifierCheckBoxClick(Sender: TObject);
begin
  UpdateIdentifier;
end;

procedure TMakeResStrDialog.IdentLengthComboBoxChange(Sender: TObject);
begin
  UpdateIdentifier;
  UpdateSourcePreview;
end;

procedure TMakeResStrDialog.IdentPrefixComboBoxChange(Sender: TObject);
begin
  UpdateIdentifier;
  UpdateSourcePreview;
end;

procedure TMakeResStrDialog.IdentifierEditChange(Sender: TObject);
begin
  UpdateIdentifier;
  UpdateSourcePreview;
end;

procedure TMakeResStrDialog.MakeResStrDialogResize(Sender: TObject);
var
  NewTop: Integer;
begin
  // source synedit
  with StringConstGroupBox do begin
    SetBounds(2,2,Parent.ClientWidth-2*Left,Parent.ClientHeight div 4);
  end;

  // options
  with ConversionGroupBox do begin
    SetBounds(StringConstGroupBox.Left,
              StringConstGroupBox.Top+StringConstGroupBox.Height+5,
              StringConstGroupBox.Width,140);
  end;

  // preview
  with SrcPreviewGroupBox do begin
    NewTop:=ConversionGroupBox.Top+ConversionGroupBox.Height+5;
    SetBounds(ConversionGroupBox.Left,NewTop,
              ConversionGroupBox.Width,Parent.ClientHeight-NewTop-50);
  end;

  // ok+cancel buttons
  with OkButton do begin
    SetBounds(Parent.ClientWidth-200,Parent.ClientHeight-35,
              Width,Height);
  end;

  with CancelButton do begin
    SetBounds(OkButton.Left+OkButton.Width+10,OkButton.Top,Width,Height);
  end;
end;

procedure TMakeResStrDialog.OkButtonClick(Sender: TObject);
var
  Index: Integer;
begin
  Index:=ResStrSectionComboBox.ItemIndex;
  if (Index<0) or (Index>=Positions.Count) then begin
    MessageDlg('Invalid Resourcestring section',
      'Please choose a resourstring section from the list.',
      mtError,[mbCancel],0);
    exit;
  end;
  SaveHistories;
  ModalResult:=mrOk;
end;

procedure TMakeResStrDialog.ResStrSectionComboBoxChange(Sender: TObject);
begin
  UpdateIdentifier;
  UpdateSourcePreview;
end;

procedure TMakeResStrDialog.SetupComponents;
begin
  SynPasSyn:=TSynPasSyn.Create(Self);

  // source
  StringConstGroupBox:=TGroupBox.Create(Self);
  with StringConstGroupBox do begin
    Name:='StringConstGroupBox';
    Parent:=Self;
    Caption:='String Constant in source';
  end;
  
  StringConstSynEdit:=TSynEdit.Create(Self);
  with StringConstSynEdit do begin
    Name:='StringConstSynEdit';
    Parent:=StringConstGroupBox;
    Align:=alClient;
    Highlighter:=SynPasSyn;
  end;

  // conversion options
  ConversionGroupBox:=TGroupBox.Create(Self);
  with ConversionGroupBox do begin
    Name:='ConversionGroupBox';
    Parent:=Self;
    Caption:='Conversion Options';
    OnResize:=@ConversionGroupBoxResize;
  end;

  // identifier prefix
  IdentPrefixLabel:=TLabel.Create(Self);
  with IdentPrefixLabel do begin
    Name:='IdentPrefixLabel';
    Parent:=ConversionGroupBox;
    Caption:='Identifier Prefix:';
  end;

  IdentPrefixComboBox:=TComboBox.Create(Self);
  with IdentPrefixComboBox do begin
    Name:='IdentPrefixComboBox';
    Parent:=ConversionGroupBox;
    OnChange:=@IdentPrefixComboBoxChange;
  end;

  // identifier length
  IdentLengthLabel:=TLabel.Create(Self);
  with IdentLengthLabel do begin
    Name:='IdentLengthLabel';
    Parent:=ConversionGroupBox;
    Caption:='Identifier Length:';
  end;

  IdentLengthComboBox:=TComboBox.Create(Self);
  with IdentLengthComboBox do begin
    Name:='IdentLengthComboBox';
    Parent:=ConversionGroupBox;
    OnChange:=@IdentLengthComboBoxChange;
  end;

  // custom identifier
  CustomIdentifierCheckBox:=TCheckBox.Create(Self);
  with CustomIdentifierCheckBox do begin
    Name:='CustomIdentifierCheckBox';
    Parent:=ConversionGroupBox;
    Caption:='Custom Identifier';
    Checked:=false;
    OnClick:=@CustomIdentifierCheckBoxClick;
  end;
  
  IdentifierEdit:=TEdit.Create(Self);
  with IdentifierEdit do begin
    Name:='IdentifierEdit';
    Parent:=ConversionGroupBox;
    Enabled:=false;
    OnChange:=@IdentifierEditChange;
  end;
  
  // resourcestring section
  ResStrSectionLabel:=TLabel.Create(Self);
  with ResStrSectionLabel do begin
    Name:='ResStrSectionLabel';
    Parent:=ConversionGroupBox;
    Caption:='Resourcestring Section:';
  end;

  ResStrSectionComboBox:=TComboBox.Create(Self);
  with ResStrSectionComboBox do begin
    Name:='ResStrSectionComboBox';
    Parent:=ConversionGroupBox;
    OnChange:=@ResStrSectionComboBoxChange;
  end;

  // insert position type
  AppendResStrRadioButton:=TRadioButton.Create(Self);
  with AppendResStrRadioButton do begin
    Name:='AppendResStrRadioButton';
    Parent:=ConversionGroupBox;
    Caption:='Append to section';
  end;

  InsertAlphabeticallyResStrRadioButton:=TRadioButton.Create(Self);
  with InsertAlphabeticallyResStrRadioButton do begin
    Name:='InsertAlphabeticallyResStrRadioButton';
    Parent:=ConversionGroupBox;
    Caption:='Insert alphabetically';
  end;

  // converted source preview
  SrcPreviewGroupBox:=TGroupBox.Create(Self);
  with SrcPreviewGroupBox do begin
    Name:='SrcPreviewGroupBox';
    Parent:=Self;
    Caption:='Source preview';
  end;

  SrcPreviewSynEdit:=TSynEdit.Create(Self);
  with SrcPreviewSynEdit do begin
    Name:='SrcPreviewSynEdit';
    Parent:=SrcPreviewGroupBox;
    Align:=alClient;
    Highlighter:=SynPasSyn;
  end;

  // ok+cancel buttons
  OkButton:=TButton.Create(Self);
  with OkButton do begin
    Name:='OkButton';
    Parent:=Self;
    Caption:='Ok';
    OnClick:=@OkButtonClick;
  end;
  
  CancelButton:=TButton.Create(Self);
  with CancelButton do begin
    Name:='CancelButton';
    Parent:=Self;
    Caption:='Cancel';
    OnClick:=@CancelButtonClick;
  end;
end;

constructor TMakeResStrDialog.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  if LazarusResources.Find(Classname)=nil then begin
    Name:='MakeResStrDialog';
    Caption := 'Make ResourceString';
    Width:=550;
    Height:=400;
    Position:=poScreenCenter;
    OnResize:=@MakeResStrDialogResize;
    SetupComponents;
  end;
  IDEDialogLayoutList.ApplyLayout(Self,550,400);
  OnResize(nil);
  EditorOpts.GetHighlighterSettings(SynPasSyn);
  EditorOpts.GetSynEditSettings(StringConstSynEdit);
  StringConstSynEdit.ReadOnly:=true;
  StringConstSynEdit.Gutter.Visible:=false;
  EditorOpts.GetSynEditSettings(SrcPreviewSynEdit);
  SrcPreviewSynEdit.ReadOnly:=true;
  SrcPreviewSynEdit.Gutter.Visible:=false;
end;

destructor TMakeResStrDialog.Destroy;
begin
  inherited Destroy;
end;

procedure TMakeResStrDialog.FillResourceStringSections(
  NewPositions: TCodeXYPositions);
var
  i: Integer;
  p: PCodeXYPosition;
  s: String;
begin
  Positions:=NewPositions;
  // the history list contains the filenames plus the
  with ResStrSectionComboBox do begin
    Text:='';
    Items.BeginUpdate;
    for i:=0 to Positions.Count-1 do begin
      p:=Positions[i];
      s:=p^.Code.Filename+' ('+IntToStr(p^.Y)+','+IntToStr(p^.X)+')';
      if i<Items.Count then
        Items[i]:=s
      else
        Items.Add(s);
    end;
    while Items.Count>Positions.Count do
      Items.Delete(Items.Count-1);
    Items.EndUpdate;
    ItemIndex:=0;
  end;
end;

procedure TMakeResStrDialog.FillIdentPrefixes;
var
  HistoryList: THistoryList;
begin
  // get the Prefixes history list
  HistoryList:=
    InputHistories.HistoryLists.GetList(hlMakeResourceStringPrefixes,true);
  IdentPrefixComboBox.Items.Assign(HistoryList);
  if IdentPrefixComboBox.Items.Count>0 then
    IdentPrefixComboBox.Text:=IdentPrefixComboBox.Items[0]
  else
    IdentPrefixComboBox.Text:='rs';
end;

procedure TMakeResStrDialog.FillIdentLengths;
var
  HistoryList: THistoryList;
begin
  // get the Length history list
  HistoryList:=
    InputHistories.HistoryLists.GetList(hlMakeResourceStringLengths,true);
  IdentLengthComboBox.Items.Assign(HistoryList);
  if IdentLengthComboBox.Items.Count>0 then
    IdentLengthComboBox.Text:=IdentLengthComboBox.Items[0]
  else begin
    with IdentLengthComboBox.Items do begin
      Add('8');
      Add('12');
      Add('20');
      Add('50');
    end;
    IdentLengthComboBox.Text:='12';
  end;
end;

procedure TMakeResStrDialog.UpdateIdentifier;
var
  CustomIdent: Boolean;
begin
  CustomIdent:=CustomIdentifierCheckBox.Checked;
  IdentifierEdit.Enabled:=CustomIdent;
  IdentPrefixLabel.Enabled:=not CustomIdent;
  IdentPrefixComboBox.Enabled:=not CustomIdent;
  IdentLengthLabel.Enabled:=not CustomIdent;
  IdentLengthComboBox.Enabled:=not CustomIdent;
  if not CustomIdent then
    IdentifierEdit.Text:=GetDefaultIdentifier;
end;

procedure TMakeResStrDialog.UpdateSourcePreview;
var
  NewSource, NewValue: string;
begin
  GetNewSource(NewSource,NewValue);
  SrcPreviewSynEdit.Text:=NewSource+#13#10
     +StringOfChar('-',
                  CodeToolBoss.SourceChangeCache.BeautifyCodeOptions.LineLength)
     +#13#10
     +CodeToolBoss.SourceChangeCache.BeautifyCodeOptions.BeautifyStatement(
        GetIdentifier+' = '''+NewValue+'''',0);
end;

function TMakeResStrDialog.GetIdentifier: string;
begin
  Result:=IdentifierEdit.Text;
  if Result='' then Result:=GetDefaultIdentifier;
end;

function TMakeResStrDialog.GetDefaultIdentifier: string;
var
  DefIdenLength: Integer;
  i: Integer;
begin
  DefIdenLength:=StrToIntDef(IdentLengthComboBox.Text,8);
  if DefIdenLength<1 then DefIdenLength:=1;
  if DefIdenLength>80 then DefIdenLength:=80;
  Result:=IdentPrefixComboBox.Text+copy(DefaultIdentifier,1,DefIdenLength);
  if ResourceStringExists(Result) then begin
    i:=2;
    while ResourceStringExists(Result+IntToStr(i)) do inc(i);
    Result:=Result++IntToStr(i);
  end;
end;

procedure TMakeResStrDialog.SetSource(NewCode: TCodeBuffer; const NewStartPos,
  NewEndPos: TPoint);
begin
  Code:=NewCode;
  StartPos:=NewStartPos;
  EndPos:=NewEndPos;
end;

function TMakeResStrDialog.ResourceStringExists(const Identifier: string
  ): boolean;
var
  CodeXY: PCodeXYPosition;
  Index: Integer;
begin
  Result:=false;
  Index:=ResStrSectionComboBox.ItemIndex;
  if (Index<0) or (Index>=Positions.Count) then exit;
  CodeXY:=Positions.Items[Index];
  Result:=CodeToolBoss.IdentifierExistsInResourceStringSection(
                                CodeXY^.Code,CodeXY^.X,CodeXY^.Y,Identifier);
end;

procedure TMakeResStrDialog.GetNewSource(var NewSource,
  ResourceStringValue: string);
var
  FormatStringConstant: string;
  FormatParameters: string;
  LeftSide: String;
  LastLine: string;
  NewString: String;
  RightSide: String;
begin
  if not CodeToolBoss.StringConstToFormatString(Code,StartPos.X,StartPos.Y,
     Code,EndPos.X,EndPos.Y,FormatStringConstant,FormatParameters)
  then begin
    SrcPreviewSynEdit.Text:='Error:'#13+CodeToolBoss.ErrorMessage;
    exit;
  end;
  if FormatParameters='' then
    NewString:=GetIdentifier
  else
    NewString:='Format('+GetIdentifier+',['+FormatParameters+'])';
  LeftSide:=copy(StringConstSynEdit.Lines[0],1,StartPos.X-1);
  LastLine:=StringConstSynEdit.Lines[EndPos.Y-StartPos.Y];
  RightSide:=copy(LastLine,EndPos.X,length(LastLine)-EndPos.X+1);

  NewSource:=LeftSide+NewString+RightSide;
  with CodeToolBoss.SourceChangeCache.BeautifyCodeOptions do
    NewSource:=BeautifyStatement(NewSource,0);

  ResourceStringValue:=FormatStringConstant;
end;

procedure TMakeResStrDialog.Init;
begin
  // string constant
  StringConstSynEdit.Text:=Code.GetLines(StartPos.Y,EndPos.Y);
  // reachable resourcestring sections
  FillResourceStringSections(Positions);
  // identifier prefixes
  FillIdentPrefixes;
  // identifier lengths
  FillIdentLengths;
  // identifier
  CustomIdentifierCheckBox.Checked:=false;
  CodeToolBoss.CreateIdentifierFromStringConst(Code,StartPos.X,StartPos.Y,
     Code,EndPos.X,EndPos.Y,DefaultIdentifier,50);
  UpdateIdentifier;
  // show new source
  UpdateSourcePreview;
end;

procedure TMakeResStrDialog.SaveHistories;
begin
  SaveIdentPrefixes;
  SaveIdentLengths;
end;

procedure TMakeResStrDialog.SaveIdentPrefixes;
var
  HistoryList: THistoryList;
begin
  if (not CustomIdentifierCheckBox.Checked)
  or (IdentPrefixComboBox.Text='') then
    exit;
  HistoryList:=
    InputHistories.HistoryLists.GetList(hlMakeResourceStringPrefixes,true);
  HistoryList.Push(IdentPrefixComboBox.Text);
end;

procedure TMakeResStrDialog.SaveIdentLengths;
var
  HistoryList: THistoryList;
begin
  if (not CustomIdentifierCheckBox.Checked)
  or (IdentLengthComboBox.Text='') then
    exit;
  HistoryList:=
    InputHistories.HistoryLists.GetList(hlMakeResourceStringLengths,true);
  HistoryList.Push(IdentLengthComboBox.Text);
end;


end.

