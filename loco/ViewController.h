#import <UIKit/UIKit.h>

#import "LocationManagerListener.h"

@class LocationManager;
@class MKMapView;

@interface ViewController : UITableViewController<LocationManagerListener> {
  LocationManager *locationManager;
  NSMutableArray *events;
  
  UIView *tableViewHeader;
  MKMapView *mapView;
}

@end
