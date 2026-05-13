/*
 * Copyright (c) 2013-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided
 * that the following conditions are met:
 *
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
 *    the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or
 *    promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import SalesforceSDKCommon

private let ME = "me"
private let PAGE = "page"
private let VERSION = "versionNumber"
private let CONTENT_DOCUMENT_ID = "ContentDocumentId"
private let LINKED_ENTITY_ID = "LinkedEntityId"
private let SHARE_TYPE = "ShareType"
private let RENDITION_TYPE = "type"
private let FILE_DATA = "fileData"
private let FILE_UPLOAD = "fileUpload"

@objc
extension RestClient {

    /**
     * Build a Request that can fetch a page from the files owned by the
     * specified user.
     *
     * @param userId if nil the context user is used, otherwise it should be an Id of a user.
     * @param page if nil fetches the first page, otherwise fetches the specified page.
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to fetch this data.
     */
    @objc
    public func requestForOwnedFilesList(_ userId: String?, page: UInt, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/users/\(userId ?? ME)"
        var params: [String: String] = [:]
        if page > 0 {
            params[PAGE] = "\(page)"
        }
        return RestRequest.request(withMethod: .GET, path: path, queryParams: params)
    }

    /**
     * Build a Request that can fetch a page from the list of files from groups
     * that the user is a member of.
     *
     * @param userId if nil the context user is used, otherwise it should be an Id of a user.
     * @param page if nil fetches the first page, otherwise fetches the specified page.
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to fetch this data.
     */
    @objc
    public func requestForFilesInUsersGroups(_ userId: String?, page: UInt, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/users/\(userId ?? ME)/filter/groups"
        var params: [String: String] = [:]
        if page > 0 {
            params[PAGE] = "\(page)"
        }
        return RestRequest.request(withMethod: .GET, path: path, queryParams: params)
    }

    /**
     * Build a Request that can fetch a page from the list of files that have
     * been shared with the user.
     *
     * @param userId if nil the context user is used, otherwise it should be an Id of a user.
     * @param page if nil fetches the first page, otherwise fetches the specified page.
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to fetch this data.
     */
    @objc
    public func requestForFilesSharedWithUser(_ userId: String?, page: UInt, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/users/\(userId ?? ME)/filter/sharedwithme"
        var params: [String: String] = [:]
        if page > 0 {
            params[PAGE] = "\(page)"
        }
        return RestRequest.request(withMethod: .GET, path: path, queryParams: params)
    }

    /**
     * Build a Request that can fetch the file details of a particular version
     * of a file.
     *
     * @param sfdcId The Id of the file
     * @param version if nil fetches the most recent version, otherwise fetches this specific version.
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to fetch this data.
     */
    @objc
    public func requestForFileDetails(_ sfdcId: String, forVersion version: String?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/\(sfdcId)"
        var params: [String: String] = [:]
        if let version = version {
            params[VERSION] = version
        }
        return RestRequest.request(withMethod: .GET, path: path, queryParams: params)
    }

    /**
     * Build a request that can fetch the latest file details of one or more
     * files in a single request.
     *
     * @param sfdcIds The list of file Ids to fetch.
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to fetch this data
     */
    @objc
    public func requestForBatchFileDetails(_ sfdcIds: [String], apiVersion: String?) -> RestRequest {
        let ids = sfdcIds.joined(separator: ",")
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/batch/\(ids)"
        return RestRequest.request(withMethod: .GET, path: path, queryParams: nil)
    }

    /**
     * Build a Request that can fetch the a preview/rendition of a particular
     * page of the file (and version).
     *
     * @param sfdcId The Id of the file.
     * @param version if nil fetches the most recent version, otherwise fetches this specific version
     * @param renditionType What format of rendition do you want to get
     * @param page which page to fetch, pages start at 0.
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to fetch this data.
     */
    @objc
    public func requestForFileRendition(_ sfdcId: String, version: String?, renditionType: String, page: UInt, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/\(sfdcId)/rendition"
        var params: [String: String] = [:]
        params[RENDITION_TYPE] = renditionType
        if page > 0 {
            params[PAGE] = "\(page)"
        }
        if let version = version {
            params[VERSION] = version
        }
        return RestRequest.request(withMethod: .GET, path: path, queryParams: params)
    }

    /**
     * Builds a request that can fetch the actual binary file contents of this
     * particular file.
     *
     * @param sfdcId The Id of the file.
     * @param version The version of the file.
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to fetch this data.
     */
    @objc
    public func requestForFileContents(_ sfdcId: String, version: String?, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/\(sfdcId)/content"
        var params: [String: String] = [:]
        if let version = version {
            params[VERSION] = version
        }
        return RestRequest.request(withMethod: .GET, path: path, queryParams: params)
    }

    /**
     * Build a request that can fetch a page from the list of entities that this
     * file is shared to.
     *
     * @param sfdcId The Id of the file.
     * @param page if nil fetches the first page, otherwise fetches the specified page.
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to fetch this data.
     */
    @objc
    public func requestForFileShares(_ sfdcId: String, page: UInt, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/\(sfdcId)/file-shares"
        var params: [String: String] = [:]
        if page > 0 {
            params[PAGE] = "\(page)"
        }
        return RestRequest.request(withMethod: .GET, path: path, queryParams: params)
    }

    /**
     * Build a request that will add a file share for the specified fileId to
     * the specified entityId.
     *
     * @param fileId the Id of the file being shared.
     * @param entityId the Id of the entity to share the file to (e.g. a user or a group).
     * @param shareType the type of share (V - View, C - Collaboration).
     * @param apiVersion API version.
     * @return A new RestRequest that be can used to create this share.
     */
    @objc
    public func requestForAddFileShare(_ fileId: String, entityId: String, shareType: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/ContentDocumentLink"
        let params: [String: Any] = [
            CONTENT_DOCUMENT_ID: fileId,
            LINKED_ENTITY_ID: entityId,
            SHARE_TYPE: shareType
        ]
        let request = RestRequest.request(withMethod: .POST, path: path, queryParams: nil)
        request.requestBodyAsDictionary = params
        if let body = try? SFJsonUtils.jsonDataRepresentation(params, options: []) {
            request.setCustomRequestBodyData(body, contentType: "application/json")
        }
        return request
    }

    /**
     * Build a request that will delete the specified file share.
     *
     * @param shareId The Id of the file share record (aka ContentDocumentLink).
     * @param apiVersion API version.
     * @return A new RestRequest that can be used to delete this share.
     */
    @objc
    public func requestForDeleteFileShare(_ shareId: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/sobjects/ContentDocumentLink/\(shareId)"
        return RestRequest.request(withMethod: .DELETE, path: path, queryParams: nil)
    }

    /**
     * Build a request that can upload a new file to the server, this will
     * create a new file at version 1.
     *
     * @param data Data to upload to the server.
     * @param name The name/title of this file.
     * @param description A description of the file.
     * @param mimeType The mime-type of the file, if known.
     * @param apiVersion API version.
     * @return A RestRequest that can perform this upload.
     */
    @objc
    public func requestForUploadFile(_ data: Data, name: String, description: String, mimeType: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/files/users/me"
        let request = RestRequest.request(withMethod: .POST, path: path, queryParams: nil)
        let params = ["title": name, "desc": description]
        request.addPostFileData(data, paramName: FILE_DATA, fileName: name, mimeType: mimeType, params: params)
        return request
    }

    /**
     * Build a request that can upload a new profile photo to the server
     *
     * @param data Data to upload to the server.
     * @param fileName The name of this file.
     * @param mimeType The mime-type of the file, if known.
     * @param userId The id of the user to update.
     * @param apiVersion API version.
     * @return A RestRequest that can perform this upload.
     */
    @objc
    public func requestForProfilePhotoUpload(_ data: Data, fileName: String, mimeType: String, userId: String, apiVersion: String?) -> RestRequest {
        let path = "/\(computeAPIVersion(apiVersion))/connect\(communitiesUrlPathIfRequired())/user-profiles/\(userId)/photo"
        let request = RestRequest.request(withMethod: .POST, path: path, queryParams: nil)
        request.addPostFileData(data, paramName: FILE_UPLOAD, fileName: fileName, mimeType: mimeType, params: nil)
        return request
    }

    @objc
    func communitiesUrlPathIfRequired() -> String {
        guard let communityId = userAccount.credentials.communityId else {
            return ""
        }
        return "/communities/\(communityId)"
    }
}
