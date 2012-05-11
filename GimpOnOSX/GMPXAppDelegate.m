//
//  GMPXAppDelegate.m
//  Gimp
//
//  Created by Chris Fraire on 5/10/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GMPXAppDelegate.h"
#import "GMPXConstants.h"

static NSString * const kGimpTaskScript = @"script";
static NSString * const kGimpOpenDocScript = @"openDoc";
static NSString * const kGimpQuitAppScript = @"quitApp";

@interface GMPXAppDelegate ()

- (void)startGimpTask;
- (void)handleGimpTaskFinished:(NSNotification *)notification;
- (void)activateX11;

- (NSString *)getPathToScript:(NSString *)scriptName;

@end

@implementation GMPXAppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [_window release];
    [_gimpTask release];
    [_gimpPeerTask release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self startGimpTask];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self activateX11];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
#warning TODO handle reopen
    return NO;
}

- (void)startGimpTask
{
    if (_gimpTask)
        return;

    _gimpTask = [[NSTask alloc] init];
    [_gimpTask setLaunchPath:[self getPathToScript:kGimpTaskScript]];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleGimpTaskFinished:)
                                                 name:NSTaskDidTerminateNotification 
                                               object:_gimpTask];
    [_gimpTask launch];
}

- (void)handleGimpTaskFinished:(NSNotification *)notification
{
    [_gimpTask release];
    _gimpTask = nil;

    NSEvent *shouldStop = [NSEvent otherEventWithType:NSApplicationDefined location:NSPointFromCGPoint(CGPointZero) modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 
                                                data1:kShouldStopEvent data2:0];
    [[NSApplication sharedApplication] postEvent:shouldStop atStart:NO];
}

- (void)activateX11
{
    if (!_activateX11) {
        _activateX11 = [[NSAppleScript alloc] initWithSource:kActivateX11ScriptCode];
    }
    [_activateX11 executeAndReturnError:nil];
}

- (NSString *)getPathToScript:(NSString *)scriptName
{
    return [[NSBundle mainBundle] pathForResource:scriptName ofType:@""];
}

@end
