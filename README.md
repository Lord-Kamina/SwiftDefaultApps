ANNOUNCEMENT: I have recently noticed Apple has introduced replacements for the deprecated APIs used in this app. As a result, slow as it may be, I plan to resume development. I will be taking PRs as well, if somebody wishes to contribute.
========

SwiftDefaultApps
========

SwiftDefaultApps is a macOS app for viewing and changing the default applications for URL schemes and file types. It is chiefly intended to be a modern replacement for the amazing RCDefaultApp developed way back when by Carl Lindberg, which stopped working in 10.12 due to deprecation of ObjC Garbage collection.
Additionally, I guess it was a good way to teach myself Swift.

Feel free to contribute, comment or report issues at https://github.com/Lord-Kamina/SwiftDefaultApps.

## Installing & Uninstalling

* Download the latest app release from https://github.com/Lord-Kamina/SwiftDefaultApps/releases.
* Drag `SwiftDefaultApps.app` to Applications, then open it from Finder or Spotlight.
* To uninstall, quit SwiftDefaultApps and move the app to the Trash.

The app requires macOS 13 or later and supports both Apple Silicon and Intel Macs.

## Installing with brew

The Homebrew formula needs updating for the standalone app. Until then, install the app manually or build it from source.

## Building from source

With Xcode 15.2 or later installed:

```bash
git clone https://github.com/Lord-Kamina/SwiftDefaultApps.git
cd SwiftDefaultApps
./build.sh
```

`build.sh` builds a universal app (arm64 + x86_64), signs the embedded `ThisAppDoesNothing.app` and then the main app with hardened runtime, and verifies the signature. It uses the first `Developer ID Application` identity in your keychain, falling back to an ad-hoc signature for local use. Before installing into `~/Applications`, it quits a running SwiftDefaultApps instance and moves any previously installed copy to `backups/`.

```
./build.sh                 build, sign, install
./build.sh --no-install    build and sign only
./build.sh --cli           also build the swda command line tool

SIGN_ID="-"                force an ad-hoc signature
ARCH="arm64"               narrow the build (default: universal)
DEPLOY_TARGET="13.0"       minimum macOS version
```

The app is built at `build/Release/SwiftDefaultApps.app`; with `--cli`, the command line tool is built at `build/Release/swda`. You can also open `SwiftDefaultApps.xcworkspace` or `SwiftDefaultApps.xcodeproj` in Xcode and run the **Build App** scheme.

The CLI dependency at `Packages/SwiftCLI-2.0.3` must use tag `2.0.3+swift5`. Tag `2.0.3` is Swift 3 code and fails to compile (`String.characters` was removed). `build.sh` fetches the correct tag if the dependency is missing.

### App UI

Use the segmented picker in the window toolbar to switch between Internet, URL Schemes, File Types and Applications. The resizable window has a searchable list on the left and the selected item's handlers on the right. Closing the window quits the app; **About SwiftDefaultApps** is in the app menu.

Search matches names, identifiers, bundle IDs and file extensions (type `.md` on the File Types tab to find Markdown), and ↑/↓ move through the results without leaving the search field. File Types can be grouped by kind or by the application that currently opens them; click a group header to collapse it, Option-click to collapse or expand every group. The sidebar is an `NSOutlineView`, so lists with thousands of types stay responsive.

The Applications tab lists every scheme and type an application declares. Launch Services cannot clear a default, only replace it, so rows the application already owns offer a menu to hand them to another application, and the other rows offer "Make Default".

Some changes, such as the default web browser, only take effect once you confirm a system prompt. The app waits for Launch Services to report the new handler (or for the prompt to be declined) and shows the handler actually in place.

The app uses the deprecated Launch Services calls `LSSetDefaultHandlerForURLScheme` and `LSSetDefaultRoleHandlerForContentType`, and the private `_LSCopySchemesAndHandlerURLs` SPI, to read and write handler associations.

## How to use the "Do Nothing" app

SwiftDefaultApps automatically locates and launches the embedded **Do Nothing** app when it needs to register it with Launch Services. To launch it manually after installing with `build.sh`, run:

```bash
open "$HOME/Applications/SwiftDefaultApps.app/Contents/Resources/ThisAppDoesNothing.app"
```

If you installed into `/Applications`, use `/Applications/SwiftDefaultApps.app/Contents/Resources/ThisAppDoesNothing.app` instead.

## Usage Notes

SwiftDefaultApps lets you view and change default application associations for basically any URI Scheme and/or filetype in macOS.
The user-interface should be pretty self-explanatory; but, there are some things that might require an explanation:
	
- Selecting any URI Scheme or File type (always represented by a UTI), will give you a list of all valid applications for each LaunchServices role. This data is generated by LaunchServices itself.
  - There's two additional options: 
    - One of them is **"Do Nothing"**, what this does is register the item to be handled by a dummy application which basically does nothing. Its only function is being able to open any URI Scheme or UTI whatsoever, printing a line to the console (specifying whatever it was that launched it) and immediately quitting. By default this application should be located in the `Resources` folder inside the app bundle; SwiftDefaultApps will, however, also look for it in the directory it is itself located in (for the CLI version) and every `Applications`folder in the computer.
    - The second is **"Other..."**, which obviously will allow you to select an application not in the list; with a caveat. In recent versions of macOS, the LaunchServices have become quite a bit smarter under the hood than they used to be. In practice, what this means is that although you can choose *any* application to handle anything, only valid associations will be preserved, as the LaunchServices is permanently looking for invalid or stale associations and removing them.
  - One final note: In the URI Schemes tab, you have the option of adding a custom URI Scheme (Removing them on demand is neither possible nor necessary, due to the same thing explained above). This options is provided for completeness' sake; you should virtually never need to use it, since Launch Services should be able to properly detect any valid URL Handlers. As a further cautionary note: If you add a custom URI Scheme when it is not needed, you may not be able to remove it except by uninstalling and reinstalling SwiftDefaultApps. Why? Because new schemes are by default associated to *"Do Nothing", which means Launch Services will always find a valid handler as long as SwiftDefaultApps is installed.

### How to Find Out File UTI

Run in your terminal the following command (replace my_song.mp3 by your file):

`mdls -name kMDItemContentType -name kMDItemContentTypeTree -name kMDItemKind my_song.mp3`

## Acknowledgments & Attributions

- Using jakeheis' SwiftCLI 2.0 as a base for the CLI version located inside the bundle. (https://github.com/jakeheis/SwiftCLI)
- Using AMTourky's DRYView canned views system (https://github.com/AMTourky/CocoaBindingDryView-ReusableViews/)
- Using ZamzamKit's SynchronizedArray (https://github.com/ZamzamInc/ZamzamKit)
- Icon made using the following resources:
	- Brush, Ruler and Pencil designed by Freepik. (http://www.freepik.com/free-vector/background-of-back-to-school_769298.htm)
	- Magnifying glass frame designed by Balintseby / Freepik (http://www.freepik.com/free-vector/realistic-magnifying-glass_789215.htm)
	- Magnifying glass crystal designed by Freepik (http://www.freepik.com/free-vector/crystal-frames-collection_724172.htm)
	- Gears designed by Freepik (http://www.freepik.com/free-vector/gray-background-of-gear_956712.htm)

## Current Version

- Version: 2.0.1
- Date: 2019-07-26

## Known Issues

See https://github.com/Lord-Kamina/SwiftDefaultApps/issues

## TO DO

- Localizations

# Release Notes

## [2.0.1] - 2019-07-26
  + ### Fixed
  	+ CLI: Crash when displaying the results for setHandler with shortcuts such as internet, browser, email, etc.

## [2.0.0] - 2019-06-12
  + ### Added
    + Signed prefpane, CLI and Dummy apps.
    + Both the prefpane and the CLI version will now automatically try to locate ThisAppDoesNothing.app if it does not appear registered with launch services.
  + ### Changed
    + SwiftCLI is now built and linked as a static library instead of a framework.
    + Updated to Swift 5
    + The content array is now populated by overriding `didSelect()` instead of relying on an arbitrary sleep timer.
    + Changed the CLI app's name from lsreg to swda.
    + Messages in both the CLI and Preference Pane are now a bit more verbose.
    + Under the hood, folded most of the app's feedback to the user into a single `displayAlert()` function.
  + ### Fixed
  	+ Updated the Swift Package Manager manifest to version 5.
  	+ Updated the SynchronizedArray code and corrected the attribution; Before, I had inadvertently credited an unrelated project with the same name.
  	+ Various small optimizations, fixes and text corrections.

## [1.1.3] - 2018-11-15
  + ### Fixed
  	+ Bug causing crash on related to force-unwrapping bundleIdentifier.

## [1.1.2] - 2018-10-07
  + ### Changed
  	+ Migrated to Swift 4.2
  	+ Force Static linking of standard library, which should fix issues running on Mojave.

## [1.1.1] - 2018-04-15
  + ### Changed
  	+ Small changes for Swift 4.1.

## [1.1.0] - 2017-09-27
  + ### Changed
  	+ Migrated code to Swift 4.
  + ### Fixed
  	+ Fixed an unwrapped Optional when changing associations in the "Applications" tab.
  	+ Fixed CLI tool.
  	+ Some other cleanups.

## [1.0.0] - 2017-05-01
  + ### Added
    + Initial release!
  + ### Changed
  + ### Fixed
