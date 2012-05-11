//
//  GMPXFileUtil.h
//  GimpOnOSX
//
//  Created by Chris Fraire on 5/11/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GMPXFileUtil : NSObject

+ (NSString *)findExecutableWithName:(NSString *)executable;
+ (NSString *)findExecutableWithName:(NSString *)executable atPaths:(NSArray *)paths;

@end
