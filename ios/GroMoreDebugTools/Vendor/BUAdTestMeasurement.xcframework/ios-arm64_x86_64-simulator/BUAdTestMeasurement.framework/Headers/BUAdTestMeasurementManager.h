//
//  BUAdTestMeasurementManager.h
//  BUAdTestMeasurement
//
//  Created by bytedance on 2021/2/23.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class BUAdTestMeasurementConfiguration;
@interface BUAdTestMeasurementManager : NSObject
+ (instancetype)manager;
+ (void)showTestMeasurementWithController:(UIViewController *)rootViewController;
@end

NS_ASSUME_NONNULL_END
