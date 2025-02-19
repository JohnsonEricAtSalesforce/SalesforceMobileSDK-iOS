/*
 UIColor+SFColors.m
 SalesforceSDKCore
 
 Created by Kunal Chitalia on 3/28/16.
 Copyright (c) 2016-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UIColor+SFColors.h"
#import <UIKit/UIKit.h>

@implementation UIColor (SFColors)

+(UIColor *) salesforceBlueColor {
    return [UIColor colorWithRed:0.0f/255.0f green:112.0f/255.0f blue:210.0f/255.0f alpha:1.0f];
}

+ (UIColor *)sfsdk_colorFromHexValue:(NSString *)hexString {
    UIColor *color = nil;
    hexString = [[self class] sfsdk_sixDigitHexFromString:hexString];
    if ([hexString length] > 0) {
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:hexString];
        [scanner scanHexInt:&rgbValue];
        color = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
    }
    return color;
}

+ (NSString *)sfsdk_sixDigitHexFromString:(NSString *)hexString {
    if (hexString.length == 0) {
        return nil;
    }
    if ([hexString characterAtIndex:0] == '#') {
        hexString = [hexString substringFromIndex:1];
    }
    if (hexString.length == 6) {
        return hexString;
    }
    //invalid shorthand representation.
    if (hexString.length != 3) {
        return nil;
    }
    NSMutableString *sixDigitHex = [[NSMutableString alloc] init];
    for (NSInteger i = 0; i < 3; i++) {
        [sixDigitHex appendFormat:@"%C", [hexString characterAtIndex:i]];
        [sixDigitHex appendFormat:@"%C", [hexString characterAtIndex:i]];
    }
    return [sixDigitHex copy];
}

+ (UIColor *)salesforceSystemBackgroundColor {
    return [UIColor systemBackgroundColor];
}

+ (UIColor *)salesforceLabelColor {
    return [UIColor labelColor];
}

+ (UIColor *)salesforceBackgroundRowSelectedColor {
    return [UIColor colorWithRed:240.0/255.0 green:248.0/255.0 blue:252.0/255.0 alpha:1.0];
}

+ (UIColor *)salesforceBorderColor {
    return [UIColor colorWithRed:216.0/255.0 green:221.0/255.0 blue:230.0/255.0 alpha: 1.0];
}

+ (UIColor *)salesforceWeakTextColor {
    return [UIColor colorWithRed: 84.0/255.0 green:105.0/255.0 blue: 141.0/255.0 alpha: 1.0];
}

+ (UIColor *)salesforceDefaultTextColor {
    return [UIColor colorWithRed: 22.0/255.0 green:50.0/255.0 blue: 92.0/255.0 alpha: 1.0];
}

+ (UIColor *)salesforceAltTextColor {
    return [UIColor colorWithRed: 24.0/255.0 green:52.0/255.0 blue: 95.0/255.0 alpha: 1.0];
}

+ (UIColor *)salesforceAlt2BackgroundColor{
    return [UIColor colorWithRed: 224.0/255.0 green:229.0/255.0 blue: 238.0/255.0 alpha: 1.0];
}

+ (UIColor *)salesforceAltBackgroundColor{
    return [UIColor whiteColor];
}

+ (UIColor *)salesforceTableCellBackgroundColor{
    return [UIColor colorWithRed: 245.0/255.0 green:246.0/255.0 blue: 250.0/255.0 alpha: 1.0];
}

+ (UIColor *)salesforceNavBarTintColor {
    return [UIColor whiteColor];
}

+ (UIColor *)sfsdk_colorForLightStyle:(UIColor *)lightStyleColor darkStyle:(UIColor *)darkStyleColor {
    return [[UIColor alloc] initWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return darkStyleColor;
                } else {
                    return lightStyleColor;
                }
            }];
}

- (NSString *)sfsdk_hexStringFromColor {
    NSAssert (self.canProvideRGBComponents, @"Must be a RGB color to use hexStringFromColor");
    
    CGFloat r, g, b;
    r = self.red;
    g = self.green;
    b = self.blue;
    
    // Fix range if needed
    if (r < 0.0f) r = 0.0f;
    if (g < 0.0f) g = 0.0f;
    if (b < 0.0f) b = 0.0f;
    
    if (r > 1.0f) r = 1.0f;
    if (g > 1.0f) g = 1.0f;
    if (b > 1.0f) b = 1.0f;
    
    // Convert to hex string between 0x00 and 0xFF
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

- (CGColorSpaceModel)colorSpaceModel {
    return CGColorSpaceGetModel(CGColorGetColorSpace(self.CGColor));
}

- (NSString *)colorSpaceString{
    switch ([self colorSpaceModel])
    {
        case kCGColorSpaceModelUnknown:
            return @"kCGColorSpaceModelUnknown";
        case kCGColorSpaceModelMonochrome:
            return @"kCGColorSpaceModelMonochrome";
        case kCGColorSpaceModelRGB:
            return @"kCGColorSpaceModelRGB";
        case kCGColorSpaceModelCMYK:
            return @"kCGColorSpaceModelCMYK";
        case kCGColorSpaceModelLab:
            return @"kCGColorSpaceModelLab";
        case kCGColorSpaceModelDeviceN:
            return @"kCGColorSpaceModelDeviceN";
        case kCGColorSpaceModelIndexed:
            return @"kCGColorSpaceModelIndexed";
        case kCGColorSpaceModelPattern:
            return @"kCGColorSpaceModelPattern";
        default:
            return @"Not a valid color space";
    }
}

- (BOOL)canProvideRGBComponents {
    return (([self colorSpaceModel] == kCGColorSpaceModelRGB) ||
            ([self colorSpaceModel] == kCGColorSpaceModelMonochrome));
}

- (CGFloat)red {
    NSAssert (self.canProvideRGBComponents, @"Must be a RGB color to use -red, -green, -blue");
    const CGFloat *c = CGColorGetComponents(self.CGColor);
    return c[0];
}

- (CGFloat)green {
    NSAssert (self.canProvideRGBComponents, @"Must be a RGB color to use -red, -green, -blue");
    const CGFloat *c = CGColorGetComponents(self.CGColor);
    if ([self colorSpaceModel] == kCGColorSpaceModelMonochrome) return c[0];
    return c[1];
}

- (CGFloat)blue {
    NSAssert (self.canProvideRGBComponents, @"Must be a RGB color to use -red, -green, -blue");
    const CGFloat *c = CGColorGetComponents(self.CGColor);
    if ([self colorSpaceModel] == kCGColorSpaceModelMonochrome) return c[0];
    return c[2];
}

- (CGFloat)alpha {
    const CGFloat *c = CGColorGetComponents(self.CGColor);
    return c[CGColorGetNumberOfComponents(self.CGColor)-1];
}

@end

