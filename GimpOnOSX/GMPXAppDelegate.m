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

- (void)activateX11;

- (void)startGimpRemoteTask:(NSArray *)arguments;
- (void)handleGimpRemoteTaskFinished:(NSNotification *)notification;

- (NSString *)getPathToScript:(NSString *)scriptName;

@end

@implementation GMPXAppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [_window release];
    [_remoteTasks release];
    [_tasksLock release];
    [_activateX11 release];
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

    if ([_remoteTasks count] < 1) {
        NSEvent *shouldStop = [NSEvent otherEventWithType:NSApplicationDefined location:NSPointFromCGPoint(CGPointZero) modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 
                                                    data1:kShouldStopEvent data2:0];
        [[NSApplication sharedApplication] postEvent:shouldStop atStart:NO];
    }

    [_tasksLock unlock];    
}

- (NSString *)getPathToScript:(NSString *)scriptName
{
    return [[NSBundle mainBundle] pathForResource:scriptName ofType:@""];
}

@end
