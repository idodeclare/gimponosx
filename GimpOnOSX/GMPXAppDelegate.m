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

- (void)cancelDelayedTermination:(NSTimer*)theTimer;

- (void)activateX11;

- (void)startGimpRemoteTask:(NSArray *)arguments;
- (void)handleGimpRemoteTaskFinished:(NSNotification *)notification;

- (void)wmCloseGimp;

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
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    //
    // If there are active tasks:
    // 1) ask the tasks to terminate
    // 2) schedule a timer to for further handling
    // 3) tell the NSApplication to NSTerminateLater
    //
    NSArray *tasksToTerm = nil;
    if (_remoteTasks) {
        [_tasksLock lock];
        tasksToTerm = [NSArray arrayWithArray:_remoteTasks];
        [_tasksLock unlock];
    }

    // Run wmctlr -c for graceful gimp shutdown
    [self wmCloseGimp];

    // set a timer that, if active after a number of seconds, will indicate
    // that the termination should NOT happen
    _terminationTimer = [[NSTimer scheduledTimerWithTimeInterval:kTerminateDelaySeconds 
                                                         target:self 
                                                        selector:@selector(cancelDelayedTermination:)
                                                        userInfo:nil repeats:NO] retain];
    return NSTerminateLater;
}

- (void)cancelDelayedTermination:(NSTimer*)theTimer
{
    NSLog(@"canceling termination");
    [[NSApplication sharedApplication] replyToApplicationShouldTerminate:NO];
}
     
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
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

    if ([_remoteTasks count] < 1) 
    {
        if (_terminationTimer) {
            // proceed with delayed termination
            [_terminationTimer invalidate];
            [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
        }

        NSEvent *shouldStop = [NSEvent otherEventWithType:NSApplicationDefined location:NSPointFromCGPoint(CGPointZero) modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 
                                                    data1:kShouldStopEvent data2:0];
        [[NSApplication sharedApplication] postEvent:shouldStop atStart:NO];
    }

    [_tasksLock unlock];    
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
