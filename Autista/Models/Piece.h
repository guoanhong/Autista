//
//  Piece.h
//  Autista
//
//  Created by Shashwat Parhi on 1/27/13.
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class PuzzleObject;

@interface Piece : NSManagedObject

@property (nonatomic, retain) NSNumber * finalPositionX;
@property (nonatomic, retain) NSNumber * finalPositionY;
@property (nonatomic, retain) NSString * label;
@property (nonatomic, retain) NSString * imageName;
@property (nonatomic, retain) NSData * pieceImage;
@property (nonatomic, retain) PuzzleObject *puzzleObject;

@end
