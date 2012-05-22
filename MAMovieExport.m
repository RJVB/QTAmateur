//
//  MAMovieExport.m
//  QTAmateur
//
//  Created by Michael Ash on 5/23/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "MAMovieExport.h"

#import "NSString+QTMAAdditions.h"


@implementation MAMovieExport

NSString * const kMAMovieExportComponentName = @"kMAMovieExportComponentName"; // NSString
NSString * const kMAMovieExportComponentInfo = @"kMAMovieExportComponentInfo"; // NSString
NSString * const kMAMovieExportComponentData = @"kMAMovieExportComponentData"; // NSData wrapping Component
NSString * const kMAMovieExportComponentType = @"kMAMovieExportComponentType"; // NSNumber
NSString * const kMAMovieExportComponentSubtype = @"kMAMovieExportComponentSubtype"; // NSNumber
NSString * const kMAMovieExportComponentManufacturer = @"kMAMovieExportComponentManufacturer"; // NSNumber
NSString * const kMAMovieExportComponentFileExtension = @"kMAMovieExportComponentFileExtension"; // NSString

static MAMovieExport *sharedInstance = nil;

+ sharedInstance
{
	if(!sharedInstance)
		sharedInstance = [[self alloc] init];
	return sharedInstance;
}

- init
{
	if(sharedInstance)
	{
		[self release];
		return [sharedInstance retain];
	}
	return [super init];
}

- (NSArray *)componentList
{
	if(!componentList)
	{
		NSMutableArray *array = [NSMutableArray array];
		
		ComponentDescription cd;
		Component c;
		
		cd.componentType = MovieExportType;
		cd.componentSubType = 0;
		cd.componentManufacturer = 0;
		cd.componentFlags = canMovieExportFiles;
		cd.componentFlagsMask = canMovieExportFiles;
		
		while((c = FindNextComponent(c, &cd)))
		{
			Handle name = NewHandle(4);
			Handle info = NewHandle(4);
			ComponentDescription exportCD;
			
			if (GetComponentInfo(c, &exportCD, name, info, nil) == noErr)
			{
				// skip 'musi' components
				if(exportCD.componentManufacturer == 'musi')
					continue;
				
				unsigned char *namePStr = (unsigned char *)*name;
				unsigned char *infoPStr = (unsigned char *)*info;
				
				NSString *nameStr = [[NSString alloc] initWithBytes:&namePStr[1] length:namePStr[0] encoding:NSMacOSRomanStringEncoding];
				NSString *infoStr = [[NSString alloc] initWithBytes:&infoPStr[1] length:infoPStr[0] encoding:NSMacOSRomanStringEncoding];
				
				if(!nameStr)
					nameStr = NSLocalizedString(@"Name couldn't be read", @"");
				if(!infoStr)
					infoStr = NSLocalizedString(@"Info couldn't be read", @"");
				
				OSType extensionOSType;
				NSString *extension = nil;
				ComponentResult err = MovieExportGetFileNameExtension((MovieExportComponent)c, &extensionOSType);
				if(err == noErr)
					extension = [[NSString stringWithFourCharCode:extensionOSType] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
					nameStr, kMAMovieExportComponentName,
					infoStr, kMAMovieExportComponentInfo,
					[NSData dataWithBytes:&c length:sizeof(c)], kMAMovieExportComponentData,
					[NSNumber numberWithLong:exportCD.componentType], kMAMovieExportComponentType,
					[NSNumber numberWithLong:exportCD.componentSubType], kMAMovieExportComponentSubtype,
					[NSNumber numberWithLong:exportCD.componentManufacturer], kMAMovieExportComponentManufacturer,
					extension, kMAMovieExportComponentFileExtension,
					nil];
				[array addObject:dictionary];
				
				[nameStr release];
				[infoStr release];
			}
			
			DisposeHandle(name);
			DisposeHandle(info);
		}
		
		NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:kMAMovieExportComponentName ascending:YES];
		[array sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
		[descriptor release];
		
		componentList = [array copy];
	}
	return componentList;
}

	// this method displays the QT export settings dialog for the specified component
	// it returns nil if the user canceled, the data otherwise, as a wrapped
	// QTAtomContainer
- (NSData *)exportDataForMovie:(QTMovie *)movie withComponent:(NSDictionary *)componentDictionary withOldSettings:(NSData *)settingsData
{
	Component c;
	memcpy(&c, [[componentDictionary objectForKey:kMAMovieExportComponentData] bytes], sizeof(c));
	
	MovieExportComponent exporter = OpenComponent(c);
	
	if(settingsData)
	{
		QTAtomContainer settingsAtom = NULL;
		PtrToHand([settingsData bytes], &settingsAtom, [settingsData length]);
		MovieExportSetSettingsFromAtomContainer(exporter, settingsAtom);
		DisposeHandle(settingsAtom);
	}
	
	Boolean canceled;
	ComponentResult err = MovieExportDoUserDialog(exporter, [movie quickTimeMovie], NULL, 0, 0, &canceled);
	if(err)
	{
		NSLog(@"Got error %d when calling MovieExportDoUserDialog");
		CloseComponent(exporter);
		return nil;
	}
	if(canceled)
	{
		CloseComponent(exporter);
		return nil;
	}
	QTAtomContainer settings;
	err = MovieExportGetSettingsAsAtomContainer(exporter, &settings);
	if(err)
	{
		NSLog(@"Got error %d when calling MovieExportGetSettingsAsAtomContainer");
		CloseComponent(exporter);
		return nil;
	}
	NSData *data = [NSData dataWithBytes:*settings length:GetHandleSize(settings)];
	DisposeHandle(settings);
	
	CloseComponent(exporter);
	
	return data;
}	

	// this method returns a dictionary suitable for passing to -[QTMovie writeToFile:withAttributes:]
- (NSDictionary *)exportAttributesWithComponent:(NSDictionary *)componentDictionary withExportData:(NSData *)exportData
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES], QTMovieExport,
		[componentDictionary objectForKey:kMAMovieExportComponentSubtype], QTMovieExportType,
		[componentDictionary objectForKey:kMAMovieExportComponentManufacturer], QTMovieExportManufacturer,
		exportData, QTMovieExportSettings,
		nil];
}

@end
