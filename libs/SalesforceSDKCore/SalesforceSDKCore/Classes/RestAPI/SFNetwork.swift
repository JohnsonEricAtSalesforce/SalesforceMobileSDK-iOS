//
//  SFNetwork.swift
//  SalesforceSDKCore
//
//  Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
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

/// Identifier for the default ephemeral network instance.
public let NetworkEphemeralInstanceIdentifier: String = "com.salesforce.network.ephemeralSession"

/// Identifier for the default background network instance.
public let NetworkBackgroundInstanceIdentifier: String = "com.salesforce.network.backgroundSession"

/// Block type for data response callbacks.
public typealias DataResponseBlock = (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void

/// Block type for metrics collected callbacks.
public typealias MetricsCollectedBlock = (_ session: URLSession, _ task: URLSessionTask, _ metrics: URLSessionTaskMetrics) -> Void

/// Network class that wraps URLSession for REST requests.
@objc(SFNetwork)
@objcMembers
public class Network: NSObject, URLSessionDelegate, URLSessionTaskDelegate {

    // MARK: - Static Properties

    private static var sharedInstances = SafeMutableDictionary<NSString, Network>()
    private static let lock = NSRecursiveLock()

    /// The block to execute when metrics are collected on a URL session task.
    @objc public static var metricsCollectedAction: MetricsCollectedBlock?

    // MARK: - Properties

    /// The active URL session.
    @objc public private(set) var activeSession: URLSession

    // MARK: - Shared Instance Accessors

    /// Returns an instance with the default ephemeral session configuration.
    @objc public static func sharedEphemeralInstance() -> Network {
        return sharedEphemeralInstance(withIdentifier: NetworkEphemeralInstanceIdentifier)
    }

    /// Returns an instance with the default background session configuration.
    @objc public static func sharedBackgroundInstance() -> Network {
        return sharedBackgroundInstance(withIdentifier: NetworkBackgroundInstanceIdentifier)
    }

    /// Returns an instance for the given identifier with an ephemeral session configuration.
    @objc public static func sharedEphemeralInstance(withIdentifier identifier: String) -> Network {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        return sharedInstance(withIdentifier: identifier, sessionConfiguration: sessionConfiguration)
    }

    /// Returns an instance for the given identifier with a background session configuration.
    @objc public static func sharedBackgroundInstance(withIdentifier identifier: String) -> Network {
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: identifier)
        return sharedInstance(withIdentifier: identifier, sessionConfiguration: sessionConfiguration)
    }

    /// Returns an instance with the given session configuration.
    @objc public static func sharedInstance(withIdentifier identifier: String, sessionConfiguration: URLSessionConfiguration) -> Network {
        lock.lock()
        defer { lock.unlock() }

        if let existing = sharedInstances.object(forKey: identifier as NSString) as? Network {
            return existing
        }
        let network = Network(sessionConfiguration: sessionConfiguration)
        sharedInstances.setObject(network, forKey: identifier as NSString)
        return network
    }

    // MARK: - Init

    private init(sessionConfiguration: URLSessionConfiguration) {
        activeSession = URLSession(configuration: sessionConfiguration, delegate: nil, delegateQueue: nil)
        super.init()
        activeSession = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }

    // MARK: - Send Request

    /// Sends a REST request and calls the appropriate completion block.
    @objc @discardableResult
    public func sendRequest(_ urlRequest: URLRequest, dataResponseBlock: DataResponseBlock?) -> URLSessionDataTask {
        var mutableRequest = urlRequest
        // Sets Mobile SDK user agent if it hasn't been set already elsewhere.
        if mutableRequest.allHTTPHeaderFields?["User-Agent"] == nil {
            mutableRequest.setValue(SalesforceSDKManager.shared.userAgentString?("") ?? "", forHTTPHeaderField: "User-Agent")
        }
        let dataTask = activeSession.dataTask(with: mutableRequest) { data, response, error in
            dataResponseBlock?(data, response, error)
        }
        dataTask.resume()
        return dataTask
    }

    // MARK: - Session Configuration

    /// Sets a session configuration to be used for network requests.
    @objc public static func setSessionConfiguration(_ sessionConfig: URLSessionConfiguration, identifier: String) {
        removeSharedInstance(forIdentifier: identifier)
        _ = sharedInstance(withIdentifier: identifier, sessionConfiguration: sessionConfig)
    }

    // MARK: - Remove Instances

    /// Removes shared instance for the default ephemeral identifier.
    @objc public static func removeSharedEphemeralInstance() {
        removeSharedInstance(forIdentifier: NetworkEphemeralInstanceIdentifier)
    }

    /// Removes shared instance for the default background identifier.
    @objc public static func removeSharedBackgroundInstance() {
        removeSharedInstance(forIdentifier: NetworkBackgroundInstanceIdentifier)
    }

    /// Removes shared instance for given identifier.
    @objc public static func removeSharedInstance(forIdentifier identifier: String?) {
        guard let identifier = identifier else { return }
        lock.lock()
        defer { lock.unlock() }
        if let network = sharedInstances.object(forKey: identifier as NSString) as? Network {
            network.activeSession.invalidateAndCancel()
        }
        sharedInstances.removeObject(identifier as NSString)
    }

    /// Removes all shared instances.
    @objc public static func removeAllSharedInstances() {
        lock.lock()
        defer { lock.unlock() }
        if let allValues = sharedInstances.allValues as? [Network] {
            for network in allValues {
                network.activeSession.invalidateAndCancel()
            }
        }
        sharedInstances.removeAllObjects()
    }

    /// Returns list of identifiers for all shared instances.
    @objc public static func sharedInstanceIdentifiers() -> [String]? {
        return sharedInstances.allKeys as? [String]
    }

    /// Generates a unique instance identifier.
    @objc public static func uniqueInstanceIdentifier() -> String {
        return "com.salesforce.network.\(UUID().uuidString)"
    }

    // MARK: - URLSessionDelegate

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Network.lock.lock()
        defer { Network.lock.unlock() }
        if let allKeys = Network.sharedInstances.allKeys as? [String] {
            for identifier in allKeys {
                if let sharedInstance = Network.sharedInstances.object(forKey: identifier as NSString) as? Network,
                   session === sharedInstance.activeSession {
                    Network.sharedInstances.removeObject(identifier as NSString)
                }
            }
        }
    }

    // MARK: - URLSessionTaskDelegate

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if task.originalRequest?.value(forHTTPHeaderField: "Authorization") != nil,
           let url = request.url, !isSalesforceURL(url) {
            // Don't auto follow redirects in authenticated case if we don't recognize the domain
            completionHandler(nil)
        } else {
            var newRequest = request
            newRequest.allHTTPHeaderFields = task.originalRequest?.allHTTPHeaderFields
            newRequest.httpBody = task.originalRequest?.httpBody
            newRequest.httpMethod = task.originalRequest?.httpMethod ?? "GET"
            completionHandler(newRequest)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        Network.metricsCollectedAction?(session, task, metrics)
    }

    // MARK: - Private Helpers

    private func isSalesforceURL(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
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

    // MARK: - Test Support

    /// Getter for tests - returns all shared instances.
    @objc public static func allSharedInstances() -> [String: Network] {
        return (sharedInstances.dictionary as? [String: Network]) ?? [:]
    }
}
