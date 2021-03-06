/* 
 GMPXFileUtil.m
 Originally code from: Libmacgpg GPGTask.m
 
 Copyright © Roman Zechmeister, 2011
 
 Diese Datei ist Teil von Libmacgpg.
 
 Libmacgpg ist freie Software. Sie können es unter den Bedingungen 
 der GNU General Public License, wie von der Free Software Foundation 
 veröffentlicht, weitergeben und/oder modifizieren, entweder gemäß 
 Version 3 der Lizenz oder (nach Ihrer Option) jeder späteren Version.
 
 Die Veröffentlichung von Libmacgpg erfolgt in der Hoffnung, daß es Ihnen 
 von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die implizite 
 Garantie der Marktreife oder der Verwendbarkeit für einen bestimmten Zweck. 
 Details finden Sie in der GNU General Public License.
 
 Sie sollten ein Exemplar der GNU General Public License zusammen mit diesem 
 Programm erhalten haben. Falls nicht, siehe <http://www.gnu.org/licenses/>.
 */

#import "GMPXFileUtil.h"

@implementation GMPXFileUtil

+ (NSString *)findExecutableWithName:(NSString *)executable 
{
	NSArray *searchPaths = [NSMutableArray arrayWithObjects:@"/usr/local/bin", @"/usr/bin", @"/bin", 
                            @"/opt/local/bin", @"/sw/bin", nil];
	
	NSString *foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
	if (foundPath) 
		return foundPath;
	
	foundPath = [self findExecutableWithNameInDefaultPath:executable];	
	return foundPath;
}

+ (NSString *)findExecutableWithName:(NSString *)executable atPaths:(NSArray *)paths 
{
	for (NSString *searchPath in paths) {
		NSString *foundPath = [searchPath stringByAppendingPathComponent:executable];
		if ([[NSFileManager defaultManager] isExecutableFileAtPath:foundPath]) {
			return [foundPath stringByStandardizingPath];
		}
	}
	return nil;
}

+ (NSString *)findExecutableWithNameInDefaultPath:(NSString *)executable
{
	NSString *envPATH = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
	if (envPATH) {
		NSArray *searchPaths = [envPATH componentsSeparatedByString:@":"];
		NSString *foundPath = [self findExecutableWithName:executable atPaths:searchPaths];
		if (foundPath) 
			return foundPath;
	}
    return nil;
}

@end
