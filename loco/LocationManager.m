#import "LocationManager.h"

#import "LocationManagerListener.h"

@implementation LocationManager

// Time in seconds significant changes are recognized after an exact location is acquired.
#define kMinSecondsSignificantChange 30
// Maximum time ago in seconds for a location to be considered recent.
#define kMaxSecondsRecentUpdate 30
// Maximum number of failed location update attempts until retrying later.
#define kMaxFailedUpdateAttempts 5
// TODO
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

- (void) setLocationState:(LocationState)locationStateParam {
  locationState = locationStateParam;
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(setLocationState:)]) {
      [listener setLocationState:locationState];
    }
  }
}

- (BOOL) isAcquiredLocationAccurate {
  return (acquiringLocation.horizontalAccuracy < kCLLocationAccuracyNearestTenMeters);
}

- (void) startMonitoringSignificantChanges {
  [manager stopUpdatingLocation];
  [self setLocationState:LocationStateWaitingSignificantChange];
  [manager startMonitoringSignificantLocationChanges];
}

- (void) finishAcquiringLocation {
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
  
  // Switch back to monitoring significant location changes.
  [self startMonitoringSignificantChanges];
}

- (void) acquiringLocationTimerExpired {
  [self finishAcquiringLocation];
}

- (void) cancelAcquiringLocationTimer {
  [NSObject
   cancelPreviousPerformRequestsWithTarget:self
   selector:@selector(acquiringLocationTimerExpired)
   object:nil];
}

- (void) finishAcquiringLocationAndCancelTimer {
  [self cancelAcquiringLocationTimer];
  [self finishAcquiringLocation];
}

- (void) startAcquiringLocationTimer {
  [self performSelector:@selector(acquiringLocationTimerExpired)
             withObject:nil
             afterDelay:kMaxGpsOnTime];
}

- (void) startAcquiringLocation {
  [manager stopMonitoringSignificantLocationChanges];
  
  manager.desiredAccuracy = kCLLocationAccuracyBest;
  manager.distanceFilter = kCLDistanceFilterNone;
  [manager startUpdatingLocation];
  
  // TODO: set location state?
  
  // Do not use GPS forever.
  [self startAcquiringLocationTimer];
}

- (void) promptEnableLocationAccess {
  // Simply starting the location manager will prompt again.
  [self setLocationState:LocationStatePrompted];
  [self startAcquiringLocation];
  
  for (NSObject<LocationManagerListener> *listener in listeners) {
    if ([listener respondsToSelector:@selector(accessPrompted)]) {
      [listener accessPrompted];
    }
  }
}

- (void) tryPromptEnableLocationAccess {
  if (locationState == LocationStateInit) {
    [self promptEnableLocationAccess];
  }
}

- (void) forcePromptEnableLocationAccess {
  if ((locationState == LocationStateInit) ||
      (locationState == LocationStateDenied)) {
    [self promptEnableLocationAccess];
  }
}

- (void) updateAcquiringLocation:(CLLocation *)newLocation {
  // The horizontalAccuracy does not use the CLLocationAccuracy constants. If
  // negative, it is invalid, and not kCLLocationAccuracyBest.
  if (newLocation.horizontalAccuracy < 0) {
    return;
  }
  
  if ((location == nil) ||
      (newLocation.horizontalAccuracy < location.horizontalAccuracy)) {
    location = newLocation;
    
    // Less than ten meters is sufficiently close.
    if (location.horizontalAccuracy < kCLLocationAccuracyNearestTenMeters) {
      [self finishAcquiringLocationAndCancelTimer];
    }
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
  }
  
  failedUpdateAttempts = 0;
  if (locationState == LocationStatePrompted) {
    [self setLocationState:LocationStateAcquiring];

    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(accessGranted)]) {
        [listener accessGranted];
      }
    }

    // Already attempting to acquire location using GPS.
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
    
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(currentSignificantChangeDetected:)]) {
        [listener significantChangeDetected:newLocation];
      }
    }
    
    // Exact location is found comparing to current significant change timestamp.
    [significantChangeTimestamp release];
    significantChangeTimestamp = [newLocation.timestamp retain];

    [manager stopMonitoringSignificantLocationChanges];
    
    // Get a more accurate location.
    [self startAcquiringLocation];
    [self setLocationState:LocationStateAcquiring];
    return;
  }
  
  if (locationState == LocationStateAcquiring) {
    if (significantChangeTimestamp == nil) {
      // Acquiring the first location; make it recent.
      NSTimeInterval locationAgeInSeconds = [[NSDate date]
                                             timeIntervalSinceDate:newLocation.timestamp];
      if (locationAgeInSeconds < kMaxSecondsRecentUpdate) {
        [self updateAcquiringLocation:newLocation];
      } else {
        NSLog(@"First location with GPS is stale");
      }
    } else {
      // Wait for a location acquired after the significant location change.
      if ([newLocation.timestamp
           compare:significantChangeTimestamp] == NSOrderedDescending) {
        [self updateAcquiringLocation:newLocation];
      } else {
        NSLog(@"Next location with GPS is stale");
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
      for (NSObject<LocationManagerListener> *listener in listeners) {
        if ([listener respondsToSelector:@selector(accessDenied)]) {
          [listener accessDenied];
        }
      }
      
      [self setLocationState:LocationStateDenied];
      [manager stopUpdatingLocation];
    } else {
      // Location access was granted, but acquisition failed.
      [self setLocationState:LocationStateAcquiring];
      
      for (NSObject<LocationManagerListener> *listener in listeners) {
        if ([listener respondsToSelector:@selector(accessGranted)]) {
          [listener accessGranted];
        }
      }
    }
    return;
  }

  // Failing to get a significant change in location is ignored. 
  if (locationState == LocationStateAcquiring) {
    for (NSObject<LocationManagerListener> *listener in listeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationFailed)]) {
        [listener acquiringLocationFailed];
      }
    }

    ++failedUpdateAttempts;
    if (failedUpdateAttempts >= kMaxFailedUpdateAttempts) {
      // Failed too many times to acquire the location again, so stop for now.
      failedUpdateAttempts = 0;
      [self setLocationState:LocationStateAcquiringBestFailed];
      [manager stopUpdatingLocation];
    }
  }
}

- (void) pause {
  if ((locationState == LocationStateInit) || 
      (locationState == LocationStatePrompted) ||
      (locationState == LocationStateDenied)) {
    return;
  }
  NSAssert(!isPaused, @"LocationManager is already paused");
  isPaused = YES;
  
  if (locationState == LocationStateWaitingSignificantChange) {
    [manager stopMonitoringSignificantLocationChanges];
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationPaused)]) {
        [listener acquiringLocationPaused];
      }
    }
  } else if ((locationState == LocationStateAcquiringBest) ||
             (locationState == LocationStateAcquiringBestFailed)) {
    [manager stopUpdatingLocation];
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationPaused)]) {
        [listener acquiringLocationPaused];
      }
    }
  }
}

- (void) resume {
  if ((locationState == LocationStateUnknown) || 
      (locationState == LocationStatePrompted) ||
      (locationState == LocationStateDenied)) {
    return;
  }
  NSAssert(isPaused, @"LocationManager was not paused");
  isPaused = NO;
  
  if (locationState == LocationStateWaitingSignificantChange) {
    [manager startMonitoringSignificantLocationChanges];
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationResumed)]) {
        [listener acquiringLocationResumed];
      }
    }
  } else if ((locationState == LocationStateAcquiringBest) ||
             (locationState == LocationStateAcquiringBestFailed)) {
    failedUpdateAttempts = 0;
    [self startAcquiringAccurateLocation];
    locationState = LocationStateAcquiringBest;
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(acquiringLocationResumed)]) {
        [listener acquiringLocationResumed];
      }
    }
  }
}

- (void) forceAcquireBestLocation {
  if (locationState == LocationStateWaitingSignificantChange)) {
    [exactLocationTimestamp release];
    exactLocationTimestamp = nil;
    
    [manager stopMonitoringSignificantLocationChanges];
    
    // Get a more accurate location.
    [self startAcquiringAccurateLocation];
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(forceAcquireBestLocation)]) {
        [listener forceAcquireBestLocation];
      }
    }
    [self setLocationState:LocationStateAcquiringBest];
  }
}

@end
