//
//  JCAppleScript.m
//  Link-OSX
//
//  Created by John Clem on 8/15/13.
//  Copyright (c) 2013 John Clem. All rights reserved.
//

#import "JCAppleScript.h"

@implementation JCAppleScript


//===================================================================================================
//  Executes an arbitrary AppleScript command passed in as a string.
//  Multi-line AppleScript commands should include the line terminator \n\ at the end of each line
//===================================================================================================
+ (void)appleScript:(NSString *)cmd
{
    NSAppleScript *appsc = [[NSAppleScript alloc] initWithSource:cmd];
    [appsc executeAndReturnError:nil];
}
//===================================================================================================
//  Executes an AppleScript file with .scpt extension located in the App bundle. Ensure that you've
//  ticked the boxes to add the script to your target when adding .scpt files to your project
+ (void)runAppleScript:(NSString *)path
{
    NSDictionary *errorDict;
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *scriptFile = [bundle URLForResource:path withExtension:@"scpt"];
    NSAppleScript *appsc = [[NSAppleScript alloc] initWithContentsOfURL:scriptFile error:&errorDict];
    [appsc executeAndReturnError:&errorDict];
    
    if (errorDict) {
        NSLog(@"%@", errorDict);
    }
}
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
{
    NSDictionary* errorDict;
    NSAppleEventDescriptor* returnDescriptor = NULL;
    NSURL *scriptURL = [[NSBundle mainBundle] URLForResource:path withExtension:@"scpt"];
    NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&errorDict];
    NSString *scriptString = [scriptObject source];
    
    for (NSString *scriptVar in variables) {
        NSString *placeholder = [NSString stringWithFormat:@"$%lu", (unsigned long)[variables indexOfObject:scriptVar]];
        scriptString = [scriptString stringByReplacingOccurrencesOfString:placeholder
                                                               withString:scriptVar];
    }
    
    scriptObject = [[NSAppleScript alloc] initWithSource:scriptString];
    
    returnDescriptor = [scriptObject executeAndReturnError: &errorDict];
    
    if (returnDescriptor != NULL)
    {
        // successful execution
        if (kAENullEvent != [returnDescriptor descriptorType])
        {
            // script returned an AppleScript result
            if (cAEList == [returnDescriptor descriptorType])
            {
                // result is a list of other descriptors
            }
            else
            {
                // coerce the result to the appropriate ObjC type
            }
        }
    }
    else
    {
        return FALSE;
        NSLog(@"Error occurred while executing script: %@", errorDict);
    }
    
    return TRUE;
}
//===================================================================================================

@end
