//
//  GMPXApplication.m
//  GimpOnOSX
//
//  Created by Chris Fraire on 5/10/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GMPXApplication.h"
#import "GMPXConstants.h"

@implementation GMPXApplication

- (void)sendEvent:(NSEvent *)theEvent
{
    switch ([theEvent type]) {            
        case NSApplicationDefined:
            if ([theEvent data1] == kShouldStopEvent)
                [self terminate:theEvent];
            else if ([theEvent data1] == kShouldFinishDelayedTerminationEvent)
                [self replyToApplicationShouldTerminate:YES];
            break;
    }

    [super sendEvent:theEvent];
}

@end
