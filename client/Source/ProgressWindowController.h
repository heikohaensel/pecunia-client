//
//  ProgressWindowController.h
//  Pecunia
//
//  Created by Frank Emminghaus on 20.09.11.
//  Copyright 2011 Frank Emminghaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MessageLog.h"

@interface ProgressWindowController : NSWindowController <MessageLogUI> {
    IBOutlet NSTextView             *logView;
    IBOutlet NSButton               *closeButton;
    IBOutlet NSProgressIndicator    *progressIndicator;
	BOOL                            isHidden;
	MessageLog                      *messageLog;
    LogLevel                        maxLevel;
    
}

-(IBAction)cancel:(id)sender;
-(void)stop;
-(void)start;
@end