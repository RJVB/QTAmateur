//
//  ExportManager.h
//  QTAmateur
//
//  Created by Michael Ash on 5/24/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ExportManager : NSObject {
	QTMovie *movie;
	
	NSData *exportSettingsLatest;
	NSMutableArray *exportSettingsArray;
	
	int defaultIndex;

	NSModalSession progressModalSession;
	IBOutlet NSPanel *progressPanel;
	IBOutlet NSTextField *progressText;
	IBOutlet NSProgressIndicator *progressIndicator;	
}

- initWithQTMovie:(QTMovie *)m;
- (void)setMovie:(QTMovie *)m;

- (void)progressCancel:sender;

- (int)defaultIndex;
- (void)setDefaultIndex:(int)index;
- (void)showSettingsAtIndex:(int)index;

- (BOOL)exportToFile:(NSString *)file named:(NSString *)name atIndex:(int)index;
- (BOOL)exportMovie:(QTMovie *)m toFile:(NSString *)file named:(NSString *)name atIndex:(int)index;

@end
