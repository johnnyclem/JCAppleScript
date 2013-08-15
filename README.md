JCAppleScript
=============

Simple, helpful library for using your Objective-C variables within a bundled AppleScript or OSAScript.


## Introduction

Apple provides NSAppleScript and OSAKit for executing AppleScript in Cocoa, but there is no clear way to execute a script with variables from your Objective-C code, unless you do a long-ass ```[NSString stringWithFormat:]``` like this

```
    NSString *scriptString = [NSString stringWithFormat:@"\
                              tell application \"Wirecast\"\n\
                              set myDoc to last document \n\
                              set desired_shot to the shot named \"%@\" of myDoc\n\
                              set normal_layer to the layer named \"normal\" of myDoc\n\
                              set the active shot of normal_layer to the desired_shot\n\
                              end tell", shotName];                              
```

JCAppleScript attempts to provide a simple, sane way of adding AppleScript files to you App bundle and executing them while optionally inserting your Objective-C variables into the script before executing it.

Please fork and submit pull requests if there are additional features or improvements to be made.

## Getting Started

Clone the repo

``` $ git clone https://github.com/johnnyclem/JCAppleScript.git ```

Drag the JCAppleScript.h and JCAppleScript.m files to your Xcode Project, make sure to check the box to add JCAppleScript to your App's target(s)

In your Objective-C class, import JCAppleScript

``` #import "JCAppleScript ```


## What Works

- Executing an NSString as AppleScript
- Executing a .scpt file from your App's bundle
- Executing a .scpt file from your App's bundle with an array of NSString variables passed in

## Not Yet Implemented

- Return variables and/or responses after an AppleScript finishes executing
- Support OSAScript in addition to AppleScript (i'm not sure what the difference is, but others have noted that AppleScript tends to leak memory over time, whereas OSAScript does not)
- Pass variables to your AppleScript other than NSStrings (not sure if this is possible, but it would be sick)

## Usage

######Display a dialog window in Finder:

```
[JCAppleScript appleScript:@"tell application \"Finder\"\n\
							 display dialog \"Hello World\"\n\
							 end tell"];
```

######Execute an AppleScript in your App's bundle named MyScript.scpt:

```
[JCAppleScript runAppleScript:@"MyScript"];
```

######Execute an AppleScript in your App's bundle named MyScript.scpt, with variables:

#####In MyScript.scpt
```
tell application "Finder"
	display dialog $0 $1
end tell
```
#####In Your Objective-C Class
```
NSArray *myVariables = [NSArray arrayWithObjects:@"Hello", @"World", nil];
[JCAppleScript runAppleScript:@"MyScript" withVariables:myVariables;
```
