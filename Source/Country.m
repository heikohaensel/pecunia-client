//
//  Country.m
//  Pecunia
//
//  Created by Frank Emminghaus on 15.11.08.
//  Copyright 2008 Frank Emminghaus. All rights reserved.
//

#import "Country.h"


@implementation Country

@synthesize name;
@synthesize currency;
@synthesize code;

-(void)dealloc
{
	name = nil;
	currency = nil;
	code = nil;

}

@end
