// Monitors changes in cellular towers and acquiring the location using GPS in
// response.
//
// See https://github.com/mgp/loco for complete documentation.

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

// Enumeration that specifies what the LocationManager is currently doing.
typedef enum {
  // Not prompted the user yet for authorization to use location services.
  LocationStateInit,
  // Prompting the user to authorize the application use of location services.
  LocationStatePrompted,
  // The user denied the application authorization to use location services.
  LocationStateDenied,
  // Waiting for a change in cellular towers.
  LocationStateWaitingSignificantChange,
  // Acquiring the device location using GPS.
  LocationStateAcquiring,
  // Monitoring for any changes in location has been paused.
  LocationStatePaused,
} LocationState;

@interface LocationManager : NSObject<CLLocationManagerDelegate> {
@private
  LocationState locationState;
  CLLocation *location;
  NSMutableArray *listeners;

  CLLocationManager *manager;
  CLLocation *acquiringLocation;
  NSDate *significantChangeTimestamp;
  NSUInteger failedUpdateAttempts;
}

// An enumeration defining the state of the LocationManager.
@property (nonatomic, readonly) LocationState locationState;
// The last location acquired using GPS, or nil if no such location has been
// acquired yet.
@property (nonatomic, readonly) CLLocation *location;
// The mutable array containing registered listeners.
@property (nonatomic, readonly) NSMutableArray *listeners;

+ (LocationManager *) sharedInstance;

// If the user has not already declined authorization, prompts the user to
// authorize the application use of location services.
- (void) tryPromptAuthorization;
// Regardless of whether the user has already declined authorization, prompts
// the user to authorize the application use of location services.
- (void) forcePromptAuthorization;

// If location access has been enabled, pauses monitoring for any changes in
// location.
- (void) pause;
// If location access has been enabled but is paused, resumes monitoring for any
// changes in location. This implicitly calls forceAcquireLocation below.
- (void) resume;

// Attempts to acquire the device location using GPS instead of waiting for a
// change in cellular towers to trigger acquisition.
- (void) forceAcquireLocation;

@end
