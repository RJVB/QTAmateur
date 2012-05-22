//
//  FullscreenFocusedWindow.m
//  QTAmateur
//
//  Created by Michael Ash on 5/22/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "FullscreenFocusedWindow.h"


@implementation FullscreenFocusedWindow

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

- (BOOL)canBecomeMainWindow
{
	return YES;
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	return [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:bufferingType defer:flag];
}

- (void)sendEvent:(NSEvent *)event
{
	BOOL pass = YES;
	if([event type] == NSKeyDown)
	{
		NSString *str = [event charactersIgnoringModifiers];
		if([str length] > 0 && [str characterAtIndex:0] == 27) // 27 == esc
		{
			[self performClose:self];
			pass = NO;
		}
	}

	if(pass)
	{
		[super sendEvent:event];
	}
}

- (void)performClose:sender
{
	if([[self delegate] respondsToSelector:_cmd])
		[[self delegate] performClose:sender];
}

//- (BOOL)validateMenuItem:(id <NSMenuItem>)item
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	return ([item action] == @selector(performClose:)) || [super validateMenuItem:item];
}

@end
