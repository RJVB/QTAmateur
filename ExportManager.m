//
//  ExportManager.m
//  QTAmateur
//
//  Created by Michael Ash on 5/24/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "ExportManager.h"

#import "NSString+QTMAAdditions.h"

#import "MAMovieExport.h"


NSString * const kExportSelectedCodecDefaultsName = @"Selected Exporter"; // NSString w/ type/manf
NSString * const kExportSettingsDefaultsName = @"Export Settings"; // NSDictionary (NSString w/ type/manf -> NSData)

@implementation ExportManager

- init
{
	return [self initWithQTMovie:nil];
}

- initWithQTMovie:(QTMovie *)m
{
	[self setMovie:m];

	NSArray *components = [[MAMovieExport sharedInstance] componentList];
	NSDictionary *savedSettings = [[NSUserDefaults standardUserDefaults] objectForKey:kExportSettingsDefaultsName];
	NSString *codecName = [[NSUserDefaults standardUserDefaults] objectForKey:kExportSelectedCodecDefaultsName];
	int count = [components count];
	int i;
	exportSettingsArray = [[NSMutableArray alloc] initWithCapacity:[components count]];
	for(i = 0; i < count; i++)
	{
		NSDictionary *component = [components objectAtIndex:i];
		NSString *subtype = [NSString stringWithFourCharCode:[[component objectForKey:kMAMovieExportComponentSubtype] longValue]];
		NSString *manufacturer = [NSString stringWithFourCharCode:[[component objectForKey:kMAMovieExportComponentManufacturer] longValue]];
		NSString *name = [subtype stringByAppendingString:manufacturer];
		id data = [savedSettings objectForKey:name];
		[exportSettingsArray addObject:(data ? data : [NSNull null])];
		if([name isEqualToString:codecName])
			defaultIndex = i;
	}
	
	return self;
}

- (void)dealloc
{
	[self setMovie:nil];
	[exportSettingsArray release];
	
	[progressPanel release];
	
	[super dealloc];
}

- (void)setMovie:(QTMovie *)m
{
	if(m != movie)
	{
		[movie release];
		movie = [m retain];
	}
}

- (void)progressCancel:sender
{
	[NSApp abortModal];
}

- (void)saveSettingsToDefaults
{
	NSMutableDictionary *savedSettings = [[[NSUserDefaults standardUserDefaults] objectForKey:kExportSettingsDefaultsName] mutableCopy];
	if(!savedSettings) savedSettings = [[NSMutableDictionary alloc] init];
	
	NSArray *components = [[MAMovieExport sharedInstance] componentList];
	int count = [components count];
	int i;
	for(i = 0; i < count; i++)
	{
		id data = [exportSettingsArray objectAtIndex:i];
		if(data != [NSNull null] || i == defaultIndex)
		{
			NSDictionary *component = [components objectAtIndex:i];
			NSString *subtype = [NSString stringWithFourCharCode:[[component objectForKey:kMAMovieExportComponentSubtype] longValue]];
			NSString *manufacturer = [NSString stringWithFourCharCode:[[component objectForKey:kMAMovieExportComponentManufacturer] longValue]];
			NSString *name = [subtype stringByAppendingString:manufacturer];
			if(data != [NSNull null])
				[savedSettings setObject:data forKey:name];
			if(i == defaultIndex)
				[[NSUserDefaults standardUserDefaults] setObject:name forKey:kExportSelectedCodecDefaultsName];
		}
	}
	[[NSUserDefaults standardUserDefaults] setObject:savedSettings forKey:kExportSettingsDefaultsName];
	[savedSettings release];
}

- (int)defaultIndex
{
	return defaultIndex;
}

- (void)setDefaultIndex:(int)index
{
	defaultIndex = index;
	[self saveSettingsToDefaults];
}

- (void)showSettingsAtIndex:(int)index
{
	NSDictionary *component = [[[MAMovieExport sharedInstance] componentList] objectAtIndex:index];
	id exportSettings = [exportSettingsArray objectAtIndex:index];
	if(exportSettings == [NSNull null]) exportSettings = exportSettingsLatest;
	NSData *data = [[MAMovieExport sharedInstance] exportDataForMovie:movie withComponent:component withOldSettings:exportSettings];
	if(data)
	{
		[exportSettingsArray replaceObjectAtIndex:index withObject:data];
		exportSettingsLatest = data;
	}
}

- (BOOL)exportToFile:(NSString *)file named:(NSString *)name atIndex:(int)index
{
	return [self exportMovie:movie toFile:file named:name atIndex:index];
}

- (BOOL)exportMovie:(QTMovie *)m toFile:(NSString *)file named:(NSString *)name atIndex:(int)index
{
	id exportSettings = [exportSettingsArray objectAtIndex:index];
	if(exportSettings == [NSNull null]) exportSettings = exportSettingsLatest;
	NSDictionary *component = [[[MAMovieExport sharedInstance] componentList] objectAtIndex:index];
	NSMutableDictionary *attributes = [[[MAMovieExport sharedInstance] exportAttributesWithComponent:component withExportData:exportSettings] mutableCopy];
	[attributes setObject:name forKey:@"MAName"];
	
	id oldDelegate = [m delegate];
	[m setDelegate:self];
	BOOL result = [m writeToFile:file withAttributes:attributes];
	[m setDelegate:oldDelegate];
	
	[attributes release];
	
	return result;
}

- (BOOL)movie:(QTMovie *)movie shouldContinueOperation:(NSString *)op withPhase:(QTMovieOperationPhase)phase atPercent:(NSNumber *)percent withAttributes:(NSDictionary *)attributes
{
	if(!progressPanel)
		[NSBundle loadNibNamed:@"ExportManager" owner:self];
	
	if(phase == QTMovieOperationBeginPhase)
	{
		[progressPanel setTitle:NSLocalizedString(@"Export", @"")];
		[progressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting %@...", @""), [attributes objectForKey:@"MAName"]]];
		[progressIndicator setDoubleValue:0];
		[progressIndicator setUsesThreadedAnimation:YES];
		progressModalSession = [NSApp beginModalSessionForWindow:progressPanel];
	}
	else if(phase == QTMovieOperationEndPhase)
	{
		[NSApp endModalSession:progressModalSession];
		[progressPanel orderOut:self];
	}
	else if(phase == QTMovieOperationUpdatePercentPhase)
	{
		[progressIndicator setDoubleValue:[percent doubleValue]];
		
		int response = [NSApp runModalSession:progressModalSession];
		
		return (response == NSRunContinuesResponse);
	}
	return YES;
}

@end
