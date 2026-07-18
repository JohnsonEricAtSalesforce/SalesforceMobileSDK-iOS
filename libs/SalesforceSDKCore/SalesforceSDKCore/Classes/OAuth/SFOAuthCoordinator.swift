// Copyright (c) 2011-present, salesforce.com, inc. All rights reserved.
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

import AuthenticationServices
import Security
import UIKit
import WebKit
import SalesforceSDKCommon

/// Callback block used for the browser flow authentication.
public typealias SFOAuthBrowserFlowCallbackBlock = (Bool) -> Void

/// Protocol for objects intending to be a delegate for an OAuth coordinator.
@objc(SFOAuthCoordinatorDelegate)
public protocol SFOAuthCoordinatorDelegate: NSObjectProtocol {

    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginAuthenticationWithView view: WKWebView)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didStartLoad view: WKWebView)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFinishLoad view: WKWebView, error: Error?)
    @objc optional func oauthCoordinatorWillBeginAuthentication(_ coordinator: SFOAuthCoordinator, authInfo info: SFOAuthInfo)
    @objc optional func oauthCoordinatorDidAuthenticate(_ coordinator: SFOAuthCoordinator, authInfo info: SFOAuthInfo)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didFailWithError error: Error, authInfo info: SFOAuthInfo?)
    @objc optional func oauthCoordinatorIsNetworkAvailable(_ coordinator: SFOAuthCoordinator) -> Bool
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, willBeginBrowserAuthentication callbackBlock: @escaping SFOAuthBrowserFlowCallbackBlock)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, displayAlertMessage message: String, completion: @escaping () -> Void)
    @objc optional func oauthCoordinator(_ coordinator: SFOAuthCoordinator, displayConfirmationMessage message: String, completion: @escaping (Bool) -> Void)
    @objc optional func oauthCoordinatorDidFetchAuthCode(_ coordinator: SFOAuthCoordinator, authInfo: SFOAuthInfo)

    // Required
    @objc func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithView view: WKWebView)
    @objc func oauthCoordinator(_ coordinator: SFOAuthCoordinator, didBeginAuthenticationWithSession session: ASWebAuthenticationSession)
    @objc func oauthCoordinatorDidBeginNativeAuthentication(_ coordinator: SFOAuthCoordinator)
    @objc func oauthCoordinatorDidCancelBrowserAuthentication(_ coordinator: SFOAuthCoordinator)
}

/// Enumeration for token endpoint flow types.
@objc(SFOAuthTokenEndpointFlow)
public enum SFOAuthTokenEndpointFlow: UInt {
    case none = 0
    case refresh
    case advancedBrowser
}

/// The SFOAuthCoordinator class is the central class of the OAuth2 authentication process.
@objc(SFOAuthCoordinator)
@objcMembers
public class SFOAuthCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

    // MARK: - Public Properties

    public var credentials: OAuthCredentials?
    public weak var delegate: SFOAuthCoordinatorDelegate?
    public var scopes: NSSet?
    public var timeout: TimeInterval = kSFOAuthDefaultTimeout
    public var additionalOAuthParameterKeys: [String] = []
    public var additionalTokenRefreshParams: [String: Any] = [:]
    public var brandLoginPath: String = ""
    public var useBrowserAuth: Bool = false
    public var authClient: SFSDKOAuthProtocol
    public var useNativeAuth: Bool = false

    // MARK: - Internal Properties

    var authenticating: Bool = false
    var responseData: NSMutableData?
    var initialRequestLoaded: Bool = false
    var domainUpdated: Bool = false
    var approvalCode: String?
    var codeVerifier: String?
    var authInfo: SFOAuthInfo = SFOAuthInfo(authType: .unknown)
    var origWebUserAgent: String?
    var spAppCredentials: OAuthCredentials?
    weak var authSession: SFSDKAuthSession?
    var frontdoorBridgeLoginOverride: AuthCoordinatorFrontdoorBridgeLoginOverride?
    var loginHint: String?

    private var networkIdentifier: String?
    private var domainDiscoveryCoordinator: DomainDiscoveryCoordinator
    private var _view: WKWebView?
    private var _asWebAuthenticationSession: ASWebAuthenticationSession?
    private var _session: URLSession?

    // MARK: - Computed Properties

    public var view: WKWebView {
        if _view == nil {
            let config = WKWebViewConfiguration()
            let scene = authSession?.oauthRequest.scene as? UIWindowScene
            var bounds = scene?.coordinateSpace.bounds ?? .zero
            #if !os(visionOS)
            if scene == nil {
                bounds = UIScreen.main.bounds
            }
            #endif
            let webView = WKWebView(frame: bounds, configuration: config)
            webView.navigationDelegate = self
            webView.autoresizesSubviews = true
            webView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            webView.clipsToBounds = true
            webView.translatesAutoresizingMaskIntoConstraints = false
            webView.customUserAgent = SalesforceSDKManager.shared.userAgentString?("") ?? ""
            webView.isInspectable = SalesforceSDKManager.shared.isLoginWebviewInspectable
            webView.uiDelegate = self
            _view = webView
        }
        return _view ?? WKWebView()
    }

    public var asWebAuthenticationSession: ASWebAuthenticationSession? {
        return _asWebAuthenticationSession
    }

    private var session: URLSession {
        if _session == nil {
            networkIdentifier = Network.uniqueInstanceIdentifier()
            if let id = networkIdentifier {
                let network = Network.sharedEphemeralInstance(withIdentifier: id)
                _session = network.activeSession
            }
        }
        return _session ?? URLSession.shared
    }

    // MARK: - Initialization

    @objc public override convenience init() {
        self.init(credentials: nil)
    }

    @objc public init(credentials: OAuthCredentials?) {
        self.credentials = credentials
        self.authClient = SFSDKOAuth2()
        self.domainDiscoveryCoordinator = DomainDiscoveryCoordinator()
        super.init()
    }

    @objc public init(authSession: SFSDKAuthSession) {
        self.authSession = authSession
        self.credentials = authSession.credentials
        self.authClient = SFSDKOAuth2()
        self.domainDiscoveryCoordinator = DomainDiscoveryCoordinator()
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let id = networkIdentifier {
            Network.removeSharedInstance(forIdentifier: id)
        }
    }

    // MARK: - Authentication Control

    @objc public func authenticate() {
        NSAssert(credentials != nil, "credentials cannot be nil")
        NSAssert((credentials?.clientId?.count ?? 0) > 0, "credentials.clientId cannot be nil or empty")
        NSAssert((credentials?.identifier.count ?? 0) > 0, "credentials.identifier cannot be nil or empty")
        NSAssert((credentials?.domain?.count ?? 0) > 0, "credentials.domain cannot be nil or empty.")
        NSAssert(delegate != nil, "cannot authenticate with nil delegate")

        guard !authenticating else {
            SFSDKCoreLogger.d(Self.self, format: "%@ Error: authenticate called while already authenticating. Call stopAuthenticating first.", #function)
            return
        }

        SFSDKCoreLogger.d(Self.self, format: "%@ authenticating as %@ %@ refresh token on '%@://%@' ...",
                          #function,
                          credentials?.clientId ?? "",
                          credentials?.refreshToken == nil ? "without" : "with",
                          credentials?.protocol ?? "",
                          credentials?.domain ?? "")
        authenticating = true

        if credentials?.refreshToken != nil {
            authInfo = SFOAuthInfo(authType: .refresh)
        } else if useBrowserAuth {
            authInfo = SFOAuthInfo(authType: .advancedBrowser)
        } else if SalesforceSDKManager.shared.useWebServerAuthentication {
            authInfo = SFOAuthInfo(authType: .webServer)
        } else {
            authInfo = SFOAuthInfo(authType: .userAgent)
        }

        // Don't try to authenticate if there is no network available
        if let del = delegate, del.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinatorIsNetworkAvailable(_:))) {
            if del.oauthCoordinatorIsNetworkAvailable?(self) == false {
                SFSDKCoreLogger.d(Self.self, format: "Network is not available, so bypassing login")
                let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
                notifyDelegateOfFailure(error, authInfo: authInfo)
                return
            }
        }

        if credentials?.refreshToken != nil {
            notifyDelegateOfBeginAuthentication()
            beginTokenEndpointFlow()
        } else if credentials?.jwt != nil {
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
            } else if frontdoorBridgeLoginOverride == nil && useBrowserAuth {
                SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.authInfo = SFOAuthInfo(authType: .advancedBrowser)
                    self.notifyDelegateOfBeginAuthentication()
                    self.beginNativeBrowserFlow(withSharedBrowserSessionEnabled: false)
                }
            } else {
                let loginDomain: String
                if let overrideHost = frontdoorBridgeLoginOverride?.frontdoorBridgeUrl?.host {
                    loginDomain = overrideHost
                } else {
                    loginDomain = credentials?.domain ?? ""
                }
                SFSDKAuthConfigUtil.getMyDomainAuthConfig({ [weak self] authConfig, _ in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if self.frontdoorBridgeLoginOverride == nil && (authConfig?.useNativeBrowserForAuth ?? false) {
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

    @objc public func authenticate(withCredentials credentials: OAuthCredentials) {
        self.credentials = credentials
        if domainDiscoveryCoordinator.isDiscoveryDomain(credentials.domain ?? "") {
            SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureWelcomeDiscovery)
            runMyDomainDiscoveryAndAuthenticate()
            return
        } else {
            SFSDKAppFeatureMarkers.unregisterAppFeature(kSFAppFeatureWelcomeDiscovery)
        }
        authenticate()
    }

    @objc public func isAuthenticating() -> Bool {
        return authenticating
    }

    @objc public func stopAuthentication() {
        _view?.stopLoading()
        _session?.invalidateAndCancel()
        _session = nil
        networkIdentifier = nil
        authenticating = false
        authInfo = SFOAuthInfo(authType: .unknown)
    }

    @objc public func revokeAuthentication() {
        stopAuthentication()
        credentials?.revoke()
    }

    @objc @discardableResult
    public func handleAdvancedAuthenticationResponse(_ appUrlResponse: URL) -> Bool {
        authInfo = SFOAuthInfo(authType: .advancedBrowser)
        let success = handleWebServerResponse(appUrlResponse)
        if success {
            authInfo = SFOAuthInfo(authType: .advancedBrowser)
        }
        return success
    }

    @objc @discardableResult
    public func handleIDPAuthenticationResponse(_ appUrlResponse: URL) -> Bool {
        authInfo = SFOAuthInfo(authType: .idp)
        guard let query = appUrlResponse.query, query.count > 0 else {
            SFSDKCoreLogger.i(Self.self, format: "%@ URL has no query string.", #function)
            return false
        }

        guard let codeVal = (appUrlResponse as NSURL).sfsdk_value(forParameterName: "code"), codeVal.count > 0 else {
            SFSDKCoreLogger.i(Self.self, format: "%@ URL has no 'code' parameter value.", #function)
            return false
        }
        approvalCode = codeVal

        if let keychainReference = (appUrlResponse as NSURL).sfsdk_value(forParameterName: SFSDKIDPConstants.kSFKeychainReferenceParam) {
            let keychainGroup = (appUrlResponse as NSURL).sfsdk_value(forParameterName: SFSDKIDPConstants.kSFKeychainGroupParam)
            let result = KeychainHelper.read(service: keychainReference, account: nil, accessGroup: keychainGroup, cacheMode: .disabled)
            if let codeV = (result.data as NSData?)?.sfsdk_base64UrlString(), result.error == nil {
                codeVerifier = codeV
            } else {
                SFSDKCoreLogger.e(Self.self, format: "URL has keychain group parameter but unable to retrieve value from the keychain: %@", result.error?.localizedDescription ?? "")
                return false
            }
        }

        SFSDKCoreLogger.i(Self.self, format: "%@ Received advanced authentication response. Beginning token exchange.", #function)
        DispatchQueue.main.async { [weak self] in
            self?.beginTokenEndpointFlow()
        }
        return true
    }

    @objc public func beginIDPFlow(_ user: UserAccount, success successBlock: @escaping () -> Void, failure failureBlock: @escaping (Error) -> Void) {
        authInfo = SFOAuthInfo(authType: .idp)
        initialRequestLoaded = false
        if credentials?.accessToken != nil, credentials?.apiUrl != nil {
            let approvalPathForSP = computeAuthorizationPathForSP()
            guard let restClient = RestClient.restClient(for: user) else { return }
            let singleAccessRequest = restClient.requestForSingleAccess(approvalPathForSP)
            restClient.send(singleAccessRequest, failureBlock: { _, error, _ in
                if let error = error { failureBlock(error) }
            }, successBlock: { [weak self] response, _ in
                guard let self = self else { return }
                successBlock()
                if let dict = response as? [String: Any], let frontDoorUrlString = dict["frontdoor_uri"] as? String {
                    self.loadWebView(withUrlString: frontDoorUrlString, cookie: true)
                }
            })
        }
    }

    // MARK: - Private Methods

    private func runMyDomainDiscoveryAndAuthenticate() {
        startWebviewAuthenticationIfNeeded()
        guard let creds = credentials else { return }
        domainDiscoveryCoordinator.runMyDomainsDiscovery(on: view, with: creds)
    }

    func notifyDelegateOfFailure(_ error: Error, authInfo info: SFOAuthInfo) {
        authenticating = false
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:didFailWithError:authInfo:))) ?? false {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.oauthCoordinator?(self, didFailWithError: error, authInfo: info)
            }
        }
        clearFrontDoorBridgeLoginOverride()
    }

    func notifyDelegateOfSuccess(_ authInfo: SFOAuthInfo) {
        authenticating = false
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinatorDidAuthenticate(_:authInfo:))) ?? false {
            delegate?.oauthCoordinatorDidAuthenticate?(self, authInfo: authInfo)
        }
        clearFrontDoorBridgeLoginOverride()
    }

    private func notifyDelegateOfBeginAuthentication() {
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinatorWillBeginAuthentication(_:authInfo:))) ?? false {
            delegate?.oauthCoordinatorWillBeginAuthentication?(self, authInfo: authInfo)
        }
    }

    private func beginNativeBrowserFlow(withSharedBrowserSessionEnabled shareBrowserSession: Bool) {
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:willBeginBrowserAuthentication:))) ?? false {
            delegate?.oauthCoordinator?(self, willBeginBrowserAuthentication: { [weak self] proceed in
                if proceed {
                    self?.continueNativeBrowserFlow(withSharedBrowserSessionEnabled: shareBrowserSession)
                }
            })
        } else {
            continueNativeBrowserFlow(withSharedBrowserSessionEnabled: shareBrowserSession)
        }
    }

    private func continueNativeBrowserFlow(withSharedBrowserSessionEnabled shareBrowserSession: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.continueNativeBrowserFlow(withSharedBrowserSessionEnabled: shareBrowserSession)
            }
            return
        }

        var approvalUrl = approvalURL(forEndpoint: brandedAuthorizeURL(), credentials: credentials, webServerFlow: true, protocolValue: nil, domain: nil, codeChallenge: nil)
        approvalUrl = "\(approvalUrl)&state=\(credentials?.identifier ?? "")"
        if !shareBrowserSession {
            approvalUrl = "\(approvalUrl)&prompt=login"
        }

        SFSDKCoreLogger.d(Self.self, format: "%@: Initiating native browser flow with URL %@", #function, approvalUrl)
        guard let nativeBrowserUrl = URL(string: approvalUrl) else { return }
        SFSDKAppFeatureMarkers.registerAppFeature(kSFAppFeatureSafariBrowserForLogin)

        let redirectScheme = URL(string: credentials?.redirectUri ?? "")?.scheme
        _asWebAuthenticationSession = ASWebAuthenticationSession(url: nativeBrowserUrl, callbackURLScheme: redirectScheme) { [weak self] callbackURL, error in
            guard let self = self else { return }
            if error == nil, let url = callbackURL, SFSDKURLHandlerManager.sharedInstance.canHandleRequest(url, options: nil) {
                let options: [AnyHashable: Any] = [UserAccountManager.IDPSceneKey: self.authSession?.sceneId ?? ""]
                SFSDKURLHandlerManager.sharedInstance.processRequest(url, options: options, completion: nil, failure: nil)
            } else {
                self.delegate?.oauthCoordinatorDidCancelBrowserAuthentication(self)
            }
        }
        _asWebAuthenticationSession?.prefersEphemeralWebBrowserSession = SalesforceSDKManager.shared.useEphemeralSessionForAdvancedAuth
        if let session = _asWebAuthenticationSession {
            delegate?.oauthCoordinator(self, didBeginAuthenticationWithSession: session)
        }
    }

    func beginWebViewFlow() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.beginWebViewFlow()
            }
            return
        }
        initialRequestLoaded = false
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:willBeginAuthenticationWithView:))) ?? false {
            delegate?.oauthCoordinator?(self, willBeginAuthenticationWithView: view)
        }
        let approvalUrlString = generateApprovalUrlString()
        loadWebView(withUrlString: approvalUrlString, cookie: true)
    }

    private func beginJwtTokenExchangeFlow() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.beginJwtTokenExchangeFlow()
            }
            return
        }
        NSAssert((credentials?.jwt?.count ?? 0) > 0, "JWT token should be present at this point.")
        swapJWT { [weak self] data, _, error in
            guard let self = self else { return }
            if let error = error {
                SFSDKCoreLogger.e(Self.self, format: "Fail to swap JWT for access token: %@", error.localizedDescription)
                self.notifyDelegateOfFailure(error, authInfo: self.authInfo)
                return
            }
            self.credentials?.setValue(nil, forKey: "jwt")
            guard let data = data, let json = SFJsonUtils.object(fromJSONData: data) as? [String: Any] else {
                let err = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeJWTLaunchFailed, description: "Error parsing JWT token exchange response.", underlyingError: SFJsonUtils.lastError())
                self.notifyDelegateOfFailure(err, authInfo: self.authInfo)
                return
            }
            if let oauthError = json[kSFOAuthError] as? String {
                let err = SFSDKOAuth2.error(withType: oauthError, description: json[kSFOAuthErrorDescription] as? String ?? "")
                self.notifyDelegateOfFailure(err, authInfo: self.authInfo)
                return
            }
            self.credentials?.update(json as [AnyHashable: Any])
            if self.credentials?.accessToken != nil, let apiUrl = self.credentials?.apiUrl {
                let baseUrlString = apiUrl.absoluteString
                let approvalUrlString = self.generateApprovalUrlString()
                let escapedApproval = approvalUrlString.sfsdk_stringByURLEncoding()
                let frontDoorUrlString = "\(baseUrlString)/secur/frontdoor.jsp?sid=\(self.credentials?.accessToken ?? "")&retURL=\(escapedApproval)"
                self.loadWebView(withUrlString: frontDoorUrlString, cookie: true)
            }
        }
    }

    private func swapJWT(completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let urlString = "\(credentials?.protocol ?? "https")://\(credentials?.domain ?? "")\(kSFOAuthEndPointToken)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
        let grantType = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        let bodyStr = "grant_type=\(grantType.sfsdk_stringByURLEncoding())&assertion=\(credentials?.jwt ?? "")"
        request.httpBody = bodyStr.data(using: .utf8)
        request.httpMethod = kHttpMethodPost
        request.setValue(kHttpPostContentType, forHTTPHeaderField: kHttpHeaderContentType)
        session.dataTask(with: request, completionHandler: completionHandler).resume()
    }

    func migrateRefreshToken(_ user: UserAccount) {
        authInfo = SFOAuthInfo(authType: .refreshTokenMigration)
        initialRequestLoaded = false

        let approvalUrlString = generateApprovalUrlString()
        guard let approvalUrl = URL(string: approvalUrlString) else { return }
        var approvalPath = approvalUrl.path
        if let query = approvalUrl.query {
            approvalPath += "?\(query)"
        }

        guard let restClient = RestClient.restClient(for: user) else { return }
        let singleAccessRequest = restClient.requestForSingleAccess(approvalPath)
        restClient.send(singleAccessRequest, failureBlock: { [weak self] _, error, _ in
            guard let self = self else { return }
            if let error = error {
                self.authSession?.authFailureCallback?(self.authInfo, error)
            }
        }, successBlock: { [weak self] response, _ in
            guard let self = self else { return }
            if let dict = response as? [String: Any], let frontDoorUrlString = dict["frontdoor_uri"] as? String {
                self.loadWebView(withUrlString: frontDoorUrlString, cookie: true)
            }
        })
    }

    private func computeAuthorizationPathForSP() -> String {
        guard let spCreds = spAppCredentials else { return "" }
        let approvalUrlString = approvalURL(forEndpoint: kSFOAuthEndPointAuthorize, credentials: spCreds, webServerFlow: true, protocolValue: "https", domain: credentials?.domain, codeChallenge: spCreds.challengeString)
        guard let approvalUrl = URL(string: approvalUrlString) else { return "" }
        var approvalPath = approvalUrl.path
        if let query = approvalUrl.query {
            approvalPath += "?\(query)"
        }
        return approvalPath
    }

    private func loadWebView(withUrlString urlString: String, cookie enableCookie: Bool) {
        guard let urlToLoad = URL(string: urlString) else {
            SFSDKCoreLogger.d(Self.self, format: "%@ Invalid URL, unable to load web view for '%@' auth flow", #function, authInfo.authTypeDescription)
            let error = NSError(domain: kSFOAuthErrorDomain, code: Int(kSFOAuthErrorInvalidURL), userInfo: nil)
            notifyDelegateOfFailure(error, authInfo: authInfo)
            return
        }

        var request = URLRequest(url: urlToLoad)
        request.httpShouldHandleCookies = enableCookie
        request.cachePolicy = .reloadIgnoringLocalCacheData
        SFSDKCoreLogger.d(Self.self, format: "%@ Loading web view for '%@' auth flow, with URL: %@", #function, authInfo.authTypeDescription, (urlToLoad as NSURL).sfsdk_redactedAbsoluteString(["sid"]))
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let overrideUrl = self.frontdoorBridgeLoginOverride?.frontdoorBridgeUrl {
                self.view.load(URLRequest(url: overrideUrl))
            } else {
                self.view.load(request)
            }
        }
    }

    @objc public func updateCredentials(_ params: [String: Any]) {
        credentials?.update(params as [AnyHashable: Any])
    }

    func beginTokenEndpointFlow() {
        responseData = NSMutableData(length: 512)
        let request = SFSDKOAuthTokenEndpointRequest()
        request.additionalOAuthParameterKeys = additionalOAuthParameterKeys
        request.additionalTokenRefreshParams = additionalTokenRefreshParams as NSDictionary
        request.clientID = credentials?.clientId ?? ""
        request.refreshToken = credentials?.refreshToken ?? ""
        request.redirectURI = credentials?.redirectUri ?? ""
        if let serverURL = credentials?.overrideDomainIfNeeded() {
            request.serverURL = serverURL
        }

        if let code = approvalCode {
            SFSDKCoreLogger.i(Self.self, format: "%@: Initiating authorization code flow.", #function)
            request.approvalCode = code
            request.codeVerifier = frontdoorBridgeLoginOverride?.codeVerifier ?? codeVerifier
            authClient.accessToken(forApprovalCode: request) { [weak self] response in
                guard let response = response else { return }
                self?.handleResponse(response)
            }
        } else {
            SFSDKCoreLogger.i(Self.self, format: "%@: Initiating refresh token flow.", #function)
            authClient.accessToken(forRefresh: request) { [weak self] response in
                guard let response = response else { return }
                self?.handleResponse(response)
            }
        }
    }

    private func beginHeadlessNativeLoginFlow() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.beginHeadlessNativeLoginFlow()
            }
            return
        }
        delegate?.oauthCoordinatorDidBeginNativeAuthentication(self)
    }

    private func handleResponse(_ response: SFSDKOAuthTokenEndpointResponse) {
        if !response.hasError {
            let scopeParser = ScopeParser(scopes: response.scopes)
            if !scopeParser.hasRefreshTokenScope() {
                SFSDKCoreLogger.w(Self.self, format: "Missing refresh token scope.")
            }
            credentials?.update(response.asDictionary() as? [AnyHashable: Any] ?? [:])
            if let additionalFields = response.additionalOAuthFields as? [AnyHashable: Any] {
                credentials?.setValue(additionalFields, forKey: "additionalOAuthFields")
            }
            notifyDelegateOfSuccess(authInfo)
        } else {
            if let err = response.error?.error {
                if err.code == NSURLErrorTimedOut {
                    SFSDKCoreLogger.d(Self.self, format: "Refresh attempt timed out after %f seconds.", timeout)
                    stopAuthentication()
                }
                notifyDelegateOfFailure(err, authInfo: authInfo)
                responseData = NSMutableData(capacity: Int(kSFOAuthReponseBufferLength))
            }
        }
    }

    func generateApprovalUrlString() -> String {
        return approvalURL(forEndpoint: brandedAuthorizeURL(), credentials: credentials, webServerFlow: useBrowserAuth || SalesforceSDKManager.shared.useWebServerAuthentication, protocolValue: nil, domain: nil, codeChallenge: nil)
    }

    private func approvalURL(forEndpoint authorizeEndpoint: String, credentials creds: OAuthCredentials?, webServerFlow: Bool, protocolValue: String?, domain: String?, codeChallenge: String?) -> String {
        let proto = protocolValue ?? creds?.protocol ?? "https"
        let dom = domain ?? creds?.domain ?? ""

        NSAssert(dom.count > 0, "domain is required")
        NSAssert(creds?.clientId != nil, "credentials.clientId is required")
        NSAssert(creds?.redirectUri != nil, "credentials.redirectUri is required")

        var approvalUrlString = "\(proto)://\(dom)\(authorizeEndpoint)?\(kSFOAuthClientId)=\(creds?.clientId ?? "")&\(kSFOAuthRedirectUri)=\(creds?.redirectUri ?? "")&\(kSFOAuthDisplay)=\(kSFOAuthDisplayTouch)&\(kSFOAuthDeviceId)=\(UIDevice.current.identifierForVendor?.uuidString ?? "")"

        if webServerFlow {
            approvalUrlString += "&\(kSFOAuthResponseType)=\(kSFOAuthResponseTypeCode)"
            var challenge = codeChallenge
            if challenge == nil {
                codeVerifier = (SFSDKCryptoUtils.randomByteData(withLength: UInt(kSFOAuthCodeVerifierByteLength)) as NSData).sfsdk_base64UrlString()
                if let verifier = codeVerifier, let verifierData = verifier.data(using: .utf8) {
                    challenge = (verifierData as NSData).sfsdk_sha256Data()?.sfsdk_base64UrlString()
                }
            }
            if let ch = challenge {
                approvalUrlString += "&\(kSFOAuthCodeChallengeParamName)=\(ch)"
            }
        } else {
            let responseType = SalesforceSDKManager.shared.useHybridAuthentication ? kSFOAuthResponseTypeHybridToken : kSFOAuthResponseTypeToken
            approvalUrlString += "&\(kSFOAuthResponseType)=\(responseType)"
        }

        let scopeString = self.scopeQueryParamString(creds?.scopes ?? [])
        if scopeString.count > 0 {
            approvalUrlString += scopeString
        }

        if let hint = loginHint {
            approvalUrlString += "&login_hint=\(hint)"
        }

        return approvalUrlString
    }

    private func clearFrontDoorBridgeLoginOverride() {
        frontdoorBridgeLoginOverride = nil
    }

    func scopeQueryParamString(_ scopes: [String]) -> String {
        if scopes.count > 0 {
            let scopeStr = ScopeParser.computeScopeParameterWithURLEncoding(scopes: NSSet(array: scopes) as? Set<String> ?? Set())
            return "&\(kSFOAuthScope)=\(scopeStr)"
        }
        return ""
    }

    private func handleCustomDomainUpdate(withLoginHint hint: String?, myDomain: String) {
        domainUpdated = true
        stopAuthentication()
        loginHint = hint
        credentials?.setValue(myDomain, forKey: "domain")
        UserAccountManager.shared.loginHost = myDomain
        authenticate()
    }

    private func brandedAuthorizeURL() -> String {
        var brandedUrl = kSFOAuthEndPointAuthorize
        if !brandLoginPath.isEmpty && !brandLoginPath.sfsdk_isEmptyOrWhitespaceAndNewlines() {
            var path = brandLoginPath
            if path.hasPrefix("/") { path.removeFirst() }
            if path.hasSuffix("/") { path.removeLast() }
            brandedUrl += "/\(path)"
        }
        return brandedUrl
    }

    @discardableResult
    private func handleWebServerResponse(_ appUrlResponse: URL) -> Bool {
        let appUrlResponseString = appUrlResponse.absoluteString
        guard let redirectUri = credentials?.redirectUri, appUrlResponseString.lowercased().hasPrefix(redirectUri.lowercased()) else {
            SFSDKCoreLogger.i(Self.self, format: "%@ URL does not match redirect URI.", #function)
            if isBiometricPromptURL(appUrlResponseString) {
                SFSDKCoreLogger.i(Self.self, format: "Caught biometric request scheme. Showing native biometric prompt.")
                let bioAuthManager = BiometricAuthenticationManagerInternal.shared
                if bioAuthManager.locked && bioAuthManager.hasBiometricOptedIn(), let scene = view.window?.windowScene {
                    bioAuthManager.presentBiometric(scene: scene)
                }
            }
            return false
        }
        guard let query = appUrlResponse.query, query.count > 0 else {
            SFSDKCoreLogger.i(Self.self, format: "%@ URL has no query string.", #function)
            return false
        }
        let queryDict = SFSDKOAuth2.parseQueryString(query, decodeParams: false)
        guard let codeVal = queryDict[kSFOAuthResponseTypeCode] as? String, codeVal.count > 0 else {
            SFSDKCoreLogger.i(Self.self, format: "%@ URL has no 'code' parameter value.", #function)
            return false
        }
        approvalCode = codeVal
        SFSDKCoreLogger.i(Self.self, format: "%@ Received web server response. Beginning token exchange.", #function)
        DispatchQueue.main.async { [weak self] in
            self?.beginTokenEndpointFlow()
        }
        return true
    }

    private func handleUserAgentResponse(_ requestUrl: URL) {
        var response: String?
        if let fragment = requestUrl.fragment {
            response = fragment
        } else if let query = requestUrl.query {
            response = query
        } else {
            SFSDKCoreLogger.d(Self.self, format: "%@ Error: response has no payload: %@", #function, requestUrl.absoluteString)
            let error = SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "redirect response has no payload")
            notifyDelegateOfFailure(error, authInfo: authInfo)
            return
        }

        if let resp = response {
            let params = SFSDKOAuth2.parseQueryString(resp) as? [String: String] ?? [:]
            if params[kSFOAuthError] == nil {
                credentials?.update(params as [AnyHashable: Any])
                credentials?.setValue(params[kSFOAuthRefreshToken], forKey: "refreshToken")
                if additionalOAuthParameterKeys.count > 0 {
                    var parsedValues: [String: Any] = [:]
                    for key in additionalOAuthParameterKeys {
                        if let obj = params[key] {
                            parsedValues[key] = obj
                        }
                    }
                    credentials?.setValue(parsedValues, forKey: "additionalOAuthFields")
                }
                notifyDelegateOfSuccess(authInfo)
            } else {
                var finalError: NSError
                let error = SFSDKOAuth2.error(withType: params[kSFOAuthError] ?? "", description: params[kSFOAuthErrorDescription] ?? "")
                if error.code == Int(kSFOAuthErrorInvalidClientId) {
                    var dict = error.userInfo
                    dict[kSFOAuthClientId] = credentials?.clientId
                    finalError = NSError(domain: error.domain, code: error.code, userInfo: dict)
                } else {
                    finalError = error as NSError
                }
                notifyDelegateOfFailure(finalError, authInfo: authInfo)
            }
        }
    }

    private func isRedirectURL(_ requestUrlString: String) -> Bool {
        guard let redirectUri = credentials?.redirectUri else { return false }
        return requestUrlString.lowercased().hasPrefix(redirectUri.lowercased())
    }

    private func isSPAppRedirectURL(_ requestUrlString: String) -> Bool {
        guard let redirectUri = spAppCredentials?.redirectUri else { return false }
        return requestUrlString.lowercased().hasPrefix(redirectUri.lowercased())
    }

    private func isBiometricPromptURL(_ requestedUrlString: String) -> Bool {
        return requestedUrlString == "mobilesdk://biometric/authentication/prompt"
    }

    private func startWebviewAuthenticationIfNeeded() {
        if !initialRequestLoaded {
            initialRequestLoaded = true
            startAuthentication(withView: view)
        }
    }

    private func startAuthentication(withView view: WKWebView) {
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:didBeginAuthenticationWithView:))) ?? false {
            delegate?.oauthCoordinator(self, didBeginAuthenticationWithView: view)
        }
    }

    private func shouldUpdateDomain(_ webviewURL: URL) -> Bool {
        guard let regex = SalesforceSDKManager.shared.customDomainInferencePattern else { return false }
        if domainUpdated { return false }
        if credentials?.domain == webviewURL.host { return false }
        let urlString = webviewURL.absoluteString
        return regex.firstMatch(in: urlString, options: [], range: NSRange(location: 0, length: urlString.count)) != nil
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let requestUrl = url.absoluteString

        if let discoveryResult = domainDiscoveryCoordinator.handle(action: navigationAction) {
            handleCustomDomainUpdate(withLoginHint: discoveryResult.loginHint, myDomain: discoveryResult.myDomain)
            decisionHandler(.cancel)
        } else if isRedirectURL(requestUrl) {
            if frontdoorBridgeLoginOverride?.frontdoorBridgeUrl != nil
                ? frontdoorBridgeLoginOverride?.codeVerifier != nil
                : (useBrowserAuth || SalesforceSDKManager.shared.useWebServerAuthentication) {
                handleWebServerResponse(url)
            } else {
                handleUserAgentResponse(url)
            }
            decisionHandler(.cancel)
        } else if isSPAppRedirectURL(requestUrl) {
            handleIDPAuthCodeResponse(url)
            decisionHandler(.cancel)
        } else if isBiometricPromptURL(requestUrl) {
            SFSDKCoreLogger.i(Self.self, format: "Caught biometric request scheme. Showing native biometric prompt.")
            let bioAuthManager = BiometricAuthenticationManagerInternal.shared
            if bioAuthManager.locked && bioAuthManager.hasBiometricOptedIn(), let scene = view.window?.windowScene {
                bioAuthManager.presentBiometric(scene: scene)
            }
            decisionHandler(.allow)
        } else if shouldUpdateDomain(url) {
            handleCustomDomainUpdate(withLoginHint: loginHint, myDomain: url.host ?? "")
            decisionHandler(.cancel)
        } else if let policyBlock = UserAccountManager.shared.navigationPolicyForAction {
            decisionHandler(policyBlock(webView, navigationAction))
        } else {
            decisionHandler(.allow)
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            SFSDKCoreLogger.i(Self.self, format: "%@ host=%@ : path=%@", #function, url.host ?? "", url.path)
        }
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:didStartLoad:))) ?? false {
            delegate?.oauthCoordinator?(self, didStartLoad: webView)
        }
        if UserAccountManager.shared.showAuthWindowWhileLoading {
            startWebviewAuthenticationIfNeeded()
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:didFinishLoad:error:))) ?? false {
            delegate?.oauthCoordinator?(self, didFinishLoad: webView, error: nil)
        }
        if !UserAccountManager.shared.showAuthWindowWhileLoading {
            startWebviewAuthenticationIfNeeded()
        }
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        sfwebView(webView, didFailLoadWithError: error)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        sfwebView(webView, didFailLoadWithError: error)
    }

    private func sfwebView(_ webView: WKWebView, didFailLoadWithError error: Error) {
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:didFinishLoad:error:))) ?? false {
            delegate?.oauthCoordinator?(self, didFinishLoad: webView, error: error)
        }
        let nsError = error as NSError
        if nsError.code == -999 {
            SFSDKCoreLogger.d(Self.self, format: "SFOAuthCoordinator:didFailLoadWithError: error code: %ld, description: %@", nsError.code, error.localizedDescription)
        } else {
            SFSDKCoreLogger.d(Self.self, format: "SFOAuthCoordinator:didFailLoadWithError: error code: %ld, description: %@", nsError.code, error.localizedDescription)
            notifyDelegateOfFailure(error, authInfo: authInfo)
        }
    }

    private func handleIDPAuthCodeResponse(_ requestUrl: URL) {
        let error = checkFrontdoorResponseForErrors(requestUrl)
        if let error = error {
            var finalError: NSError
            if error.code == Int(kSFOAuthErrorInvalidClientId) {
                var dict = error.userInfo
                dict[kSFOAuthClientId] = credentials?.clientId
                finalError = NSError(domain: error.domain, code: error.code, userInfo: dict)
            } else {
                finalError = error as NSError
            }
            notifyDelegateOfFailure(finalError, authInfo: authInfo)
        } else {
            let response = requestUrl.fragment ?? requestUrl.query
            if let resp = response {
                let params = SFSDKOAuth2.parseQueryString(resp, decodeParams: false) as? [String: String] ?? [:]
                spAppCredentials?.setValue(params[kSFOAuthApprovalCode], forKey: "authCode")
                if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinatorDidFetchAuthCode(_:authInfo:))) ?? false {
                    delegate?.oauthCoordinatorDidFetchAuthCode?(self, authInfo: authInfo)
                }
            }
        }
    }

    private func checkFrontdoorResponseForErrors(_ requestUrl: URL) -> NSError? {
        let ecValue = (requestUrl as NSURL).sfsdk_value(forParameterName: "ec")
        let foundValidEcValue = (ecValue == "301" || ecValue == "302")
        let errorCode = (requestUrl as NSURL).sfsdk_value(forParameterName: kSFOAuthError)
        let errorDescription = (requestUrl as NSURL).sfsdk_value(forParameterName: kSFOAuthErrorDescription)

        if foundValidEcValue {
            return SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "IDP Authcode redirect response encountered an ec=301 or 302 redirect") as NSError
        } else if let code = errorCode {
            return SFSDKOAuth2.error(withType: code, description: errorDescription ?? "") as NSError
        } else if requestUrl.fragment == nil && requestUrl.query == nil {
            return SFSDKOAuth2.error(withType: kSFOAuthErrorTypeMalformedResponse, description: "IDP Authcode redirect response has no payload") as NSError
        }
        return nil
    }

    // MARK: - WKUIDelegate

    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:displayAlertMessage:completion:))) ?? false {
            delegate?.oauthCoordinator?(self, displayAlertMessage: message, completion: completionHandler)
        } else {
            SFSDKCoreLogger.w(Self.self, format: "WKWebView did want to display an alert but no delegate responded to it")
            completionHandler()
        }
    }

    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        if delegate?.responds(to: #selector(SFOAuthCoordinatorDelegate.oauthCoordinator(_:displayConfirmationMessage:completion:))) ?? false {
            delegate?.oauthCoordinator?(self, displayConfirmationMessage: message, completion: completionHandler)
        } else {
            SFSDKCoreLogger.w(Self.self, format: "WKWebView did want to display a confirmation alert but no delegate responded to it")
            completionHandler(false)
        }
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let createBlock = UserAccountManager.shared.createWebview {
            return createBlock(webView, configuration, navigationAction, windowFeatures)
        }
        return nil
    }
}

// Helper for NSAssert equivalent in Swift.
//
// The ObjC `NSAssert` these call sites were migrated from raises a catchable
// `NSInternalInconsistencyException` on failure. The prior implementation used Swift
// `assert()`, which instead calls `abort()` (uncatchable) in debug builds and is compiled
// out entirely in release — silently changing the precondition contract of the public
// `authenticate()` / `authenticate(withCredentials:)` entry points. Raise a catchable
// `NSException` to restore the original, oracle-faithful behavior.
private func NSAssert(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        NSException(name: .internalInconsistencyException, reason: message, userInfo: nil).raise()
    }
}
