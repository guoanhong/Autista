//
//  EventLogger.m
//  Autista
//
//  Created by Shashwat Parhi on 2/2/13.
//  Copyright (c) 2013 Shashwat Parhi
//
//  This file is part of Autista.
//  
//  Autista is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//  
//  Autista is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  To view the GNU General Public License, visit <http://www.gnu.org/licenses/>.
//

#import "EventLogger.h"
#import "AppDelegate.h"
#import "GlobalPreferences.h"
#import "PuzzleObject.h"
#import "User.h"
#import "Log.h"
#import "Event.h"
#import "Attempt.h"
#import "SBJson.h"
#import "NSObject+SBJson.h"

@implementation EventLogger

+ (id)sharedLogger
{
	static dispatch_once_t pred = 0;
	__strong static id _sharedObject = nil;
	dispatch_once(&pred, ^{
		_sharedObject = [[self alloc] init];					// call our init method
	});
	return _sharedObject;
}

+ (NSInteger)numberOfLogs
{
	AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
	NSManagedObjectContext *context = [appDelegate managedObjectContext];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"Log" inManagedObjectContext:context]];
	
	NSArray *logs = [context executeFetchRequest:fetchRequest error:nil];
	
	return [logs count];
}

- (id)init {
	_appDelegate = [[UIApplication sharedApplication] delegate];
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	if ([userDefaults objectForKey:@"sendData_preference"] != nil)
		_canSendAnonymousData = [[userDefaults objectForKey:@"sendData_preference"] boolValue];

	_currentUser = _appDelegate.currentUser;
	_appEnteredForegroundOn = [NSDate date];
	_trackingMode = -1;											// initialized to an invalid state
	_modeRepeatCount = 0;
	
	[self loadEvents];
	
	[self performSelectorInBackground:@selector(archiveMonthOldLogData) withObject:nil];
	
	return self;
}

- (void)loadEvents
{
	NSManagedObjectContext *context = [_appDelegate managedObjectContext];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"Event" inManagedObjectContext:context]];
	
	NSArray *sortDescriptors = [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"eventCode" ascending:YES]];
	[fetchRequest setSortDescriptors:sortDescriptors];
	
	_events = [context executeFetchRequest:fetchRequest error:nil];
}

- (void)archiveMonthOldLogData
{
	NSManagedObjectContext *context = [_appDelegate managedObjectContext];
	
	NSDate *dateMonthAgo = [NSDate date];
	NSTimeInterval monthAgoTimeStamp = [dateMonthAgo timeIntervalSince1970];
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"absoluteTime < %@", @(monthAgoTimeStamp)];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"Log" inManagedObjectContext:context]];
	[fetchRequest setPredicate:predicate];

}

- (void)logEvent:(LogEventCode)eventCode eventInfo:(NSDictionary *)eventInfo
{
	if (eventCode == LogEventCodePieceDragMoved) {
		NSNumber *absoluteTime = [NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]];
		NSNumber *timeSinceLaunch = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceDate:_appEnteredForegroundOn]];
		
		NSDictionary *dragDict = @{@"absoluteTime":absoluteTime, @"timeSinceLaunch":timeSinceLaunch, @"eventInfo":eventInfo};
		[_dragMoves addObject:dragDict];
	}
	else {
		GlobalPreferences *prefs = [GlobalPreferences sharedGlobalPreferences];
		NSInteger index = [self getEventIndexWithCode:eventCode];
		
		Log *newLog = [_appDelegate newManagedObjectWithEntity:@"Log"];
		newLog.user = _appDelegate.currentUser;

		if (eventCode == LogEventCodePieceDragBegan) {
			_dragMoves = [NSMutableArray array];
		}
		else if (eventCode == LogEventCodePieceReleased) {
			Event *dragEvent = [_events objectAtIndex:[self getEventIndexWithCode:LogEventCodePieceDragMoved]];
			
			NSArray *sortDescriptors = [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"timeSinceLaunch" ascending:YES]];
			[_dragMoves sortUsingDescriptors:sortDescriptors];
			
			for (NSDictionary *dragDict in _dragMoves) {
				Log *moveLog = [_appDelegate newManagedObjectWithEntity:@"Log"];
				moveLog.user = _appDelegate.currentUser;

				moveLog.absoluteTime = [dragDict objectForKey:@"absoluteTime"];
				moveLog.timeSinceLaunch = [dragDict objectForKey:@"timeSinceLaunch"];
				moveLog.eventInfo = [[dragDict objectForKey:@"eventInfo"] JSONRepresentation];
				moveLog.event = dragEvent;
			}
		}
		else if (eventCode == LogEventCodeAppLaunched || eventCode == LogEventCodeAdminModeEntered || eventCode == LogEventCodeAdminModeExited)
			newLog.appSettings = [[prefs packagedSettings] JSONRepresentation];
			
		newLog.absoluteTime = [NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]];
		newLog.timeSinceLaunch = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceDate:_appEnteredForegroundOn]];
		newLog.eventInfo = [eventInfo JSONRepresentation];
		newLog.event = [_events objectAtIndex:index];
		
		[_appDelegate saveContext];
	}
}

- (NSInteger)getEventIndexWithCode:(LogEventCode)eventCode
{
	NSInteger index = [_events indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		if ([[obj valueForKey:@"eventCode"] intValue] == eventCode) {
			*stop = YES;
			
			return YES;
		}
		else return NO;
	}];

	return index;
}

- (void)logAttemptForPuzzle:(PuzzleObject *)puzzleObject inMode:(PuzzleMode)mode state:(PuzzleState)state;
{
	Attempt *attempt = [_appDelegate newManagedObjectWithEntity:@"Attempt"];
	attempt.user = _appDelegate.currentUser;
	attempt.puzzleObject = puzzleObject;
	attempt.mode = [NSNumber numberWithInt:mode];
	attempt.score = [NSNumber numberWithInt:state];
	attempt.attemptedOn = [NSDate date];
}

- (NSDictionary *)getScoresFromAttempsForUser:(User *)user
{
	CGFloat dragCount = 0, dragScore = 0;
	CGFloat typeCount = 0, typeScore = 0;
	CGFloat sayCount = 0, sayScore = 0;
	
	for (Attempt *attempt in user.attempts) {
		PuzzleMode mode = [attempt.mode intValue];
		
		switch (mode) {
			case PuzzleModePoint:
				dragCount++;
				dragScore += [attempt.score intValue];
				break;
			
			case PuzzleModeSay:
				sayCount++;
				sayScore += [attempt.score intValue];
				break;
				
			case PuzzleModeType:
				typeCount++;
				typeScore += [attempt.score intValue];
				break;
				
			default:
				break;
		}
	}
	
	NSNumber *dragSuccess = [NSNumber numberWithFloat:dragScore / dragCount * 100.];
	NSNumber *saySuccess = [NSNumber numberWithFloat:sayScore / sayCount * 100.];
	NSNumber *typeSuccess = [NSNumber numberWithFloat:typeScore / typeCount * 100.];
	
	NSInteger numAttempts = [user.attempts count];
	
	NSNumber *dragFrequency = [NSNumber numberWithFloat:dragCount / numAttempts * 100.];
	NSNumber *sayFrequency = [NSNumber numberWithFloat:sayCount / numAttempts * 100.];
	NSNumber *typeFrequency = [NSNumber numberWithFloat:typeCount / numAttempts * 100.];
	
	return @{@"dragSuccess":dragSuccess, @"saySuccess":saySuccess, @"typeSuccess":typeSuccess,
			 @"dragFrequency":dragFrequency, @"sayFrequency":sayFrequency, @"typeFrequency":typeFrequency};
}

- (PuzzleMode)suggestModeForPuzzle:(PuzzleObject *)object
{
	CGFloat dragCount = 0, dragScore = 0, dragSuccess;
	CGFloat typeCount = 0, typeScore = 0, typeSuccess;
	CGFloat sayCount = 0, sayScore = 0, saySuccess;
	
	for (Attempt *attempt in _currentUser.attempts) {
		PuzzleMode mode = [attempt.mode intValue];
		
		switch (mode) {
			case PuzzleModePoint:
				dragCount++;
				dragScore += [attempt.score intValue];
				break;
				
			case PuzzleModeSay:
				sayCount++;
				sayScore += [attempt.score intValue];
				break;
				
			case PuzzleModeType:
				typeCount++;
				typeScore += [attempt.score intValue];
				break;
				
			default:
				break;
		}
	}
	
	sayScore = sayCount * 2;														// for now we award full scores for Speech mode
	dragSuccess = dragCount != 0 ? dragScore / dragCount * 100. : 0;
	saySuccess = sayCount != 0 ? sayScore / sayCount * 100. : 0;
	typeSuccess = typeScore != 0 ? typeScore / typeCount * 100. : 0;
	
	NSInteger numAttempts = [_currentUser.attempts count];
	
	CGFloat dragFrequency = dragCount / numAttempts * 100.;
	CGFloat sayFrequency =  sayCount / numAttempts * 100.;
	CGFloat typeFrequency = typeCount / numAttempts * 100.;
	
	GlobalPreferences *prefs = [GlobalPreferences sharedGlobalPreferences];
	CGFloat dragAdmin = prefs.dragPuzzleFrequency;
	CGFloat sayAdmin  =  prefs.speakPuzzleFrequency;
	CGFloat typeAdmin =  100 - (dragAdmin + sayAdmin);
		
	CGFloat dragVol = (dragSuccess ) * (dragFrequency) * (100 - dragAdmin);
	CGFloat sayVol  =  (saySuccess) * (sayFrequency) * (100 - sayAdmin);
	CGFloat typeVol = (typeSuccess) * (typeFrequency) * (100 - typeAdmin);
	
	CGFloat temp = MIN(dragVol, sayVol);
	CGFloat minVol = MIN(temp, typeVol);
	
	PuzzleMode suggestedMode, nextBestSuggestedMode;
	
	if (minVol == dragVol) {
		suggestedMode = PuzzleModePoint;
		nextBestSuggestedMode = sayVol < typeVol ? PuzzleModeSay : PuzzleModeType;
	}
	else if (minVol == sayVol) {
		suggestedMode = PuzzleModeSay;
		nextBestSuggestedMode = dragVol < typeVol ? PuzzleModePoint : PuzzleModeType;
	}
	else {
		suggestedMode = PuzzleModeType;
		nextBestSuggestedMode = sayVol < dragVol ? PuzzleModeSay : PuzzleModePoint;
	}
	
	if (_trackingMode == suggestedMode && _trackingObject == object) {
		if (_modeRepeatCount < 2)
			_modeRepeatCount++;
		else {
			suggestedMode = nextBestSuggestedMode;
			_trackingMode = suggestedMode;
			_modeRepeatCount = 0;
		}
	}
	else {
		_trackingObject = object;
		_trackingMode = suggestedMode;
		_modeRepeatCount = 0;
	}
	
	//RD
    //return PuzzleModeSay;
    
    return suggestedMode;
}

/*
- (NSDictionary *)suggestPuzzle
{
	AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
	NSManagedObjectContext *context = [appDelegate managedObjectContext];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"PuzzleObject" inManagedObjectContext:context]];
	
//	NSArray *sortDescriptors = [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES]];
//	[fetchRequest setSortDescriptors:sortDescriptors];
	
	NSArray *puzzles = [context executeFetchRequest:fetchRequest error:nil];
	NSInteger index = arc4random() % [puzzles count];
	PuzzleObject *object = [puzzles objectAtIndex:index];
	PuzzleMode mode = arc4random() % (PuzzleModeType + 1);
	
	return @{@"puzzle": object, @"mode": @(mode)};
}
*/

- (NSDictionary *)suggestPuzzle
{
	AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
	NSManagedObjectContext *context = [appDelegate managedObjectContext];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"PuzzleObject" inManagedObjectContext:context]];
	
	NSArray *puzzles = [context executeFetchRequest:fetchRequest error:nil];
	
	for (PuzzleObject *puzzle in puzzles) {
		CGFloat dragCount = 1, dragScore = 1;										// we initialize to 1 so that objects
		CGFloat typeCount = 1, typeScore = 1;										// that have not been attempted yet still yield
		CGFloat sayCount = 1, sayScore = 1;											// right values for volume calculations
		
		for (Attempt *attempt in puzzle.attempts) {
			PuzzleMode mode = [attempt.mode intValue];
			
			switch (mode) {
				case PuzzleModePoint:
					dragCount++;
					dragScore += [attempt.score intValue];
					break;
					
				case PuzzleModeSay:
					sayCount++;
					sayScore += [attempt.score intValue];
					break;
					
				case PuzzleModeType:
					typeCount++;
					typeScore += [attempt.score intValue];
					break;
					
				default:
					break;
			}
		}
		
		GlobalPreferences *prefs = [GlobalPreferences sharedGlobalPreferences];
		CGFloat dragAdmin = prefs.dragPuzzleFrequency;
		CGFloat sayAdmin  =  prefs.speakPuzzleFrequency;
		CGFloat typeAdmin =  100 - (dragAdmin + sayAdmin);
		
		CGFloat dragVol = [puzzle.difficultyDrag floatValue] * dragCount * dragScore * (101 - dragAdmin);
		CGFloat sayVol = [puzzle.difficultySpeak floatValue] * sayCount * sayScore * (101 - sayAdmin);
		CGFloat typeVol = [puzzle.difficultyType floatValue] * typeCount * typeScore * (101 - typeAdmin);
		
		puzzle.dragWeight = @(-1);
		puzzle.speakWeight = @(-1);
		puzzle.typeWeight = @(-1);
		
		if (dragVol < sayVol) {
			if (dragVol < typeVol)
				puzzle.dragWeight = @(dragVol);
			else puzzle.typeWeight = @(typeVol);
		}
		else if (sayVol < typeVol)
			puzzle.speakWeight = @(sayVol);
		else puzzle.typeWeight = @(typeVol);
	}
	
	puzzles = [puzzles sortedArrayUsingComparator:^NSComparisonResult(PuzzleObject *obj1, PuzzleObject *obj2) {
		CGFloat weight1 = [obj1.dragWeight floatValue] * [obj1.speakWeight floatValue] * [obj1.typeWeight floatValue];
		CGFloat weight2 = [obj2.dragWeight floatValue] * [obj2.speakWeight floatValue] * [obj2.typeWeight floatValue];
				
		if (weight1 < weight2)
			return NSOrderedAscending;
		else if (weight1 == weight2)
			return NSOrderedSame;
		else return NSOrderedDescending;
	}];
	
	PuzzleObject *object = [puzzles objectAtIndex:0];
	PuzzleMode mode;
	
	if ([object.dragWeight floatValue] > -1)
		mode = PuzzleModePoint;
	else if ([object.speakWeight floatValue] > -1)
		mode = PuzzleModeSay;
	else mode = PuzzleModeType;
	
	return @{@"puzzle": object, @"mode": @(mode)};
}

- (NSData *)logData
{
	NSManagedObjectContext *context = [_appDelegate managedObjectContext];
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"Log" inManagedObjectContext:context]];
	
	NSArray *logs = [context executeFetchRequest:fetchRequest error:nil];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *logFilename = [documentsDirectory stringByAppendingPathComponent:@"Logs.txt"];
	
	[[NSFileManager defaultManager] createFileAtPath:logFilename contents:nil attributes:nil];
	
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilename];
	NSData *separator = [@"\t" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *newLine = [@"\r\n" dataUsingEncoding:NSUTF8StringEncoding];
	
	NSString *userInfo = [@"User Info\r\n" stringByAppendingFormat:@"Gender: %@\r\nDate of Birth: %@\r\n\r\n", _currentUser.gender, _currentUser.dob];
	NSString *legends = @"Absolute Time\tTime Since Lauch\tApp Settings\tApp State\tEvent Title\tEvent Info\r\n";
	
	[fileHandle writeData:[userInfo dataUsingEncoding:NSUTF8StringEncoding]];
	[fileHandle writeData:[legends dataUsingEncoding:NSUTF8StringEncoding]];
	
	for (Log *log in logs) {
		[fileHandle writeData:[[log.absoluteTime stringValue] dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:separator];
		[fileHandle writeData:[[log.timeSinceLaunch stringValue] dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:separator];
		[fileHandle writeData:[log.appSettings dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:separator];
		[fileHandle writeData:[log.appState dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:separator];
		[fileHandle writeData:[log.event.title dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:separator];
		[fileHandle writeData:[log.eventInfo dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:newLine];
	}

	[fileHandle closeFile];
	
	NSData *logData = [NSData dataWithContentsOfFile:logFilename];
		
	return logData;
}

- (void)deleteLogData
{
	NSManagedObjectContext *context = [_appDelegate managedObjectContext];
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"Log" inManagedObjectContext:context]];
	
	NSArray *logs = [context executeFetchRequest:fetchRequest error:nil];

	for (Log *log in logs) {
		[context deleteObject:log];
	}
	
	[context save:nil];
}

- (void)deleteAllUserData {
	NSManagedObjectContext *context = [_appDelegate managedObjectContext];
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"Log" inManagedObjectContext:context]];
	
	NSArray *logs = [context executeFetchRequest:fetchRequest error:nil];
	
	for (Log *log in logs) {
		[context deleteObject:log];
	}

}

@end
