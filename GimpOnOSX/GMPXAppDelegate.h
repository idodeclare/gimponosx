//
//  GMPXAppDelegate.h
//  Gimp
//
//  Created by Chris Fraire on 5/10/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GMPXAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *_window;
    NSTask *_gimpTask;
    NSTask *_gimpPeerTask;
    NSAppleScript *_activateX11; 
}

@property (assign) IBOutlet NSWindow *window;

@end
