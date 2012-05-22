//
//  NSATextField.h
//  QTAmateur
//
//  Created by René J.V. Bertin on 20070514.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSATextField : NSTextField {

	QTMovie *movie;

}

- (void)setMovie:(QTMovie*)m;

- (IBAction)goTime:(id)sender;

@end
