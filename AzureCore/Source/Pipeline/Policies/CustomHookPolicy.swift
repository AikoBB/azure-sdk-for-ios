//
//  CustomHookPolicy.swift
//  AzureCore
//
//  Created by Travis Prescott on 8/28/19.
//  Copyright © 2019 Azure SDK Team. All rights reserved.
//

import Foundation

@objc public class CustomHookPolicy: NSObject, SansIOHttpPolicy {
    
    private var callback: ((PipelineResponse) -> Void)?
    
    @objc public func onRequest(_ request: PipelineRequest) {
        self.callback = request.context?.getValue(forKey: "rawResponseHook") as? ((PipelineResponse) -> Void)
    }
    
    @objc public func onResponse(_ response: PipelineResponse, request: PipelineRequest) {
        guard let callback = self.callback else { return }
        callback(response)
        request.context = request.context?.add(value: self.callback as AnyObject, forKey: "rawResponseHook")
    }
}
