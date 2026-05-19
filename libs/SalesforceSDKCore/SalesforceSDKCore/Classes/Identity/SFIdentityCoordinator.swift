// Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.
// Redistribution and use of this software in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided
// with the distribution.
// * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
// endorse or promote products derived from this software without specific prior written
// permission of salesforce.com, inc.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
// WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import SalesforceSDKCommon

/// The default timeout period, in seconds, for the identity request.
public let kSFIdentityRequestDefaultTimeoutSeconds: TimeInterval = 120.0

/// The error domain associated with any errors returned by this object.
public let kSFIdentityErrorDomain: String = "com.salesforce.Identity.ErrorDomain"

/// The Authorization header value.
public let kHttpHeaderAuthorization: String = "Authorization"

/// The Bearer value string for Authorization.
public let kHttpAuthHeaderFormatString: String = "Bearer %@"

/// Error codes associated with identity retrieval process.
public let kSFIdentityErrorUnknown: Int = 766
public let kSFIdentityErrorNoData: Int = 767
public let kSFIdentityErrorDataMalformed: Int = 768
public let kSFIdentityErrorBadHttpResponse: Int = 769
public let kSFIdentityErrorMissingParameters: Int = 770
public let kSFIdentityErrorAlreadyRetrieving: Int = 771

// Private constants
private let kSFIdentityError = "error"
private let kSFIdentityErrorDescription = "error_description"
private let kSFIdentityErrorTypeNoData = "no_data_returned"
private let kSFIdentityErrorTypeDataMalformed = "malformed_response"
private let kSFIdentityErrorTypeBadHttpResponse = "bad_http_response"
private let kSFIdentityErrorTypeMissingParameters = "missing_parameters"
private let kSFIdentityErrorTypeAlreadyRetrieving = "retrieval_in_progress"
private let kMissingParametersFormatString = "The following required parameters for the identity service were missing: %@"

/// Protocol for being a delegate to the SFIdentityCoordinator process.
@objc(SFIdentityCoordinatorDelegate)
public protocol SFIdentityCoordinatorDelegate: NSObjectProtocol {
    @objc func identityCoordinatorRetrievedData(_ coordinator: SFIdentityCoordinator)
    @objc func identityCoordinator(_ coordinator: SFIdentityCoordinator, didFailWithError error: Error)
}

/// The SFIdentityCoordinator class is used to retrieve identity data from the ID endpoint.
@objc(SFIdentityCoordinator)
@objcMembers
public class SFIdentityCoordinator: NSObject {

    public var credentials: OAuthCredentials?
    public var idData: SFIdentityData?
    public weak var delegate: SFIdentityCoordinatorDelegate?
    public var timeout: TimeInterval = kSFIdentityRequestDefaultTimeoutSeconds

    // Internal properties
    var retrievingData: Bool = false
    var session: URLSession?
    var oauthSessionRefresher: SFOAuthSessionRefresher?
    weak var authSession: SFSDKAuthSession?
    private var networkIdentifier: String?

    private var typeToCodeDict: [String: NSNumber] {
        return [
            kSFIdentityErrorTypeNoData: NSNumber(value: kSFIdentityErrorNoData),
            kSFIdentityErrorTypeDataMalformed: NSNumber(value: kSFIdentityErrorDataMalformed),
            kSFIdentityErrorTypeBadHttpResponse: NSNumber(value: kSFIdentityErrorBadHttpResponse),
            kSFIdentityErrorTypeMissingParameters: NSNumber(value: kSFIdentityErrorMissingParameters),
            kSFIdentityErrorTypeAlreadyRetrieving: NSNumber(value: kSFIdentityErrorAlreadyRetrieving)
        ]
    }

    /// Designated initializer.
    @objc public init(credentials: OAuthCredentials) {
        self.credentials = credentials
        super.init()
    }

    @objc public init(authSession: SFSDKAuthSession) {
        self.authSession = authSession
        self.credentials = authSession.credentials
        super.init()
    }

    deinit {
        if let id = networkIdentifier {
            Network.removeSharedInstance(forIdentifier: id)
        }
    }

    // MARK: - Public Methods

    /// Begins the identity request.
    @objc public func initiateIdentityDataRetrieval() {
        let missingParameters = validateParameters()
        if missingParameters.count > 0 {
            let error = self.error(withType: kSFIdentityErrorTypeMissingParameters, description: missingParameters)
            notifyDelegateOfFailure(error)
            return
        }
        if retrievingData {
            let msg = "Identity data retrieval already in progress. Call cancelRetrieval to stop the transaction in progress."
            SFSDKCoreLogger.d(Self.self, format: msg)
            let error = self.error(withType: kSFIdentityErrorTypeAlreadyRetrieving, description: msg)
            notifyDelegateOfFailure(error)
            return
        }
        retrievingData = true
        sendRequest()
    }

    /// Cancels a request in progress.
    @objc public func cancelRetrieval() {
        session?.invalidateAndCancel()
        cleanupData()
    }

    // MARK: - Private Methods

    private func validateParameters() -> String {
        var invalidParameters = ""
        if (credentials?.accessToken?.count ?? 0) == 0 {
            invalidParameters += "access token"
        }
        if (credentials?.identityUrl?.absoluteString.count ?? 0) == 0 {
            if invalidParameters.count > 0 { invalidParameters += ", " }
            invalidParameters += "identity URL"
        }
        if invalidParameters.count > 0 {
            return String(format: kMissingParametersFormatString, invalidParameters)
        }
        return ""
    }

    private func sendRequest() {
        guard let identityUrl = credentials?.identityUrl else { return }
        var request = URLRequest(url: identityUrl, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue(String(format: kHttpAuthHeaderFormatString, credentials?.accessToken ?? ""), forHTTPHeaderField: kHttpHeaderAuthorization)
        request.timeoutInterval = timeout
        request.httpShouldHandleCookies = false

        SFSDKCoreLogger.d(Self.self, format: "SFIdentityCoordinator:Starting identity request at %@", identityUrl.absoluteString)

        networkIdentifier = Network.uniqueInstanceIdentifier()
        guard let netId = networkIdentifier else { return }
        let network = Network.sharedEphemeralInstance(withIdentifier: netId)
        session = network.activeSession
        network.sendRequest(request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                SFSDKCoreLogger.d(Self.self, format: "SFIdentityCoordinator session failed with error: %@", error.localizedDescription)
                self.notifyDelegateOfFailure(error)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 401 || statusCode == 403 {
                SFSDKCoreLogger.i(Self.self, format: "%@: Identity request failed due to expired credentials. Attempting to refresh credentials.", #function)
                self.oauthSessionRefresher = SFOAuthSessionRefresher(credentials: self.credentials)
                self.oauthSessionRefresher?.refreshSession(withCompletion: { [weak self] updatedCredentials in
                    guard let self = self else { return }
                    SFSDKCoreLogger.d(Self.self, format: "%@: Credentials refresh successful. Replaying original identity request.", #function)
                    self.credentials = updatedCredentials
                    DispatchQueue.main.async {
                        self.sendRequest()
                    }
                }, error: { [weak self] refreshError in
                    guard let self = self else { return }
                    SFSDKCoreLogger.e(Self.self, format: "SFIdentityCoordinator failed to refresh expired session. Error: %@", refreshError.localizedDescription)
                    self.notifyDelegateOfFailure(refreshError)
                })
            } else if statusCode != 200 {
                let httpError = self.error(withType: kSFIdentityErrorTypeBadHttpResponse, description: "Unexpected HTTP response code from the identity service: \(statusCode)")
                self.notifyDelegateOfFailure(httpError)
            } else {
                self.processResponse(data)
            }
        }
    }

    func notifyDelegateOfSuccess() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.identityCoordinatorRetrievedData(self)
            self.cleanupData()
        }
    }

    func notifyDelegateOfFailure(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.identityCoordinator(self, didFailWithError: error)
            self.cleanupData()
        }
    }

    func cleanupData() {
        if let id = networkIdentifier {
            Network.removeSharedInstance(forIdentifier: id)
        }
        networkIdentifier = nil
        session = nil
        oauthSessionRefresher = nil
        retrievingData = false
    }

    func processResponse(_ data: Data?) {
        guard let data = data else {
            let error = self.error(withType: kSFIdentityErrorTypeNoData, description: "No identity data returned in response.")
            notifyDelegateOfFailure(error)
            return
        }

        guard let idJsonData = SFJsonUtils.object(fromJSONData: data) as? [String: Any] else {
            let error = self.error(withType: kSFIdentityErrorTypeDataMalformed, description: "Unable to parse identity response data.")
            notifyDelegateOfFailure(error)
            return
        }

        var mutableData = idJsonData
        if authSession?.nativeLogin == true {
            mutableData["native_login"] = NSNumber(value: true)
        }
        idData = SFIdentityData(jsonDict: mutableData)
        notifyDelegateOfSuccess()
    }

    func error(withType type: String, description: String) -> NSError {
        var intCode = kSFIdentityErrorUnknown
        if let numCode = typeToCodeDict[type] {
            intCode = numCode.intValue
        }
        let dict: [String: Any] = [
            kSFIdentityError: type,
            kSFIdentityErrorDescription: description,
            NSLocalizedDescriptionKey: description
        ]
        return NSError(domain: kSFIdentityErrorDomain, code: intCode, userInfo: dict)
    }
}
