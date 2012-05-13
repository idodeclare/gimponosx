//
//  GMPXConstants.h
//  GimpOnOSX
//
//  Created by Chris Fraire on 5/10/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Used for NSApplicationDefined event to indicate a stop: 
extern const int kShouldStopEvent;
// Used for NSApplicationDefined event to finish NSTerminateLater: 
extern const int kShouldFinishDelayedTerminationEvent;

extern NSString * const kActivateX11ScriptCode;