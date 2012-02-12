#import <UIKit/UIKit.h>

#import "LocationManagerListener.h"

@class LocationManager;

@interface ViewController : UITableViewController<LocationManagerListener> {
  LocationManager *locationManager;
  NSMutableArray *events;
}

@end
