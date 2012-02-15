#import <UIKit/UIKit.h>

#import "LocationManager.h"
#import "LocationManagerListener.h"

@class LocationManager;
@class MKMapView;

@interface ViewController : UITableViewController<LocationManagerListener> {
  LocationManager *locationManager;
  LocationState lastState;
  NSMutableArray *events;
  
  UIView *tableViewHeader;
  MKMapView *mapView;
}

@end
