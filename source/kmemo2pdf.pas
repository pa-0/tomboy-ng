unit kmemo2pdf;

{    Copyright (C) 2023 David Bannon

    License:
    This code is licensed under BSD 3-Clause Clear License, see file License.txt
    or https://spdx.org/licenses/BSD-3-Clause-Clear.html

    ------------------

	This form will convert an in memory KMemo note to a PDF. At this stage, it requires
    creating, getting told a few things (The Kmemo, a default font, etc) and call show.

    It still needs to offer some options to the user and manage some file overwriting issues.

    I need to confirm we know where Windows and Mac keep their fonts.

    It probably needs an awful lot of testing ...

    See https://gitlab.com/freepascal.org/fpc/source/-/issues/30116 for issues about fonts !
    https://forum.lazarus.freepascal.org/index.php/topic,62254.0.html - my question on the topic.

    We have to assume here that fpPDF cannot 'generate' bold or italic from a regular
    font. So, you must have chosen a font that comes with, at least regular, bold, italic
    and bold-italic font files. If its "all in one TTF file" you get a warning and
    any bold or italic will be converted to regular.

    Fonts like DejaVu that have 'Oblique' do not get translated to italic.

    Fonts that mention bold and italic in the Font selection dialog do not necessarily
    have seperate font files for bold and italic, they may generate them !  But fpPDF does not.

    History :
        2023-02-14 Initial Release of this unit.

}





{$mode ObjFPC}{$H+}

interface

uses  {$ifdef unix}cwstring,{$endif}
    Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
    kmemo, k_prn, fpimage, fppdf, fpparsettf, fpttf, typinfo, tb_utils, KFunctions;

type
    PFontRecord=^TFontRecord;
    TFontRecord=record
      FamName:string;       // eg 'Ubuntu', 'FreeSans'
      Bold : boolean;
      Italic : boolean;
      FontIndex : integer;  // -1 if not set yet
    end;

type
    { TFontList }

    TFontList = class(TFPList)
        private
            //DefaultFontName : string;
            function Get(Index : Integer) : PFontRecord;
        public
            //constructor Create(DFN : string);
            destructor Destroy; Override;
                            // Adds details of passed font to list if not already present.
            procedure Add(TheFont: ANSIString; Bold, Italic: boolean);
            procedure Dump();
                            // Returns FontIndex of passed font record, -1 is not present;
            function Find(TheFont: ANSIString; Bold, Italic, FIndex: boolean): integer;
            property Items[Index : integer] : PFontRecord read Get; default;
    end;

type
    { TFormKMemo2pdf }
    TFormKMemo2pdf = class(TForm)
        BitBtn1: TBitBtn;
        BitBtnProceed: TBitBtn;
        Memo1: TMemo;
        procedure BitBtnProceedClick(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure FormShow(Sender: TObject);
    private
        AllowNoBoldItalic : boolean;// Allow use of font that does not have its own Bold or Italic font file.
        BulletIndent : integer;     // Bullet Indent (not including bullet), zero means no bullet;
        FontList : TFontList;       // A list of all the fonts we will need to print/display the PDF, Initially populated in KMemoRead()
        WordList : TWordList;       // A list of all the words and their details such as font, size etc. Populated in KMemoRead().
        WordIndex : integer;        // Points to a word in wordlist, must be less than WordList.count
        FPage: integer;
        FDoc: TPDFDocument;
        CurrentPage : integer ;     // Starts at zero ?
                                    // does a non write scan of next block of words returning the necessary Height
                                    // to push Y down to to provide clearance for any larger text. Do We have to push down
                                    // by less if first char of the line is higher ? test run is very strange !
                                    // Return 0 for a blank line (just inc Y by line height, don't run WriteLine)
        function CheckHeight: integer;
                                    // Returns with width and height in mm of the word in wordlist pointed to by WI
                                    // If AltText contains anything, it will be used instead of the text in WordList
                                    // but font and associated settings from WordList will still be used.
        function GetWordDimentions(const WI: integer; out W: integer; var H: integer; AltText: string = ''): boolean;
                                    // Builds a WordList based on the KMemo. Each word will have a trailing space if applicable
                                    // A newline has an empty list item and NewLine true.
        function KMemoRead(): boolean;
        function LoadFonts(): boolean;
        function MakePDF: boolean;
        procedure SaveDocument();
                                    // Tries to print out a line of words, word by word, at indicated starting point.
                                    // returns false if there is no more words to print.
        function WriteLine(Page: TPDFPage; XLoc: integer; const Y: integer): boolean;
                                    // sends a page of text to the Document, returning True when its all done.
        function WritePage(): boolean;
    public

        TheKMemo : TKMemo;          // This is the KMemo, set it before showing the form.
        TheTitle : string;
        FFileName : string;         // Full filename including path,
        DefaultFont : string;        // New Text in a KMemo is saved with font='default', only after reload does it have true name
                            // Public function to initiate the PDF. If it returns False then
                            // show user the form with some error or advice messages. Its
                            // going to be a font problem most likely, see header.
        function StartPDF: boolean;
    end;

var
    FormKMemo2pdf: TFormKMemo2pdf;

implementation

{$R *.lfm}

{ TFormKMemo2pdf }

const   TopMargin = 15;
        BottomMargin = 10;
        SideMargin = 15;
        PageHeight = 297;
        PageWidth = 210;
        LineHeight = 6;

{ TFontList }

function TFontList.Get(Index: Integer): PFontRecord;
begin
    Result := PFontRecord(inherited get(Index));
end;

{constructor TFontList.Create(DFN: string);
begin
    inherited Create;
    DefaultFontName := DFN;
end; }

destructor TFontList.Destroy;
var
    I : integer;
begin
    for I := 0 to Count-1 do begin
        dispose(Items[I]);
    end;
    inherited Destroy;
end;

procedure TFontList.Add(TheFont: ANSIString; Bold, Italic: boolean);
var
    P : PFontRecord;
begin
    if Find(TheFont, Bold, Italic, False) = -1 then begin
        new(P);
        P^.FamName := TheFont;
        P^.Bold := Bold;
        P^.Italic := Italic;
        P^.FontIndex := -1;
        inherited Add(P);
    end;
end;

procedure TFontList.Dump();
var i : integer;
begin
  writeln('TFontList.Dump we have ' + count.tostring + ' items ========');
  for i := 0 to count -1 do
    writeln('FONT : ', Items[i]^.FamName, ' B=', booltostr(Items[i]^.Bold, True), ' I=', booltostr(Items[i]^.Italic, True));
end;

function TFontList.Find(TheFont: ANSIString; Bold, Italic, FIndex: boolean): integer;
var i : integer;
begin
    Result := -1;
    for i := 0 to count -1 do
        if (Items[i]^.FamName = TheFont) and (Items[i]^.Bold = Bold)
                    and (Items[i]^.Italic = Italic) then begin
            if FIndex then
                Result := Items[i]^.FontIndex
            else Result := i;
           break;
        end;
end;

function TFormKMemo2PDF.GetWordDimentions(const WI : integer; out W : integer; var H : integer; AltText : string = '') : boolean;
var
    CachedFont : TFPFontCacheItem;
    SWidthF, DescenderH : single;
    LocH : integer;
begin
    Result := true;
    //writeln('INFO - TFormKMemo2pdf.GetWordDimentions WI=' + inttostr(WI) + ' and Wordlist.Count=' + inttostr(WordList.count));
    if AltText = '' then
           AltText := WordList[WI]^.AWord;
    //writeln('INFO - TFormKMemo2pdf.GetWordDimentions looking at ' + WordList[WI]^.AWord + ' Font=' + WordList[WI]^.FName);
    CachedFont := gTTFontCache.Find(WordList[WI]^.FName, WordList[WI]^.Bold, WordList[WI]^.Italic);
    if not Assigned(CachedFont) then  begin
        //writeln('INFO - TFormKMemo2pdf.GetWordDimentions Cannot find Font in Cache : ', WordList[WI]^.FName, ' ', WordList[WI]^.Bold, ' ', WordList[WI]^.Italic);
        // We will try a plain version of same font and if that works, change entry in WordList
        CachedFont := gTTFontCache.Find(WordList[WI]^.FName, False, False);
        if Assigned(CachedFont) then begin
            WordList[WI]^.Bold := False;                                        // ToDo : this is very, very ugly must understand fonts better
            WordList[WI]^.Italic := False;
        end else begin
            //writeln('ERROR - TFormKMemo2pdf.GetWordDimentions Cannot find Font in Cache : ', WordList[WI]^.FName, ' Plain Font');
            memo1.append('ERROR - TFormKMemo2pdf.GetWordDimentions Cannot find Font in Cache : ' + WordList[WI]^.FName + ' Plain Font');
            exit(False);
        end;
    end;
    SWidthF := CachedFont.TextWidth(AltText,  WordList[WI]^.Size);
    W := round((SWidthF * 25.4) / gTTFontCache.DPI);
    LocH := round(CachedFont.TextHeight(AltText, WordList[WI]^.Size, DescenderH) / 2.0);
    // writeln('TFormKMemo2pdf.GetWordDimentions LocH=', LocH);
    if LocH > H then H := LocH;
end;

function TFormKMemo2pdf.WriteLine(Page : TPDFPage; XLoc : integer; const Y : integer) : boolean;
var
    W, H : integer; // word dimensions
    i : integer;
    Bullet : string;

    function ExtraIndent(Bull : TKMemoParaNumbering) : integer;
    begin
        case Bull of
            pnuNone       : result := 0;         // The bullet is at indicated indent
            BulletOne     : result := 1;         // and the text starts the width of bullet
            BulletTwo     : result := 6;         // and a couple of spaces further in.
            BulletThree   : result := 11;        // mm.
            BulletFour    : result := 16;
            BulletFive    : result := 21;
            BulletSix     : result := 26;
            BulletSeven   : result := 31;
            BulletEight   : result := 36;
        end;
    end;

begin
    H := 0;
    i := 0;
    if WordList[WordIndex]^.ABullet <> pnuNone then  begin // We arrive at the start of a line, is it a bullet line ?
        Bullet := UnicodeToNativeUTF(cRoundBullet) + '  ';
           if not GetWordDimentions(WordIndex, W, H, Bullet) then exit(False);    // font fault unlikely, we have already checked this block.
           BulletIndent := ExtraIndent(WordList[WordIndex]^.ABullet);
           Page.WriteText(BulletIndent + XLoc, Y, Bullet);                        // u2022
           inc(BulletIndent, W);
    end;
    while WordIndex < WordList.Count do begin
        inc(i);
        if i > 2000 then break;
        if WordList[WordIndex]^.NewLine then begin
            inc(WordIndex);
            BulletIndent := 0;
            exit(true);
        end;
        if not GetWordDimentions(WordIndex, W, H) then exit(False);             // font fault unlikely, we have already checked this block.

        Page.SetFont(   FontList.Find(WordList[WordIndex]^.FName, WordList[WordIndex]^.Bold, WordList[WordIndex]^.Italic, True), WordList[WordIndex]^.Size);
        if (XLoc+W+BulletIndent) > (PageWidth - SideMargin) then exit(true);    // no more on this line.
        //writeln('TFormKMemo2pdf.WriteLine will WriteText T=', WordList[WordIndex]^.AWord, ' F=', WordList[WordIndex]^.FName, ' X=', BulletIndent + XLoc, ' W=', W);
        Page.WriteText(BulletIndent + XLoc, Y, WordList[WordIndex]^.AWord);
        //writeln('TFormKMemo2pdf.WriteLine wrote word=' + WordList[WordIndex]^.AWord + ' Font=' + WordList[WordIndex]^.FName + ' ' + inttostr(W) + ' ' + inttostr(H));
        XLoc := XLoc+W;
        inc(WordIndex);
    end;
    result := false;    // no more to do.
end;


function TFormKMemo2pdf.CheckHeight() : integer;
var
    W, i, WI : integer; // word dimensions
    Xloc : integer = SideMargin;
    OldFont : string;
begin
    i := 0;
    WI := WordIndex;
    Result := 0;
    while WI < WordList.Count do begin
        inc(i);
        if i > 2000 then break;
        if WordList[WI]^.NewLine then begin
            //BulletIndent := 0;
            exit;
        end;
        if not GetWordDimentions(WI, W, Result) then begin
            OldFont := WordList[WI]^.FName;
            WordList[WI]^.FName := DefaultFont;                                // We will change it to default font and try again

            if not GetWordDimentions(WI, W, Result) then begin
                memo1.Append('ERROR - TFormKMemo2pdf.CheckHeight Failed to load the requested font : ' + OldFont);
                exit;
            end;
        end;
//        writeln('TFormKMemo2pdf.WriteLine Setting FontIndex to ', FontList.Find(WordList[Wi]^.FName, WordList[WI]^.Bold, WordList[WI]^.Italic)
//            , ' and name is ', WordList[WI]^.FName);
        if (Xloc+W) > (PageWidth - SideMargin) then exit;
        if WI >= WordList.Count then exit;
        XLoc := XLoc+W;
        inc(WI);
    end;
end;

function TFormKMemo2pdf.LoadFonts() : boolean;
var
    I  : integer;
    CachedFont : TFPFontCacheItem;
    Suffix : string = '';
begin
    Result := True;
    for i := 0 to FontList.Count -1 do begin
        //writeln('TFormKMemo2pdf.LoadFonts FontName=', FontList[i]^.FamName);
        Suffix := '';
        CachedFont := gTTFontCache.Find(FontList[i]^.FamName, FontList[i]^.Bold, FontList[i]^.Italic);
        if not Assigned(CachedFont) then begin
           Memo1.Append('Font ' + FontList[i]^.FamName + ' does not have a bold or italic font file.');
           //writeln('WARNING - TFormKMemo2pdf.LoadFonts could not find font in cache ' + FontList[i]^.FamName + ' ' + booltostr(FontList[i]^.Bold, True) +' ' + booltostr(FontList[i]^.Italic, True));
           Result := False;
           continue;                            // will cause problems in GetWordDimensions()  !
        end;
        // writeln('INFO - TFormKMemo2pdf.LoadFonts DID find font in cache ' + FontList[i]^.FamName + ' ' + booltostr(FontList[i]^.Bold, True) +' ' + booltostr(FontList[i]^.Italic, True));
        if  FontList[i]^.Bold then Suffix := 'B';
        if  FontList[i]^.Italic then Suffix := Suffix + 'I';
        if Suffix <> '' then Suffix := '-' + Suffix;
        FontList[i]^.FontIndex := FDoc.AddFont(CachedFont.FileName, CachedFont.FamilyName + Suffix);       // is This  my naming scheme ??
        // FontList[i]^.FontIndex := FDoc.AddFont(gTTFontCache.Items[i].FileName,  gTTFontCache.Items[i].FamilyName + Suffix);
        // writeln('TFormKMemo2pdf.LoadFonts Font=', CachedFont.FamilyName + Suffix, ' FontIndex=',FontList[i]^.FontIndex, ' Family=', FontList[i]^.FamName);
    end;
end;


function TFormKMemo2pdf.WritePage() : boolean;
var
    X : integer = SideMargin;       // how far we are across the page, left to right, mm
    Y : integer = TopMargin;        // how far we are down the page, top to botton, mm
    Page : TPDFPage;
    i, Yt : integer;
begin
    Result := true;
    if WordList.Count < 1 then begin
       showmessage('WritePage called with empty word list');
       exit(false);
    end;
    // writeln('TFormKMemo2pdf.WritePage starting page ===== ' + inttostr(CurrentPage));
    Page := FDoc.Pages[CurrentPage];
    // writeln('TFormKMemo2pdf.WritePage Fonts loaded for this page -');
//    for i := 0 to Page.Document.Fonts.Count-1 do begin
//        writeln('Found in Page ' + Page.Document.Fonts[i].Name + ' DisplayName=' + Page.Document.Fonts[i].DisplayName );
//    end;
    while Result do begin        // Returns false if it has run out of words
        Yt := CheckHeight();     // Does not inc WordIndex.
        inc(Y, Yt);
        if Y > (PageHeight - TopMargin - BottomMargin) then exit;
        if Yt <> 0 then
             Result := WriteLine(Page, X, Y)   // Does inc WordIndex
        else begin
           inc(Y, LineHeight);
           inc(WordIndex);
        end;
        if WordIndex >= WordList.Count then Result := false;
        // writeln('TFormKMemo2pdf.WritePage writing at ', X, ' ', Y);
    end;
end;


function TFormKMemo2pdf.StartPDF : boolean;
var
    i : integer;
begin
    Memo1.Clear;
    CurrentPage := -1;
    If WordList <> nil then
        FreeAndNil(WordList);
    if FontList <> Nil then
        FreeAndNil(FontList);
    FontList := TFontList.Create();
    WordList := TWordList.Create;
    FDoc := TPDFDocument.Create(Nil);
    try
        KMemoRead();
        // This is for later, it does no make fonts available to the PDF
        gTTFontCache.ReadStandardFonts;                             // https://forum.lazarus.freepascal.org/index.php/topic,54280.msg406091.html
        //    gTTFontCache.SearchPath.Add('/usr/share/fonts/');     // can, possibly, add custom font locations ....
        gTTFontCache.BuildFontCache;
        // FDoc := TPDFDocument.Create(Nil);
        //    FDoc.FontDirectory := '/usr/share/fonts';             // ToDo : this is NOT cross platform
        Result := MakePDF();                                        // False if we found an issue, probably font related !
    finally
        FDoc.Free;
        FreeAndNil(FontList);
        FreeAndNil(WordList);
    end;
end;


function TFormKMemo2pdf.MakePDF : boolean;
var
  P: TPDFPage;
  S: TPDFSection;
  Opts: TPDFOptions;
begin
    FDoc.Infos.Title := TheTitle;
    FDoc.Infos.Author := 'tomboy-ng notes';
    FDoc.Infos.Producer := 'fpGUI Toolkit 1.4.1';
    //Result.Infos.ApplicationName := ApplicationName;
    FDoc.Infos.CreationDate := Now;
    Opts := [poPageOriginAtTop];
    Include(Opts, poSubsetFont);
    Include(Opts, poCompressFonts);
    Include(Opts,poCompressText);
    FDoc.Options := Opts;
    FDoc.StartDocument;
    if not LoadFonts() then begin
        if not AllowNoBoldItalic then
             {memo1.Append('Warning, your selected fonts may be unsuitable')
        else} begin
           showmessage('Warning, your selected fonts may be unsuitable');
           memo1.Append('Warning, Press Retry to make a PDF without bold or italics');
           Memo1.Append('or close, select more appropriate fonts from Settings and start again.');
           exit(False);                     // check for memory leaks here plaease
        end;
    end;

    S := FDoc.Sections.AddSection; // we always need at least one section
    // ToDo : chase this up one way or another.
    // If the note has eg bold or italic markup and the user selected font does not
    // have seperate font files for bold and/or italic, the markup will be ignored
    // and the user will be shown the following message.
    repeat
        //if CurrentPage > 15 then break;      // ToDo : remove me. For testing only.

        P := FDoc.Pages.AddPage;
        P.PaperType := ptA4;
        P.UnitOfMeasure := uomMillimeters;
        S.AddPage(P);               // Add the Page to the Section
        inc(CurrentPage);
    until not WritePage();                   // This is where page content is created.
    SaveDocument();
end;

procedure TFormKMemo2pdf.SaveDocument();
var
    F: TFileStream;
begin
  F := TFileStream.Create(FFileName, fmCreate);
  try try
    FDoc.SaveToStream(F);
//    Writeln('Document used ',FDoc.ObjectCount,' PDF objects/commands');
  except on E: Exception do
    Memo1.Append('ERROR - Failed to save the PDF ' + E.Message);
  end;
  finally
    F.Free;
  end;
   Memo1.Append('INFO Wrote file to ' + FFileName);
end;

procedure TFormKMemo2pdf.BitBtnProceedClick(Sender: TObject);                   // ToDo : replace all this with call to StartPDF
var
    i : integer;
begin
    AllowNoBoldItalic := True;
    StartPDF();
    exit();

(*  CurrentPage := -1;
    If WordList <> nil then
        FreeAndNil(WordList);
    FontList := TFontList.Create();
    WordList := TWordList.Create;
    KMemoRead();
    // This is for later, it does no make fonts available to the PDF
    gTTFontCache.ReadStandardFonts;                             // https://forum.lazarus.freepascal.org/index.php/topic,54280.msg406091.html
//    gTTFontCache.SearchPath.Add('/usr/share/fonts/');         // ToDo : this is NOT cross platform
    gTTFontCache.BuildFontCache;

//    Memo1.append('TFormKMemo2pdf.BitBtn2Click gTTFontCache has ' + inttostr(gTTFontCache.Count) + ' fonts including - ');
    for i := 0 to gTTFontCache.Count -1 do                      // ToDo : remove me
(*     if (gTTFontCache.Items[i].FamilyName = 'Ubuntu') or (gTTFontCache.Items[i].FamilyName = 'Karumbi') then begin

         Memo1.append(gTTFontCache.Items[i].FamilyName
            + ' - ' + gTTFontCache.Items[i].FileName
            + ' - ' + gTTFontCache.Items[i].HumanFriendlyName
            + ' - ' + booltostr(gTTFontCache.Items[i].IsBold, true)
            + ' - ' + booltostr(gTTFontCache.Items[i].IsItalic, true)
            + ' - ' + booltostr(gTTFontCache.Items[i].IsFixedWidth, true)
            + ' - ' + booltostr(gTTFontCache.Items[i].IsRegular, true));

         writeln(gTTFontCache.Items[i].FamilyName
            + ' - ' + gTTFontCache.Items[i].FileName
            + ' - ' + gTTFontCache.Items[i].HumanFriendlyName
            + ' - ' + booltostr(gTTFontCache.Items[i].IsBold, true)
            + ' - ' + booltostr(gTTFontCache.Items[i].IsItalic, true)
            + ' - ' + booltostr(gTTFontCache.Items[i].IsFixedWidth, true)
            + ' - ' + booltostr(gTTFontCache.Items[i].IsRegular, true));

     end; *)


    FDoc := TPDFDocument.Create(Nil);
//    FDoc.FontDirectory := '/usr/share/fonts';            // ToDo : this is NOT cross platform
    MakePDF();
    FDoc.Free;
    FreeAndNil(FontList);
    FreeAndNil(WordList);               *)
end;


function TFormKMemo2pdf.KMemoRead() : boolean;
var
    BlockNo : integer = 0;
    I : integer;
    ExFont : TFont;
    AWord : ANSIString = '';

        procedure CopyFont(FromFont : TFont);
        begin
            ExFont.Bold := FromFont.Bold;
            ExFont.Italic := FromFont.Italic;
            ExFont.Size := FromFont.Size;
            ExFont.Color := FromFont.Color;
            ExFont.Name := FromFont.Name;
        end;
begin
    ExFont := TFont.Create();
    for BlockNo := 0 to TheKMemo.Blocks.Count-1 do begin                                    // For every block
        if not TheKMemo.Blocks.Items[BlockNo].ClassNameIs('TKMemoParagraph') then begin
           CopyFont(TKMemoTextBlock(TheKmemo.Blocks.Items[BlockNo]).TextStyle.Font);        // copies to ExFont
           if ExFont.Name = 'default' then begin
               //writeln('INFO TFormKMemo2pdf.KMemoRead() Reasigning [' + TheKmemo.Blocks.Items[BlockNo].Text + '] to font=' + DefaultFont);
               ExFont.Name := DefaultFont;
           end;
           FontList.Add(ExFont.Name, ExFont.Bold, ExFont.Italic);
           for I := 0 to TheKMemo.Blocks.Items[BlockNo].WordCount-1 do begin                // For every word in this block
               AWord := TheKMemo.Blocks.Items[BlockNo].Words[I];
               WordList.Add(AWord, ExFont.Size, ExFont.Bold, ExFont.Italic, False, ExFont.Color, ExFont.Name);
           end;
        end else begin
            WordList.Add('', 0, False, False, True, clBlack);   // TKMemoParagraph, thats easy but is it a Bullet ?
            if (TKMemoParagraph(Thekmemo.blocks.Items[BlockNo]).Numbering <> pnuNone) then begin
               // We want to mark start of bullet, not KMemo's way of marking at the end.
               I := WordList.Count -2;                          // Thats just before the current one
               while I > -1 do begin
                       if WordList[i]^.NewLine then break;
                       dec(i);
               end;
               if i < 0 then                                    // under run, bullet must be first line ??
                      WordList[0]^.ABullet := TKMemoParagraph(Thekmemo.blocks.Items[BlockNo]).Numbering
               else WordList[i+1]^.ABullet := TKMemoParagraph(Thekmemo.blocks.Items[BlockNo]).Numbering;  // Must be the one we want. Mark first word after NL
            end;
        end;
    end;
    FreeandNil(ExFont);
    WordIndex := 0;
    result := (WordList.Count > 1);
    //WordList.Dump();
    {   (TKMemoParagraph(Thekmemo.blocks.Items[BlockNo]).Numbering = pnuBullets)
    pnuNone, BulletOne .. BulletEight }
end;


procedure TFormKMemo2pdf.FormCreate(Sender: TObject);
begin
    WordList := nil;
    FontList := nil;
    CurrentPage := -1;
    Memo1.Clear;
end;

procedure TFormKMemo2pdf.FormShow(Sender: TObject);
begin
    AllowNoBoldItalic := False;
end;

end.

