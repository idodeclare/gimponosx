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

// Same as script, gimp-remote
static NSString * const kGimpBinary = @"gimp-2.8";
static NSString * const kUsrLocalBin = @"/usr/local/bin";

static NSString * const kGimpTaskScript = @"script";
static NSString * const kGimpOpenDocScript = @"openDoc";
static NSString * const kGimpQuitAppScript = @"quitApp";

static NSString * const kWmCloseGimpScript = @"wm-closegimp";
static NSString * const kWmctrlProgramName = @"wmctrl";
static const NSTimeInterval kTerminateDelaySeconds = 4;

@interface GMPXAppDelegate ()

// Used by a timer to report to NSApplication the failure to wmctrl gimp
- (void)cancelDelayedTermination:(NSTimer*)theTimer;

// Call an applescript to activate X11
- (void)activateX11;

// start primary task
- (void)startPrimaryTaskWithArguments:(NSArray *)arguments;

// run the script 
- (void)startScript:(NSString *)scriptName withArguments:(NSArray *)arguments;

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
    // gimp-remote looks in PATH and /usr/local/bin
    if (![GMPXFileUtil findExecutableWithName:kGimpBinary atPaths:[NSArray arrayWithObject:kUsrLocalBin]]
        && ![GMPXFileUtil findExecutableWithNameInDefaultPath:kGimpBinary])
    {
        NSString *msg = [NSString stringWithFormat:@"%@ was not found.", kGimpBinary];
        NSAlert *noGimp = [NSAlert alertWithMessageText:msg defaultButton:nil 
                                        alternateButton:nil otherButton:nil 
                              informativeTextWithFormat:@"Brew gimp and try again."];
        [noGimp runModal];
        [[NSApplication sharedApplication] terminate:self];
        return;
    }

    _shouldActivateX11 = YES;

    if (!_remoteTasks)
        [self startPrimaryTaskWithArguments:[NSArray array]];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (_shouldActivateX11)
        [self activateX11];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (_terminationTimer)
        [_terminationTimer invalidate];
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
    [_terminationTimer release];
    _terminationTimer = nil;

    [[NSApplication sharedApplication] replyToApplicationShouldTerminate:NO];
}
     
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
    // just activate this app, which will trigger applicationDidBecomeActive:
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    return NO;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    NSArray *arguments = [NSArray arrayWithObject:filename];
    if (!_remoteTasks) {
        [self startPrimaryTaskWithArguments:arguments];
    }
    else {
        [self startScript:kGimpOpenDocScript withArguments:arguments];
    }
    // we successfully made our best effort to send to gimp :)
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    if (!_remoteTasks) {
        [self startPrimaryTaskWithArguments:filenames];
    }
    else {
        [self startScript:kGimpOpenDocScript withArguments:filenames];
    }
    // we successfully made our best effort to send to gimp :)
    [[NSApplication sharedApplication] replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (void)activateX11
{
    if (!_activateX11) 
        _activateX11 = [[NSAppleScript alloc] initWithSource:kActivateX11ScriptCode];

    [_activateX11 executeAndReturnError:nil];
    // hide Gimp.app so that X11 itself can be hidden (or else Gimp.app would 
    // immediately re-activate X11 when Gimp.app is shown)
    [[NSApplication sharedApplication] hide:self];
}

- (void)startPrimaryTaskWithArguments:(NSArray *)arguments
{
    [self startScript:kGimpTaskScript withArguments:arguments];
}

- (void)startScript:(NSString *)scriptName withArguments:(NSArray *)arguments
{
    NSString *fullScript = [self getPathToScript:scriptName];
    if (!fullScript) {
        NSLog(@"Unknown application script %@", scriptName);
        return;
    }

    NSTask *ntask = [[[NSTask alloc] init] autorelease];
    [ntask setLaunchPath:fullScript];
    [ntask setArguments:arguments];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleGimpRemoteTaskFinished:)
                                                 name:NSTaskDidTerminateNotification 
                                               object:ntask];
    // this method is thread safe on the first call if called from a 
    // NSApplication event, as it is
    if (!_tasksLock)
        _tasksLock = [[NSLock alloc] init];
    if (!_remoteTasks) 
        _remoteTasks = [[NSMutableArray alloc] init];
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
        NSEvent *customEvent = nil;
        
        if (_terminationTimer) {
            // proceed with delayed termination
            [_terminationTimer invalidate];
            [_terminationTimer release];
            _terminationTimer = nil;
            customEvent = [NSEvent otherEventWithType:NSApplicationDefined location:NSPointFromCGPoint(CGPointZero) modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 
                                                data1:kShouldFinishDelayedTerminationEvent data2:0];
        }
        else {
            customEvent = [NSEvent otherEventWithType:NSApplicationDefined location:NSPointFromCGPoint(CGPointZero) modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 
                                                data1:kShouldStopEvent data2:0];
        }

        if (customEvent)
            [[NSApplication sharedApplication] postEvent:customEvent atStart:NO];
    }

}

- (void)wmCloseGimp
{
    // call wmctrl if the binary can be found. Otherwise, no graceful shutdown
    // can happen, and Gimp.app will cancel termination
    //
    if (![GMPXFileUtil findExecutableWithName:kWmctrlProgramName atPaths:[NSArray arrayWithObject:kUsrLocalBin]]
        && ![GMPXFileUtil findExecutableWithNameInDefaultPath:kWmctrlProgramName]) 
    {
        NSLog(@"gimp cannot be shutdown gracefully: %@ is not found", kWmctrlProgramName);
        return;
    }

    [self startScript:kWmCloseGimpScript withArguments:[NSArray array]];
}

- (NSString *)getPathToScript:(NSString *)scriptName
{
    return [[NSBundle mainBundle] pathForResource:scriptName ofType:@""];
}

@end
