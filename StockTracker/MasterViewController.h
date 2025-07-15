//
// MasterViewController.h
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

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "LTPopup.h"
#import "LTLog.h"

@interface MasterViewController : NSViewController
{
    NSTimer *mUpdateTimer;
    NSInteger mUpdateRate;
    BOOL mFinalUpdate;
    WKWebView *mWKView;
    NSString *mApiKey;
    
    // For logging
    os_log_t mLog;
    NSString *mLogFile;
    
    // For market news
    NSURLSessionDataTask *mMarketNewsTask;
    NSData *mMarketNewsData;
    NSTimer *mMarketNewsTimer;
    NSInteger mNewsID;
    NSString *mMarketNews;
    
    // For popup window
    LTPopup *mPopupWindow;
    NSMutableString *mText;
    
    IBOutlet NSTextField *mSymbolEntry;
    IBOutlet NSTextField *mNumberOfSharesEntry;
    IBOutlet NSTextField *mPricePaidEntry;
    IBOutlet NSButton *mUpdateButton;
    IBOutlet NSView *mWKWebView;
}

- (IBAction)updateStocks:(id)sender;

- (void)setUpdateRate:(NSInteger)updateRate;
- (void)setWebsiteURL:(NSString *)websiteURL;
- (void)setApiKey:(NSString *)apiKey;
- (void)setLogFile:(NSString *)logFile;

@property (strong) IBOutlet NSTextFieldCell *mLastUpdate;
@property (strong) IBOutlet NSTextView *mNews;
@property (strong) IBOutlet NSTableView *stocksTableView;
@property (strong) IBOutlet NSButton *deleteButton;
@property (strong) IBOutlet NSButton *upButton;
@property (strong) IBOutlet NSButton *downButton;
@property (strong) NSMutableArray *stocks;

@end
