/*
 Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.

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
import AuthenticationServices
import Security
import UIKit
import WebKit
import SalesforceSDKCommon

/**
 Callback block used for the browser flow authentication.
 @see oauthCoordinator:willBeginBrowserAuthentication:
 */
public typealias SFOAuthBrowserFlowCallbackBlock = (Bool) -> Void

/** Protocol for objects intending to be a delegate for an OAuth coordinator.

 Implement this protocol to receive updates from an `SFOAuthCoordinator` instance.
 Use these methods to update your interface and refresh your application once a session restarts.

 @see SFOAuthCoordinator
 */
@objc(SFOAuthCoordinatorDelegate)
public protocol SFOAuthCoordinatorDelegate: NSObjectProtocol {

    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginAuthenticationWith view: WKWebView)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didStartLoad view: WKWebView)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFinishLoad view: WKWebView, error: Error?)
    @objc optional func oauthCoordinatorWillBeginAuthentication(_ coordinator: SFOAuthCoordinator, authInfo: SFOAuthInfo)
    @objc optional func oauthCoordinatorDidAuthenticate(_ coordinator: SFOAuthCoordinator, authInfo: SFOAuthInfo)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFailWithError error: Error, authInfo: SFOAuthInfo?)
    @objc optional func oauthCoordinatorIsNetworkAvailable(_ coordinator: SFOAuthCoordinator) -> Bool
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginBrowserAuthentication callbackBlock: @escaping SFOAuthBrowserFlowCallbackBlock)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, displayAlertMessage message: String, completion: @escaping () -> Void)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, displayConfirmationMessage message: String, completion: @escaping (Bool) -> Void)
    @objc optional func oauthCoordinatorDidFetchAuthCode(_ coordinator: SFOAuthCoordinator, authInfo: SFOAuthInfo)

    @objc(oauthCoordinator:didBeginAuthenticationWithWKWebView:)
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith view: WKWebView)
    @objc(oauthCoordinator:didBeginAuthenticationWithASWebAuthenticationSession:)
    func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWith session: ASWebAuthenticationSession)
    @objc func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator)
    @objc func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator)
}

/** The `SFOAuthCoordinator` class is the central class of the OAuth2 authentication process.

 This class manages a `WKWebView` instance and monitors it as it works its way
 through the various stages of the OAuth2 workflow. When authentication is complete,
 the coordinator instance extracts the necessary session information from the response
 and updates the `SFOAuthCredentials` object as necessary.

 @warning This class requires the following dependencies:
 the Security framework and either the NSJSONSerialization iOS 5.0 SDK class
 or the third party SBJsonParser class.
 */
@objc(SFOAuthCoordinator)
public class SFOAuthCoordinator: NSObject {

    /** User credentials to use within the authentication process.

     @warning The behavior of this class is undefined if this property is set after `authenticate` has been called and
     authentication has started.
     @warning This property must not be `nil` at the time the `authenticate` method is called or an exception will be raised.

     @see OAuthCredentials
     */
    @objc public var credentials: OAuthCredentials?

    /** The delegate object for this coordinator.

     The delegate is sent messages at different stages of the authentication process.

     @see SFOAuthCoordinatorDelegate
     */
    @objc public weak var delegate: SFOAuthCoordinatorDelegate?

    /** A set of scopes for OAuth.
     See:
     https://help.salesforce.com/apex/HTViewHelpDoc?language=en&id=remoteaccess_oauth_scopes.htm

     Generally you need not specify this unless you are using something other than the "api" scope.
     For instance, if you are accessing Visualforce pages as well as the REST API, you could use:
     [@"api", @"visualforce"]

     (You need not specify the "refresh_token" scope as this is always requested by this library.)

     If you do not set this property, the library does not add the "scope" parameter to the initial
     OAuth request, which implicitly sets the scope to include: "id", "api", and "refresh_token".
     */
    @objc public var scopes: Set<AnyHashable>?

    /** Timeout interval for OAuth requests.

     This value controls how long requests will wait before timing out.
     */
    @objc public var timeout: TimeInterval = kSFOAuthDefaultTimeout

    /** View in which the user will input OAuth credentials for the user-agent flow OAuth process.

     This is only guaranteed to be non-`nil` after one of the delegate methods returning a web view has been called.
     @see SFOAuthCoordinatorDelegate
     */
    @objc public private(set) var view: WKWebView! {
        get {
            if _view == nil {
                let config = WKWebViewConfiguration()
                var bounds = CGRect.zero
                if let scene = authSession?.oauthRequest.scene as? UIWindowScene {
                    bounds = scene.coordinateSpace.bounds
                } else {
                    #if !targetEnvironment(simulator)
                    bounds = UIScreen.main.bounds
                    #endif
                }

                _view = WKWebView(frame: bounds, configuration: config)
                _view?.navigationDelegate = self
                _view?.autoresizesSubviews = true
                _view?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                _view?.clipsToBounds = true
                _view?.translatesAutoresizingMaskIntoConstraints = false
                _view?.customUserAgent = SalesforceManager.shared.userAgentString("")
                _view?.isInspectable = SalesforceManager.shared.isLoginWebviewInspectable
                _view?.uiDelegate = self
            }
            return _view
        }
        set {
            _view = newValue
        }
    }
    private var _view: WKWebView?

    /**
     Auth session through which the user will input OAuth credentials for the user-agent flow OAuth process.
     */
    @objc public private(set) var asWebAuthenticationSession: ASWebAuthenticationSession!

    /**
     The user agent string that will be used for authentication.  While this property will persist throughout
     the lifetime of the coordinator object, the user agent configured for the system will be reset back to
     its original value in between authentication requests.
     */
    @available(*, deprecated, message: "Not used, will be removed in SDK 14.0")
    @objc public var userAgentForAuth: String = ""

    /**
     An array of additional keys (NSString) to parse during OAuth
     */
    @objc public var additionalOAuthParameterKeys: [String]?

    /**
     A dictionary of additional parameters (key value pairs) to send during token refresh
     */
    @objc public var additionalTokenRefreshParams: [String: Any]?

    /** Brand Login Path.
     The brand login path used for the authorize endpoint e.g. /brand in
     https://community.force.com/services/oauth2/authorize/<brand>?response_type=code&...
     */
    @objc public var brandLoginPath: String?

    /** Setup the coordinator to use ASWebAuthenticationSession for authentication.
     */
    @objc public var useBrowserAuth: Bool = false

    @objc public var authClient: SFSDKOAuthProtocol = SFSDKOAuth2()

    /** Setup the coordinator to use an app provided native UI for authentication.
     */
    @objc public var useNativeAuth: Bool = false

    // MARK: - Internal properties
    var authenticating: Bool = false
    var session: URLSession? {
        if _session == nil {
            let identifier = Network.uniqueInstanceIdentifier()
            networkIdentifier = identifier
            let network = Network.sharedEphemeralInstance(withIdentifier: identifier)
            _session = network.activeSession
        }
        return _session
    }
    private var _session: URLSession?
    var responseData: NSMutableData?
    var initialRequestLoaded: Bool = false
    var domainUpdated: Bool = false
    var approvalCode: String?
    var codeVerifier: String?
    var authInfo: SFOAuthInfo {
        get {
            if _authInfo == nil {
                _authInfo = SFOAuthInfo(authType: .unknown)
            }
            return _authInfo!
        }
        set {
            _authInfo = newValue
        }
    }
    private var _authInfo: SFOAuthInfo?
    var origWebUserAgent: String?
    var spAppCredentials: OAuthCredentials?
    weak var authSession: AuthSession?
    var frontdoorBridgeLoginOverride: AuthCoordinatorFrontdoorBridgeLoginOverride?
    var loginHint: String?
    var networkIdentifier: String?
    var domainDiscoveryCoordinator: DomainDiscoveryCoordinator = DomainDiscoveryCoordinator()

    // MARK: - Initialization

    /** Initializes a new OAuth coordinator with the supplied credentials. This is the designated initializer.

     @warning Although it is permissible to pass `nil` for the credentials argument, the credentials propery
     must not be `nil` prior to calling the `authenticate` method or an exception will be raised.

     @param credentials An instance of `OAuthCredentials` identifying the user to be authenticated.
     @return The initialized authentication coordinator.

     @see OAuthCredentials
     */
    @objc(initWithCredentials:)
    public init(credentials: OAuthCredentials?) {
        self.credentials = credentials
        self.authenticating = false
        super.init()
    }

    @objc public init(authSession: AuthSession) {
        self.authSession = authSession
        self.credentials = authSession.credentials
        self.authenticating = false
        super.init()
    }

    public override init() {
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let networkId = networkIdentifier {
            Network.removeSharedInstance(forIdentifier: networkId)
        }
        networkIdentifier = nil
        approvalCode = nil
        _session = nil
        credentials = nil
        responseData = nil
        scopes = nil
        _view = nil
        authSession = nil
    }

    // MARK: - Authentication control

    /** Begins the authentication process.

     @exception NSInternalInconsistencyException If called when the `credentials` property is `nil`.
     */
    @objc public func authenticate() {
        assert(credentials != nil, "credentials cannot be nil")
        assert(credentials!.clientId?.count ?? 0 > 0, "credentials.clientId cannot be nil or empty")
        assert(credentials!.identifier.count > 0, "credentials.identifier cannot be nil or empty")
        assert(credentials!.domain?.count ?? 0 > 0, "credentials.domain cannot be nil or empty.")
        assert(delegate != nil, "cannot authenticate with nil delegate")

        if authenticating {
            SFSDKCoreLogger.d(type(of: self), message: "\(#function) Error: authenticate called while already authenticating. Call stopAuthenticating first.")
            return
        }

        SFSDKCoreLogger.d(type(of: self), message: "\(#function) authenticating as \(credentials!.clientId) \(credentials!.refreshToken == nil ? "without" : "with") refresh token on '\(credentials!.protocol)://\(credentials!.domain)' ...")

        authenticating = true

        if credentials!.refreshToken != nil {
            authInfo = SFOAuthInfo(authType: .refresh)
        } else if useBrowserAuth {
            authInfo = SFOAuthInfo(authType: .advancedBrowser)
        } else if SalesforceManager.shared.useWebServerAuthentication {
            authInfo = SFOAuthInfo(authType: .webServer)
        } else {
            authInfo = SFOAuthInfo(authType: .userAgent)
        }

        // Don't try to authenticate if there is no network available
        if delegate?.oauthCoordinatorIsNetworkAvailable?(self) == false {
            SFSDKCoreLogger.d(type(of: self), message: "Network is not available, so bypassing login")
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
            notifyDelegateOfFailure(error, authInfo: authInfo)
            return
        }

        if credentials!.refreshToken != nil {
            // clear any access token we may have and begin refresh flow
            notifyDelegateOfBeginAuthentication()
            beginTokenEndpointFlow()
        } else if credentials!.jwt != nil {
            // JWT token existence means we're doing JWT token exchange.
            authInfo = SFOAuthInfo(authType: .jwtTokenExchange)
            notifyDelegateOfBeginAuthentication()
            beginJwtTokenExchangeFlow()
        } else {
            if useNativeAuth {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.authInfo = SFOAuthInfo(authType: .native)
                    self.notifyDelegateOfBeginAuthentication()
                    self.beginHeadlessNativeLoginFlow()
                }
            } else if !frontdoorBridgeLoginOverride.isSome && useBrowserAuth {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.authInfo = SFOAuthInfo(authType: .advancedBrowser)
                    self.notifyDelegateOfBeginAuthentication()
                    self.beginNativeBrowserFlow(withSharedBrowserSessionEnabled: false)
                }
            } else {
                let loginDomain = frontdoorBridgeLoginOverride?.frontdoorBridgeUrl?.host ?? credentials!.domain ?? ""
                SFSDKAuthConfigUtil.getMyDomainAuthConfig({ [weak self] authConfig, error in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        // Ignore any errors while retrieving authconfig. Default to WKWebView
                        // Errors should have already been logged.
                        if !self.frontdoorBridgeLoginOverride.isSome && authConfig?.useNativeBrowserForAuth == true {
                            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin)
                            self.authInfo = SFOAuthInfo(authType: .advancedBrowser)
                            self.notifyDelegateOfBeginAuthentication()
                            self.beginNativeBrowserFlow(withSharedBrowserSessionEnabled: authConfig?.shareBrowserSession ?? false)
                        } else {
                            SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureSafariBrowserForLogin)
                            self.notifyDelegateOfBeginAuthentication()
                            self.beginWebViewFlow()
                        }
                    }
                }, loginDomain: loginDomain)
            }
        }
    }

    /**
     * Sets the credentials property and begins the authentication process. Simply a convenience method for:
     *   `coordinator.credentials = theCredentials;`
     *   `[coordinator authenticate];`
     * @param credentials The OAuth credentials used for authentication.
     * @exception NSInternalInconsistencyException If called with a `nil` `credentials` argument.
     */
    @objc public func authenticate(with credentials: OAuthCredentials) {
        self.credentials = credentials
        if domainDiscoveryCoordinator.isDiscoveryDomain(credentials.domain) {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureWelcomeDiscovery)
            Task {
                await runMyDomainDiscoveryAndAuthenticate()
            }
            return
        } else {
            SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureWelcomeDiscovery)
        }
        authenticate()
    }

    @MainActor
    func runMyDomainDiscoveryAndAuthenticate() {
        startWebviewAuthenticationIfNeeded()
        if let creds = credentials {
            domainDiscoveryCoordinator.runMyDomainsDiscovery(on: view, with: creds)
        }
    }

    /** Returns YES if the coordinator is in the process of authentication; otherwise NO.
     */
    @objc public func isAuthenticating() -> Bool {
        return authenticating
    }

    /** Stops the authentication process.
     */
    @objc public func stopAuthentication() {
        _view?.stopLoading()
        session?.invalidateAndCancel()
        _session = nil
        networkIdentifier = nil
        authenticating = false
        _authInfo = nil
    }

    /** Revokes the authentication credentials.
     */
    @objc public func revokeAuthentication() {
        stopAuthentication()
        credentials?.revoke()
    }

    /**
     Handle an advanced authentication response from the external browser, continuing any
     in-progress adavanced authentication flow.
     @param appUrlResponse The URL response returned to the app from the external browser.
     @return YES if this is a valid URL response from advanced authentication that the coordinator
     should handle, NO otherwise.
     */
    @objc public func handleAdvancedAuthenticationResponse(_ appUrlResponse: URL) -> Bool {
        authInfo = SFOAuthInfo(authType: .advancedBrowser)
        let success = handleWebServerResponse(appUrlResponse)
        if success {
            authInfo = SFOAuthInfo(authType: .advancedBrowser)
        }
        return success
    }

    @objc public func handleIDPAuthenticationResponse(_ appUrlResponse: URL) -> Bool {
        authInfo = SFOAuthInfo(authType: .idp)

        guard let query = appUrlResponse.query, !query.isEmpty else {
            SFSDKCoreLogger.i(type(of: self), message: "\(#function) URL has no query string.")
            return false
        }

        guard let codeVal = appUrlResponse.sfsdk_valueForParameterName("code"), !codeVal.isEmpty else {
            SFSDKCoreLogger.i(type(of: self), message: "\(#function) URL has no '\(kSFOAuthResponseTypeCode)' parameter value.")
            return false
        }
        approvalCode = codeVal

        if let keychainReference = appUrlResponse.sfsdk_valueForParameterName(kSFKeychainReferenceParam) {
            let keychainGroup = appUrlResponse.sfsdk_valueForParameterName(kSFKeychainGroupParam)
            let result = KeychainHelper.read(service: keychainReference, account: nil, accessGroup: keychainGroup, cacheMode: .disabled)
            guard let data = result.data, result.error == nil else {
                SFSDKCoreLogger.e(type(of: self), message: "URL has keychain group parameter but unable to retrieve value from the keychain: \(result.error?.localizedDescription ?? "unknown error")")
                return false
            }
            guard let codeVerifier = (data as NSData).sfsdk_base64UrlString as String? else {
                SFSDKCoreLogger.e(type(of: self), message: "URL has keychain group parameter but unable to retrieve value from the keychain: \(result.error?.localizedDescription ?? "unknown error")")
                return false
            }
            self.codeVerifier = codeVerifier
        }

        SFSDKCoreLogger.i(type(of: self), message: "\(#function) Received advanced authentication response.  Beginning token exchange.")
        DispatchQueue.main.async { [weak self] in
            self?.beginTokenEndpointFlow()
        }
        return true
    }

    @objc public func beginIDPFlow(_ user: UserAccount, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        authInfo = SFOAuthInfo(authType: .idp)
        initialRequestLoaded = false

        // notify delegate will be begin authentication in our (web) view
        if let credentials = credentials, credentials.accessToken != nil, credentials.apiUrl != nil,
           let restClient = RestClient.restClient(for: user) {
            let approvalPathForSP = computeAuthorizationPathForSP()
            let singleAccessRequest = restClient.requestForSingleAccess(approvalPathForSP)

            restClient.send(singleAccessRequest, failureBlock: { (_: Any?, error: Error?, _: URLResponse?) in
                failure(error!)
            }, successBlock: { [weak self] (response: Any?, _: URLResponse?) in
                guard let self = self else { return }
                if success != nil {
                    success()
                }
                if let frontDoorUrlString = (response as? [String: Any])?["frontdoor_uri"] as? String {
                    self.loadWebView(withUrlString: frontDoorUrlString, cookie: true)
                }
            })
        }
    }

    // MARK: - Private Methods

    func notifyDelegateOfFailure(_ error: Error, authInfo: SFOAuthInfo) {
        authenticating = false
        if delegate?.oauthCoordinator(_:didFailWithError:authInfo:) != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.oauthCoordinator?(self, didFailWithError: error, authInfo: authInfo)
            }
        }
        clearFrontDoorBridgeLoginOverride()
    }

    func notifyDelegateOfSuccess(_ authInfo: SFOAuthInfo) {
        authenticating = false
        delegate?.oauthCoordinatorDidAuthenticate?(self, authInfo: authInfo)
        clearFrontDoorBridgeLoginOverride()
    }

    func notifyDelegateOfBeginAuthentication() {
        delegate?.oauthCoordinatorWillBeginAuthentication?(self, authInfo: authInfo)
    }

    func beginNativeBrowserFlow(withSharedBrowserSessionEnabled shareBrowserSession: Bool) {
        if delegate?.oauthCoordinator(_:willBeginBrowserAuthentication:) != nil {
            delegate?.oauthCoordinator?(self, willBeginBrowserAuthentication: { [weak self] proceed in
                if proceed {
                    self?.continueNativeBrowserFlow(withSharedBrowserSessionEnabled: shareBrowserSession)
                }
            })
        } else {
            // If delegate does not implement the method, simply continue with the browser flow.
            continueNativeBrowserFlow(withSharedBrowserSessionEnabled: shareBrowserSession)
        }
    }

    func continueNativeBrowserFlow(withSharedBrowserSessionEnabled shareBrowserSession: Bool) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.continueNativeBrowserFlow(withSharedBrowserSessionEnabled: shareBrowserSession)
            }
            return
        }

        var approvalUrl = self.approvalURL(forEndpoint: brandedAuthorizeURL(),
                                          credentials: credentials!,
                                          webServerFlow: true,
                                          protocol: nil,
                                          domain: nil,
                                          codeChallenge: nil)
        approvalUrl = "\(approvalUrl)&state=\(credentials!.identifier)"

        if !shareBrowserSession {
            approvalUrl = "\(approvalUrl)&prompt=login"
        }

        // Launch the native browser.
        SFSDKCoreLogger.d(type(of: self), message: "\(#function): Initiating native browser flow with URL \(approvalUrl)")
        let nativeBrowserUrl = URL(string: approvalUrl)!
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin)

        guard let redirectUri = credentials?.redirectUri,
              let callbackURL = URL(string: redirectUri),
              let callbackScheme = callbackURL.scheme else {
            return
        }
        asWebAuthenticationSession = ASWebAuthenticationSession(url: nativeBrowserUrl, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
            guard let self = self else { return }
            if error == nil, let callbackURL = callbackURL, SFSDKURLHandlerManager.sharedInstance.canHandleRequest(callbackURL, options: nil) {
                let options: [String: Any] = [kSFIDPSceneIdKey: self.authSession?.sceneId ?? ""]
                _ = SFSDKURLHandlerManager.sharedInstance.processRequest(callbackURL, options: options, completion: nil, failure: nil)
            } else {
                self.delegate?.oauthCoordinatorDidCancelBrowserAuthentication(self)
            }
        }
        asWebAuthenticationSession.prefersEphemeralWebBrowserSession = SalesforceManager.shared.useEphemeralSessionForAdvancedAuth
        delegate?.oauthCoordinator(self, didBeginAuthenticationWith: asWebAuthenticationSession)
    }

    func beginWebViewFlow() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.beginWebViewFlow()
            }
            return
        }
        initialRequestLoaded = false

        // notify delegate will be begin authentication in our (web) view
        delegate?.oauthCoordinator?(self, willBeginAuthenticationWith: view)

        let approvalUrlString = generateApprovalUrlString()
        loadWebView(withUrlString: approvalUrlString, cookie: true)
    }

    func beginJwtTokenExchangeFlow() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.beginJwtTokenExchangeFlow()
            }
            return
        }

        assert(credentials!.jwt!.count > 0, "JWT token should be present at this point.")

        swapJWT { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                SFSDKCoreLogger.e(type(of: self), message: "Fail to swap JWT for access token: \(error.localizedDescription)")
                self.notifyDelegateOfFailure(error, authInfo: self.authInfo)
                return
            }

            self.credentials?.jwt = nil

            guard let data = data,
                  let json = SFJsonUtils.object(from: data) as? [String: Any] else {
                let error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeJWTLaunchFailed,
                                             description: "Error parsing JWT token exchange response.",
                                             underlyingError: nil)
                self.notifyDelegateOfFailure(error, authInfo: self.authInfo)
                return
            }

            if let errorType = json[kSFOAuthError] as? String {
                let error = SFSDKOAuth2.error(withType: errorType, description: json[kSFOAuthErrorDescription] as? String ?? "")
                self.notifyDelegateOfFailure(error, authInfo: self.authInfo)
                return
            }

            self.credentials?.updateCredentials(json)
            if let accessToken = self.credentials?.accessToken,
               let apiUrl = self.credentials?.apiUrl {
                let baseUrlString = apiUrl.absoluteString
                let approvalUrlString = self.generateApprovalUrlString()
                let escapedApprovalUrlString = approvalUrlString.sfsdk_stringByURLEncoding
                let frontDoorUrlString = "\(baseUrlString)/secur/frontdoor.jsp?sid=\(accessToken)&retURL=\(escapedApprovalUrlString)"
                self.loadWebView(withUrlString: frontDoorUrlString, cookie: true)
            }
        }
    }

    func swapJWT(completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let urlString = "\(credentials!.protocol)://\(credentials!.domain ?? "")\(kSFOAuthEndPointToken)"
        let request = NSMutableURLRequest(url: URL(string: urlString)!,
                                         cachePolicy: .reloadIgnoringLocalCacheData,
                                         timeoutInterval: timeout)
        let grantType = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        let bodyStr = "grant_type=\(grantType.sfsdk_stringByURLEncoding)&assertion=\(credentials!.jwt!)"
        let body = bodyStr.data(using: .utf8)
        request.httpBody = body
        request.httpMethod = kHttpMethodPost
        request.setValue(kHttpPostContentType, forHTTPHeaderField: kHttpHeaderContentType)

        session?.dataTask(with: request as URLRequest, completionHandler: completionHandler).resume()
    }

    // Refresh token migration
    @objc public func migrateRefreshToken(_ user: UserAccount) {
        authInfo = SFOAuthInfo(authType: .refreshTokenMigration)
        initialRequestLoaded = false

        // Use the single access bridge API to get a front door URL for the new app
        let approvalUrl = URL(string: generateApprovalUrlString())!
        let approvalPath = approvalUrl.path + (approvalUrl.query != nil ? "?\(approvalUrl.query!)" : "")

        guard let restClient = RestClient.restClient(for: user) else { return }
        let singleAccessRequest = restClient.requestForSingleAccess(approvalPath)

        restClient.send(singleAccessRequest, failureBlock: { [weak self] (_: Any?, error: Error?, _: URLResponse?) in
            if let authFailureCallback = self?.authSession?.authFailureCallback,
               let authInfo = self?.authInfo,
               let error = error as NSError? {
                authFailureCallback(authInfo, error)
            }
        }, successBlock: { [weak self] (response: Any?, _: URLResponse?) in
            guard let self = self else { return }
            if let frontDoorUrlString = (response as? [String: Any])?["frontdoor_uri"] as? String {
                self.loadWebView(withUrlString: frontDoorUrlString, cookie: true)
            }
        })
    }

    // IDP related
    func computeAuthorizationPathForSP() -> String {
        let approvalUrlString = approvalURL(forEndpoint: kSFOAuthEndPointAuthorize,
                                           credentials: spAppCredentials!,
                                           webServerFlow: true,
                                           protocol: "https",
                                           domain: credentials!.domain,
                                           codeChallenge: spAppCredentials!.challengeString)

        // Create an NSURL from the string
        let approvalUrl = URL(string: approvalUrlString)!

        // Extract everything but the protocol and domain
        let approvalPath = approvalUrl.path + (approvalUrl.query != nil ? "?\(approvalUrl.query!)" : "")

        return approvalPath
    }

    func loadWebView(withUrlString urlString: String, cookie enableCookie: Bool) {
        guard let urlToLoad = URL(string: urlString) else {
            SFSDKCoreLogger.d(type(of: self), message: "\(#function) Invalid URL, unable to load web view for '\(authInfo.authTypeDescription)' auth flow")
            let error = NSError(domain: kSFOAuthErrorDomain, code: kSFOAuthErrorInvalidURL, userInfo: nil)
            notifyDelegateOfFailure(error, authInfo: authInfo)
            return
        }

        let request = NSMutableURLRequest(url: urlToLoad)
        request.httpShouldHandleCookies = enableCookie
        request.cachePolicy = .reloadIgnoringLocalCacheData // don't use cache
        SFSDKCoreLogger.d(type(of: self), message: "\(#function) Loading web view for '\(authInfo.authTypeDescription)' auth flow, with URL: \(urlToLoad.sfsdk_redactedAbsoluteString(["sid"]))")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // If a valid overriding Salesforce Identity API UI Bridge front door bridge is present, load it.
            if let frontdoorBridgeUrl = self.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl {
                self.view.load(URLRequest(url: frontdoorBridgeUrl))
            } else {
                self.view.load(request as URLRequest)
            }
        }
    }

    @objc public func updateCredentials(_ params: [String: Any]) {
        credentials?.updateCredentials(params)
    }

    func beginTokenEndpointFlow() {
        responseData = NSMutableData(length: 512)
        let request = SFSDKOAuthTokenEndpointRequest()
        request.additionalOAuthParameterKeys = additionalOAuthParameterKeys
        request.additionalTokenRefreshParams = additionalTokenRefreshParams?.compactMapValues { $0 as? String }
        request.clientID = credentials!.clientId ?? ""
        request.refreshToken = credentials!.refreshToken ?? ""
        request.redirectURI = credentials!.redirectUri ?? ""
        request.serverURL = credentials!.overrideDomainIfNeeded() ?? URL(string: "https://login.salesforce.com")!

        // TODO: Remove in Mobile SDK 14.0
        #if !swift(>=5.5)
        request.userAgentForAuth = userAgentForAuth
        #endif

        if let approvalCode = approvalCode {
            SFSDKCoreLogger.i(type(of: self), message: "\(#function): Initiating authorization code flow.")
            request.approvalCode = approvalCode
            // Choose either the default generated code verifier or the code verifier matching the overriding Salesforce Identity API UI Bridge front door bridge.
            request.codeVerifier = frontdoorBridgeLoginOverride?.codeVerifier ?? codeVerifier
            authClient.accessToken(forApprovalCode: request) { [weak self] response in
                self?.handleResponse(response)
            }
        } else {
            // Assumes refresh token flow.
            SFSDKCoreLogger.i(type(of: self), message: "\(#function): Initiating refresh token flow.")
            authClient.accessToken(forRefresh: request) { [weak self] response in
                self?.handleResponse(response)
            }
        }
    }

    func beginHeadlessNativeLoginFlow() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.beginHeadlessNativeLoginFlow()
            }
            return
        }

        delegate?.oauthCoordinatorDidBeginNativeAuthentication(self)
    }

    func handleResponse(_ response: SFSDKOAuthTokenEndpointResponse) {
        if !response.hasError {
            // Check if refresh token scope is present in the response
            let scopeParser = ScopeParser(scopes: response.scopes)
            if !scopeParser.hasRefreshTokenScope() {
                SFSDKCoreLogger.w(type(of: self), message: "Missing refresh token scope.")
            }
            credentials?.updateCredentials(response.asDictionary())
            if let additionalFields = response.additionalOAuthFields {
                credentials?.additionalOAuthFields = additionalFields as NSDictionary
            }
            notifyDelegateOfSuccess(authInfo)
        } else {
            if let error = response.error?.error {
                if error.code == NSURLErrorTimedOut {
                    SFSDKCoreLogger.d(type(of: self), message: "Refresh attempt timed out after \(timeout) seconds.")
                    stopAuthentication()
                }
                notifyDelegateOfFailure(error, authInfo: authInfo)
                responseData = NSMutableData(capacity: Int(kSFOAuthReponseBufferLength))
            }
        }
    }

    func checkFrontdoorResponseForErrors(_ requestUrl: URL) -> Error? {
        var error: Error?
        let ecValue = requestUrl.sfsdk_valueForParameterName(kSFECParameter)
        let foundValidEcValue = (ecValue == "301" || ecValue == "302")
        let errorCode = requestUrl.sfsdk_valueForParameterName(kSFOAuthError)
        let errorDescription = requestUrl.sfsdk_valueForParameterName(kSFOAuthErrorDescription)

        if foundValidEcValue {
            SFSDKCoreLogger.d(type(of: self), message: "\(#function) IDP Authcode redirect response encountered an ec=301 or 302 redirect: \(requestUrl)")
            error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "IDP Authcode redirect response encountered an ec=301 or 302 redirect")
        } else if let errorCode = errorCode {
            error = SFSDKOAuth2.error(withType: errorCode, description: errorDescription ?? "")
        } else if requestUrl.fragment == nil && requestUrl.query == nil {
            SFSDKCoreLogger.d(type(of: self), message: "\(#function) Error: IDP Authcode response has no payload: \(requestUrl)")
            error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "IDP Authcode redirect response has no payload")
        }
        return error
    }

    func handleIDPAuthCodeResponse(_ requestUrl: URL) {
        let error = checkFrontdoorResponseForErrors(requestUrl)

        // all error cases should be handled by the above call
        if let error = error {
            var finalError: Error
            // add any additional relevant info to the userInfo dictionary
            if (error as NSError).code == kSFOAuthErrorInvalidClientId {
                var dict = (error as NSError).userInfo
                dict[kSFOAuthClientId] = credentials!.clientId
                finalError = NSError(domain: (error as NSError).domain, code: (error as NSError).code, userInfo: dict)
            } else {
                finalError = error
            }
            notifyDelegateOfFailure(finalError, authInfo: authInfo)
        } else {
            // Should have a valid response here. Must be a fragment or query. No Errors in response, no ec=*
            let response = requestUrl.fragment ?? requestUrl.query
            if let response = response {
                let params = SFSDKOAuth2.parseQueryString(response, decodeParams: false)
                spAppCredentials?.authCode = params[kSFOAuthApprovalCode] as? String
                delegate?.oauthCoordinatorDidFetchAuthCode?(self, authInfo: authInfo)
            }
        }
    }

    func handleUserAgentResponse(_ requestUrl: URL) {
        var response: String?

        // Check for a response in the URL fragment first, then fall back to the query string.
        if let fragment = requestUrl.fragment {
            response = fragment
        } else if let query = requestUrl.query {
            response = query
        } else {
            SFSDKCoreLogger.d(type(of: self), message: "\(#function) Error: response has no payload: \(requestUrl)")
            let error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "redirect response has no payload")
            notifyDelegateOfFailure(error, authInfo: authInfo)
            response = nil
        }

        if let response = response {
            let params = SFSDKOAuth2.parseQueryString(response)
            let errorParam = params[kSFOAuthError] as? String
            if errorParam == nil {
                credentials?.updateCredentials(params)
                credentials?.refreshToken = params[kSFOAuthRefreshToken] as? String
                // Parse additional flags
                if let additionalKeys = additionalOAuthParameterKeys, !additionalKeys.isEmpty {
                    var parsedValues: [String: Any] = [:]
                    for key in additionalKeys {
                        if let obj = params[key] {
                            parsedValues[key] = obj
                        }
                    }
                    credentials?.additionalOAuthFields = parsedValues as NSDictionary
                }
                notifyDelegateOfSuccess(authInfo)
            } else {
                var finalError: Error
                let error = SFSDKOAuth2.error(withType: params[kSFOAuthError] as? String ?? "",
                                             description: params[kSFOAuthErrorDescription] as? String ?? "")

                // add any additional relevant info to the userInfo dictionary
                if error.code == kSFOAuthErrorInvalidClientId {
                    var dict = (error as NSError).userInfo
                    dict[kSFOAuthClientId] = credentials!.clientId
                    finalError = NSError(domain: error.domain, code: error.code, userInfo: dict)
                } else {
                    finalError = error
                }
                notifyDelegateOfFailure(finalError, authInfo: authInfo)
            }
        }
    }

    @objc public func generateApprovalUrlString() -> String {
        return approvalURL(forEndpoint: brandedAuthorizeURL(),
                         credentials: credentials!,
                         webServerFlow: (useBrowserAuth || SalesforceManager.shared.useWebServerAuthentication),
                         protocol: nil,
                         domain: nil,
                         codeChallenge: nil)
    }

    func approvalURL(forEndpoint authorizeEndpoint: String,
                    credentials: OAuthCredentials,
                    webServerFlow: Bool,
                    protocol: String?,
                    domain: String?,
                    codeChallenge: String?) -> String {
        let protocolToUse = `protocol` ?? credentials.protocol
        let domainToUse = domain ?? credentials.domain

        assert(domainToUse != nil, "domain is required")
        assert(credentials.clientId != nil, "credentials.clientId is required")
        assert(credentials.redirectUri != nil, "credentials.redirectUri is required")

        // E.g. https://login.salesforce.com/services/oauth2/authorize
        //      ?client_id=<Connected App ID>&redirect_uri=<Connected App Redirect URI>&display=touch
        //      &response_type=code
        var approvalUrlString = "\(protocolToUse)://\(domainToUse)\(authorizeEndpoint)?\(kSFOAuthClientId)=\(credentials.clientId)&\(kSFOAuthRedirectUri)=\(credentials.redirectUri)&\(kSFOAuthDisplay)=\(kSFOAuthDisplayTouch)&\(kSFOAuthDeviceId)=\(UIDevice.current.identifierForVendor!.uuidString)"

        if webServerFlow {
            approvalUrlString += "&\(kSFOAuthResponseType)=\(kSFOAuthResponseTypeCode)"

            var codeChallengeToUse = codeChallenge
            if codeChallengeToUse == nil {
                // Code verifier challenge:
                //   - self.codeVerifier is a Base64 URL-Safe encoded (Note, not URL encoded) random data string
                //   - The code challenge sent here is an SHA-256 hash of self.codeVerifier, also Base64 URL-Safe encoded
                //   - Later, self.codeVerifier will be sent to the service, to be used to compare against the initial code challenge sent here.
                codeVerifier = (CryptoUtils.randomByteData(withLength: kSFOAuthCodeVerifierByteLength) as NSData).sfsdk_base64UrlString
                codeChallengeToUse = ((codeVerifier!.data(using: .utf8)! as NSData).sfsdk_sha256Data! as NSData).sfsdk_base64UrlString
            }
            approvalUrlString += "&\(kSFOAuthCodeChallengeParamName)=\(codeChallengeToUse!)"
        } else { // User-Agent
            let responseType = SalesforceManager.shared.useHybridAuthentication ? kSFOAuthResponseTypeHybridToken : kSFOAuthResponseTypeToken
            approvalUrlString += "&\(kSFOAuthResponseType)=\(responseType)"
        }

        // OAuth scopes
        let scopeString = scopeQueryParamString(credentials.scopes ?? [])
        if !scopeString.isEmpty {
            approvalUrlString += scopeString
        }

        if let loginHint = loginHint {
            approvalUrlString += "&login_hint=\(loginHint)"
        }

        return approvalUrlString
    }

    /**
     * Resets all state related to Salesforce Identity API UI Bridge front door bridge URL log in to its default
     * inactive state.
     */
    func clearFrontDoorBridgeLoginOverride() {
        frontdoorBridgeLoginOverride = nil
    }

    @objc public func scopeQueryParamString(_ scopes: [String]) -> String {
        if !scopes.isEmpty {
            let scopeStr = ScopeParser.computeScopeParameterWithURLEncoding(scopes: Set(scopes))
            return "&\(kSFOAuthScope)=\(scopeStr)"
        } else {
            return ""
        }
    }

    func handleCustomDomainUpdate(withLoginHint loginHint: String?, myDomain: String) {
        domainUpdated = true
        stopAuthentication()
        self.loginHint = loginHint
        // Note: domain is private(set), so we create new credentials with updated domain
        if let oldCreds = credentials {
            credentials = OAuthCredentials(identifier: oldCreds.identifier, clientId: oldCreds.clientId, encrypted: oldCreds.isEncrypted)
            credentials?.updateCredentials(["instance_url": "https://\(myDomain)"])
        }
        UserAccountManager.shared.loginHost = myDomain
        authenticate()
    }

    func handleWebServerResponse(_ appUrlResponse: URL) -> Bool {
        let appUrlResponseString = appUrlResponse.absoluteString
        if !appUrlResponseString.lowercased().hasPrefix((credentials!.redirectUri ?? "").lowercased()) {
            SFSDKCoreLogger.i(type(of: self), message: "\(#function) URL does not match redirect URI.")

            if isBiometricPromptURL(appUrlResponseString) {
                SFSDKCoreLogger.i(type(of: self), message: "Caught biometric request scheme.  Showing native biometric prompt.")

                let bioAuthManager = SFBiometricAuthenticationManagerInternal.shared
                if bioAuthManager.locked && bioAuthManager.hasBiometricOptedIn(),
                   let windowScene = view.window?.windowScene {
                    bioAuthManager.presentBiometric(scene: windowScene)
                }
            }

            return false
        }

        guard let query = appUrlResponse.query, !query.isEmpty else {
            SFSDKCoreLogger.i(type(of: self), message: "\(#function) URL has no query string.")
            return false
        }

        let queryDict = SFSDKOAuth2.parseQueryString(query, decodeParams: false)
        guard let codeVal = queryDict[kSFOAuthResponseTypeCode] as? String, !codeVal.isEmpty else {
            SFSDKCoreLogger.i(type(of: self), message: "\(#function) URL has no '\(kSFOAuthResponseTypeCode)' parameter value.")
            return false
        }

        approvalCode = codeVal
        SFSDKCoreLogger.i(type(of: self), message: "\(#function) Received web server response.  Beginning token exchange.")
        DispatchQueue.main.async { [weak self] in
            self?.beginTokenEndpointFlow()
        }
        return true
    }

    func isRedirectURL(_ requestUrlString: String) -> Bool {
        return credentials?.redirectUri != nil && requestUrlString.lowercased().hasPrefix((credentials!.redirectUri ?? "").lowercased())
    }

    func isSPAppRedirectURL(_ requestUrlString: String) -> Bool {
        return spAppCredentials?.redirectUri != nil && requestUrlString.lowercased().hasPrefix((spAppCredentials!.redirectUri ?? "").lowercased())
    }

    func isBiometricPromptURL(_ requestedUrlString: String) -> Bool {
        return requestedUrlString == "mobilesdk://biometric/authentication/prompt"
    }

    func shouldUpdateDomain(_ webviewURL: URL) -> Bool {
        guard let regex = SalesforceManager.shared.customDomainInferencePattern,
              !domainUpdated,
              credentials?.domain != webviewURL.host else {
            return false
        }
        let urlString = webviewURL.absoluteString
        return regex.firstMatch(in: urlString, options: [], range: NSRange(location: 0, length: urlString.count)) != nil
    }

    func startWebviewAuthenticationIfNeeded() {
        if !initialRequestLoaded {
            initialRequestLoaded = true
            startAuthentication(with: view)
        }
    }

    func startAuthentication(with view: WKWebView) {
        delegate?.oauthCoordinator(self, didBeginAuthenticationWith: view)
    }

    func sfwebView(_ webView: WKWebView, didFailLoadWithError error: Error) {
        delegate?.oauthCoordinator?(self, didFinishLoad: webView, error: error)

        let requestUrl = webView.url
        let errorUrlString = "\(requestUrl?.scheme ?? "")://\(requestUrl?.host ?? "")\(requestUrl?.relativePath ?? "")"

        if (error as NSError).code == -999 {
            // -999 errors (operation couldn't be completed) occur during normal execution, therefore only log for debugging
            SFSDKCoreLogger.d(type(of: self), message: "SFOAuthCoordinator:didFailLoadWithError: error code: \((error as NSError).code), description: \(error.localizedDescription), URL: \(errorUrlString)")
        } else {
            SFSDKCoreLogger.d(type(of: self), message: "SFOAuthCoordinator:didFailLoadWithError: error code: \((error as NSError).code), description: \(error.localizedDescription), URL: \(errorUrlString)")
            notifyDelegateOfFailure(error, authInfo: authInfo)
        }
    }

    func brandedAuthorizeURL() -> String {
        var brandedAuthorizeURL = kSFOAuthEndPointAuthorize
        if let brandLoginPath = brandLoginPath, !brandLoginPath.sfsdk_isEmptyOrWhitespaceAndNewlines {
            var urlString = brandLoginPath
            // get rid of leading and trailing slash
            if urlString.hasPrefix("/") {
                urlString.removeFirst()
            }

            if urlString.hasSuffix("/") {
                urlString.removeLast()
            }

            brandedAuthorizeURL += "/\(urlString)"
        }
        return brandedAuthorizeURL
    }
}

// MARK: - WKNavigationDelegate (User-Agent Token Flow)
extension SFOAuthCoordinator: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let requestUrl = url.absoluteString

        // Determine if presence of discovery domain, then handle if present.
        if let discoveryResult = domainDiscoveryCoordinator.handle(action: navigationAction) {
            handleCustomDomainUpdate(withLoginHint: discoveryResult.loginHint, myDomain: discoveryResult.myDomain)
            decisionHandler(.cancel)
        } else if isRedirectURL(requestUrl) {
            // If a front door bridge URL override is present, use its code verifier to choose between user agent or web server authentication.
            if frontdoorBridgeLoginOverride?.frontdoorBridgeUrl != nil
                ? frontdoorBridgeLoginOverride?.codeVerifier != nil // If yes, only proceed if it's a web server flow as indicated by a code verifier.
                : (useBrowserAuth || SalesforceManager.shared.useWebServerAuthentication) { // If there's no override use browser auth or the default SDK setting.
                handleWebServerResponse(url) // Web server flow/URLs with query string parameters.
            } else {
                handleUserAgentResponse(url) // User agent flow/URLs with the fragment component.
            }
            decisionHandler(.cancel)
        } else if isSPAppRedirectURL(requestUrl) {
            handleIDPAuthCodeResponse(url)
            decisionHandler(.cancel)
        } else if isBiometricPromptURL(requestUrl) {
            SFSDKCoreLogger.i(type(of: self), message: "Caught biometric request scheme.  Showing native biometric prompt.")

            let bioAuthManager = SFBiometricAuthenticationManagerInternal.shared
            if bioAuthManager.locked && bioAuthManager.hasBiometricOptedIn(),
               let windowScene = view.window?.windowScene {
                bioAuthManager.presentBiometric(scene: windowScene)
            }
            decisionHandler(.allow)
        } else if shouldUpdateDomain(url) {
            // To support case where my domain is entered through "Use Custom Domain"
            handleCustomDomainUpdate(withLoginHint: loginHint, myDomain: url.host!)
            decisionHandler(.cancel)
        } else if let navigationPolicyForAction = UserAccountManager.shared.navigationPolicyForAction {
            decisionHandler(navigationPolicyForAction(webView, navigationAction))
        } else {
            decisionHandler(.allow)
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        let url = webView.url
        SFSDKCoreLogger.i(type(of: self), message: "\(#function) host=\(url?.host ?? "") : path=\(url?.path ?? "")")
        delegate?.oauthCoordinator?(self, didStartLoad: webView)

        if UserAccountManager.shared.showAuthWindowWhileLoading {
            startWebviewAuthenticationIfNeeded()
        }
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        sfwebView(webView, didFailLoadWithError: error)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        delegate?.oauthCoordinator?(self, didFinishLoad: webView, error: nil)

        if !UserAccountManager.shared.showAuthWindowWhileLoading {
            startWebviewAuthenticationIfNeeded()
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        sfwebView(webView, didFailLoadWithError: error)
    }
}

// MARK: - WKUIDelegate
extension SFOAuthCoordinator: WKUIDelegate {

    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        if delegate?.oauthCoordinator(_:displayAlertMessage:completion:) != nil {
            delegate?.oauthCoordinator?(self, displayAlertMessage: message, completion: completionHandler)
        } else {
            SFSDKCoreLogger.w(type(of: self), message: "WKWebView did want to display an alert but no delegate responded to it")
        }
    }

    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        if delegate?.oauthCoordinator(_:displayConfirmationMessage:completion:) != nil {
            delegate?.oauthCoordinator?(self, displayConfirmationMessage: message, completion: completionHandler)
        } else {
            SFSDKCoreLogger.w(type(of: self), message: "WKWebView did want to display a confirmation alert but no delegate responded to it")
        }
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let createWebview = UserAccountManager.shared.createWebview {
            return createWebview(webView, configuration, navigationAction, windowFeatures)
        }
        return nil
    }
}

// MARK: - Helper extension for Optional checking
private extension Optional {
    var isSome: Bool {
        switch self {
        case .none:
            return false
        case .some:
            return true
        }
    }
}
