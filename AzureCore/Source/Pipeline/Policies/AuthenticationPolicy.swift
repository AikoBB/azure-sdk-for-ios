//
//  AuthenticationPolicy.swift
//  AzureCore
//
//  Created by Travis Prescott on 8/28/19.
//  Copyright © 2019 Azure SDK Team. All rights reserved.
//

import Foundation

@objc public class BearerTokenCredentialPolicy: NSObject, HttpPolicy {
    
    @objc public var next: PipelineSendable?
    @objc public let scopes: [String]
    @objc public let credential: TokenCredential
    @objc public var needNewToken: Bool {
        // TODO: Also if token expires within 300... ms?
        return (self.token == nil)
    }
    
    private var token: AccessToken?

    @objc public init(credential: TokenCredential, scopes: [String]) {
        self.scopes = scopes
        self.credential = credential
        self.token = nil
    }
    
    @objc public func updateHeaders(request: PipelineRequest, token: String) {
        request.httpRequest.headers[HttpHeader.authorization.rawValue] = "Bearer \(token)"
    }
    
    @objc public func send(request: PipelineRequest) throws -> PipelineResponse {
        if self.needNewToken {
            self.token = self.credential.getToken(scopes: self.scopes)
        }
        self.updateHeaders(request: request, token: self.token!.token)
        return try self.next!.send(request: request)
    }
}
