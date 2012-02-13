// Finds the user's location.

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

typedef enum {
  LocationStateInit,
  LocationStatePrompted,
  LocationStateDenied,
  LocationStateWaitingSignificantChange,
  LocationStateAcquiring,
  LocationStatePaused,
} LocationState;

@interface LocationManager : NSObject<CLLocationManagerDelegate> {
@private
  LocationState locationState;
  CLLocation *location;
  NSMutableArray *listeners;

  CLLocationManager *manager;
  NSDate *significantChangeTimestamp;
  NSUInteger failedUpdateAttempts;
}

@property (nonatomic, readonly) LocationState locationState;
@property (nonatomic, readonly) CLLocation *location;
@property (nonatomic, readonly) NSMutableArray *listeners;

+ (LocationManager *) sharedInstance;

// Prompts the user to grant the application location access unless already denied.
- (void) tryPromptAuthorization;
// Prompts the user to grant the application location access.
- (void) forcePromptAuthorization;

// Pauses all location monitoring.
- (void) pause;
// Resumes all location monitoring. This will implicitly force acquiring the
// user's exact location.
- (void) resume;

// Force reading the user's exact location 
- (void) forceAcquireLocation;

@end
