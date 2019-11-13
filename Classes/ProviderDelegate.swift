//
//  ProviderDelegate.swift
//  linphone
//
//  Created by Danmei Chen on 07/11/2019.
//

import Foundation
import CallKit
import UIKit
import linphonesw

import os

class ProviderDelegate: NSObject {
	// 1.
	//private let callManager: CallManager
	private let provider: CXProvider
	
	var uuids: [AnyHashable : UUID] = [:]
	
	//init(callManager: CallManager) {
	override init() {
		//self.callManager = callManager
		// 2.
		provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
		
		super.init()
		// 3.
		provider.setDelegate(self, queue: nil)
	}
	
	// 4.
	static var providerConfiguration: CXProviderConfiguration = {
		let providerConfiguration = CXProviderConfiguration(localizedName: Bundle.main.infoDictionary!["CFBundleName"] as! String)
		
		providerConfiguration.ringtoneSound = "notes_of_the_optimistic.caf"
		providerConfiguration.supportsVideo = false
		providerConfiguration.iconTemplateImageData = UIImage(named: "callkit_logo")?.pngData()
		providerConfiguration.supportedHandleTypes = [.generic]
		
		providerConfiguration.maximumCallsPerCallGroup = 1
		providerConfiguration.maximumCallGroups = 2
		
		//not show app's calls in tel's history
		//providerConfiguration.includesCallsInRecents = NO;
		
		return providerConfiguration
	}()
	
	func reportIncomingCall(
	call:Call?,
	uuid: UUID,
	handle: String,
	hasVideo: Bool = false,
	completion: ((Error?) -> Void)?
	) {
		// 1.
		let update = CXCallUpdate()
		update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
		update.hasVideo = hasVideo
		update.supportsDTMF = true;
		update.supportsHolding = true;
		update.supportsGrouping = true;
		update.supportsUngrouping = true;
	
		// 2.
		os_log("CallKit: report new incoming call with call-id:   and UUID: [%@]", uuid.description)
		provider.reportNewIncomingCall(with: uuid, update: update) { error in
		if error == nil {
		} else {
			os_log("CallKit: cannot complete incoming call with call-id: and UUID: [%@] from [%@] caused by [%@]", uuid.description, handle, error?.localizedDescription ?? "")
			let code = (error as NSError?)?.code
			if code == CXErrorCodeIncomingCallError.filteredByBlockList.rawValue || code == CXErrorCodeIncomingCallError.filteredByDoNotDisturb.rawValue {
				try? call?.decline(reason: Reason.Busy)
			} else {
				try? call?.decline(reason: Reason.Unknown)
			}
		}
	}
	}
}

// MARK: - CXProviderDelegate
extension ProviderDelegate: CXProviderDelegate {
	func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
		print("CallKit: Call ended");
		let call = CallManager.instance().lc!.currentCall;
		if (call != nil) {
			do {
				try call!.terminate()
			} catch {
			}
		}
		action.fulfill()
	}
	
	func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
		print("CallKit: Call answered.")
		CallManager.instance().acceptCall(call: CallManager.instance().lc!.currentCall,hasVideo: false)
		action.fulfill()
	}
	
	func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
	}
	
	func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
	}
	
	func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
	}
	
	func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
	}
	
	func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
	}
	
	func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
		
	}
	
	func providerDidReset(_ provider: CXProvider) {
	}
}
