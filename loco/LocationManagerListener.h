// Protocol that can be adopted by any class that wants to be notified of
// changes in location or changes to the state of the LocationManager. To
// register or unregister listeners, simply add or remove them from the
// listeners property of the LocationManager instance.

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

#import "LocationManager.h"

@protocol LocationManagerListener <NSObject>
@optional

// A new location is found using GPS.
- (void) setLocation:(CLLocation *)coordinate;
// The application prompts the user for authorization to use location services.
- (void) accessPrompted;
// The user grants the application authorization to use location services.
- (void) accessGranted;
// The user denies the application authorization to use location services.
- (void) accessDenied;
// The application attempts to acquire the device location using GPS instead of
// waiting for a change in cellular towers.
- (void) forceAcquireLocation;
// A change in cellular towers is detected and so an attempt is started to
// acquire the device location using GPS.
- (void) significantChangeDetected:(CLLocation *)location;
// The device location could not be found using GPS.
- (void) acquiringLocationFailed;
// The application pauses monitoring for any changes in location.
- (void) acquiringLocationPaused;
// The application resumes monitoring for any changes in location.
- (void) acquiringLocationResumed;

@end
