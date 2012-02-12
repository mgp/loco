// Finds the user's location.

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

typedef enum {
  LocationStateUnknown,
  LocationStatePrompted,
  LocationStateDenied,
  LocationStateWaitingSignificantChange,
  LocationStateAcquiringBest,
  LocationStateAcquiringBestFailed,
} LocationState;

@interface LocationManager : NSObject<CLLocationManagerDelegate> {
@private
  CLLocationManager *manager;
  NSUInteger failedUpdateAttempts;
  NSDate *significantChangeTimestamp;
  BOOL isPaused;
  
  CLLocationCoordinate2D exactLocation;
  CLLocationAccuracy exactLocationAccuracy;
  NSDate *exactLocationTimestamp;
  
  LocationState locationState;
  
  NSMutableArray *locationManagerListeners;
}

@property (nonatomic, readonly) BOOL isPaused;
@property (nonatomic, readonly) LocationState locationState;
@property (nonatomic, readonly) NSMutableArray *locationManagerListeners;

+ (LocationManager *) sharedInstance;

// Prompts the user to grant the application location access unless already denied.
- (void) tryPromptEnableLocationAccess;
// Prompts the user to grant the application location access.
- (void) forcePromptEnableLocationAccess;

// Pauses all location monitoring.
- (void) pause;
// Resumes all location monitoring.
- (void) resume;

// Force reading the user's exact location 
- (void) forceAcquireBestLocation;

@end
