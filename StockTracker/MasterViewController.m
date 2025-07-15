//
// MasterViewController.m
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

#import "MasterViewController.h"
#import "StockTrackerData.h"

@implementation MasterViewController

@synthesize mLastUpdate;
@synthesize mNews;
@synthesize deleteButton;
@synthesize upButton;
@synthesize downButton;

- (id)initWithNibName:(NSString *)nibNameOrNil 
    bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  
    mUpdateTimer = nil;
    mFinalUpdate = NO;

    // Watch for new data notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(newDataNotification:)
        name:@"StockTrackerNewData" object:nil];

    return self;
}

- (void)loadView
{
    [super loadView];
    
    mMarketNews = @"";
    mNewsID = 0;
    mLog = os_log_create("com.larrymtaylor.StockTracker", "AppDelegate");
    
    // Get starting data
    [self updatePrices];
    
    // Set status and last update time
    [self marketsOpen];
    [self setLastUpdate];

    // Setup for web page
    WKWebViewConfiguration *configuration =
        [[WKWebViewConfiguration alloc] init];
    mWKView = [[WKWebView alloc] initWithFrame:[mWKWebView frame]
               configuration:configuration];
    mWKView.navigationDelegate = (id<WKNavigationDelegate> _Nullable)self;
    [mWKWebView addSubview:mWKView];
}

- (void)viewDidLoad
{
}

- (NSView *)tableView:(NSTableView *)tableView 
    viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // Get a new ViewCell
    NSTableCellView *cellView = 
        [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    if ([tableColumn.identifier isEqualToString:@"StockColumn"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        NSMutableString *text = [[NSMutableString alloc] initWithFormat:
            @"<a href='https://finance.yahoo.com/quote/%@'>%@</a>",
            stockData.symbol, stockData.symbol];
        NSAttributedString *attributedString = [[NSAttributedString alloc]
            initWithData:[text dataUsingEncoding:NSUnicodeStringEncoding]
            options:@{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType}
            documentAttributes:nil error:nil];
        cellView.textField.attributedStringValue = attributedString;
        return cellView;
    }
    else if ([tableColumn.identifier isEqualToString:@"CompanyColumn"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        cellView.textField.stringValue = stockData.companyName;
        return cellView;
    }
    else if ([tableColumn.identifier isEqualToString:@"PriceColumn"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        
        cellView.textField.stringValue =
            [NSString localizedStringWithFormat:@"$%.2f",
             stockData.currentPrice];;
        return cellView;
    }
    else if ([tableColumn.identifier isEqualToString:@"ChangeColumn"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        
        NSString *changeString;
        
        if (stockData.change < 0)
        {
            double absChange = ABS(stockData.change);
            changeString = [NSString localizedStringWithFormat:@"-$%.2f",
                            absChange];
            cellView.textField.textColor = [NSColor redColor];
        }
        else
        {
            changeString = [NSString localizedStringWithFormat:@"+$%.2f",
                            stockData.change];
            cellView.textField.textColor = [NSColor colorWithRed:0.0
                                            green:0.64 blue:0.0 alpha:1.0];
        }
           
        cellView.textField.stringValue = changeString;
        return cellView;
    }
    else if ([tableColumn.identifier isEqualToString:@"SharesColumn"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        
        NSString *shares = @"          ";
           
        if (stockData.numberOfShares > 0)
        {
            double temp;
            
            if (modf(stockData.numberOfShares, &temp) == 0)
            {
                shares = [NSString stringWithFormat:@"%.0d",
                          (int)stockData.numberOfShares];
            }
            else
            {
                shares = [NSString stringWithFormat:@"%.1f",
                          stockData.numberOfShares];
            }
        }
        
        cellView.textField.stringValue = shares;
        return cellView;
    }
    else if ([tableColumn.identifier isEqualToString:@"PaidColumn"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        
        NSString *pricePaidString = @"          ";
          
        if (stockData.numberOfShares > 0)
        {
            pricePaidString = [NSString localizedStringWithFormat:@"$%.2f",
                               stockData.pricePaid];
        }
        
        cellView.textField.stringValue = pricePaidString;
        return cellView;
    }
    else if ([tableColumn.identifier isEqualToString:@"DivColumn"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        
        NSString *dividendsString = @"          ";
          
        if (stockData.numberOfShares > 0)
        {
            dividendsString = [NSString localizedStringWithFormat:@"$%.2f",
                               stockData.dividends];
        }
        
        cellView.textField.stringValue = dividendsString;
        return cellView;
    }
    else if ([tableColumn.identifier isEqualToString:@"GainColumn"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        
        NSString *gainString = @"          ";
        
        if (stockData.numberOfShares > 0)
        {
            if (stockData.gain < 0)
            {
                double absGain = ABS(stockData.gain);
                gainString = [NSString localizedStringWithFormat:@"-$%.2f",
                              absGain];
                cellView.textField.textColor = [NSColor redColor];
            }
            else
            {
                gainString = [NSString localizedStringWithFormat:@"+$%.2f",
                              stockData.gain];
                cellView.textField.textColor = [NSColor colorWithRed:0.0
                                                green:0.64 blue:0.0 alpha:1.0];
            }
        }
        
        cellView.textField.stringValue = gainString;
        return cellView;
    }
    else if ([tableColumn.identifier isEqualToString:@"Gain%"] == YES)
    {
        StockTrackerData *stockData = [self.stocks objectAtIndex:row];
        
        NSString *gainPercentString = @"          ";
        
        if (stockData.numberOfShares > 0)
        {
            if (stockData.gainPercent < 0)
            {
                double absGainPercent = ABS(stockData.gainPercent);
                gainPercentString =
                    [NSString localizedStringWithFormat:@"-%.2f%% ",
                     absGainPercent];
                cellView.textField.textColor = [NSColor redColor];
            }
            else
            {
                gainPercentString =
                    [NSString localizedStringWithFormat:@"+%.2f%% ",
                     stockData.gainPercent];
                cellView.textField.textColor = [NSColor colorWithRed:0.0
                                                green:0.64 blue:0.0 alpha:1.0];
            }
        }
        
        cellView.textField.stringValue = gainPercentString;
        return cellView;
    }
    
    return cellView;
}

- (StockTrackerData *)selectedStockData
{
    NSInteger selectedRow = [self.stocksTableView selectedRow];

    if (selectedRow >= 0 && self.stocks.count > selectedRow)
    {
        StockTrackerData *selectedStock =
            [self.stocks objectAtIndex:selectedRow];
        return selectedStock;
    }
    
    return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    StockTrackerData *selectedData = [self selectedStockData];
    
    // Enable/disable buttons based on selection
    BOOL buttonsEnabled = (selectedData != nil);
    [self.deleteButton setEnabled:buttonsEnabled];
    
    NSUInteger rowIndex = self.stocksTableView.selectedRow;

    if (rowIndex > 0)
    {
        [self.upButton setEnabled:true];
    }
    else
    {
        [self.upButton setEnabled:false];
    }
     
    if (rowIndex < ([self.stocks count] - 1))
    {
        [self.downButton setEnabled:true];
    }
    else
    {
        [self.downButton setEnabled:false];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.stocks count];
}

- (IBAction)addStock:(id)sender
{
    if ([[mSymbolEntry stringValue] isEqualToString:@""] == NO)
    {
        // Create a new StockTrackerData object
        StockTrackerData *newData =
            [[StockTrackerData alloc]
             initWithSymbol:[mSymbolEntry stringValue]
             withPricePaid:[mPricePaidEntry doubleValue]
             withNumberOfShares:[mNumberOfSharesEntry doubleValue]];
        
        // Add the new stock object to our model (insert into the array)
        [self.stocks addObject:newData];
        NSInteger newRowIndex = self.stocks.count - 1;
        
        // Insert new row in the table view
        [self.stocksTableView insertRowsAtIndexes:
         [NSIndexSet indexSetWithIndex:newRowIndex]
          withAnimation:NSTableViewAnimationEffectGap];
        
        // Select the new stock and scroll to make sure it's visible
        [self.stocksTableView selectRowIndexes:
         [NSIndexSet indexSetWithIndex:newRowIndex] byExtendingSelection:NO];
        [self.stocksTableView scrollRowToVisible:newRowIndex];
        
        // Clear input fields
        [mSymbolEntry setStringValue:@""];
        [mPricePaidEntry setStringValue:@""];
        [mNumberOfSharesEntry setStringValue:@""];
        
        // Update
        [self updatePrices];

        // Trigger a save
        [[NSNotificationCenter defaultCenter]
          postNotificationName:@"StockListChange" object:nil];
    }
}

- (IBAction)deleteStock:(id)sender
{
    // Get selected doc
    StockTrackerData *selectedData = [self selectedStockData];

    if (selectedData)
    {
        // Remove the stock from the model
        [self.stocks removeObject:selectedData];
        
        // Remove the selected row from the table view.
        [self.stocksTableView removeRowsAtIndexes:
            [NSIndexSet indexSetWithIndex:self.stocksTableView.selectedRow]
             withAnimation:NSTableViewAnimationSlideRight];

        // Trigger a save
        [[NSNotificationCenter defaultCenter]
          postNotificationName:@"StockListChange" object:nil];
    }
}

- (IBAction)addDividend:(id)sender
{
    for (int i = 0; i < [self.stocks count]; i++)
    {
        StockTrackerData *selectedData = self.stocks[i];
        
        if ([selectedData.symbol
             isEqualToString:[mSymbolEntry stringValue]] == YES)
        {
            double dividend = [mPricePaidEntry doubleValue];
            selectedData.dividends += dividend;
            [self updatePrices];

            // Trigger a save
            [[NSNotificationCenter defaultCenter]
              postNotificationName:@"StockListChange" object:nil];

            break;
        }
    }

    // Clear input fields
    [mSymbolEntry setStringValue:@""];
    [mPricePaidEntry setStringValue:@""];
    [mNumberOfSharesEntry setStringValue:@""];
}

- (void)updatePrices
{
    // Initiate updates
    [self getMarketNews];
    
    for (int i = 0; i < [self.stocks count]; i++)
    {
        StockTrackerData *stock = self.stocks[i];
        [stock updateData];
    }
    
    // Update company news
    NSMutableString *text = [[NSMutableString alloc] initWithString:@""];
    
    for (int i = 0; i < [self.stocks count]; i++)
    {
        StockTrackerData *stockData = self.stocks[i];
        [text appendString:stockData.news];
    }
    
    // Update market news
    [text appendString:mMarketNews];
    
    NSAttributedString *attributedString = [[NSAttributedString alloc]
        initWithData:[text dataUsingEncoding:NSUnicodeStringEncoding]
        options:@{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType}
        documentAttributes:nil error:nil];
    
    [mNews.textStorage setAttributedString:attributedString];
    [mWKView reload];
}

- (void)newDataNotification:(NSNotification *)notification
{
    if ([[notification name] isEqualToString:@"StockTrackerNewData"])
    {
        [self.stocksTableView reloadData];
        [self setLastUpdate];
    }
}

- (void)setLastUpdate
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"h:mm a"];
    NSString *day = [dateFormatter stringFromDate:[NSDate date]];
    [mLastUpdate setStringValue:day];
}

- (void)updatePriceTimer:(NSTimer *)timer
{
    if ([self marketsOpen] == true)
    {
        [self updatePrices];
        mFinalUpdate = YES;
    }
    else if (mFinalUpdate == YES)
    {
        [self updatePrices];
        mFinalUpdate = NO;
    }
}

- (bool)marketsOpen
{
    bool open = false;
    
    // Get day of the week
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"EEEE"];
    NSString *day = [dateFormatter stringFromDate:[NSDate date]];
 
    // Get current time
    NSDate *date = [NSDate date];
    
    // Set opening time
    NSCalendar *gregorian = [[NSCalendar alloc]
        initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components =
        [gregorian components:NSUIntegerMax fromDate:date];
    [components setHour: 9];
    [components setMinute: 30];
    [components setSecond: 00];
    NSDate *date1 = [gregorian dateFromComponents: components];

    // Set closing time
    [components setHour: 16];
    [components setMinute: 00];
    [components setSecond: 00];
    NSDate *date2 = [gregorian dateFromComponents: components];
    
    // Check market status
    if (([date timeIntervalSinceDate:date1] > 0 &&
         [date timeIntervalSinceDate:date2] < 0) &&
        ([day isEqualToString:@"Saturday"] == NO) &&
        ([day isEqualToString:@"Sunday"] == NO))
    {
        open = true;
    }
    else
    {
        open = false;
    }
    
    return open;
}

- (IBAction)moveUp:(id)sender
{
    NSUInteger rowIndex = self.stocksTableView.selectedRow;
    
    if (rowIndex > 0)
    {
        [self.stocksTableView moveRowAtIndex:rowIndex toIndex:(rowIndex - 1)];
        [self.stocks exchangeObjectAtIndex:rowIndex
         withObjectAtIndex:(rowIndex - 1)];
        
        // Trigger a save
        [[NSNotificationCenter defaultCenter]
          postNotificationName:@"StockListChange" object:nil];
    }
}

- (IBAction)moveDown:(id)sender
{
    NSUInteger rowIndex = self.stocksTableView.selectedRow;
    
    if (rowIndex < ([self.stocks count] - 1))
    {
        [self.stocksTableView moveRowAtIndex:rowIndex toIndex:(rowIndex + 1)];
        [self.stocks exchangeObjectAtIndex:rowIndex
         withObjectAtIndex:(rowIndex + 1)];

        // Trigger a save
        [[NSNotificationCenter defaultCenter]
          postNotificationName:@"StockListChange" object:nil];
    }
}

- (IBAction)updateStocks:(id)sender
{
    [self updatePrices];
}

- (void)setUpdateRate:(NSInteger)updateRate;
{
    mUpdateRate = updateRate;
     
    if (mUpdateTimer)
    {
        [mUpdateTimer invalidate];
        mUpdateTimer = nil;
    }
        
    // Start update timer
    mUpdateTimer =
        [NSTimer scheduledTimerWithTimeInterval:(mUpdateRate * 60)
         target:self selector:@selector(updatePriceTimer:)
         userInfo:nil repeats:YES];
}

- (void)setWebsiteURL:(NSString *)websiteURL
{
    NSURL *url = [NSURL URLWithString:websiteURL];
    NSURLRequest *request =[NSURLRequest requestWithURL:url];
    [mWKView loadRequest:request];
}

- (void)setApiKey:(NSString *)apiKey
{
    mApiKey = [apiKey copy];
}

- (void)setLogFile:(NSString *)logFile
{
    mLogFile = [logFile copy];
}

- (void)marketNewsTimer:(NSTimer *)timer
{
    if (([mMarketNewsTask state] != NSURLSessionTaskStateCompleted))
    {
        return;
    }

    [mMarketNewsTimer invalidate];
    mMarketNewsTimer = nil;
   
    // Process the market news
    @try
    {
        NSString *dataString = [[NSString alloc] initWithData:mMarketNewsData
                                encoding:NSUTF8StringEncoding];
        NSData *newData = [dataString dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableData *jsonData = [[NSMutableData alloc] init];
        const unsigned char *bytes = [newData bytes];

        for (int i = 0; i < [newData length]; i++)
        {
            if ((bytes[i] == ';') && (bytes[i + 1] == '\n'))
            {
                break;
            }
            else
            {
                [jsonData appendBytes:&bytes[i] length:1];
            }
        }
 
        NSError *e = nil;
        NSDictionary *jsonDict = [NSJSONSerialization
                                  JSONObjectWithData:jsonData
                                  options:NSJSONReadingMutableContainers
                                  error:&e];
       
        if (e != nil)
        {
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"Market news NSJSONSerialization JSONObjectWithData "
                   "error: %@", e);
            return;
        }
    
        if ([jsonDict count] > 0)
        {
            NSMutableString *text = [[NSMutableString alloc]
                                     initWithString:@""];
        
            for (NSDictionary *dict in jsonDict)
            {
                NSString *value = [dict valueForKeyPath:@"error"];
               
                if (value != nil)
                {
                    [mText setString:@""];
                    [mText appendFormat:
                     @"Finnhub returned error for market news: %@", value];
                    [mPopupWindow show];
                    [mPopupWindow setText:(NSString *)mText];

                    LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                          @"Finnhub returned error for market news: %@",
                          value);
                    return;
                }
            
                value = [dict valueForKeyPath:@"headline"];
                NSString *link = [dict valueForKeyPath:@"url"];
            
                if ((value != nil) && (link != nil))
                {
                    [text appendFormat:
                     @"<p style='font-size:14px;'><b>Market News - "];
                    [text appendFormat:@"<a href='%@'>%@</a></b><br />",
                     link, value];
                }

                value = [dict valueForKeyPath:@"summary"];
            
                if (value != nil)
                {
                    [text appendFormat:@"%@<br /></p>", value];
                }
                
                value = [dict valueForKeyPath:@"id"];
            
                if (value != nil)
                {
                    mNewsID = [value integerValue];
                }
            }
        
            mMarketNews = [text copy];
        }
        else
        {
            mMarketNews = @"";
        }
    }
    @catch(NSException *e)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Market news error: %@ ", e.name);
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR, @"Reason: %@ ", e.reason);
        mMarketNews = @"";
    }
    @finally
    {
    }

    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"StockTrackerNewData" object:nil];
}

- (void)getMarketNews
{
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSString *urlString = [NSString stringWithFormat:
        @"https://finnhub.io/api/v1//news?category=general&minID=%i&token=%@",
        mNewsID, mApiKey];
    mMarketNewsTask = [session dataTaskWithURL:[NSURL URLWithString:urlString]
                       completionHandler:^(NSData *data,
                       NSURLResponse *response, NSError *error)
    {
        if (error != nil)
        {
            LTLog(self->mLog, self->mLogFile, OS_LOG_TYPE_ERROR,
                  @"Market news network session error: %@", error);
        }
        else if ((data) && ([data length] > 0))
        {
            self->mMarketNewsData = [data copy];
        }
    }];
    
    [mMarketNewsTask resume];
    
    mMarketNewsTimer = [NSTimer scheduledTimerWithTimeInterval:1
                        target:self selector:@selector(marketNewsTimer:)
                        userInfo:nil repeats:YES];
}

@end
