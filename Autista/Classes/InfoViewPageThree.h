//
//  InfoViewPageThree.h
//  Autista
//  Autista is a tablet application to help autistic children with speech
//  difficulties develop manual motor and oral motor skills.
//
//  Copyright (C) 2014 The Groden Center, Inc.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//

#import <UIKit/UIKit.h>
#import "GlobalPreferences.h"

@interface InfoViewPageThree : UIView

/**-----------------------------------------------------------------------------
 * @name Properties
 * -----------------------------------------------------------------------------
 */

@property (nonatomic, retain) IBOutlet UILabel *titleLabel;
@property (nonatomic, retain) IBOutlet UITextView *textView;
@property (nonatomic, retain) IBOutlet UISwitch *activitylogSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *audiologSwitch;
@property GlobalPreferences *prefs;
@property (nonatomic, retain) IBOutlet UIImageView *imageView;

/**-----------------------------------------------------------------------------
 * @name Methods
 * -----------------------------------------------------------------------------
 */
/**
 *
 */
- (void)layoutSubviews;
- (void)setImageView:(UIImageView *)imageView;
- (IBAction)flip:(id)sender;

@end
