//
//  IBeaconReceiver.m
//  ble_plugin
//
//  Created by Michael Hoffstaedter on 10.02.14.
//  Copyright (c) 2014 Michael Hoffstaedter. All rights reserved.
//

#import "IBeaconReceiver.h"

@implementation IBeaconReceiver

- (void) InitWithUUID:(NSUUID *)uuid andRegionIdentifier:(NSString *)identifier andLog:(BOOL)log {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    [self startScanWithUUID:uuid andRegionIdentifier:identifier];
    if (log)
        NSLog(@"Started location manager");
}

- (void) startScanWithUUID:(NSUUID *)uuid andRegionIdentifier:(NSString *)identifier {
    CLBeaconRegion *tempRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:identifier];
    if (self.beaconRegions == nil)
        self.beaconRegions = [[NSMutableArray alloc] initWithObjects:tempRegion, nil];
    else
        [self.beaconRegions addObject:tempRegion];
    [self.locationManager startMonitoringForRegion:tempRegion];
}


- (void) stopScan {
    for (CLBeaconRegion *reg in self.beaconRegions)
        [self.locationManager stopMonitoringForRegion:reg];
    [self.beaconRegions removeAllObjects];
    
}
#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (![CLLocationManager locationServicesEnabled]) {
        
            NSLog(@"Couldn't turn on Receiver: Location services are not enabled.");
            
            return;
      
    }
    
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized) {
       
            NSLog(@"Couldn't turn on Receiver: Location services not authorised.");
        
            return;
        
    }
    
}

- (void) locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    [self.locationManager requestStateForRegion:region];
}

- (void) locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    NSString *stateString = nil;
    switch (state) {
        case CLRegionStateInside:
            stateString = @"inside";
            break;
        case CLRegionStateOutside:
            stateString = @"outside";
            break;
        case CLRegionStateUnknown:
            stateString = @"unknown";
            break;
    }
    if (log) {
        NSLog(@"State changed to %@ for region %@.", stateString, region);
    }
    
}

- (void) locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    if (log)
        NSLog(@"Entered region: %@", region);
    
    [self sendLocalNotificationForBeaconRegion:(CLBeaconRegion *)region];
    
    NSPredicate *regionPredicate = [NSPredicate predicateWithFormat:@"identifier = %@",region.identifier];
    NSArray *tempArray = [[self.beaconRegions copy] filteredArrayUsingPredicate:regionPredicate];
    for (CLBeaconRegion *cl in tempArray)
        [self.locationManager startRangingBeaconsInRegion:cl];
}

- (void) locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    if (log)
        NSLog(@"Exited region: %@", region);
    
    NSPredicate *regionPredicate = [NSPredicate predicateWithFormat:@"identifier = %@",region.identifier];
    NSArray *tempArray = [[self.beaconRegions copy] filteredArrayUsingPredicate:regionPredicate];
    for (CLBeaconRegion *cl in tempArray)
        [self.locationManager stopRangingBeaconsInRegion:cl];
}

- (void) locationManager:(CLLocationManager *)manager
         didRangeBeacons:(NSArray *)beacons
                inRegion:(CLBeaconRegion *)region
{
                    
    NSArray *filteredBeacons = [self filteredBeacons:beacons];
    if (log)
    {
        if (filteredBeacons.count == 0) {
            NSLog(@"No beacons found nearby.");
        } else {
            NSLog(@"Found %lu %@.", (unsigned long)[filteredBeacons count],
                [filteredBeacons count] > 1 ? @"beacons" : @"beacon");
        }
    }
    NSMutableString *data = [NSMutableString stringWithString:@""];
    for (CLBeacon *beacon in filteredBeacons) {
        int proximity = 0;
        if (beacon.proximity == CLProximityFar) {
            proximity = 1;
        } else if (beacon.proximity == CLProximityNear) {
            proximity = 2;
        } else if (beacon.proximity == CLProximityImmediate) {
            proximity = 3;
        }
        [data appendFormat:@"%@,%d,%d,%d,%ld,%f;",beacon.proximityUUID.UUIDString,beacon.major.intValue,beacon.minor.intValue,proximity,(long)beacon.rssi,beacon.accuracy];
        
    }
    if (log)
        NSLog(@"IOS: Sending %@",data);
    UnitySendMessage("IBeaconReceiver","RangeBeacons",[[NSString stringWithString:data] cStringUsingEncoding:NSUTF8StringEncoding]);
}

#pragma avilable checks by jlk

- (BOOL) checkDeviceAvilable
{
    NSLog(@"Checking Ranging require ...");
    
    if (![CLLocationManager isRangingAvailable]) {
        NSLog(@"Couldn't turn on ranging: Ranging is not available.");
        return NO;
    }
    
    if (self.locationManager.rangedRegions.count > 0) {
        NSLog(@"Didn't turn on ranging: Ranging already on.");
        return NO;
    }
    NSLog(@"Checking Monitor require ...");
    
    if (![CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
        NSLog(@"Couldn't turn on region monitoring: Region monitoring is not available for CLBeaconRegion class.");
        
        return NO;
    }
    return YES;
}


- (NSArray *)filteredBeacons:(NSArray *)beacons
{
    // Filters duplicate beacons out; this may happen temporarily if the originating device changes its Bluetooth id
    NSMutableArray *mutableBeacons = [beacons mutableCopy];
    
    NSMutableSet *lookup = [[NSMutableSet alloc] init];
    for (int index = 0; index < [beacons count]; index++) {
        CLBeacon *curr = [beacons objectAtIndex:index];
        NSString *identifier = [NSString stringWithFormat:@"%@/%@", curr.major, curr.minor];
        
        // this is very fast constant time lookup in a hash table
        if ([lookup containsObject:identifier]) {
            [mutableBeacons removeObjectAtIndex:index];
        } else {
            [lookup addObject:identifier];
        }
    }
    
    return [mutableBeacons copy];
}
    
#pragma mark - Local notifications
    - (void)sendLocalNotificationForBeaconRegion:(CLBeaconRegion *)region
    {
        UILocalNotification *notification = [UILocalNotification new];
        
        // Notification details
        notification.alertBody = [NSString stringWithFormat:@"Entered beacon region for UUID: %@",
                                  region.proximityUUID.UUIDString];   // Major and minor are not available at the monitoring stage
        notification.alertAction = NSLocalizedString(@"View Details", nil);
        notification.soundName = UILocalNotificationDefaultSoundName;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    }


@end

IBeaconReceiver *currentReceiver;

void InitReceiver(char * uuid, char * regionIdentifier, bool simulateRegionEnter, bool shouldLog) {
    
    
    
    if (currentReceiver == nil) {
        currentReceiver = [IBeaconReceiver alloc];
        BOOL device_avilable = [currentReceiver checkDeviceAvilable];
        if (!device_avilable) {
            currentReceiver = nil;
            return;
        }
        [currentReceiver InitWithUUID:[[NSUUID alloc] initWithUUIDString:[NSString stringWithUTF8String:uuid]] andRegionIdentifier:[NSString stringWithUTF8String:regionIdentifier] andLog:shouldLog];
    } else {
        [currentReceiver startScanWithUUID:[[NSUUID alloc]initWithUUIDString:[NSString stringWithUTF8String:uuid]] andRegionIdentifier:[NSString stringWithUTF8String:regionIdentifier]];
   }
}

void StopIOSScan() {
    [currentReceiver stopScan];
}