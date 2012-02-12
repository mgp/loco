#import "LocationManager.h"

#import "LocationManagerListener.h"

@implementation LocationManager

// Time in seconds significant changes are recognized after an exact location is acquired.
#define kMinSecondsSignificantChange 30
// Maximum time ago in seconds for a location to be considered recent.
#define kMaxSecondsRecentUpdate 30
// Maximum number of failed location update attempts until retrying later.
#define kMaxFailedUpdateAttempts 5

@synthesize locationState;
@synthesize locationManagerListeners;

static LocationManager *singleton;

- (id) init {
  self = [super init];
  if (self) {
    manager = [[CLLocationManager alloc] init];
    manager.delegate = self;
    failedUpdateAttempts = 0;
    isPaused = NO;
    
    locationState = LocationStateUnknown;
    
    locationManagerListeners = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void) dealloc {
  [manager release];
  [significantChangeTimestamp release];
  [exactLocationTimestamp release];
  
  [locationManagerListeners release];

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
  for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
    if ([listener respondsToSelector:@selector(setLocationState:)]) {
      [listener setLocationState:locationState];
    }
  }
}

- (void) stopAcquiringAccurateLocation {
  for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
    if ([listener respondsToSelector:@selector(setLocation:)]) {
      [listener setLocation:exactLocation];
    }
  }
  NSLog(@"New location found, lat=%f, lon=%f",
        exactLocation.latitude,
        exactLocation.longitude);
  
  // Switch back to monitoring significant location changes.
  [manager stopUpdatingLocation];
  [self setLocationState:LocationStateWaitingSignificantChange];
  [manager startMonitoringSignificantLocationChanges];
}

- (void) acquiringAccurateLocationTimerExpired {
  [self stopAcquiringAccurateLocation];
}

- (void) cancelAcquiringAccurateLocationTimer {
  [NSObject
   cancelPreviousPerformRequestsWithTarget:self
   selector:@selector(acquiringAccurateLocationTimerExpired)
   object:nil];
}

#define kMaxGpsOnTime 15

- (void) startAcquiringAccurateLocationTimer {
  [self performSelector:@selector(acquiringAccurateLocationTimerExpired)
             withObject:nil
             afterDelay:kMaxGpsOnTime];
}

- (void) startAcquiringAccurateLocation {
  manager.desiredAccuracy = kCLLocationAccuracyBest;
  manager.distanceFilter = kCLDistanceFilterNone;
  [manager startUpdatingLocation];
  
  // Do not use GPS forever.
  [self startAcquiringAccurateLocationTimer];
}

- (void) promptEnableLocationAccess {
  // Simply starting the location manager will prompt again.
  [self setLocationState:LocationStatePrompted];
  [self startAcquiringAccurateLocation];
  
  for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
    if ([listener respondsToSelector:@selector(accessPrompted)]) {
      [listener accessPrompted];
    }
  }
}

- (void) tryPromptEnableLocationAccess {
  if ((locationState == LocationStateUnknown) ||
      (locationState == LocationStateAcquiringBestFailed)) {
    [self promptEnableLocationAccess];
  }
}

- (void) forcePromptEnableLocationAccess {
  if ((locationState == LocationStateUnknown) ||
      (locationState == LocationStateAcquiringBestFailed) ||
      (locationState == LocationStateDenied)) {
    [self promptEnableLocationAccess];
  }
}

- (void) updateToLocation:(CLLocation *)newLocation {
  // The horizontalAccuracy does not use the CLLocationAccuracy constants. If
  // negative, it is invalid, and not kCLLocationAccuracyBest.
  if (newLocation.horizontalAccuracy < 0) {
    return;
  }
  
  if ((exactLocationAccuracy < 0) ||
      (newLocation.horizontalAccuracy < exactLocationAccuracy)) {
    exactLocation = newLocation.coordinate;
    exactLocationAccuracy = newLocation.horizontalAccuracy;
    exactLocationTimestamp = [newLocation.timestamp retain];
    
    // Less than ten meters is sufficiently close.
    if (exactLocationAccuracy < kCLLocationAccuracyNearestTenMeters) {
      [self cancelAcquiringAccurateLocationTimer];
      [self stopAcquiringAccurateLocation];
    }
  }
}

#pragma mark CLLocationManagerDelegate methods.

- (void) locationManager:(CLLocationManager *)managerParam
     didUpdateToLocation:(CLLocation *)newLocation
            fromLocation:(CLLocation *)oldLocation {
  if (isPaused) {
    return;
  }
  
  failedUpdateAttempts = 0;
  if (locationState == LocationStateDenied) {
    NSLog(@"Got new location when access denied");
    return;
  }
  if (locationState == LocationStatePrompted) {
    // Location access was granted, and acquisition succeeded.
    [self setLocationState:LocationStateAcquiringBest];
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(accessGranted)]) {
        [listener accessGranted];
      }
    }
  }

  if (locationState == LocationStateWaitingSignificantChange) {
    NSTimeInterval secondsSinceExactLocation = [newLocation.timestamp
                                                timeIntervalSinceDate:exactLocationTimestamp];
    if (secondsSinceExactLocation < kMinSecondsSignificantChange) {
      for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
        if ([listener respondsToSelector:@selector(staleSignificantChangeDetected:)]) {
          [listener staleSignificantChangeDetected:newLocation];
        }
      }
      return;
    }
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(currentSignificantChangeDetected:)]) {
        [listener currentSignificantChangeDetected:newLocation];
      }
    }
    
    // Found a current significant change comparing against the exact location timestamp.
    [exactLocationTimestamp release];
    exactLocationTimestamp = nil;
    // Exact location is found comparing to current significant change timestamp.
    significantChangeTimestamp = [newLocation.timestamp retain];

    [manager stopMonitoringSignificantLocationChanges];
    
    // Get a more accurate location.
    [self startAcquiringAccurateLocation];
    [self setLocationState:LocationStateAcquiringBest];
  } else if (locationState == LocationStateAcquiringBest) {
    if (significantChangeTimestamp == nil) {
      // Acquiring the first location; make it recent.
      NSTimeInterval locationAgeInSeconds = [[NSDate date]
                                             timeIntervalSinceDate:newLocation.timestamp];
      if (locationAgeInSeconds < kMaxSecondsRecentUpdate) {
        for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
          if ([listener respondsToSelector:@selector(currentFirstLocationFound:)]) {
            [listener currentFirstLocationFound:newLocation];
          }
        }

        [self updateToLocation:newLocation];
      } else {
        for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
          if ([listener respondsToSelector:@selector(staleFirstLocationFound:)]) {
            [listener staleFirstLocationFound:newLocation];
          }
        }
      }
    } else {
      // Wait for a location acquired after the significant location change.
      if ([newLocation.timestamp
           compare:significantChangeTimestamp] == NSOrderedDescending) {
        for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
          if ([listener respondsToSelector:@selector(currentNextLocationFound:)]) {
            [listener currentNextLocationFound:newLocation];
          }
        }

        [self updateToLocation:newLocation];
      } else {
        for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
          if ([listener respondsToSelector:@selector(staleNextLocationFound:)]) {
            [listener staleNextLocationFound:newLocation];
          }
        }
      }
    }
  }
}

- (void) locationManager:(CLLocationManager *)managerParam
        didFailWithError:(NSError *)error {
  if (isPaused) {
    return;
  }
  if (locationState == LocationStateDenied) {
    NSLog(@"Failed to acquire location when access denied");
    return;
  }
  
  if (error.code == kCLErrorDenied) {
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(accessDenied)]) {
        [listener accessDenied];
      }
    }

    // The user denied location access, so stop attempting to acquire it.
    [self setLocationState:LocationStateDenied];
    [manager stopUpdatingLocation];
    
    UIAlertView *alert =
        [[UIAlertView alloc]
         initWithTitle:@"Location Access Recommended"
         message:@"Your location is needed to show nearby plans and provide a location for your own plans. "
                 @"Visit the Settings tab to enable."
         delegate:nil
         cancelButtonTitle:@"Okay"
         otherButtonTitles:nil];
    [alert show];
    [alert release];
    return;
  }
  
  if (locationState == LocationStatePrompted) {
    // Location access was granted, but acquisition failed.
    [self setLocationState:LocationStateAcquiringBest];
    
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
      if ([listener respondsToSelector:@selector(accessGranted)]) {
        [listener accessGranted];
      }
    }
  }

  // Failing to get a significant change in location is ignored. 
  if (locationState == LocationStateAcquiringBest) {
    for (NSObject<LocationManagerListener> *listener in locationManagerListeners) {
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

- (BOOL) isPaused {
  return isPaused;
}

- (void) pause {
  if ((locationState == LocationStateUnknown) || 
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
  if (!isPaused && (locationState == LocationStateWaitingSignificantChange)) {
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
