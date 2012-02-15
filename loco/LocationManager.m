#import "LocationManager.h"

#import "LocationManagerListener.h"

@interface LocationManager()

- (void) startMonitoringSignificantChanges;
- (void) stopMonitoringSignificantChanges;
- (void) startAcquiringLocation;
- (void) stopAcquiringLocation;

@end

@implementation LocationManager

// Time in seconds significant changes are recognized after acquiring a location.
#define kMinSecondsSignificantChange 30
// Maximum time ago in seconds for a location to be considered recent.
#define kMaxSecondsRecentUpdate 30
// Maximum number of failed location update attempts until retrying later.
#define kMaxFailedUpdateAttempts 5
// Maximum number of seconds to keep the GPS on for.
#define kMaxGpsOnTime 15

@synthesize locationState;
@synthesize location;
@synthesize listeners;

static LocationManager *singleton;

- (id) init {
  self = [super init];
  if (self) {
    locationState = LocationStateInit;
    listeners = [[NSMutableArray alloc] init];

    manager = [[CLLocationManager alloc] init];
    manager.delegate = self;
    failedUpdateAttempts = 0;
  }
  return self;
}

- (void) dealloc {
  [location release];
  [listeners release];

  [manager release];
  [acquiringLocation release];
  [significantChangeTimestamp release];

  [super dealloc];
}

+ (LocationManager *) sharedInstance {
  if (singleton == nil) {
    singleton = [[LocationManager alloc] init];
  }
  return singleton;
}

- (BOOL) isAcquiredLocationAccurate {
  return (acquiringLocation.horizontalAccuracy < kCLLocationAccuracyNearestTenMeters);
}

- (void) finishAcquiringLocation {
  // The location we acquired is accurate enough, and is the new location.
  [location release];
  location = acquiringLocation;
  acquiringLocation = nil;
  
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(setLocation:)]) {
      [listener setLocation:location];
    }
  }
}

- (void) acquiringLocationTimerExpired {
  if ((acquiringLocation == nil) || ![self isAcquiredLocationAccurate]) {
    // The location we acquired is not accurate enough, so discard it.
    [acquiringLocation release];
    acquiringLocation = nil;
    
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationFailed)]) {
        [listener acquiringLocationFailed];
      }
    }
  } else  {
    [self finishAcquiringLocation];
  }

  // Switch back to monitoring significant location changes.
  [self stopAcquiringLocation];
  [self startMonitoringSignificantChanges];
}

- (void) cancelAcquiringLocationTimer {
  [NSObject
   cancelPreviousPerformRequestsWithTarget:self
   selector:@selector(acquiringLocationTimerExpired)
   object:nil];
}

- (void) startMonitoringSignificantChanges {
  locationState = LocationStateWaitingSignificantChange;
  [manager startMonitoringSignificantLocationChanges];  
}

- (void) startAcquiringLocationTimer {
  [self performSelector:@selector(acquiringLocationTimerExpired)
             withObject:nil
             afterDelay:kMaxGpsOnTime];
}

- (void) stopMonitoringSignificantChanges {
  [manager stopUpdatingLocation];
}

- (void) stopAcquiringLocation {
  [self cancelAcquiringLocationTimer];
  [manager stopUpdatingLocation];
}

- (void) startAcquiringLocation {
  locationState = LocationStateAcquiring;
  failedUpdateAttempts = 0;
  
  manager.desiredAccuracy = kCLLocationAccuracyBest;
  manager.distanceFilter = kCLDistanceFilterNone;
  [manager startUpdatingLocation];
  
  // Do not use GPS forever.
  [self startAcquiringLocationTimer];
}

- (void) promptEnableLocationAccess {
  // Simply starting the location manager will prompt again.
  [manager startUpdatingLocation];
  
  locationState = LocationStatePrompted;
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(accessPrompted)]) {
      [listener accessPrompted];
    }
  }
}

- (void) tryPromptAuthorization {
  if (locationState == LocationStateInit) {
    [self promptEnableLocationAccess];
  }
}

- (void) forcePromptAuthorization {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied)) {
    [self promptEnableLocationAccess];
  }
}

#pragma mark CLLocationManagerDelegate methods.

- (void) locationManager:(CLLocationManager *)managerParam
     didUpdateToLocation:(CLLocation *)newLocation
            fromLocation:(CLLocation *)oldLocation {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied) ||
      (locationState == LocationStatePaused)) {
    NSLog(@"Got new location when locationState=%d", locationState);
    return;
  }
  
  failedUpdateAttempts = 0;
  if (locationState == LocationStatePrompted) {
    // If got an update, then location access was granted.
    [self startAcquiringLocation];
    
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(accessGranted)]) {
        [listener accessGranted];
      }
    }
    return;
  }

  if (locationState == LocationStateWaitingSignificantChange) {
    if (location != nil) {
      // Ignore change if acquired location using GPS recently.
      NSTimeInterval secondsSinceExactLocation = [newLocation.timestamp
                                                  timeIntervalSinceDate:location.timestamp];
      if (secondsSinceExactLocation < kMinSecondsSignificantChange) {
        return;
      }
    }
    
    // Exact location is found comparing to current significant change timestamp.
    [significantChangeTimestamp release];
    significantChangeTimestamp = [newLocation.timestamp retain];
    // Get a more accurate location.
    [self stopMonitoringSignificantChanges];
    [self startAcquiringLocation];

    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(currentSignificantChangeDetected:)]) {
        [listener significantChangeDetected:newLocation];
      }
    }
    return;
  }
  
  if (locationState == LocationStateAcquiring) {
    if (significantChangeTimestamp == nil) {
      // If acquiring the first location, it must be recent.
      NSTimeInterval locationAgeInSeconds = [[NSDate date]
                                             timeIntervalSinceDate:newLocation.timestamp];
      if (locationAgeInSeconds >= kMaxSecondsRecentUpdate) {
        NSLog(@"First location with GPS is stale");
        return;
      }
    } else {
      // If not the first location, it must follow the significant location change.
      if ([newLocation.timestamp
           compare:significantChangeTimestamp] != NSOrderedDescending) {
        NSLog(@"Next location with GPS is stale");
        return;
      }
    }

    // The horizontalAccuracy does not use the CLLocationAccuracy constants. If
    // negative, it is invalid, and not kCLLocationAccuracyBest.
    if (newLocation.horizontalAccuracy < 0) {
      return;
    }
    
    if ((acquiringLocation == nil) ||
        (newLocation.horizontalAccuracy < acquiringLocation.horizontalAccuracy)) {
      [acquiringLocation release];
      acquiringLocation = [newLocation retain];
      
      if ([self isAcquiredLocationAccurate]) {
        // Switch back to monitoring significant location changes.
        [self stopAcquiringLocation];
        [self startMonitoringSignificantChanges];

        [self finishAcquiringLocation];
      }
    }
    return;
  }
}

- (void) locationManager:(CLLocationManager *)managerParam
        didFailWithError:(NSError *)error {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied) ||
      (locationState == LocationStateWaitingSignificantChange) ||
      (locationState == LocationStatePaused)) {
    NSLog(@"Failed to get new location when locationState=%d", locationState);
  }
  
  if (locationState == LocationStatePrompted) {
    if (error.code == kCLErrorDenied) {
      // The user denied the application authorization to use location services.
      [self stopAcquiringLocation];

      locationState = LocationStateDenied;
      for (NSObject<LocationManagerListener> *listener in listeners) {
        if ([listener respondsToSelector:@selector(accessDenied)]) {
          [listener accessDenied];
        }
      }
    } else {
      // Location access was granted, but acquisition failed.
      [self startAcquiringLocation];
      
      for (NSObject<LocationManagerListener> *listener in listeners) {
        if ([listener respondsToSelector:@selector(accessGranted)]) {
          [listener accessGranted];
        }
      }
    }
    return;
  }

  if (locationState == LocationStateAcquiring) {
    ++failedUpdateAttempts;

    if (failedUpdateAttempts >= kMaxFailedUpdateAttempts) {
      // Failed too many times to acquire the location again, so stop for now.
      [self stopAcquiringLocation];
      [self startMonitoringSignificantChanges];

      for (NSObject<LocationManagerListener> *listener in listeners) {
        if ([listener respondsToSelector:@selector(acquiringLocationFailed)]) {
          [listener acquiringLocationFailed];
        }
      }
    }
  }
}

- (void) pause {
  if ((locationState == LocationStateInit) || 
      (locationState == LocationStatePrompted) ||
      (locationState == LocationStateDenied) ||
      (locationState == LocationStatePaused)) {
    return;
  }
  
  if (locationState == LocationStateWaitingSignificantChange) {
    [self stopMonitoringSignificantChanges];
  } else if (locationState == LocationStateAcquiring) {
    [self stopAcquiringLocation];
  }
  // TODO: clear this on only one branch of the conditional
  [significantChangeTimestamp release];
  significantChangeTimestamp = nil;

  locationState = LocationStatePaused;
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(acquiringLocationPaused)]) {
      [listener acquiringLocationPaused];
    }
  }
}

- (void) resume {
  if (locationState == LocationStatePaused) {
    [self startAcquiringLocation];

    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationResumed)]) {
        [listener acquiringLocationResumed];
      }
    }
  }
}

- (void) forceAcquireLocation {
  if (locationState == LocationStateWaitingSignificantChange) {
    [self stopMonitoringSignificantChanges];
    [self startAcquiringLocation];
    
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(forceAcquireBestLocation)]) {
        [listener forceAcquireLocation];
      }
    }
  }
}

@end
