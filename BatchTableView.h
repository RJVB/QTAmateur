//
//  BatchTableView.h
//  QTAmateur
//
//  Created by Michael Ash on 5/24/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BatchTableView : NSTableView {

}

@end

@interface NSObject (BatchTableViewDataSource)

- (void)tableViewDeleteSelectedRows:(NSTableView *)tableView;

@end