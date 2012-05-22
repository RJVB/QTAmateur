//
//  main.m
//  QTAmateur
//
//  Created by Michael Ash on 5/22/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

void SetupQTDRM(void)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSData *data = [NSData dataWithContentsOfFile:@"/Users/mikeash/Downloads/lame.txt"];
	if([data length] != 312)
		NSLog(@"bad data length!");
	int val = QTSetProcessProperty('dmmc', 'play', [data length], [data bytes]);
	NSLog(@"QTSetProcessProperty returned %d", val);
	
	[pool release];
}

int main(int argc, char *argv[])
{
	//SetupQTDRM();
    return NSApplicationMain(argc, (const char **) argv);
}
