// Listener for events by LocationManager.

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#import "LocationManager.h"

@protocol LocationManagerListener <NSObject>
@optional

- (void) setLocation:(CLLocation *)coordinate;
- (void) setLocationState:(LocationState)locationState;
- (void) accessPrompted;
- (void) accessGranted;
- (void) accessDenied;
- (void) forceAcquireBestLocation;
- (void) significantChangeDetected:(CLLocation *)location;
- (void) acquiringLocationFailed;
- (void) acquiringLocationPaused;
- (void) acquiringLocationResumed;

@end
