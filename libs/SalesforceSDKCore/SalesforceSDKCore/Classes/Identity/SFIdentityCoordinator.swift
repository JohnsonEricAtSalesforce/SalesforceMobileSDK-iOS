/*
 Copyright (c) 2012-present, salesforce.com, inc. All rights reserved.

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

import Foundation
import SalesforceSDKCommon

// MARK: - Public Constants

/**
 * The default timeout period, in seconds, for the identity request.
 */
public let kSFIdentityRequestDefaultTimeoutSeconds: TimeInterval = 120.0

/**
 * The error domain associated with any errors returned by this object.
 */
public let kSFIdentityErrorDomain = "com.salesforce.Identity.ErrorDomain"

/**
 * The Authorization header value.
 */
public let kHttpHeaderAuthorization = "Authorization"

/**
 * The Bearer value string for Authorization.
 */
public let kHttpAuthHeaderFormatString = "Bearer %@"

// MARK: - Error Codes

/**
 * Enumeration of error codes associated with any errors in the identity retrieval process.
 */
@objc public enum SFIdentityError: Int {
    case unknown = 766
    case noData
    case dataMalformed
    case badHttpResponse
    case missingParameters
    case alreadyRetrieving
}

// MARK: - Private Constants

private let kSFIdentityError = "error"
private let kSFIdentityErrorDescription = "error_description"
private let kSFIdentityErrorTypeNoData = "no_data_returned"
private let kSFIdentityErrorTypeDataMalformed = "malformed_response"
private let kSFIdentityErrorTypeBadHttpResponse = "bad_http_response"
private let kSFIdentityErrorTypeMissingParameters = "missing_parameters"
private let kSFIdentityErrorTypeAlreadyRetrieving = "retrieval_in_progress"
private let kMissingParametersFormatString = "The following required parameters for the identity service were missing: %@"

// MARK: - SFIdentityCoordinatorDelegate

/**
 * Protocol for being a delegate to the SFIdentityCoordinator process.  Delegates may receive
 * notifications about the success or failure of the identity request process.
 * @see SFIdentityCoordinator
 */
@objc(SFIdentityCoordinatorDelegate)
public protocol IdentityCoordinatorDelegate: AnyObject {
    /**
     * Called when the identity coordinator successfully receives identity data from the service.
     * @param coordinator the SFIdentityCoordinator instance associated with the requested data.
     */
    @objc(identityCoordinatorRetrievedData:)
    func identityCoordinatorRetrievedData(_ coordinator: IdentityCoordinator)

    /**
     * Called if there was an error while retrieving the identity data from the service.
     * @param coordinator The SFIdentityCoordinator instance associated with the request.
     * @param error The error that occurred during the request.
     */
    @objc(identityCoordinator:didFailWithError:)
    func identityCoordinator(_ coordinator: IdentityCoordinator, didFailWith error: Error)
}

// MARK: - SFIdentityCoordinator

/**
 * The SFIdentityCoordinator class is used to retrieve identity data from the ID endpoint of the
 * Salesforce service.  This data will be based on the requesting user, and the OAuth app
 * credentials he/she is using to request this information.
 */
@objc(SFIdentityCoordinator)
@objcMembers
public class IdentityCoordinator: NSObject {

    // MARK: - Public Properties

    /**
     * The OAuth credentials associated with this instance.
     */
    public var credentials: OAuthCredentials?

    /**
     * The SFIdentityData that will be populated with the response data from the service.
     */
    public var idData: IdentityData?

    /**
     * The SFIdentityCoordinatorDelegate property to set for receiving information about the request.
     * This property must be set prior to initiating an identity request.
     */
    public weak var delegate: IdentityCoordinatorDelegate?

    /**
     * The amount of time, in seconds, to attempt the request, before it times out.  If not set, the
     * default value is represented by the kSFIdentityRequestDefaultTimeoutSeconds property.
     */
    public var timeout: TimeInterval = kSFIdentityRequestDefaultTimeoutSeconds

    // MARK: - Internal Properties

    weak var authSession: AuthSession?
    var retrievingData: Bool = false
    var session: URLSession?
    var oauthSessionRefresher: OAuthSessionRefresher?
    private var networkIdentifier: String?

    // MARK: - Initialization

    /**
     * The designated initializer of IdentityCoordinator.  Creates an instance with the specified
     * OAuth credentials.
     * @param credentials The OAuth credentials used to query the identity service.  At a minimum,
     *        the OAuth credentials must specify a value for accessToken and instanceUrl.
     */
    @objc(initWithCredentials:)
    public init(credentials: OAuthCredentials) {
        self.credentials = credentials
        super.init()
    }

    @objc(initWithAuthSession:)
    public init(authSession: AuthSession) {
        self.authSession = authSession
        self.credentials = authSession.credentials
        super.init()
    }

    deinit {
        if let identifier = networkIdentifier {
            Network.removeSharedInstance(forIdentifier: identifier)
        }
        networkIdentifier = nil
        session = nil
        credentials = nil
        idData = nil
        oauthSessionRefresher = nil
    }

    // MARK: - Public Methods

    /**
     * Begins the identity request.  This request is asynchronous.  Implement the
     * SFIdentityCoordinatorDelegate protocol to receive events related to the identity response from
     * the service.
     */
    @objc(initiateIdentityDataRetrieval)
    public func initiateIdentityDataRetrieval() {
        let missingParameters = validateParameters()
        if !missingParameters.isEmpty {
            let missingParamsError = error(withType: kSFIdentityErrorTypeMissingParameters, description: missingParameters)
            notifyDelegateOfFailure(missingParamsError)
            return
        }

        if retrievingData {
            let alreadyRetrievingErrorMessage = "Identity data retrieval already in progress.  Call cancelRetrieval to stop the transaction in progress."
            SFSDKCoreLogger.d(type(of: self), message: alreadyRetrievingErrorMessage)
            let alreadyRetrievingError = error(withType: kSFIdentityErrorTypeAlreadyRetrieving, description: alreadyRetrievingErrorMessage)
            notifyDelegateOfFailure(alreadyRetrievingError)
            return
        }

        retrievingData = true
        sendRequest()
    }

    /**
     * Cancels a request in progress.
     */
    @objc(cancelRetrieval)
    public func cancelRetrieval() {
        session?.invalidateAndCancel()
        cleanupData()
    }

    // MARK: - Private Methods

    private func validateParameters() -> String {
        var invalidParameters = [String]()

        if credentials?.accessToken?.isEmpty ?? true {
            invalidParameters.append("access token")
        }

        if credentials?.identityUrl?.absoluteString.isEmpty ?? true {
            invalidParameters.append("identity URL")
        }

        if !invalidParameters.isEmpty {
            return String(format: kMissingParametersFormatString, invalidParameters.joined(separator: ", "))
        }

        return ""
    }

    func sendRequest() {
        guard let identityUrl = credentials?.identityUrl,
              let accessToken = credentials?.accessToken else {
            return
        }

        var request = URLRequest(url: identityUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue(String(format: kHttpAuthHeaderFormatString, accessToken), forHTTPHeaderField: kHttpHeaderAuthorization)
        request.timeoutInterval = timeout
        request.httpShouldHandleCookies = false

        SFSDKCoreLogger.d(type(of: self), message: "SFIdentityCoordinator:Starting identity request at \(identityUrl.absoluteString)")

        let identifier = Network.uniqueInstanceIdentifier()
        networkIdentifier = identifier
        let network = Network.sharedEphemeralInstance(withIdentifier: identifier)
        session = network.activeSession

        _ = network.sendRequest(request) { [weak self] (data: Data?, response: URLResponse?, error: Error?) in
            guard let self = self else { return }

            if let error = error {
                SFSDKCoreLogger.d(type(of: self), message: "SFIdentityCoordinator session failed with error: \(error)")
                self.notifyDelegateOfFailure(error)
                return
            }

            // The connection can succeed, but the actual HTTP response is a failure.  Check for that.
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode

                if statusCode == 401 || statusCode == 403 {
                    // The session timed out.  Identity service tends to send 403s for session timeouts.  Try to refresh.
                    SFSDKCoreLogger.i(type(of: self), message: "Identity request failed due to expired credentials. Attempting to refresh credentials.")

                    if let credentials = self.credentials {
                        self.oauthSessionRefresher = OAuthSessionRefresher(credentials: credentials)
                        self.oauthSessionRefresher?.refreshSession(completion: { [weak self] updatedCredentials in
                            guard let self = self else { return }
                            SFSDKCoreLogger.d(type(of: self), message: "Credentials refresh successful. Replaying original identity request.")
                            self.credentials = updatedCredentials
                            DispatchQueue.main.async {
                                self.sendRequest()
                            }
                        }, error: { [weak self] refreshError in
                            guard let self = self else { return }
                            SFSDKCoreLogger.e(type(of: self), message: "SFIdentityCoordinator failed to refresh expired session. Error: \(refreshError)")
                            self.notifyDelegateOfFailure(refreshError)
                        })
                    }
                } else if statusCode != 200 {
                    // Some other HTTP error.
                    let httpError = self.error(withType: kSFIdentityErrorTypeBadHttpResponse,
                                              description: "Unexpected HTTP response code from the identity service: \(statusCode)")
                    self.notifyDelegateOfFailure(httpError)
                } else {
                    // Successful response. Process the return data.
                    if let data = data {
                        self.processResponse(data)
                    }
                }
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
            self.delegate?.identityCoordinator(self, didFailWith: error)
            self.cleanupData()
        }
    }

    func cleanupData() {
        if let identifier = networkIdentifier {
            Network.removeSharedInstance(forIdentifier: identifier)
        }
        networkIdentifier = nil
        session = nil
        oauthSessionRefresher = nil
        retrievingData = false
    }

    func processResponse(_ data: Data) {
        guard let idJsonData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            let error = self.error(withType: kSFIdentityErrorTypeDataMalformed, description: "Unable to parse identity response data.")
            notifyDelegateOfFailure(error)
            return
        }

        var mutableIdJsonData = idJsonData
        if authSession?.nativeLogin == true {
            mutableIdJsonData["native_login"] = NSNumber(value: true)
        }

        let identityData = IdentityData(jsonDict: mutableIdJsonData)
        self.idData = identityData

        notifyDelegateOfSuccess()
    }

    func error(withType type: String, description: String) -> NSError {
        let intCode = typeToCodeDict[type] as? Int ?? SFIdentityError.unknown.rawValue

        let dict: [String: Any] = [
            kSFIdentityError: type,
            kSFIdentityErrorDescription: description,
            NSLocalizedDescriptionKey: description
        ]

        return NSError(domain: kSFIdentityErrorDomain, code: intCode, userInfo: dict)
    }

    // MARK: - Properties

    private var typeToCodeDict: [String: Any] {
        return [
            kSFIdentityErrorTypeNoData: SFIdentityError.noData.rawValue,
            kSFIdentityErrorTypeDataMalformed: SFIdentityError.dataMalformed.rawValue,
            kSFIdentityErrorTypeBadHttpResponse: SFIdentityError.badHttpResponse.rawValue,
            kSFIdentityErrorTypeMissingParameters: SFIdentityError.missingParameters.rawValue,
            kSFIdentityErrorTypeAlreadyRetrieving: SFIdentityError.alreadyRetrieving.rawValue
        ]
    }
}
