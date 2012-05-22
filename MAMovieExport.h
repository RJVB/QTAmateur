//
//  MAMovieExport.h
//  QTAmateur
//
//  Created by Michael Ash on 5/23/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString * const kMAMovieExportComponentName; // NSString
extern NSString * const kMAMovieExportComponentInfo; // NSString
extern NSString * const kMAMovieExportComponentData; // NSData wrapping Component
extern NSString * const kMAMovieExportComponentType; // NSNumber
extern NSString * const kMAMovieExportComponentSubtype; // NSNumber
extern NSString * const kMAMovieExportComponentManufacturer; // NSNumber
extern NSString * const kMAMovieExportComponentFileExtension; // NSString

@class QTMovie;

@interface MAMovieExport : NSObject {
	NSArray *componentList;
}

+ sharedInstance;

- (NSArray *)componentList;

// this method displays the QT export settings dialog for the specified component
// it returns nil if the user canceled, the data otherwise, as a wrapped
// QTAtomContainer. pass nil for movie to get generic export settings
// if settingsData is non-nil, it will load those settings before displaying
// the exporter configuration
- (NSData *)exportDataForMovie:(QTMovie *)movie withComponent:(NSDictionary *)componentDictionary withOldSettings:(NSData *)settingsData;

// this method returns a dictionary suitable for passing to -[QTMovie writeToFile:withAttributes:]
- (NSDictionary *)exportAttributesWithComponent:(NSDictionary *)componentDictionary withExportData:(NSData *)exportData;

@end
