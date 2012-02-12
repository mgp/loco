// Listener for events by LocationManager.

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#import "LocationManager.h"

@protocol LocationManagerListener <NSObject>
@optional

- (void) setLocation:(CLLocationCoordinate2D)coordinate;
- (void) setLocationState:(LocationState)locationState;

- (void) accessPrompted;
- (void) accessGranted;
- (void) forceAcquireBestLocation;
- (void) staleSignificantChangeDetected:(CLLocation *)location;
- (void) currentSignificantChangeDetected:(CLLocation *)location;
- (void) staleAccurateLocationFound:(CLLocation *)location;
- (void) currentAccurateLocationFound:(CLLocation *)location;
- (void) accessDenied;
- (void) acquiringLocationFailed;
- (void) acquiringLocationPaused;
- (void) acquiringLocationResumed;

@end
