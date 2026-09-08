//
//  BUAdTestMeasurementConfiguration.h
//  BUAdTestMeasurement
//
//  Created by bytedance on 2021/3/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BUAdTestMeasurementConfiguration : NSObject
+ (instancetype)configuration;
@property (nonatomic, assign) BOOL debugMode;
@end

NS_ASSUME_NONNULL_END
