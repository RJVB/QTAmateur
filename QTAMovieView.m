//
//  QTAMovieView.m
//  QTAmateur
//
//  Created by René J.V. Bertin on 20070404.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "QTAMovieView.h"


@implementation QTAMovieView

- (IBAction) play:(id) sender
{
	NSLog( @"%@: (Re)Starting movie %@", self, sender );
	return [super play:sender];
}

- (IBAction) pplay:(id) sender
{
//	NSLog( @"(Re)Starting movie" );
	return [self play:sender];
}

@end
