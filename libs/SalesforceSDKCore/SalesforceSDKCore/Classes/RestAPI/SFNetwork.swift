/*
 SFNetwork.swift
 SalesforceSDKCore

 Created by Bharath Hariharan on 2/15/17.

 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

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

public let NetworkEphemeralInstanceIdentifier = "com.salesforce.network.ephemeralSession"
public let NetworkBackgroundInstanceIdentifier = "com.salesforce.network.backgroundSession"

@objc(SFNetwork)
@objcMembers
public class Network: NSObject, URLSessionDelegate, URLSessionTaskDelegate {

    public typealias DataResponseBlock = (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void

    public typealias MetricsCollectedBlock = (_ session: URLSession, _ task: URLSessionTask, _ metrics: URLSessionTaskMetrics) -> Void

    private(set) public var activeSession: URLSession

    public static var metricsCollectedAction: MetricsCollectedBlock?

    private static var sharedInstances = SFSDKSafeMutableDictionary<NSString, Network>()

    /**
     * Returns an instance of this class with the default ephemeral session configuration.
     *
     * @return Instance of this class.
     */
    @objc
    public static func sharedEphemeralInstance() -> Network {
        return sharedEphemeralInstance(withIdentifier: NetworkEphemeralInstanceIdentifier)
    }

    /**
     * Returns an instance of this class with the default background session configuration.
     *
     * @return Instance of this class.
     */
    @objc
    public static func sharedBackgroundInstance() -> Network {
        return sharedBackgroundInstance(withIdentifier: NetworkBackgroundInstanceIdentifier)
    }

    /**
     * Returns instance of this class for the given identifier with the default ephemeral session configuration.
     *
     * @return Instance of this class.
     */
    @objc
    public static func sharedEphemeralInstance(withIdentifier identifier: String) -> Network {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        return sharedInstance(withIdentifier: identifier, sessionConfiguration: sessionConfiguration)
    }

    /**
     * Returns instance of this class for the given identifier with the default background session configuration.
     *
     * @return Instance of this class.
     */
    @objc
    public static func sharedBackgroundInstance(withIdentifier identifier: String) -> Network {
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        return sharedInstance(withIdentifier: identifier, sessionConfiguration: sessionConfiguration)
    }

    /**
     * Returns an instance of this class with the given session configuration.
     *
     * @param identifier Identifier for the instance
     * @param sessionConfiguration Configuration to use for the session.
     * @return Instance of this class.
     */
    @objc
    public static func sharedInstance(withIdentifier identifier: String, sessionConfiguration: URLSessionConfiguration) -> Network {
        if let network = sharedInstances[identifier as NSString] as? Network {
            return network
        }

        let network = Network(sessionConfiguration: sessionConfiguration)
        sharedInstances[identifier as NSString] = network
        return network
    }

    private init(sessionConfiguration: URLSessionConfiguration) {
        activeSession = URLSession(configuration: sessionConfiguration, delegate: nil, delegateQueue: nil)
        super.init()
        activeSession = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }

    /**
     * Sends a REST request and calls the appropriate completion block.
     *
     * @param urlRequest NSURLRequest instance.
     * @param dataResponseBlock Network response block.
     * @return NSURLSessionDataTask instance.
     */
    @objc
    @discardableResult
    public func sendRequest(_ urlRequest: URLRequest, dataResponseBlock: DataResponseBlock?) -> URLSessionDataTask {
        var mutableRequest = urlRequest
        if let mutableURLRequest = urlRequest as? NSMutableURLRequest {
            // Sets Mobile SDK user agent if it hasn't been set already elsewhere.
            if let allHeaders = mutableURLRequest.allHTTPHeaderFields, !allHeaders.keys.contains("User-Agent") {
                mutableURLRequest.setValue(SalesforceManager.shared.userAgentString(""), forHTTPHeaderField: "User-Agent")
            }
            mutableRequest = mutableURLRequest as URLRequest
        }

        let dataTask = activeSession.dataTask(with: mutableRequest) { data, response, error in
            dataResponseBlock?(data, response, error)
        }
        dataTask.resume()
        return dataTask
    }

    /**
     * Sets a session configuration to be used for network requests in Mobile SDK.
     *
     * @param sessionConfig Session configuration to be used.
     * @param identifier Identifier for the instance to use this config.
     */
    @objc
    public static func setSessionConfiguration(_ sessionConfig: URLSessionConfiguration, identifier: String) {
        removeSharedInstance(forIdentifier: identifier)
        _ = sharedInstance(withIdentifier: identifier, sessionConfiguration: sessionConfig)
    }

    /**
     * Removes shared instance for the default ephemeral identifier.
     */
    @objc
    public static func removeSharedEphemeralInstance() {
        removeSharedInstance(forIdentifier: NetworkEphemeralInstanceIdentifier)
    }

    /**
     * Removes shared instance for the default background identifier.
     */
    @objc
    public static func removeSharedBackgroundInstance() {
        removeSharedInstance(forIdentifier: NetworkBackgroundInstanceIdentifier)
    }

    /**
     * Removes shared instance for given identifier.
     *
     * @param identifier Identifier for the session.
     */
    @objc
    public static func removeSharedInstance(forIdentifier identifier: String?) {
        guard let identifier = identifier else { return }
        if let network = sharedInstances[identifier as NSString] as? Network {
            network.activeSession.invalidateAndCancel()
        }
        sharedInstances.removeObject(identifier as NSString)
    }

    /**
     * Removes all shared instances.
     */
    @objc
    public static func removeAllSharedInstances() {
        for network in sharedInstances.allValues as? [Network] ?? [] {
            network.activeSession.invalidateAndCancel()
        }
        sharedInstances.removeAllObjects()
    }

    /**
     * Returns list of identifiers for all shared instances.
     * @return Array of identifiers.
     */
    @objc
    public static func sharedInstanceIdentifiers() -> [String]? {
        return sharedInstances.allKeys as? [String]
    }

    /**
     * Generates a unique instance identifier.
     */
    @objc
    public static func uniqueInstanceIdentifier() -> String {
        return "com.salesforce.network.\(UUID().uuidString)"
    }

    // MARK: - NSURLSessionDelegate

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        for identifier in Network.sharedInstances.allKeys as? [String] ?? [] {
            if let sharedInstance = Network.sharedInstances[identifier as NSString] as? Network,
               session == sharedInstance.activeSession {
                Network.sharedInstances.removeObject(identifier as NSString)
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if let authHeader = task.originalRequest?.value(forHTTPHeaderField: "Authorization"),
           !authHeader.isEmpty,
           !isSalesforceURL(request.url) {
            // Don't auto follow redirects in authenticated case if we don't recognize the domain
            completionHandler(nil)
        } else {
            var newRequest = request
            if let originalRequest = task.originalRequest {
                var mutableRequest = request
                if let mutableURLRequest = request as? NSMutableURLRequest {
                    mutableURLRequest.allHTTPHeaderFields = originalRequest.allHTTPHeaderFields
                    mutableURLRequest.httpBody = originalRequest.httpBody
                    if let httpMethod = originalRequest.httpMethod {
                        mutableURLRequest.httpMethod = httpMethod
                    }
                    mutableRequest = mutableURLRequest as URLRequest
                }
                newRequest = mutableRequest
            }
            completionHandler(newRequest)
        }
    }

    private func isSalesforceURL(_ url: URL?) -> Bool {
        guard let host = url?.host else { return false }
        // List from https://help.salesforce.com/s/articleView?language=en_US&id=sf.domain_name_url_formats.htm&type=5
        return host.hasSuffix(".salesforce.com") ||
               host.hasSuffix(".force.com") ||
               host.hasSuffix(".sfdcopens.com") ||
               host.hasSuffix(".site.com") ||
               host.hasSuffix(".lightning.com") ||
               host.hasSuffix(".salesforce-sites.com") ||
               host.hasSuffix(".force-user-content.com") ||
               host.hasSuffix(".salesforce-experience.com") ||
               host.hasSuffix(".salesforce-scrt.com")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        Network.metricsCollectedAction?(session, task, metrics)
    }

    // MARK: - Private

    // Getter for tests
    @objc
    internal static func getSharedInstancesDictionary() -> [String: Any] {
        return sharedInstances.dictionary() as? [String: Any] ?? [:]
    }
}
