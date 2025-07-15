//
// StockTrackerData.m
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

#import "StockTrackerData.h"

static NSString *mApiKey;
static NSString *mLogFile;

@implementation StockTrackerData

- (id)initWithSymbol:(NSString *)symbol withPricePaid:(double)pricePaid
    withNumberOfShares:(double)numberOfShares
{
    if ((self = [super init]))
    {
        self.symbol = symbol;
        self.companyName = @"N/A";
        self.news = @"";
        self.pricePaid = pricePaid;
        self.numberOfShares = numberOfShares;
        self.currentPrice = 0;
        self.change = 0;
        self.gain = 0;
        self.gainPercent = 0;
        self.dividends = 0;

        // Setup popup window
        mPopupWindow = [[LTPopup alloc] initWithWindowNibName:@"LTPopup"];
        mText = [[NSMutableString alloc] init];
        
        // Set up logging
        mLog = os_log_create("com.larrymtaylor.StockTracker",
                             "StockTrackerData");
    }

    return self;
}

+ (void)setApiKey:(NSString *)apiKey
{
    mApiKey = [apiKey copy];
}

+ (void)setLogFile:(NSString *)logFile
{
    mLogFile = [logFile copy];
}

- (void)updateData
{
    [self getLatestData];

    mFetchTimer = [NSTimer scheduledTimerWithTimeInterval:1
                   target:self selector:@selector(fetchTimer:)
                   userInfo:nil repeats:YES];
}

- (void)fetchTimer:(NSTimer *)timer
{
    if (([mPriceDataTask state] != NSURLSessionTaskStateCompleted) ||
        ([mCompanyDataTask state] != NSURLSessionTaskStateCompleted) ||
        ([mCompanyNewsTask state] != NSURLSessionTaskStateCompleted))
    {
        return;
    }

    [mFetchTimer invalidate];
    mFetchTimer = nil;
   
    // Process the price data
    @try
    {
        NSString *dataString = [[NSString alloc] initWithData:mPriceData
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
                  @"Price NSJSONSerialization JSONObjectWithData error: %@",
                  e);
            return;
        }
 
        NSString *value = [jsonDict valueForKeyPath:@"error"];
    
        if (value != nil)
        {
            [mText setString:@""];
            [mText appendFormat:@"Finnhub returned error for %@ price: %@",
             self.symbol, value];
            [mPopupWindow show];
            [mPopupWindow setText:(NSString *)mText];
            
            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"Finnhub returned error for %@ price: %@",
                  self.symbol, value);
            return;
        }
    
        value = [jsonDict valueForKeyPath:@"c"];
    
        if (value != nil)
        {
            self.currentPrice = [value doubleValue];
        }
    
        value = [jsonDict valueForKeyPath:@"d"];
    
        if (value != nil)
        {
            self.change = [value doubleValue];
        }

        self.gain = (self.numberOfShares * (self.currentPrice -
                    self.pricePaid)) + self.dividends;
    
        if ((self.numberOfShares > 0) && (self.pricePaid > 0))
        {
            self.gainPercent = (self.gain /
                               (self.numberOfShares * self.pricePaid)) * 100;
        }
        else
        {
            self.gainPercent = 0;
        }
    }
    @catch(NSException *e)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Price data error: %@ ", e.name);
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR, @"Reason: %@ ", e.reason);
        self.currentPrice = 0;
        self.change = 0;
        self.gain = 0;
        self.gainPercent = 0;
    }
    @finally
    {
    }
   
    // Process the company name
    @try
    {
        NSString *dataString = [[NSString alloc] initWithData:mCompanyData
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
                  @"Company NSJSONSerialization JSONObjectWithData error: %@",
                  e);
            return;
        }
    
        NSString *value = [jsonDict valueForKeyPath:@"error"];
       
        if (value != nil)
        {
            [mText setString:@""];
            [mText appendFormat:
             @"Finnhub returned error for %@ company information: %@",
             self.symbol, value];
            [mPopupWindow show];
            [mPopupWindow setText:(NSString *)mText];

            LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"Finnhub returned error for %@ company information: %@",
                  self.symbol, value);
            return;
        }
       
        value = [jsonDict valueForKeyPath:@"name"];
    
        if (value != nil)
        {
            self.companyName = [value copy];
        }
    }
    @catch(NSException *e)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Company name error: %@ ", e.name);
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR, @"Reason: %@ ", e.reason);
        self.companyName = @"";
    }
    @finally
    {
    }

    // Process the company news
    @try
    {
        NSString *dataString = [[NSString alloc] initWithData:mNewsData
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
                  @"News NSJSONSerialization JSONObjectWithData error: %@", e);
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
                     @"Finnhub returned error for %@ company news: %@",
                     self.symbol, value];
                    [mPopupWindow show];
                    [mPopupWindow setText:(NSString *)mText];

                    LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
                          @"Finnhub returned error for %@ company news: %@",
                          self.symbol, value);
                    return;
                }
            
                value = [dict valueForKeyPath:@"headline"];
                NSString *link = [dict valueForKeyPath:@"url"];
            
                if ((value != nil) && (link != nil))
                {
                    [text appendFormat:@"<p style='font-size:14px;'><b>%@ - ",
                     self.symbol];
                    [text appendFormat:@"<a href='%@'>%@</a></b><br />",
                     link, value];
                }

                value = [dict valueForKeyPath:@"summary"];
            
                if (value != nil)
                {
                    [text appendFormat:@"%@<br /></p>", value];
                }
            }
        
            self.news = [text copy];
        }
        else
        {
            self.news = @"";
        }
    }
    @catch(NSException *e)
    {
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR,
              @"Company news error: %@ ", e.name);
        LTLog(mLog, mLogFile, OS_LOG_TYPE_ERROR, @"Reason: %@ ", e.reason);
        self.news = @"";
    }
    @finally
    {
    }

    [[NSNotificationCenter defaultCenter]
      postNotificationName:@"StockTrackerNewData" object:nil];
}

- (void)getLatestData
{
    NSString *hSymbol = [self.symbol stringByReplacingOccurrencesOfString:@"^"
                         withString:@"%5E"];
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSString *urlString = [NSString stringWithFormat:
        @"https://finnhub.io/api/v1/quote?symbol=%@&token=%@",
        hSymbol, mApiKey];
    mPriceDataTask = [session dataTaskWithURL:[NSURL URLWithString:urlString]
                      completionHandler:^(NSData *data,
                      NSURLResponse *response, NSError *error)
    {
        if (error != nil)
        {
            LTLog(self->mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"Price network session error: %@", error);
        }
        else if ((data) && ([data length] > 0))
        {
            self->mPriceData = [data copy];
        }
    }];
    
    [mPriceDataTask resume];
    
    urlString = [NSString stringWithFormat:
        @"https://finnhub.io/api/v1/stock/profile2?symbol=%@&token=%@",
        hSymbol, mApiKey];
    mCompanyDataTask = [session dataTaskWithURL:[NSURL URLWithString:urlString]
                        completionHandler:^(NSData *data,
                        NSURLResponse *response, NSError *error)
    {
        if (error != nil)
        {
            LTLog(self->mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"Company network session error: %@", error);
        }
        else if ((data) && ([data length] > 0))
        {
            self->mCompanyData = [data copy];
        }
    }];
    
    [mCompanyDataTask resume];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString *day = [dateFormatter stringFromDate:[NSDate date]];
    
    urlString = [NSString stringWithFormat:
        @"https://finnhub.io/api/v1/company-news?symbol=%@&"
         "from=%@&to=%@&token=%@", hSymbol, day, day, mApiKey];
    mCompanyNewsTask = [session dataTaskWithURL:[NSURL URLWithString:urlString]
                        completionHandler:^(NSData *data,
                        NSURLResponse *response, NSError *error)
    {
        if (error != nil)
        {
            LTLog(self->mLog, mLogFile, OS_LOG_TYPE_ERROR,
                  @"News network session error: %@", error);
        }
        else if ((data) && ([data length] > 0))
        {
            self->mNewsData = [data copy];
        }
    }];
    
    [mCompanyNewsTask resume];
}

@end
