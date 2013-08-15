//
//  JCAppleScript.h
//  Link-OSX
//
//  Created by John Clem on 8/15/13.
//  Copyright (c) 2013 John Clem. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCAppleScript : NSObject

//===================================================================================================
//  Executes an arbitrary AppleScript command passed in as a string.
//  Multi-line AppleScript commands should include the line terminator \n\ at the end of each line
+ (void)appleScript:(NSString *)cmd;
//===================================================================================================

//===================================================================================================
//  Executes an AppleScript file with .scpt extension located in the App bundle. Ensure that you've
//  ticked the boxes to add the script to your target when adding .scpt files to your project
+ (void)runAppleScript:(NSString *)path;
//===================================================================================================

//===================================================================================================
//  Executes an AppleScript or OSAScript file with .scpt extension located in the App bundle.
//  Variables passed in will replace any placeholders located in the .scpt file in order.
//  Placeholders should be formatted as $0, $1, $2 and so on.
//  Make sure to match each %@ with a variable in the array, otherwise they will be replaced with ""
//  and may cause your script to fail.
//  Also, ensure that you've ticked the boxes to add the script to your target when adding scpt files
//  to your project.  Returns TRUE if successful, returns FALSE if the script fails to execute or if
//  the variables array contained more placeholder variables than the .scpt file
+ (BOOL)runAppleScript:(NSString *)path withVariables:(NSArray *)variables;
//===================================================================================================

@end
