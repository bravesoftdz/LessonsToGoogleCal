object Form2: TForm2
  Left = 0
  Top = 0
  Caption = #1053#1072#1083#1072#1096#1090#1091#1074#1072#1085#1085#1103
  ClientHeight = 369
  ClientWidth = 475
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object GroupBox1: TGroupBox
    Left = 16
    Top = 25
    Width = 201
    Height = 48
    Caption = #1058#1088#1080#1074#1072#1083#1110#1089#1090#1100' '#1091#1088#1086#1082#1091
    TabOrder = 1
    object Edit1: TEdit
      Left = 101
      Top = 16
      Width = 65
      Height = 21
      Hint = #1074#1082#1072#1078#1110#1090#1100' '#1090#1088#1080#1074#1072#1083#1110#1089#1090#1100' '#1091#1088#1086#1082#1110#1074' '#1091' '#1093#1074#1080#1083#1080#1085#1072#1093
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      Text = 'Edit1'
      TextHint = #1090#1088#1080#1074'. '#1091' '#1093#1074'.'
      OnClick = Edit1Click
      OnExit = Edit1Exit
      OnMouseDown = Edit1MouseDown
    end
    object cbFixDuration: TCheckBox
      Left = 3
      Top = 18
      Width = 92
      Height = 17
      Caption = #1060#1110#1082#1089#1086#1074#1072#1085#1072
      TabOrder = 1
      OnClick = cbFixDurationClick
    end
  end
  object StringGrid1: TStringGrid
    Left = 16
    Top = 88
    Width = 201
    Height = 241
    ColCount = 3
    RowCount = 9
    TabOrder = 0
    OnDrawCell = StringGrid1DrawCell
    OnGetEditText = StringGrid1GetEditText
    OnSelectCell = StringGrid1SelectCell
  end
  object btnSaveSettings: TButton
    Left = 368
    Top = 335
    Width = 89
    Height = 25
    Caption = 'btnSaveSettings'
    TabOrder = 2
    OnClick = btnSaveSettingsClick
  end
  object AttendeesList: TStringGrid
    Left = 251
    Top = 25
    Width = 206
    Height = 304
    ColCount = 2
    FixedCols = 0
    RowCount = 29
    TabOrder = 3
    ColWidths = (
      64
      117)
  end
end
