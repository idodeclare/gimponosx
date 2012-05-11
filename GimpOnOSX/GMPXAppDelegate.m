//
//  GMPXAppDelegate.m
//  Gimp
//
//  Created by Chris Fraire on 5/10/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import "GMPXAppDelegate.h"
#import "GMPXFileUtil.h"
#import "GMPXConstants.h"

static NSString * const kGimpTaskScript = @"script";
static NSString * const kGimpOpenDocScript = @"openDoc";
static NSString * const kGimpQuitAppScript = @"quitApp";

static NSString * const kWmctrlProgramName = @"wmctrl";
static NSString * const kGimpWindowName1 = @"GNU Image Manipulation Program";
static NSString * const kGimpWindowName2 = @"gimp";
static const NSTimeInterval kTerminateDelaySeconds = 6;

@interface GMPXAppDelegate ()

// Used by a timer to report to NSApplication the failure to wmctrl gimp
- (void)cancelDelayedTermination:(NSTimer*)theTimer;

// Call an applescript to activate X11
- (void)activateX11;

// run the gimp-remote script 
- (void)startGimpRemoteTask:(NSArray *)arguments;
// process the notification for a gimp-remote task
- (void)handleGimpRemoteTaskFinished:(NSNotification *)notification;

// wmctrl -c gimp, etc.
- (void)wmCloseGimp;

// get the path to a bundle script
- (NSString *)getPathToScript:(NSString *)scriptName;

@end

@implementation GMPXAppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [_window release];
    [_tasksLock release];
    [_remoteTasks release];
    [_activateX11 release];
    [_terminationTimer release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if (!_remoteTasks)
        [self startGimpRemoteTask:[NSArray array]];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self activateX11];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (_terminationTimer)
        [_terminationTimer invalidate];
    NSLog(@"will terminate");
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if (!_remoteTasks)
        return NSTerminateNow;

    //
    // If there are active tasks:
    // 1) attempt to wmctrl gimp
    // 2) schedule a timer for further handling
    // 3) tell the NSApplication to NSTerminateLater
    //
    [_tasksLock lock];
    @try {
        if ([_remoteTasks count] < 1)
            return NSTerminateNow;
    }
    @finally {
        [_tasksLock unlock];
    }

    // Run wmctlr -c for graceful gimp shutdown
    [self wmCloseGimp];

    // set a timer that, if active after a number of seconds, will indicate
    // that the termination should NOT happen
    _terminationTimer = [[NSTimer timerWithTimeInterval:kTerminateDelaySeconds 
                                                 target:self 
                                               selector:@selector(cancelDelayedTermination:)
                                               userInfo:nil repeats:NO] retain];
    [[NSRunLoop currentRunLoop] addTimer:_terminationTimer forMode:NSModalPanelRunLoopMode];
    return NSTerminateLater;
}

- (void)cancelDelayedTermination:(NSTimer*)theTimer
{
    NSLog(@"canceling termination");
    [[NSApplication sharedApplication] replyToApplicationShouldTerminate:NO];
    [_terminationTimer release];
    _terminationTimer = nil;
}
     
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    // just activate this app, which will trigger applicationDidBecomeActive:
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    return NO;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    [self startGimpRemoteTask:[NSArray arrayWithObject:filename]];
    // we successfully made our best effort to send to gimp :)
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    [self startGimpRemoteTask:filenames];
    // we successfully made our best effort to send to gimp :)
    [[NSApplication sharedApplication] replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (void)activateX11
{
    if (!_activateX11) {
        _activateX11 = [[NSAppleScript alloc] initWithSource:kActivateX11ScriptCode];
    }
    [_activateX11 executeAndReturnError:nil];
}

- (void)startGimpRemoteTask:(NSArray *)arguments
{
    NSTask *ntask = [[[NSTask alloc] init] autorelease];
    [ntask setLaunchPath:[self getPathToScript:kGimpOpenDocScript]];
    [ntask setArguments:arguments];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleGimpRemoteTaskFinished:)
                                                 name:NSTaskDidTerminateNotification 
                                               object:ntask];
    // this method is thread safe on the first call if called from a 
    // NSApplication event, as it is
    if (!_tasksLock)
        _tasksLock = [[NSLock alloc] init];
    if (!_remoteTasks) {
        NSLog(@"Starting gimp task");
        _remoteTasks = [[NSMutableArray alloc] init];
    }
    [_tasksLock lock];
    [_remoteTasks addObject:ntask];
    [_tasksLock unlock];

    [ntask launch];
}

- (void)handleGimpRemoteTaskFinished:(NSNotification *)notification
{
    id ntask = [notification object];
    [_tasksLock lock];
    [_remoteTasks removeObject:ntask];
    BOOL shouldTerminate = ([_remoteTasks count] < 1);
    [_tasksLock unlock];    

    if (shouldTerminate) 
    {
        if (_terminationTimer) {
            // proceed with delayed termination
            [_terminationTimer invalidate];
            [_terminationTimer release];
            _terminationTimer = nil;
            [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
        }
        else {
            NSEvent *shouldStop = [NSEvent otherEventWithType:NSApplicationDefined location:NSPointFromCGPoint(CGPointZero) modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 
                                                        data1:kShouldStopEvent data2:0];
            [[NSApplication sharedApplication] postEvent:shouldStop atStart:NO];
        }
    }

}

- (void)wmCloseGimp
{
    // call wmctrl if the binary can be found. Otherwise, no graceful shutdown
    // can happen, and Gimp.app will cancel termination
    //
    NSString *wmctrlFullPath = [GMPXFileUtil findExecutableWithName:kWmctrlProgramName];
    if (!wmctrlFullPath) {
        NSLog(@"gimp cannot be shutdown gracefully: %@ is not found", kWmctrlProgramName);
        return;
    }

    [NSTask launchedTaskWithLaunchPath:wmctrlFullPath 
                             arguments:[NSArray arrayWithObjects:@"-c", kGimpWindowName1, nil]];
    [NSTask launchedTaskWithLaunchPath:wmctrlFullPath 
                             arguments:[NSArray arrayWithObjects:@"-c", kGimpWindowName2, nil]];
}

- (NSString *)getPathToScript:(NSString *)scriptName
{
    return [[NSBundle mainBundle] pathForResource:scriptName ofType:@""];
}

@end
