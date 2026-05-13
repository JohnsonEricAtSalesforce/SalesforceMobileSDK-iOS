/*
 Copyright (c) 2014-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SObjectDataManager.h"

@import SalesforceSDKCore;
@import SalesforceSDKCommon;
@import SmartStore;
@import MobileSync;

static NSUInteger kMaxQueryPageSize = 1000;
static char* const kSearchFilterQueueName = "com.salesforce.mobileSyncExplorer.searchFilterQueue";
static NSString* const kSyncDownName = @"syncDownContacts";
static NSString* const kSyncUpName = @"syncUpContacts";

@interface SObjectDataManager ()
{
    dispatch_queue_t _searchFilterQueue;
}

@property (nonatomic, strong) SFMobileSyncSyncManager *syncMgr;
@property (nonatomic, strong) SObjectDataSpec *dataSpec;
@property (nonatomic, strong) NSArray *fullDataRowList;

@end

@implementation SObjectDataManager

- (id)initWithDataSpec:(SObjectDataSpec *)dataSpec {
    self = [super init];
    if (self) {
        self.syncMgr = [SFMobileSyncSyncManager sharedInstanceForUserAccount:[SFUserAccountManager shared].currentUserAccount];
        self.dataSpec = dataSpec;
        _searchFilterQueue = dispatch_queue_create(kSearchFilterQueueName, NULL);
        // Setup store and syncs if needed
        [[MobileSyncSDKManager shared] setupUserStoreFromDefaultConfig];
        [[MobileSyncSDKManager shared] setupUserSyncsFromDefaultConfig];
    }
    return self;
}

- (void)dealloc {
}

- (SFSmartStore *)store {
    return [SFSmartStore sharedWithName:@"defaultStore"];
}

- (void)refreshRemoteData:(void (^)(void))completionBlock {
    __weak SObjectDataManager *weakSelf = self;
    // See usersyncs.json
    [self.syncMgr reSyncByName:kSyncDownName onUpdate:^(SFSyncState *sync) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ([sync isDone] || [sync hasFailed]) {
            [strongSelf refreshLocalData:completionBlock];
        }
    } error:nil];
}

- (void)updateRemoteData:(void (^)(SFSyncState *sync))completionBlock {
    // See usersyncs.json
    [self.syncMgr reSyncByName:kSyncUpName onUpdate:^(SFSyncState* sync) {
        if ([sync isDone] || [sync hasFailed]) {
            completionBlock(sync);
        }
    } error:nil];
}

- (void)filterOnSearchTerm:(NSString *)searchTerm completion:(void (^)(void))completionBlock {
    dispatch_async(_searchFilterQueue, ^{
        self.dataRows = self.fullDataRowList;
        if (self.dataRows == nil) {
            // No data yet.
            return;
        }
        
        if ([searchTerm length] > 0) {
            NSMutableArray *matchingDataRows = [NSMutableArray array];
            for (SObjectData *data in [self.fullDataRowList copy]) {
                SObjectDataSpec *dataSpec = [[data class] dataSpec];
                for (SObjectDataFieldSpec *fieldSpec in dataSpec.objectFieldSpecs) {
                    if (fieldSpec.isSearchable) {
                        // TODO: Generalize field value type, abstract search through a search protocol.
                        NSString *fieldValue = [data fieldValueForFieldName:fieldSpec.fieldName];
                        if (fieldValue != nil && [fieldValue rangeOfString:searchTerm options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location != NSNotFound) {
                            [matchingDataRows addObject:data];
                            break;
                        }
                    }
                }
            }
            
            self.dataRows = matchingDataRows;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), completionBlock);
        }
    });
}

#pragma mark - Private methods

- (void)refreshLocalData:(void (^)(void))completionBlock {
    SFQuerySpec *sobjectsQuerySpec = [SFQuerySpec newAllQuerySpec:self.dataSpec.soupName withOrderPath:self.dataSpec.orderByFieldName withOrder:SFSoupQuerySortOrderAscending withPageSize:kMaxQueryPageSize];
    NSError *queryError = nil;
    NSArray *queryResults = [self.store queryUsing:sobjectsQuerySpec startingFromPageIndex:0 error:&queryError];
    [SFSDKMobileSyncLogger d:[self class] message:@"Got local query results.  Populating data rows."];
    if (queryError) {
        [SFSDKMobileSyncLogger e:[self class] message:[NSString stringWithFormat:@"Error retrieving '%@' data from SmartStore: %@", self.dataSpec.objectType, [queryError localizedDescription]]];
        return;
    }

    self.fullDataRowList = [self populateDataRows:queryResults];
    [SFSDKMobileSyncLogger d:[self class] message:[NSString stringWithFormat:@"Finished generating data rows.  Number of rows: %lu.  Refreshing view.", (unsigned long)[self.fullDataRowList count]]];
    self.dataRows = [self.fullDataRowList copy];
    if (completionBlock) completionBlock();
}

- (void)createLocalData:(SObjectData *)newData {
    [newData updateSoupForFieldName:@"__local__" fieldValue:@YES];
    [newData updateSoupForFieldName:@"__locally_created__" fieldValue:@YES];
    [self.store upsertWithEntries:@[ newData.soupDict ] forSoupNamed:[[newData class] dataSpec].soupName];
}

- (void)updateLocalData:(SObjectData *)updatedData {
    [updatedData updateSoupForFieldName:@"__local__" fieldValue:@YES];
    [updatedData updateSoupForFieldName:@"__locally_updated__" fieldValue:@YES];
    [self.store upsertWithEntries:@[ updatedData.soupDict ] forSoupNamed:[[updatedData class] dataSpec].soupName];
}

- (void)deleteLocalData:(SObjectData *)dataToDelete {
    [dataToDelete updateSoupForFieldName:@"__local__" fieldValue:@YES];
    [dataToDelete updateSoupForFieldName:@"__locally_deleted__" fieldValue:@YES];
    [self.store upsertWithEntries:@[ dataToDelete.soupDict ] forSoupNamed:[[dataToDelete class] dataSpec].soupName];
}

- (void)undeleteLocalData:(SObjectData *)dataToUnDelete {
    [dataToUnDelete updateSoupForFieldName:@"__locally_deleted__" fieldValue:@NO];
    NSNumber* locallyCreatedOrUpdated = [NSNumber numberWithBool:[self dataLocallyCreated:dataToUnDelete] || [self dataLocallyUpdated:dataToUnDelete]];
    [dataToUnDelete updateSoupForFieldName:@"__local__" fieldValue:locallyCreatedOrUpdated];
    [self.store upsertWithEntries:@[ dataToUnDelete.soupDict ] forSoupNamed:[[dataToUnDelete class] dataSpec].soupName withExternalIdPath:kSObjectIdField];
}

- (BOOL)dataHasLocalChanges:(SObjectData *)data {
    return [[data fieldValueForFieldName:@"__local__"] boolValue];
}

- (BOOL)dataLocallyCreated:(SObjectData *)data {
    return [[data fieldValueForFieldName:@"__locally_created__"] boolValue];
}

- (BOOL)dataLocallyUpdated:(SObjectData *)data {
    return [[data fieldValueForFieldName:@"__locally_updated__"] boolValue];
}

- (BOOL)dataLocallyDeleted:(SObjectData *)data {
    return [[data fieldValueForFieldName:@"__locally_deleted__"] boolValue];
}

- (NSArray *)populateDataRows:(NSArray *)queryResults {
    NSMutableArray *mutableDataRows = [NSMutableArray arrayWithCapacity:[queryResults count]];
    for (NSDictionary *soup in queryResults) {
        [mutableDataRows addObject:[[self.dataSpec class] createSObjectData:soup]];
    }
    return mutableDataRows;
}

- (void)lastModifiedRecords:(int) limit completion:(void (^)(void))completionBlock {
    SFQuerySpec *sobjectsQuerySpec =  [SFQuerySpec newAllQuerySpec:self.dataSpec.soupName withOrderPath:@"_soupLastModifiedDate" withOrder:SFSoupQuerySortOrderDescending withPageSize:limit];
    NSError *queryError = nil;
    [SFSDKMobileSyncLogger d:[self class] message:@"Got local query results.  Populating data rows."];
    NSArray *queryResults = [self.store queryUsing:sobjectsQuerySpec startingFromPageIndex:0 error:&queryError];
    if (queryError) {
        [SFSDKMobileSyncLogger e:[self class] message:[NSString stringWithFormat:@"Error retrieving '%@' data from SmartStore: %@", self.dataSpec.objectType, [queryError localizedDescription]]];
        return;
    }
    self.fullDataRowList = [self populateDataRows:queryResults];
    [SFSDKMobileSyncLogger d:[self class] message:[NSString stringWithFormat:@"Finished generating data rows.  Number of rows: %lu.  Refreshing view.", (unsigned long)[self.fullDataRowList count]]];
    self.dataRows = [self.fullDataRowList copy];
    completionBlock();
}

@end
