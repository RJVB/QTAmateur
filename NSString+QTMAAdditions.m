//
//  NSString+QTMAAdditions.m
//  QTAmateur
//
//  Created by Michael Ash on 5/24/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "NSString+QTMAAdditions.h"


@implementation NSString (QTMAAdditions)

+ (NSString *)stringWithFourCharCode:(long)fourChar
{
	char codeChars[4] = {
		((fourChar >> 24) & 0xFF),
		((fourChar >> 16) & 0xFF),
		((fourChar >> 8) & 0xFF),
		(fourChar & 0xFF)
	};
	NSString *str = [[NSString alloc] initWithBytes:codeChars length:4 encoding:NSMacOSRomanStringEncoding];
	return [str autorelease];
}

@end
