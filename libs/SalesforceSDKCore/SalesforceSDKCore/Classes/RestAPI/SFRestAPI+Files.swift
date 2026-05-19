//
//  SFRestAPI+Files.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2013-present, salesforce.com, inc. All rights reserved.
//
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//    and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written
//    permission of salesforce.com, inc.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import SalesforceSDKCommon

extension RestClient {

    // MARK: - Files

    /// Build a request for owned files list.
    @objc public func requestForOwnedFilesList(_ userId: String?, page: UInt, apiVersion: String?) -> RestRequest {
        let resolvedUserId = userId ?? "me"
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/users/\(resolvedUserId)"
        var params: [String: Any] = [:]
        if page > 0 { params["page"] = NSNumber(value: page) }
        return RestRequest(method: .GET, path: path, queryParams: params.isEmpty ? nil : params)
    }

    /// Build a request for files in user's groups.
    @objc public func requestForFilesInUsersGroups(_ userId: String?, page: UInt, apiVersion: String?) -> RestRequest {
        let resolvedUserId = userId ?? "me"
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/users/\(resolvedUserId)/filter/groups"
        var params: [String: Any] = [:]
        if page > 0 { params["page"] = NSNumber(value: page) }
        return RestRequest(method: .GET, path: path, queryParams: params.isEmpty ? nil : params)
    }

    /// Build a request for files shared with user.
    @objc public func requestForFilesSharedWithUser(_ userId: String?, page: UInt, apiVersion: String?) -> RestRequest {
        let resolvedUserId = userId ?? "me"
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/users/\(resolvedUserId)/filter/sharedwithme"
        var params: [String: Any] = [:]
        if page > 0 { params["page"] = NSNumber(value: page) }
        return RestRequest(method: .GET, path: path, queryParams: params.isEmpty ? nil : params)
    }

    /// Build a request for file details.
    @objc public func requestForFileDetails(_ sfdcId: String, forVersion version: String?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/\(sfdcId)"
        var params: [String: Any] = [:]
        if let version = version { params["versionNumber"] = version }
        return RestRequest(method: .GET, path: path, queryParams: params.isEmpty ? nil : params)
    }

    /// Build a request for batch file details.
    @objc public func requestForBatchFileDetails(_ sfdcIds: [String], apiVersion: String?) -> RestRequest {
        let ids = sfdcIds.joined(separator: ",")
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/batch/\(ids)"
        return RestRequest(method: .GET, path: path, queryParams: nil)
    }

    /// Build a request for file rendition.
    @objc public func requestForFileRendition(_ sfdcId: String, version: String?, renditionType: String, page: UInt, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/\(sfdcId)/rendition"
        var params: [String: Any] = [:]
        params["type"] = renditionType
        if page > 0 { params["page"] = NSNumber(value: page) }
        if let version = version { params["versionNumber"] = version }
        return RestRequest(method: .GET, path: path, queryParams: params)
    }

    /// Build a request for file contents.
    @objc public func requestForFileContents(_ sfdcId: String, version: String?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/\(sfdcId)/content"
        var params: [String: Any] = [:]
        if let version = version { params["versionNumber"] = version }
        return RestRequest(method: .GET, path: path, queryParams: params.isEmpty ? nil : params)
    }

    /// Build a request for file shares.
    @objc public func requestForFileShares(_ sfdcId: String, page: UInt, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/\(sfdcId)/file-shares"
        var params: [String: Any] = [:]
        if page > 0 { params["page"] = NSNumber(value: page) }
        return RestRequest(method: .GET, path: path, queryParams: params.isEmpty ? nil : params)
    }

    /// Build a request to add a file share.
    @objc public func requestForAddFileShare(_ fileId: String, entityId: String, shareType: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/ContentDocumentLink"
        let params: [String: Any] = [
            "ContentDocumentId": fileId,
            "LinkedEntityId": entityId,
            "ShareType": shareType
        ]
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        request.requestBodyAsDictionary = params as NSDictionary
        if let body = SFJsonUtils.jsonDataRepresentation(params, options: []) {
            request.setCustomRequestBodyData(body, contentType: "application/json")
        }
        return request
    }

    /// Build a request to delete a file share.
    @objc public func requestForDeleteFileShare(_ shareId: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/ContentDocumentLink/\(shareId)"
        return RestRequest(method: .DELETE, path: path, queryParams: nil)
    }

    /// Build a request to upload a file.
    @objc public func requestForUploadFile(_ data: Data, name: String, description: String, mimeType: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/files/users/me"
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        let params: [String: Any] = ["title": name, "desc": description]
        request.addPostFileData(data, paramName: "fileData", fileName: name, mimeType: mimeType, params: params)
        return request
    }

    /// Build a request to upload a profile photo.
    @objc public func requestForProfilePhotoUpload(_ data: Data, fileName: String, mimeType: String, userId: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired)/user-profiles/\(userId)/photo"
        let request = RestRequest(method: .POST, path: path, queryParams: nil)
        request.addPostFileData(data, paramName: "fileUpload", fileName: fileName, mimeType: mimeType, params: nil)
        return request
    }

    // MARK: - Private Helper

    private var communitiesUrlPathIfRequired: String {
        guard let communityId = user?.credentials.communityId else {
            return ""
        }
        return "/communities/\(communityId)"
    }
}
