// --------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the ""Software""), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// --------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import <AzureCommunicationCommon/AzureCommunicationCommon-Swift.h>

@interface ObjCAutoRefreshProactiveTokenCredentialTests : XCTestCase
@property (nonatomic, strong) NSString *sampleToken;
@property (nonatomic, strong) NSString *sampleExpiredToken;
@property (nonatomic) double sampleTokenExpiry;
@property (nonatomic) double sampleExpiredTokenExpiry;
@property (nonatomic) int fetchTokenCallCount;
@property (nonatomic) NSTimeInterval timeout;
@end

@implementation ObjCAutoRefreshProactiveTokenCredentialTests

- (void)setUp {
    [super setUp];
    self.sampleToken = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjMyNTAzNjgwMDAwfQ.9i7FNNHHJT8cOzo-yrAUJyBSfJ-tPPk2emcHavOEpWc";
    self.sampleExpiredToken = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjEwMH0.1h_scYkNp-G98-O4cW6KvfJZwiz54uJMyeDACE4nypg";
    self.sampleTokenExpiry = 32503680000;
    self.sampleExpiredTokenExpiry = 100;
    self.fetchTokenCallCount = 0;
    self.timeout = 10.0;
}

- (void)test_ShouldNotBeCalledBeforeExpiringTime {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_ShouldNotBeCalledBeforeExpiringTime"];
    
    __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
    NSString *tokenValidFor15Mins = [self generateTokenValidForSeconds:15 * 60];
    CommunicationTokenRefreshOptions *tokenRefreshOptions = [self createTokenRefreshOptions:weakSelf initialToken:tokenValidFor15Mins refreshedToken:weakSelf.sampleToken];
    
    CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                initWithOptions: tokenRefreshOptions
                                                error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                 NSError * _Nullable error) {
            XCTAssertNotNil(accessToken);
            XCTAssertNil(error);
            XCTAssertEqual(accessToken.token, tokenValidFor15Mins);
            XCTAssertEqual(weakSelf.fetchTokenCallCount, 0);
            [expectation fulfill];
        }];
    });
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}

-(CommunicationTokenCredential *)createTokenRefreshOptions:(__weak ObjCAutoRefreshProactiveTokenCredentialTests *)weakSelf initialToken:(NSString *)initialToken refreshedToken:(NSString *) refreshedToken {
    return (CommunicationTokenCredential *) [[CommunicationTokenRefreshOptions alloc]
            initWithInitialToken:initialToken
            refreshProactively:YES
            tokenRefresher:^(void (^ block)
                             (NSString * _Nullable accessToken,
                              NSError * _Nullable error)) {
                weakSelf.fetchTokenCallCount += 1;
                block(refreshedToken, nil);
            }];
}

-(void)failForTimeout:(NSError * _Nullable) error testName:(NSString *)testName {
    if(error != NULL){
        XCTFail(@"%@ timeout exceeded!", testName);
    }
}

- (void)test_ShouldBeCalledImmediatelyWithExpiredToken {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_ShouldBeCalledImmediatelyWithExpiredToken"];
    
    __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
    CommunicationTokenRefreshOptions *tokenRefreshOptions = [self createTokenRefreshOptions:weakSelf initialToken:self.sampleExpiredToken refreshedToken:weakSelf.sampleToken];
    
    CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                initWithOptions: tokenRefreshOptions
                                                error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                 NSError * _Nullable error) {
            XCTAssertNotNil(accessToken);
            XCTAssertNil(error);
            XCTAssertEqual(accessToken.token, weakSelf.sampleToken);
            XCTAssertEqual(weakSelf.fetchTokenCallCount, 1);
            [expectation fulfill];
        }];
    });
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}

- (void)test_ShouldBeCalledIfTokenExpiringSoon {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_ShouldBeCalledIfTokenExpiringSoon"];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    int minutes[] = {1, 9};
    int arrSize = (sizeof minutes) / (sizeof minutes[0]);
    for ( int i = 0; i < arrSize; i++ ) {
        [self setUp];
        __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
        NSString *expiringToken = [self generateTokenValidForSeconds:minutes[i] * 60];
        CommunicationTokenRefreshOptions *tokenRefreshOptions = [self createTokenRefreshOptions:weakSelf initialToken:expiringToken refreshedToken:weakSelf.sampleToken];
        
        CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                    initWithOptions: tokenRefreshOptions
                                                    error:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                     NSError * _Nullable error) {
                XCTAssertNotNil(accessToken);
                XCTAssertNil(error);
                XCTAssertEqual(accessToken.token, self.sampleToken);
                XCTAssertEqual(weakSelf.fetchTokenCallCount, 1);
                if(i == arrSize - 1){
                    [expectation fulfill];
                }
                dispatch_semaphore_signal(semaphore);
            }];
        });
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
    }
    
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}

- (void)test_FetchTokenReturnsError {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_FetchTokenReturnsError"];
    __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
    NSString *errorDesc = @"Error while fetching token";
    CommunicationTokenRefreshOptions *tokenRefreshOptions = [[CommunicationTokenRefreshOptions alloc]
                                                initWithInitialToken:self.sampleExpiredToken
                                                refreshProactively:NO
                                                tokenRefresher:^(void (^ block)
                                                                 (NSString * _Nullable token,
                                                                  NSError * _Nullable error)) {
        weakSelf.fetchTokenCallCount += 1;
        NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey: errorDesc};
        NSError *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:400 userInfo:errorDictionary];
        block(nil, error);
    }];
    CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                initWithOptions: tokenRefreshOptions
                                                error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                 NSError * _Nullable error) {
            XCTAssertNotNil(error);
            XCTAssertEqual([error.localizedDescription containsString: errorDesc], YES);
            XCTAssertNil(accessToken);
            XCTAssertEqual(weakSelf.fetchTokenCallCount, 1);
            [expectation fulfill];
        }];
    });
    
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}

- (void)test_ShouldThrowExceptionOnExpiredTokenReturn {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_ShouldThrowExceptionOnExpiredTokenReturn"];
    __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
    CommunicationTokenRefreshOptions *tokenRefreshOptions = [self createTokenRefreshOptions:weakSelf initialToken:weakSelf.sampleExpiredToken refreshedToken:weakSelf.sampleExpiredToken];
    CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                initWithOptions: tokenRefreshOptions
                                                error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                 NSError * _Nullable error) {
            XCTAssertNotNil(error);
            XCTAssertEqual([error.debugDescription containsString: @"The token returned from the tokenRefresher is expired."], YES);
            XCTAssertNil(accessToken);
            XCTAssertEqual(weakSelf.fetchTokenCallCount, 2);
            [expectation fulfill];
        }];
    });
    
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}

- (void)test_fractionalBackoffAppliedWhenTokenExpiring {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_fractionalBackoffAppliedWhenTokenExpiring"];
    __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
    int validForSeconds = 7;
    int expectedTotalCallsTillLastSecond = floor(log2(validForSeconds));
    NSString *refreshedToken = [self generateTokenValidForSeconds:validForSeconds];
    CommunicationTokenRefreshOptions *tokenRefreshOptions = [self createTokenRefreshOptions:weakSelf initialToken:refreshedToken refreshedToken:refreshedToken];
    CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                initWithOptions: tokenRefreshOptions
                                                error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(validForSeconds * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                 NSError * _Nullable error) {
            XCTAssertEqual(weakSelf.fetchTokenCallCount, expectedTotalCallsTillLastSecond);
            [expectation fulfill];
        }];
    });
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}

- (void)test_ShouldNotCallWhenTokenStillValid {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_ShouldNotCallWhenTokenStillValid"];
    __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
    NSString *refreshedToken = [self generateTokenValidForSeconds:15 * 60];
    CommunicationTokenRefreshOptions *tokenRefreshOptions = [self createTokenRefreshOptions:weakSelf initialToken:weakSelf.sampleToken refreshedToken:refreshedToken];
    CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                initWithOptions: tokenRefreshOptions
                                                error:nil];
    int checkCount = 10;
    for(int i =0; i <= checkCount; i++){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                     NSError * _Nullable error) {
                XCTAssertNotNil(accessToken);
                XCTAssertNil(error);
                XCTAssertEqual(accessToken.token, self.sampleToken);
                XCTAssertEqual(weakSelf.fetchTokenCallCount, 0);
                if(i == checkCount){
                    [expectation fulfill];
                }
            }];
        });
    }
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}

- (void)test_ShouldBeCalledAgainAfterFirstRefreshCall {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_ShouldBeCalledAgainAfterFirstRefreshCall"];
    __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
    int expirySeconds = 10 * 60 + 1;
    NSString *initialToken = [self generateTokenValidForSeconds:expirySeconds];
    NSString *refreshedToken = [self generateTokenValidForSeconds:expirySeconds + 1];
    CommunicationTokenRefreshOptions *tokenRefreshOptions = [self createTokenRefreshOptions:weakSelf initialToken:initialToken refreshedToken:refreshedToken];
    CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                initWithOptions: tokenRefreshOptions
                                                error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                 NSError * _Nullable error) {
            XCTAssertNotNil(accessToken);
            XCTAssertEqual(accessToken.token, refreshedToken);
        }];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                 NSError * _Nullable error) {
            XCTAssertNotNil(accessToken);
            XCTAssertEqual(accessToken.token, refreshedToken);
            XCTAssertEqual(weakSelf.fetchTokenCallCount, 2);
            [expectation fulfill];
        }];
    });
    
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}

- (void)test_ShouldGetCalledImmediatelyWithoutInitialToken {
    XCTestExpectation *expectation = [self expectationWithDescription:@"test_ShouldGetCalledImmediatelyWithoutInitialToken"];
    __weak ObjCAutoRefreshProactiveTokenCredentialTests *weakSelf = self;
    CommunicationTokenRefreshOptions *tokenRefreshOptions = [self createTokenRefreshOptions:weakSelf initialToken:nil refreshedToken:weakSelf.sampleToken];
    CommunicationTokenCredential *credential = [[CommunicationTokenCredential alloc]
                                                initWithOptions: tokenRefreshOptions
                                                error:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [credential tokenWithCompletionHandler:^(CommunicationAccessToken * _Nullable accessToken,
                                                 NSError * _Nullable error) {
            XCTAssertNotNil(accessToken);
            XCTAssertNil(error);
            XCTAssertEqual(accessToken.token, self.sampleToken);
            XCTAssertEqual(weakSelf.fetchTokenCallCount, 1);
            [expectation fulfill];
        }];
    });
    
    [self waitForExpectationsWithTimeout:self.timeout handler:^(NSError * _Nullable error) {
        [self failForTimeout:error testName:expectation.expectationDescription];
    }];
}


- (NSString *)generateTokenValidForSeconds: (int) seconds {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    NSDate *currentDate = [NSDate date];
    NSString *d = [dateFormatter stringFromDate:currentDate];
    NSDate *expiresOn = [[dateFormatter dateFromString:d]
                        dateByAddingTimeInterval:(seconds)];
    NSTimeInterval timeInterval = [expiresOn timeIntervalSince1970];
    NSString *tokenString = [NSString stringWithFormat:@"{\"exp\":%f}", timeInterval];
    NSData *tokenStringData = [tokenString dataUsingEncoding: NSASCIIStringEncoding];
    NSString *kSampleTokenHeader = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9";
    NSString *kSampleTokenSignature = @"adM-ddBZZlQ1WlN3pdPBOF5G4Wh9iZpxNP_fSvpF4cWs";
    NSString *validToken = [NSString stringWithFormat:@"%@.%@.%@",
                            kSampleTokenHeader,
                            [tokenStringData base64EncodedStringWithOptions:NSDataBase64Encoding76CharacterLineLength],
                            kSampleTokenSignature];
    
    return validToken;
}

@end
