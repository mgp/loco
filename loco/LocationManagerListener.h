// Listener for events by LocationManager.

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#import "LocationManager.h"

@protocol LocationManagerListener <NSObject>
@optional

- (void) setLocationState:(LocationState)locationState;
- (void) setLocation:(CLLocationCoordinate2D)coordinate;

- (void) accessPrompted;
- (void) accessGranted;
- (void) forceAcquireBestLocation;
- (void) staleSignificantChangeDetected:(CLLocation *)location;
- (void) currentSignificantChangeDetected:(CLLocation *)location;
- (void) staleFirstLocationFound:(CLLocation *)location;
- (void) currentFirstLocationFound:(CLLocation *)location;
- (void) staleNextLocationFound:(CLLocation *)location;
- (void) currentNextLocationFound:(CLLocation *)location;
- (void) accessDenied;
- (void) acquiringLocationFailed;
- (void) acquiringLocationPaused;
- (void) acquiringLocationResumed;

@end
