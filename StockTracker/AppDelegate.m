//
// AppDelegate.m
// 
// Copyright (c) 2020-2025 Larry M. Taylor
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software. Permission is granted to anyone to
// use this software for any purpose, including commercial applications, and to
// to alter it and redistribute it freely, subject to 
// the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source
//    distribution.
//

#import <sys/types.h>
#import <pwd.h>
#import <uuid/uuid.h>
#import <sys/utsname.h>

#import "AppDelegate.h"
#import "MasterViewController.h"
#import "StockTrackerData.h"
#import "NSFileManager+DirectoryLocations.h"

@interface AppDelegate()

@property (nonatomic,strong) IBOutlet MasterViewController 
    *masterViewController;
@end

#define UDKEY_SETTINGS_LIST   @"StockTrackerSettings"
#define UDKEY_OPTIONS_LIST    @"StockTrackerOptions"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Create the master View Controller
    self.masterViewController = [[MasterViewController alloc] 
        initWithNibName:@"MasterViewController" bundle:nil];
    
    // Create preferences controller
    mPreferencesController = [[PreferencesController alloc] init];
    
    // Watch for preferences panel close
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(preferencesPanelClose:)
        name:NSWindowWillCloseNotification
        object:[mPreferencesController window]];

    // Watch for change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(receiveChangeNotification:)
        name:@"StockListChange" object:nil];
    
    // Load saved data
    [self loadSettings];
    
    // Update color
    [self.window setBackgroundColor:[NSColor colorWithRed:0.2
                                     green:0.2 blue:0.2 alpha:1.0]];

    // Add the view controller to the window's content view
    [self.window.contentView addSubview:self.masterViewController.view];
    self.masterViewController.view.frame =
        ((NSView*)self.window.contentView).bounds;
    [self.masterViewController setUpdateRate:mUpdateRate];
    
    // Set website
    [self.masterViewController setWebsiteURL:mWebsiteURL];

    // Set up logging
    mLog = os_log_create("com.larrymtaylor.StockTracker", "AppDelegate");
    NSString *path =
        [[NSFileManager defaultManager] applicationSupportDirectory];
    mLogFile = [[NSString alloc] initWithFormat:@"%@/logFile.txt", path];
    
    // Get macOS version
    NSOperatingSystemVersion sysVersion =
        [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString *systemVersion = [NSString stringWithFormat:@"%ld.%ld",
                               sysVersion.majorVersion,
                               sysVersion.minorVersion];
    
    // Log some basic information
    NSBundle *appBundle = [NSBundle mainBundle];
    NSDictionary *appInfo = [appBundle infoDictionary];
    NSString *appVersion =
        [appInfo objectForKey:@"CFBundleShortVersionString"];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM/dd/yyyy h:mm a"];
    NSString *day = [dateFormatter stringFromDate:[NSDate date]];
    struct utsname osinfo;
    uname(&osinfo);
    NSString *info = [NSString stringWithUTF8String:osinfo.version];
    LTLog(mLog, mLogFile, OS_LOG_TYPE_INFO,
          @"\nStockTracker v%@ running on macOS "
          "%@ (%@)\n%@", appVersion, systemVersion, day, info);
    
    // Send log file name to data classes
    [StockTrackerData setLogFile:mLogFile];
    [self.masterViewController setLogFile:mLogFile];
    
    // Version check
    mVersionCheck = [[LTVersionCheck alloc] initWithAppName:@"StockTracker"
                     withAppVersion:appVersion
                     withLogHandle:mLog withLogFile:mLogFile];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self saveSettings];
}

- (void)loadSettings
{
    NSMutableArray *stocks = [[NSMutableArray alloc] init];
    
    NSUserDefaults *userDefaults =
        [[NSUserDefaultsController sharedUserDefaultsController] values];

    if ([userDefaults valueForKey:UDKEY_SETTINGS_LIST] != nil)
    {
        NSArray *allStocks = [userDefaults valueForKey:UDKEY_SETTINGS_LIST];
        
        for (int i = 0; i < [allStocks count]; i++)
        {
            NSDictionary *settings = allStocks[i];
            NSString *symbol = [settings objectForKey:@"Symbol"];
            NSNumber *pricePaid = [settings objectForKey:@"PricePaid"];
            NSNumber *numberOfShares =
                [settings objectForKey:@"NumberOfShares"];
             
            StockTrackerData *stock =
                 [[StockTrackerData alloc] initWithSymbol:symbol
                  withPricePaid:[pricePaid doubleValue]
                  withNumberOfShares:[numberOfShares doubleValue]];
            [stocks addObject:stock];
            
            NSNumber *dividends = [settings objectForKey:@"Dividends"];
            dividends = (dividends == nil) ? [NSNumber numberWithInteger:0] :
                         dividends;
            double dividend = [dividends doubleValue];
            stock.dividends += dividend;
        }
    }
    
    if ([userDefaults valueForKey:UDKEY_OPTIONS_LIST] != nil)
    {
        NSDictionary *options = [userDefaults valueForKey:UDKEY_OPTIONS_LIST];
        NSString *rateText = [options objectForKey:@"UpdateRate"];

        if ((rateText == nil) || ([rateText isEqualToString:@""] == YES))
        {
            mUpdateRate = 10;
        }
        else
        {
            mUpdateRate = [rateText integerValue];
        }
        
        NSString *apiKey = [options objectForKey:@"APIKey"];
        mApiKey = (apiKey == nil) ? @"No API Key - see preferences help" :
                  apiKey;
        NSString *websiteURL = [options objectForKey:@"WebsiteURL"];
        mWebsiteURL = (websiteURL == nil) ? @"https://finance.yahoo.com" :
                      websiteURL;
    }
    else
    {
        mUpdateRate = 10;
        mApiKey = @"No API key - see preferences help";
        mWebsiteURL = @"https://finance.yahoo.com";
    }
     
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSString stringWithFormat:@"%.0ld", (long)mUpdateRate],
        @"UpdateRate", mApiKey, @"APIKey", mWebsiteURL, @"WebsiteURL", nil];
    
    [mPreferencesController setSettings:settings];
    self.masterViewController.stocks = stocks;
    
    // Set API key
    [StockTrackerData setApiKey:mApiKey];
    [self.masterViewController setApiKey:mApiKey];
}

- (void)saveSettings
{
    NSUserDefaults *userDefaults =
        [[NSUserDefaultsController sharedUserDefaultsController] values];
    NSMutableArray *allStocks = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < [self.masterViewController.stocks count]; i++)
    {
        StockTrackerData *stock = self.masterViewController.stocks[i];
        NSString *symbol = [stock symbol];
        NSNumber *pricePaid = [NSNumber numberWithDouble:[stock pricePaid]];
        NSNumber *numberOfShares =
            [NSNumber numberWithDouble:[stock numberOfShares]];
        NSNumber *dividends = [NSNumber numberWithDouble:[stock dividends]];
        
        NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
            symbol, @"Symbol", pricePaid, @"PricePaid",
            numberOfShares, @"NumberOfShares", dividends, @"Dividends", nil];

        [allStocks addObject:settings];
    }
    
    [userDefaults setValue:allStocks forKey:UDKEY_SETTINGS_LIST];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
         [NSString stringWithFormat:@"%.0ld", (long)mUpdateRate],
         @"UpdateRate", mApiKey, @"APIKey", mWebsiteURL, @"WebsiteURL", nil];
     
    [userDefaults setValue:options forKey:UDKEY_OPTIONS_LIST];
}

- (void)receiveChangeNotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:@"StockListChange"] == YES)
    {
        [self saveSettings];
    }
}

- (IBAction)showPreferences:(id)sender
{
    [mPreferencesController showWindow:self];
}

- (void)preferencesPanelClose:(NSNotification *)aNotification
{
    NSDictionary *settings = [mPreferencesController settings];
    mUpdateRate = [[settings objectForKey:@"UpdateRate"] integerValue];
    [self.masterViewController setUpdateRate:mUpdateRate];
    mApiKey = [settings objectForKey:@"APIKey"];
    [StockTrackerData setApiKey:mApiKey];
    mWebsiteURL = [settings objectForKey:@"WebsiteURL"];
    [self.masterViewController setWebsiteURL:mWebsiteURL];
}
    
@end
