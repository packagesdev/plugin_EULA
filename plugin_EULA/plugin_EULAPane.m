/*
 Copyright (c) 2009-2018, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "plugin_EULAPane.h"

@interface InstallerPane (Apple_Private)

- (void)setTitle:(NSString *)inTitle;

- (NSButton *)nextButton;

- (void)setPreviousTitle:(NSString *)inTitle;
- (void)setNextTitle:(NSString *)inTitle;

@end

@interface WBEULAInstallerPane ()
{
	IBOutlet NSPopUpButton * _languagePopupButton;
	
	IBOutlet NSScrollView * _scrollView;
	
	IBOutlet NSTextView * _textView;
	
	
	
	IBOutlet NSView * _bottomView;
	
	IBOutlet NSButton * _printButton;
	
	IBOutlet NSButton * _saveButton;
	
	
	IBOutlet NSWindow * _alertWindow;
	
	IBOutlet NSTextField * _alertTitle;
	
	IBOutlet NSTextField * _alertMessage;
	
	IBOutlet NSButton * _alertAgreeButton;
	
	IBOutlet NSButton * _alertDisagreeButton;
	
	IBOutlet NSButton * _alertReadLicenseButton;
	
	// Data
	
	BOOL _licenseAgreed;
	
	NSWindow * _window;
	
	NSBundle * _bundle;
	
	NSMutableArray * _sortedAvailableLanguages;
	
	NSMutableDictionary * _conversionDictionary;
	
	NSMutableDictionary * _cachedLocalizedStrings;
	
	NSMutableDictionary * _cachedLicensesDictionary;
	
	NSString * _cachedUILanguage;
	
	NSString * _cachedLicenseLanguage;
	
}

+ (NSDictionary *)defaultStorageOptionsWithPath:(NSString *)inPath;

- (NSString *)nativeLocalizedString:(NSString *)inString forLanguage:(NSString *)inLanguage;

- (NSString *)nativeNameForLanguage:(NSString *)inLanguage;

- (void)showLicenseForNativeLanguage:(NSString *)inLanguage;

- (void)updateButtonsForNativeLanguage:(NSString *)inNativeLanguage;

- (IBAction)endDialog:(id)sender;

- (IBAction)switchLicenseLanguage:(id)sender;

- (IBAction)print:(id)sender;

- (IBAction)saveAs:(id)sender;

// Notifications

- (void)viewFrameDidChange:(NSNotification *)inNotification;

@end

@implementation WBEULAInstallerPane

+ (NSDictionary *)defaultStorageOptionsWithPath:(NSString *)inPath
{
	NSDictionary * tFontDictionary=@{NSFontAttributeName:[NSFont fontWithName:@"Helvetica" size:12.0]};
	
	NSURL * tBaseURL=[NSURL fileURLWithPath:inPath];
	
	NSDictionary * tOptionsDictionary=@{@"DefaultAttributes":tFontDictionary,
										NSBaseURLDocumentOption:tBaseURL
										};
	
	return tOptionsDictionary;
}

- (id)init
{
	self=[super init];
	
	if (self!=nil)
	{
		_cachedLocalizedStrings=[NSMutableDictionary dictionary];
		_cachedLicensesDictionary=[NSMutableDictionary dictionary];
	}
	
	return self;
}

- (void)awakeFromNib
{
	_bundle=[[self section] bundle];
	
	_cachedUILanguage=[self nativeNameForLanguage:[[[NSBundle mainBundle] preferredLocalizations] firstObject]];
	
	if (_bundle!=nil)
	{
		[_textView setTextContainerInset:NSMakeSize(6.0f,6.0f)];
		
		[_textView setDrawsBackground:NO];
		
		[[_textView enclosingScrollView] setDrawsBackground:NO];
		
		NSString * tResourcesPath=[_bundle resourcePath];
		
		NSMutableArray * tLanguagesArray=[NSMutableArray array];
		
		if (tResourcesPath!=nil)
		{
			NSFileManager * tFileManager=[NSFileManager defaultManager];
			
			NSArray * tArray=[tFileManager contentsOfDirectoryAtPath:tResourcesPath error:NULL];
			
			_conversionDictionary=[NSMutableDictionary dictionary];
			
			for(NSString * tFileName in tArray)
			{
				BOOL isDirectory;
				
				NSString * tLprojFolderPath=[tResourcesPath stringByAppendingPathComponent:tFileName];
				
				if ([tFileManager fileExistsAtPath:tLprojFolderPath isDirectory:&isDirectory]==YES && isDirectory==YES)
				{
					if ([tFileName hasPrefix:@"."]==NO && [[tFileName pathExtension] isEqualToString:@"lproj"]==YES)
					{
						NSString * tFolderLanguage=[[tFileName lastPathComponent] stringByDeletingPathExtension];
						
						// Get the Localizations for this language
						
						NSString * tLocalizedStringPath=[tLprojFolderPath stringByAppendingPathComponent:@"Localizable.strings"];
						
						if ([tFileManager fileExistsAtPath:tLocalizedStringPath isDirectory:&isDirectory]==YES && isDirectory==NO)
						{
							NSDictionary * tLocalizedStringDictionary=[NSDictionary dictionaryWithContentsOfFile:tLocalizedStringPath];
							
							if (tLocalizedStringDictionary!=nil)
								_cachedLocalizedStrings[tFolderLanguage]=tLocalizedStringDictionary;
						}
						
						NSString * tLanguageKey=[self nativeNameForLanguage:tFolderLanguage];
						
						if (tLanguageKey!=nil)
							_conversionDictionary[tLanguageKey]=tFolderLanguage;
						
						// Look for a license file
						
						NSArray * tLanguageFolderContents=[tFileManager contentsOfDirectoryAtPath:tLprojFolderPath error:NULL];
						
						for(NSString * tLocalizedResourceName in tLanguageFolderContents)
						{
							if ([tFileManager fileExistsAtPath:[tLprojFolderPath stringByAppendingPathComponent:tLocalizedResourceName] isDirectory:&isDirectory]==YES)
							{
								if (isDirectory==YES)
								{
									// We only support RTFD
									
									if ([tLocalizedResourceName isEqualToString:@"License.rtfd"]==YES)
									{
										[tLanguagesArray addObject:tFolderLanguage];
										
										_cachedLicensesDictionary[tFolderLanguage]=[tLprojFolderPath stringByAppendingPathComponent:tLocalizedResourceName];
									}
								}
								else if (isDirectory==NO)
								{
									// We support RTF and TXT
									
									if ([tLocalizedResourceName isEqualToString:@"License.rtf"]==YES ||
										[tLocalizedResourceName isEqualToString:@"License.txt"]==YES)
									{
										[tLanguagesArray addObject:tFolderLanguage];
										
										_cachedLicensesDictionary[tFolderLanguage]=[tLprojFolderPath stringByAppendingPathComponent:tLocalizedResourceName];
									}
								}
							}
						}
					}
				}
			}
		}
		
		NSUInteger tLanguageCount=[_cachedLicensesDictionary count];
		
		if (tLanguageCount>0)
		{
			_sortedAvailableLanguages=[NSMutableArray array];
			
			if (_sortedAvailableLanguages!=nil)
			{
				for(NSString * tLanguageObject in tLanguagesArray)
				{
					NSString * tLanguageKey=[self nativeNameForLanguage:tLanguageObject];
					
					if (tLanguageKey!=nil)
						[_sortedAvailableLanguages addObject:tLanguageKey];
				}
			}
			
			// Build the Popup menu
			
			if ([_sortedAvailableLanguages count]>0)
			{
				[_sortedAvailableLanguages sortUsingSelector:@selector(caseInsensitiveCompare:)];
				
				[_languagePopupButton removeAllItems];
				
				[_languagePopupButton addItemsWithTitles:_sortedAvailableLanguages];
				
				_cachedLicenseLanguage=[self nativeNameForLanguage:[[NSBundle preferredLocalizationsFromArray:tLanguagesArray] firstObject]];
				
				if (_cachedLicenseLanguage!=nil)
					[_languagePopupButton selectItemWithTitle:_cachedLicenseLanguage];
				
				[self showLicenseForNativeLanguage:_cachedLicenseLanguage];
			}
		}
		else
		{
			[_textView setString:@"Missing License documents"];
		}
	}
	else
	{
		NSLog(@"Unable to create the bundle instance for the plugin");
	}
}

- (NSString *)nativeLocalizedString:(NSString *)inString forLanguage:(NSString *)inLanguage
{
	if (inLanguage!=nil && inString!=nil)
	{
		NSString * tLocalizedString=_cachedLocalizedStrings[_conversionDictionary[inLanguage]][inString];
		
		if (tLocalizedString!=nil)
			return tLocalizedString;
	}
	
	return inString;
}

- (NSString *)nativeNameForLanguage:(NSString *)inLanguage
{
	if (inLanguage==nil)
		return nil;

	static dispatch_once_t onceToken;
	static NSDictionary * sConversionDictionary=nil;
	
	dispatch_once(&onceToken, ^{
		
		NSString * tPath=[_bundle pathForResource:@"ConversionTable" ofType:@"plist"];
		
		if (tPath!=nil)
		{
			sConversionDictionary=[[NSDictionary alloc] initWithContentsOfFile:tPath];
		}
		else
		{
			NSLog(@"Missing ConversionTable.plist file");
		}
	});
	
	return sConversionDictionary[inLanguage];
}

- (NSString *)title
{
	return [[NSBundle bundleForClass:[self class]] localizedStringForKey:@"PaneTitle" value:nil table:nil];
}

- (id)bottomContentView
{
	return _bottomView;
}

#pragma mark -

- (void)didExitPane:(InstallerSectionDirection)inDirection
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:[_window contentView]];
}

- (void)didEnterPane:(InstallerSectionDirection)inDirection
{
	_window=[_languagePopupButton window];
	
	[self viewFrameDidChange:nil];
	
	[self updateButtonsForNativeLanguage:_cachedLicenseLanguage];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(viewFrameDidChange:)
												 name:NSViewFrameDidChangeNotification
											   object:[_window contentView]];
}

- (BOOL)shouldExitPane:(InstallerSectionDirection)inDirection
{
	if (inDirection!=InstallerDirectionForward)
		return YES;
	
	if (_licenseAgreed==YES)
		return YES;

	NSString * tLanguage=_cachedLicenseLanguage;
	
	if (_cachedUILanguage!=nil && [_sortedAvailableLanguages indexOfObject:_cachedUILanguage]==NSNotFound && [_sortedAvailableLanguages count]<2)
	{
		NSDictionary * tDictionary=_cachedLocalizedStrings[_conversionDictionary[_cachedUILanguage]];
		
		if (tDictionary!=nil)
			tLanguage=_cachedUILanguage;
	}
	
	_alertTitle.stringValue=[self nativeLocalizedString:@"Alert Title" forLanguage:tLanguage];
	_alertMessage.stringValue=[self nativeLocalizedString:@"Alert Message" forLanguage:tLanguage];
	
	_alertAgreeButton.title=[self nativeLocalizedString:@"Agree" forLanguage:tLanguage];
	_alertDisagreeButton.title=[self nativeLocalizedString:@"Disagree" forLanguage:tLanguage];
	_alertReadLicenseButton.title=[self nativeLocalizedString:@"Read License" forLanguage:tLanguage];
	
	[NSApp beginSheet:_alertWindow
	   modalForWindow:_window
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:NULL];
	
	return NO;
}

- (IBAction)endDialog:(NSButton *)sender
{
	[NSApp endSheet:_alertWindow];
	
	[_alertWindow orderOut:self];
	
	if ([sender tag]==1)
	{
		_licenseAgreed=YES;
		
		[self gotoNextPane];
	}
	else if ([sender tag]==2)
	{
		[NSApp terminate:self];
	}
}

#pragma mark -

- (IBAction)print:(id)sender
{
	NSPrintInfo * tPrintInfo=[NSPrintInfo sharedPrintInfo];
	
	tPrintInfo.verticallyCentered=NO;
	
	tPrintInfo.leftMargin=50.0;
	tPrintInfo.rightMargin=50.0;
	tPrintInfo.topMargin=55.0;
	tPrintInfo.bottomMargin=55.0;
	
	tPrintInfo.horizontalPagination=NSFitPagination;
	tPrintInfo.verticalPagination=NSAutoPagination;
	
	[[NSPrintOperation printOperationWithView:_textView] runOperationModalForWindow:_window
																			 delegate:nil
																	   didRunSelector:nil
																		  contextInfo:NULL];
}

- (IBAction)saveAs:(id)sender
{
	NSSavePanel * tSavePanel=[NSSavePanel savePanel];
	
	tSavePanel.allowedFileTypes=@[@"pdf"];
	tSavePanel.directoryURL=[NSURL fileURLWithPath:NSHomeDirectory()];
	tSavePanel.nameFieldStringValue=[self nativeLocalizedString:@"License" forLanguage:_cachedLicenseLanguage];
	
	NSInteger tReturnCode=[tSavePanel runModal];
	
	if (tReturnCode!=NSFileHandlingPanelOKButton)
		return;
	
	NSPrintInfo * tPrintInfo=[NSPrintInfo sharedPrintInfo];
	
	tPrintInfo.horizontallyCentered=YES;
	tPrintInfo.verticallyCentered=NO;
	
	tPrintInfo.leftMargin=50.0f;
	tPrintInfo.rightMargin=50.0;
	tPrintInfo.topMargin=55.0;
	tPrintInfo.bottomMargin=55.0;
	
	tPrintInfo.horizontalPagination=NSFitPagination;
	tPrintInfo.verticalPagination=NSAutoPagination;
	
	tPrintInfo.jobDisposition=NSPrintSaveJob;
	
	
	NSMutableDictionary * tMutableDictionary=[tPrintInfo dictionary];
	
	if (tMutableDictionary!=nil)
	{
		tMutableDictionary[NSPrintJobSavingURL]=[tSavePanel URL];
		tMutableDictionary[NSPrintAllPages]=@(YES);
	}
	
	// We use a temporary text view (instead of the one in the pane because we need to set the text view to be as high as needed)
	
	NSTextView * tTextView=[[NSTextView alloc] initWithFrame:NSMakeRect(0.0,0.0,630.0,1000.0)];		// 630.0 looks fine
	
	NSTextContainer * tTextContainer=[_textView textContainer];
	
	// We will switch between the real text view and this one
	
	[tTextContainer setTextView:tTextView];
	
	NSLayoutManager * tLayoutManager=[tTextContainer layoutManager];
	
	NSUInteger tNumberOfGlyphs=[tLayoutManager numberOfGlyphs];
	
	NSRect tBounds=[tLayoutManager boundingRectForGlyphRange:NSMakeRange(0,tNumberOfGlyphs) inTextContainer:tTextContainer];
	
	[tTextView setFrame:tBounds];
	
	NSPrintOperation * tPrintOperation=[NSPrintOperation printOperationWithView:tTextView printInfo:tPrintInfo];
	
	tPrintOperation.showsPrintPanel=NO;
	tPrintOperation.showsProgressPanel=NO;
	
	BOOL tFileSaved=[tPrintOperation runOperation];
	
	// We revert to the real view
	
	[tTextContainer setTextView:_textView];
	
	if (tFileSaved==NO)
	{
		NSBeep();
		
		NSAlert * tAlert=[NSAlert new];
		
		tAlert.messageText=NSLocalizedStringFromTableInBundle(@"Save Error Title",@"Localizable",_bundle,@"");
		tAlert.informativeText=NSLocalizedStringFromTableInBundle(@"Save Error Message",@"Localizable",_bundle,@"");
		
		[tAlert beginSheetModalForWindow:_window modalDelegate:nil didEndSelector:nil contextInfo:NULL];
	}
}

- (IBAction)switchLicenseLanguage:(NSPopUpButton *)sender
{
	NSString * tSelectedLanguage=[sender titleOfSelectedItem];
	
	if (_cachedLicenseLanguage==nil || [_cachedLicenseLanguage isEqualToString:tSelectedLanguage]==NO)
	{
		_cachedLicenseLanguage=nil;
		
		_cachedLicenseLanguage=tSelectedLanguage;
		
		_cachedUILanguage=nil;
		
		_cachedUILanguage=_cachedLicenseLanguage;
		
		[self showLicenseForNativeLanguage:_cachedLicenseLanguage];
	}
}

- (void)showLicenseForNativeLanguage:(NSString *)inLanguage
{
	NSString * tDocumentPath=_cachedLicensesDictionary[_conversionDictionary[inLanguage]];
	
	// Update Text View
	
	if (tDocumentPath!=nil)
	{
		[_textView setString:@""];
		
		NSTextStorage * tTextStorage=[_textView textStorage];
		
		[tTextStorage beginEditing];
		
		[tTextStorage readFromURL:[NSURL fileURLWithPath:tDocumentPath]
						  options:[WBEULAInstallerPane defaultStorageOptionsWithPath:tDocumentPath]
			   documentAttributes:NULL];
		
		
		[tTextStorage endEditing];
		
		[_textView scrollRangeToVisible:NSMakeRange(0,0)];
	}
	
	[self updateButtonsForNativeLanguage:inLanguage];
}

- (void)updateButtonsForNativeLanguage:(NSString *)inNativeLanguage
{
	NSString * tLanguage=_cachedLicenseLanguage;
	
	if (_cachedUILanguage!=nil && [_sortedAvailableLanguages indexOfObject:_cachedUILanguage]==NSNotFound)
	{
		NSDictionary * tDictionary=_cachedLocalizedStrings[_conversionDictionary[_cachedUILanguage]];
		
		if (tDictionary!=nil)
			tLanguage=_cachedUILanguage;
	}
	
	[self setTitle:[self nativeLocalizedString:@"PaneTitle" forLanguage:tLanguage]];
	
	// Update Buttons
	
	NSButton * tNextButton=[self nextButton];
	
	NSRect tRectInWindow=[_bottomView convertRect:_bottomView.frame
										   toView:tNextButton.superview];
	
	NSRect tButtonFrame=_printButton.frame;
	tButtonFrame.origin.y=NSMinY(tNextButton.frame)-NSMinY(tRectInWindow);
	_printButton.frame=tButtonFrame;
	
	
	tButtonFrame=_saveButton.frame;
	tButtonFrame.origin.y=NSMinY(tNextButton.frame)-NSMinY(tRectInWindow);
	_saveButton.frame=tButtonFrame;
	
	_printButton.title=[self nativeLocalizedString:@"Print..." forLanguage:tLanguage];
	
	_saveButton.title=[self nativeLocalizedString:@"Save..." forLanguage:tLanguage];
	
	
	[self setPreviousTitle:[self nativeLocalizedString:@"Go Back" forLanguage:tLanguage]];
	
	[self setNextTitle:[self nativeLocalizedString:@"Continue" forLanguage:tLanguage]];
}

#pragma mark -

- (void)viewFrameDidChange:(NSNotification *)inNotification
{
	// We want to make sure the no display text label is centered
	
	// Center the Language Popup button
	
	NSRect tViewFrame=[[_languagePopupButton superview] frame];
	
	NSRect tLabelFrame=[_languagePopupButton frame];
	
	tLabelFrame.origin.x=round(NSMidX(tViewFrame)-NSWidth(tLabelFrame)*0.5)-2.;
	
	[_languagePopupButton setFrame:tLabelFrame];
}

@end
