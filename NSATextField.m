//
//  NSATextField.m
//  QTAmateur
//
//  Created by René J.V. Bertin on 20070514.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSATextField.h"


@implementation NSATextField

- (void)setMovie:(QTMovie*) m
{
	movie= m;
}

- (void)goTime:sender;
{
	NSLog( @"goTime: %@, %@, m=%@", self, sender, movie );
}

@end
