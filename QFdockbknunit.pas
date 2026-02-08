unit QFdockbknunit;

{$mode objfpc}{$H+}

interface

uses
  LCLType,Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, DOM, XMLRead, XMLWrite, FileUtil, LazFileUtils,IniFiles , DefaultTranslator,
  //IDE 需要用到的单元
  AnchorDocking, AnchorDockStorage, AnchorDockOptionsDlg,XMLPropStorage ,IDEOptionsIntf,
  Laz2_XMLCfg,  CompOptsIntf,  LCLProc, BaseIDEIntf, ProjectIntf, LazConfigStorage,
  IDECommands, IDEWindowIntf, LazIDEIntf, MenuIntf, Types;

type

  { TDockbkFrm }

  TDockbkFrm = class(TForm)
    btnBackup: TBitBtn;
    btnDelete: TBitBtn;
    btnRestore: TBitBtn;
    btnRestoreDefault: TButton;
    lblStatus: TLabel;
    ListBox1: TListBox;
    Memo1: TMemo;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    SaveDialog1: TSaveDialog;
    Splitter1: TSplitter;
    procedure btnBackupClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnRestoreClick(Sender: TObject);
    procedure btnRestoreDefaultClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure RestoreLayout(Layoutfile:string);
  private
    FBackupFile:String;
    FBackupDir: string;
    FConfigFile: string;
    procedure LoadBackupList;
    procedure UpdateStatus(const Msg: string; IsError: Boolean = False);
  public

  end;

var
  DockbkFrm: TDockbkFrm;

resourcestring
  FMenuItemCaption='AnchorDock Backup Recovery Tool';
  Pleasespecifythebackupfilename = 'Please specify the backup file name';
  Backupsuccessful = 'Backup successful';
  Backupfailed = 'Backup failed';
  Pleaseselectthebackupfiletorestore = 'Please select the backup file to restore';
  confirm = 'confirm';
  info1 = 'Are you sure you want to restore the window layout? This will overwrite the current layout settings。';
  info2 = 'layout restored successfully!';
  info3 = 'Unable to read the file';
  btnBackupcaption = 'Backup current layout';
  btnRestorecaption = 'Restore selected layout';
  ready = 'ready';
  btnRestoreDefaultcaption = 'Restore Layout Default';
  bthDeleteSelectedLayout = 'Delete selected layout';
  adrsAreYouSureToDelete = 'Are you sure you want to delete the backup file?';
  adrsunabletodeletefile = 'Unable to delete the file';

procedure ShowDockbkFrm(Sender: TObject);
procedure Register;

implementation

{$R *.lfm}

procedure ShowDockbkFrm(Sender: TObject);
begin
  DockbkFrm:=TDockbkFrm.Create(nil);
  DockbkFrm.ShowModal;
  DockbkFrm.Free;
end;

procedure Register;
var
  CmdCatToolMenu: TIDECommandCategory;
  ToolQFCompilerRunCommand: TIDECommand;
  MenuItemCaption: String;
  MenuCommand: TIDEMenuCommand;
begin
  // register shortcut and menu item
  MenuItemCaption:=FMenuItemCaption;//'AnchorDock Backup Recovery Tool';// <- this caption should be replaced by a resourcestring
  // search shortcut category
  CmdCatToolMenu:=IDECommandList.FindCategoryByName(CommandCategoryCustomName);//CommandCategoryToolMenuName);
  // register shortcut
  ToolQFCompilerRunCommand:=RegisterIDECommand(CmdCatToolMenu,
    'QFDockbk',
    MenuItemCaption,
    IDEShortCut(VK_UNKNOWN, []), // <- set here your default shortcut
    CleanIDEShortCut, nil, @ShowDockbkFrm);

  // register menu item in Project menu
  MenuCommand:=RegisterIDEMenuCommand(mnuTools,//mnuRun, //新注册菜单的位置
    'QFDockbk', //菜单名--唯一标识（不能有中文）
    MenuItemCaption,//菜单标题
    nil, nil,ToolQFCompilerRunCommand);

end;

{ TDockbkFrm }

procedure TDockbkFrm.FormCreate(Sender: TObject);
var
  ini:TiniFile;
begin
  self.Caption := FMenuItemCaption;
  btnBackup.caption := btnBackupcaption;
  btnRestore.caption := btnRestorecaption;
  btnRestoreDefault.caption := btnRestoreDefaultcaption;;
  btnDelete.Caption  := bthDeleteSelectedLayout;

  // 设置默认路径
  FBackupDir := LazarusIDE.GetPrimaryConfigPath + PathDelim + 'backups' + PathDelim;
  ForceDirectories(FBackupDir);

  // 设置默认备份文件名
  FBackupFile := FBackupDir + 'dockbackup_' +
    FormatDateTime('yyyy-mm-dd_hhnnss', Now) + '.xml';

  // 加载备份列表
  LoadBackupList;

  UpdateStatus(ready);

end;

procedure TDockbkFrm.btnBackupClick(Sender: TObject);
var
  XMLConfig: TXMLConfigStorage;
begin
  FBackupFile := FBackupDir + 'dockbackup_' +
    FormatDateTime('yyyy-mm-dd_hhnnss', Now) + '.xml';

  if Trim(FBackupFile) = '' then
  begin
    UpdateStatus(Pleasespecifythebackupfilename,true);//'Please specify the backup file name', True);
    Exit;
  end;

  try
    XMLConfig:=TXMLConfigStorage.Create(FBackupFile,false);
    try
      DockMaster.SaveLayoutToConfig(XMLConfig);
      DockMaster.SaveSettingsToConfig(XMLConfig);
      XMLConfig.WriteToDisk;
    finally
      XMLConfig.Free;
      UpdateStatus(Backupsuccessful+': ' + ExtractFileName(FBackupFile));
      LoadBackupList;
    end;
  except
    on E: Exception do begin
      UpdateStatus(Backupfailed, True);
    end;
  end;
end;

procedure TDockbkFrm.btnDeleteClick(Sender: TObject);
var
  BackupFile: String;
begin
  Assert(ListBox1.ItemIndex>=0, 'TDockBackupFrm.btnDeleteClick: ListBox1.ItemIndex');
  BackupFile := FBackupDir + ListBox1.Items[ListBox1.ItemIndex];
  if MessageDlg(Confirm, adrsAreYouSureToDelete,
                mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    if DeleteFile(BackupFile) then begin
      UpdateStatus(Ready);
      LoadBackupList;
    end
    else
      UpdateStatus(adrsUnableToDeleteFile, True);
  end;
end;

procedure TDockbkFrm.RestoreLayout(Layoutfile:string);
var
  DefaultFile: string;
  XMLConfig:TXMLConfigStorage;
begin
  if MessageDlg(confirm, info1,
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    try
      XMLConfig:=TXMLConfigStorage.Create(Layoutfile,True);
      DockMaster.LoadLayoutFromConfig(XMLConfig,true);
      DockMaster.LoadSettingsFromConfig(XMLConfig);
      UpdateStatus(info2, False);
    finally
      XMLConfig.Free;
    end;
  end;
end;

procedure TDockbkFrm.btnRestoreClick(Sender: TObject);
var
  BackupFile: string;
begin
  if ListBox1.ItemIndex >= 0 then
    BackupFile := FBackupDir + ListBox1.Items[ListBox1.ItemIndex]
  else
  begin
    UpdateStatus(Pleaseselectthebackupfiletorestore, True);
    Exit;
  end;
  RestoreLayout(BackupFile);
end;

procedure TDockbkFrm.btnRestoreDefaultClick(Sender: TObject);
begin
  //uses IDEOptionsIntf
  RestoreLayout(IDEEnvironmentOptions.GetParsedLazarusDirectory+'components/anchordocking/design/ADLayoutDefault.xml');
end;

procedure TDockbkFrm.ListBox1Click(Sender: TObject);
begin
  if ListBox1.ItemIndex >= 0 then
  begin
    UpdateStatus(ListBox1.Items[ListBox1.ItemIndex],False);

    // 预览备份内容
    Memo1.Clear;
    try
      Memo1.Lines.LoadFromFile(FBackupDir+ListBox1.Items[ListBox1.ItemIndex]);
    except
      on E: Exception do
        Memo1.Lines.Add(info3+': ' + E.Message);
    end;
  end;
end;

procedure TDockbkFrm.LoadBackupList;
var
  Files: TStringList;
  i: Integer;
begin
  ListBox1.Clear;

  if DirectoryExists(FBackupDir) then
  begin
    Files := TStringList.Create;
    try
      FindAllFiles(Files, FBackupDir, 'dockbackup_*.xml', False);
      Files.Sort;

      for i := Files.Count - 1 downto 0 do  // 从最新到最旧排序
      begin
        ListBox1.Items.Add(ExtractFileName(Files[i]));
      end;
    finally
      Files.Free;
    end;
  end;
end;

procedure TDockbkFrm.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  lblStatus.Caption := Msg;

  if IsError then
  begin
    lblStatus.Font.Color := clRed;
    lblStatus.Font.Style := [fsBold];
  end
  else
  begin
    lblStatus.Font.Color := clGreen;
    lblStatus.Font.Style := [];
  end;

  Application.ProcessMessages;
end;

end.
