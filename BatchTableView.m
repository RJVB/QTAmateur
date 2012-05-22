//
//  BatchTableView.m
//  QTAmateur
//
//  Created by Michael Ash on 5/24/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BatchTableView.h"


@implementation BatchTableView

- (void)keyDown:(NSEvent *)event
{
	unichar c = [[event charactersIgnoringModifiers] characterAtIndex:0];
	if(c == NSDeleteCharacter || c == NSDeleteFunctionKey)
	{
		if([[self dataSource] respondsToSelector:@selector(tableViewDeleteSelectedRows:)])
			[[self dataSource] tableViewDeleteSelectedRows:self];
	}
	else
		[super keyDown:event];
}

@end
