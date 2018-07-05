#import "common.h"

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.spookybois.spotifyalarm.plist"
#define SAEnabled GetPrefBool(@"enabled")
#define SAShuffle GetPrefBool(@"shuffle")
#define SARandom GetPrefBool(@"random")
#define SAAlarm GetPrefBool(@"alarmonly")
#define SATitle @"Spotify Alarm"
#define SADefaultTitle @"Alarm"
#define DEBUG true

NSString *alarmID = NULL;


/*  method to get plist variable state  */
inline bool GetPrefBool(NSString *key) {
    return [[[NSDictionary dictionaryWithContentsOfFile:PLIST_PATH] valueForKey:key] boolValue];
}

/*  method to set plist variable state  */
inline void SetPrefBool(NSString *key, bool state) {
    // get dictionary based on current settings
    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:PLIST_PATH];

    // change appropriate key
    [preferences setObject:[NSNumber numberWithBool:state] forKey:key];

    // write back out to plist
    [preferences writeToFile:PLIST_PATH atomically:YES];
}


@implementation MySpotifyView

/*  implement the adding / removing of an alarm to Spotify Alarm database   */
-(void)toggleSpotify:(id)sender {

    // boolean here is coupled with boolean state of switch
    SetPrefBool(alarmID, [sender isOn]);

}

/* add Spotify Alarm toggle in alarm edit view */
-(void)addToView:(NSString *)name :(BOOL)switchState
{
    // initialize toggle switch label
    toggleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15,0,200,50)];
    [toggleLabel setTextColor:[UIColor whiteColor]];
    [toggleLabel setBackgroundColor:[UIColor clearColor]];
    toggleLabel.text = name;

    // initialize switch layout
    toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.frame.size.width,10,150,50)];
    toggleSwitch.frame = CGRectMake((self.frame.size.width + 250),10,150,50);

    // add target function and tint color
    [toggleSwitch addTarget:self action:@selector(toggleSpotify:) forControlEvents:UIControlEventValueChanged];
    toggleSwitch.onTintColor = [UIColor colorWithRed:46.0/255.0 green:160.0/255.0 blue:166.0/255.0 alpha:1.0];

    // set switch state
    [toggleSwitch setOn:switchState];

    // add to subviews to update interface
    [self addSubview: toggleLabel];
    [self addSubview: toggleSwitch];
    tableView.tableHeaderView = self;
}

@end


/*  hook into the alarm editing view to inject SpotifyAlarm enable slider   */
%hook EditAlarmViewController

-(void)loadView
{
    %orig;

    // grab the alarm we're currently editing...
    Alarm *spotAlarm = MSHookIvar<Alarm *>(self, "_alarm");

    // ...and save the unique alarmID
    alarmID = [spotAlarm alarmID];

    // now add a cool SpotifyAlarm selection button
    tableView = [self.view.subviews objectAtIndex:0];

    MySpotifyView *spotView = [[MySpotifyView alloc] initWithFrame:CGRectMake(0,0,tableView.frame.size.width,60)];

    // check to see if the current alarm is Spotify enabled, dictating
    // position of the spotify slider switch on render
    if (GetPrefBool(alarmID)) {
        [spotView addToView:@"Spotify Shuffle:":true];
        // [spotAlarm setTitle:SATitle];
        // i don't think this situation could ever occur, but just in case
    } else {
        [spotView addToView:@"Spotify Shuffle:":false];
        if ([[spotAlarm title] isEqualToString:SATitle]) {
            [spotAlarm setTitle:SADefaultTitle];
        }
    }

    NSLog(@"[SpotifyAlarm]:[Variable Check] enabled: %d shuffle: %d random: %d  alarmonly: %d", (int)SAEnabled, (int)SAShuffle, (int)SARandom, (int)SAAlarm);
    %log((NSString *)@"[SpotifyAlarm]:[Alarm ID] current alarm ID: ", [spotAlarm alarmID]);

}

- (void)_cancelButtonClicked:(id)arg1 {
    %orig(arg1);

    // grab the alarm we're currently editing...
    Alarm *spotAlarm = MSHookIvar<Alarm *>(self, "_alarm");

    // TODO: somehow bug exists here: when editing an existing alarm with
    // spotify shuffle enabled, disabling spotify shuffle then hitting cancel
    // disables spotify shuffle but doesn't reset the title to SADefault..
    // curious.  Editing again resets it tho now that i added a check for this
    // on line 98 in loadView()
    //
    // one solution would be to only change in setTitle() and then also check
    // for appropriate titles in _cancelbuttonclicekd and _donebuttonclicked
    //
    // also double check all %origs are passed when necessary

    // if the alarm is disabled in the database...
    if (!(GetPrefBool([spotAlarm alarmID]))) {
        // make sure the title is not SATitle
        if ([[spotAlarm title] isEqualToString:SATitle]) {
            [spotAlarm setTitle:SADefaultTitle];
        }
    }

}

%end


/*  hook into the fullscreen lockscreen notification handler to intercept
 *  alarms  */
%hook SBDashBoardFullscreenNotificationViewController

 -(void)loadView
{

    /* check if the alarm is a SpotifyAlarm based on message in notification */
    NCNotificationRequest *nreq = MSHookIvar<NCNotificationRequest *>(self, "_request");
    NCNotificationContent *ncont = MSHookIvar<NCNotificationContent *>(nreq, "_content");

    NSString* message = [ncont message];
    BOOL equal = [message isEqualToString:SATitle];

    if (DEBUG) {
        /*  for some reason one of these logging methods isn't wokring..    */
        NSLog(@"Debug equal: %d", (int)[message isEqualToString:SATitle]);
        %log((NSString *)@"Debug equal %d", (int)equal);

        NSString* header = [ncont header];
        NSString* title = [ncont title];
        NSString* subtitle = [ncont subtitle];
        NSString* topic = [ncont topic];
        NSString* description = [ncont description];
        NSString* debugDescription = [ncont debugDescription];
        NSLog((NSString *)@"First %@", (NSString *)@"Debug");
        NSLog((NSString *)@"Debug header: %@", (NSString *)header);
        NSLog((NSString *)@"Debug title: %@", (NSString *)title);
        NSLog((NSString *)@"Debug sub: %@", (NSString *)subtitle);
        NSLog((NSString *)@"Debug msg: %@", (NSString *)message);
        NSLog((NSString *)@"Debug topic: %@", (NSString *)topic);
        NSLog((NSString *)@"Debug desc: %@", (NSString *)description);
        NSLog((NSString *)@"Debug debdesc: %@", (NSString *)debugDescription);
        NSLog((NSString *)@"Second %@", (NSString *)@"Debug");
    }

    if (equal) {
        NSLog(@"Silencing...");
        [self _handleSecondaryAction];      // ayee! it worked!!

        /*  launch spotify in the background    */


        /*  grab now playing application after spotify has loaded by hooking into
         *  spotify, and then start playing music!  work on playlist later..  */


    }

    %orig;

}

%end


/*  catch the alarm being modified to mark Spotify enabled alarms w/ title  */
%hook Alarm

-(void)setTitle:(NSString *)arg1
{
    /*  check if this alarm is in the spotify database  */
    NSString *myAlarmID = MSHookIvar<NSString *>(self, "_alarmID");

    // if valid alarmID
    if (myAlarmID) {
        // and if that alarmID is registered as a SpotifyAlarm
        if (GetPrefBool(myAlarmID)) {
            NSLog(@"Debug alarm enabled in database");
            // set the Spotify Alarm title as indicator
            %orig(SATitle);
        } else {
            // otherwise, don't
            NSLog(@"Debug alarm not enabled in database");
            if ([[self title] isEqualToString:SATitle]) {
                // but make sure to remove the title if disabled
                NSLog(@"Debug has enabled title, resetting...");
                %orig(SADefaultTitle);
            } else {
                NSLog(@"Debug title is fine");
                %log((NSString *)arg1);
                %orig(arg1);
            }
        }
    } else {
        %orig(arg1);
    }
}

%end
