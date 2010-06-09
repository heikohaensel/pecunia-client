//
//  BankStatementController.m
//  Pecunia
//
//  Created by Frank Emminghaus on 10.03.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BankStatementController.h"
#import "BankAccount.h"
#import "BankStatement.h"
#import "MOAssistant.h"
#import "HBCIClient.h"
#import "ShortDate.h"

@implementation BankStatementController


- (void)dealloc
{
	[accountStatements release], accountStatements = nil;

	[super dealloc];
}

@synthesize accountStatements;


-(id)initWithAccount: (BankAccount*)acc statement:(BankStatement*)stat
{
	self = [super initWithWindowNibName:@"BankStatementController"];
	memContext = [[MOAssistant assistant ] memContext];
	context = [[MOAssistant assistant ] context];
	account = acc;
	oldStatement = stat;
	actionResult = 0;
	
	[self arrangeStatements ];
	
	currentStatement = [NSEntityDescription insertNewObjectForEntityForName:@"BankStatement" inManagedObjectContext:memContext ];

	if (stat) {
		// now copy statement
		NSEntityDescription *entity = [stat entity];
		NSArray *attributeKeys = [[entity attributesByName] allKeys];
		NSDictionary *attributeValues = [stat dictionaryWithValuesForKeys:attributeKeys];
		[currentStatement setValuesForKeysWithDictionary:attributeValues];
	} else {
		currentStatement.currency = account.currency;
		currentStatement.localAccount = account.accountNumber;
		currentStatement.localBankCode = account.bankCode;
		currentStatement.isManual = [NSNumber numberWithBool: YES ];
		if ([accountStatements count] > 0) {
			currentStatement.date = [[accountStatements objectAtIndex:0 ] date ];
			currentStatement.valutaDate = [[accountStatements objectAtIndex:0 ] valutaDate ];
		} else {
			currentStatement.date = [NSDate date ];
			currentStatement.valutaDate = [NSDate date ];
		}
	}
	return self;
}

-(void)arrangeStatements
{
	NSSortDescriptor	*sd = [[[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO] autorelease];
	NSArray				*sds = [NSArray arrayWithObject:sd];

	NSMutableSet *statements = [account mutableSetValueForKey:@"statements" ];
	self.accountStatements = [[statements allObjects ] sortedArrayUsingDescriptors:sds ];
	
	if([self.accountStatements count ] >0) lastStatement = [self.accountStatements objectAtIndex:0 ]; else lastStatement = nil;
	
}

-(void)awakeFromNib
{
	[statementController setContent:currentStatement ];
	[dateField setEnabled:(oldStatement == nil) ];
}

-(void)saveStatement
{
	NSEntityDescription *entity = [currentStatement entity];
	NSArray *attributeKeys = [[entity attributesByName] allKeys];
	NSDictionary *attributeValues = [currentStatement dictionaryWithValuesForKeys:attributeKeys];
	BankStatement *stat;
	
	if (oldStatement) {
		[oldStatement setValuesForKeysWithDictionary:attributeValues ];
	} else {
		BankStatement *newStatement = [NSEntityDescription insertNewObjectForEntityForName:@"BankStatement" inManagedObjectContext:context ];
		[newStatement setValuesForKeysWithDictionary:attributeValues ];
		
		//calculate date
		BOOL found = NO;
		for(stat in accountStatements) {
			// newStatement.date >= stat.date
			if ([[ShortDate dateWithDate:newStatement.date ] compare: [ShortDate dateWithDate: stat.date ] ] != NSOrderedAscending) {
				// newStatement.date == stat.date
				if ([[ShortDate dateWithDate:newStatement.date ] compare: [ShortDate dateWithDate: stat.date ] ] == NSOrderedSame) {
					newStatement.date = [[NSDate alloc ] initWithTimeInterval:100 sinceDate:stat.date ];
				} else {
					newStatement.date = [[ShortDate dateWithDate:newStatement.date ] lowDate ];
				}
				found = YES;
				break;
			}
		}
		
		// adjust balance of later statements
		for(stat in accountStatements) {
			// stat.date > newStatement.date
			if ([stat.date compare: newStatement.date ] == NSOrderedDescending) {
				stat.saldo = [stat.saldo decimalNumberByAdding: newStatement.value ];
			} else break;
		}		
		
		if (found == NO) {
			newStatement.date = [[ShortDate dateWithDate:newStatement.date ] lowDate ];
		}
		
		// add to account
		[newStatement addToAccount: account ];

		[self arrangeStatements ];
		
		if (lastStatement) {
			account.balance = lastStatement.saldo;
			[[Category bankRoot ] rollup ];
		}
	}
}

-(void)windowWillClose:(NSNotification *)aNotification
{
	
	[NSApp stopModalWithCode: actionResult ];
	[memContext reset ];
}


-(IBAction)cancel: (id)sender
{
	actionResult = 0;
	[self close ];
}

-(IBAction)next: (id)sender 
{
	[statementController commitEditing ];
	if ([self check ] == NO) return;
	[self saveStatement ];
	currentStatement = [NSEntityDescription insertNewObjectForEntityForName:@"BankStatement" inManagedObjectContext:memContext ];
	currentStatement.currency = account.currency;
	currentStatement.localAccount = account.accountNumber;
	currentStatement.localBankCode = account.bankCode;
	currentStatement.isManual = [NSNumber numberWithBool: YES ];
	currentStatement.date = [dateField dateValue ];
	currentStatement.valutaDate = [valutaField dateValue ];
	[statementController setContent:currentStatement ];
}

-(IBAction)done: (id)sender
{
	[statementController commitEditing ];
	if ([self check ] == NO) return;
	[self saveStatement ];
	actionResult = 1;
	[self close ];
}

-(void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	NSControl	*te = [aNotification object ];
	
	if([te tag ] == 100) {
		NSString *name = [[HBCIClient hbciClient  ] bankNameForCode: [te stringValue ] ];
		if(name) [self setValue: name forKey: @"bankName" ];
	}
	if([te tag ] == 200) {
		// amount field
		if (lastStatement == nil || [[ShortDate dateWithDate:currentStatement.date ] compare: [ShortDate dateWithDate:lastStatement.date ] ] != NSOrderedAscending) {
			if(currentStatement.value) currentStatement.saldo = [lastStatement.saldo decimalNumberByAdding:currentStatement.value ]; 
		} else {
			// find first statement that is later than current one.
			BankStatement *foundStatement = nil;
			for(BankStatement *stat in accountStatements) {
				if ([[ShortDate dateWithDate:currentStatement.date ] compare: [ShortDate dateWithDate:stat.date ] ] == NSOrderedAscending) {
					foundStatement = stat;
				} else break;
			}
			if (foundStatement && currentStatement.value != nil) {
				currentStatement.saldo = [[foundStatement.saldo decimalNumberBySubtracting: foundStatement.value ] decimalNumberByAdding:currentStatement.value ];
			}
		}
	}
}

-(IBAction)dateChanged:(id)sender
{
	// date field - enable saldo if date is >= last date
	NSDate *date = [(NSDatePicker*)sender dateValue ];
	if (lastDate == nil && [[ShortDate dateWithDate:date ] compare: [ShortDate dateWithDate:lastStatement.date ] ] != NSOrderedAscending) {
		if(currentStatement.value) currentStatement.saldo = [lastStatement.saldo decimalNumberByAdding:currentStatement.value ]; 
	} else {
		// find first statement that is later than current one.
		BankStatement *foundStatement = nil;
		for(BankStatement *stat in accountStatements) {
			if ([[ShortDate dateWithDate:date ] compare: [ShortDate dateWithDate: stat.date ] ] == NSOrderedAscending) {
				foundStatement = stat;
			} else break;
		}
		if (foundStatement && currentStatement.value != nil) {
			currentStatement.saldo = [[foundStatement.saldo decimalNumberBySubtracting: foundStatement.value ] decimalNumberByAdding:currentStatement.value ];
		}
	}
}

-(BOOL)check
{
	BOOL			res;
	NSNumber		*value;
	PecuniaError	*error = nil;
/*	
	if([currentStatement valueForKey: @"remoteName" ] == nil) {
		NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"), 
						NSLocalizedString(@"AP8", @"Please enter a receiver"),
						NSLocalizedString(@"ok", @"Ok"), nil, nil);
		return NO;
	}
*/	
	if( (value = [currentStatement valueForKey: @"value" ]) == nil ) {
		NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"), 
						NSLocalizedString(@"AP11", @"Please enter a value"),
						NSLocalizedString(@"ok", @"Ok"), nil, nil);
		return NO;
	}
/*	
	if([value doubleValue ] <= 0) {
		NSRunAlertPanel(NSLocalizedString(@"AP1", @"Missing data"), 
						NSLocalizedString(@"AP12", @"Please enter a value greater 0"),
						NSLocalizedString(@"ok", @"Ok"), nil, nil);
		return NO;
	}
*/	
	if ([currentStatement valueForKey: @"remoteAccount" ] && [currentStatement valueForKey: @"remoteBankCode" ]) {
		res = [[HBCIClient hbciClient ] checkAccount: [currentStatement valueForKey: @"remoteAccount" ] 
											bankCode:[currentStatement valueForKey: @"remoteBankCode" ] 
											   error: &error ];
		
		if(res == NO) {
			NSRunAlertPanel(NSLocalizedString(@"wrong_input", @"Wrong input"), 
							NSLocalizedString(@"AP13", @"Account number is not valid"),
							NSLocalizedString(@"retry", @"Retry"), nil, nil);
			return NO;
		}
	}

	return YES;
}



@end
