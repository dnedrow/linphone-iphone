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
import AVFoundation

import os

class ProviderDelegate: NSObject {
	// 1.
	//private let callManager: CallManager
	private let provider: CXProvider
	private let callController: CXCallController
	
	var uuids: [String : UUID] = [:]
	var calls: [UUID : String] = [:]
	
	//init(callManager: CallManager) {
	override init() {
		//self.callManager = callManager
		// 2.
		provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
		callController = CXCallController()
		
		super.init()
		// 3.
		provider.setDelegate(self, queue: nil)
		callController.callObserver.setDelegate(self, queue: nil)
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
			// TODO not used for now
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
		
		let uuid = action.callUUID
		print("CallKit: Call ended \(uuid)");
		let callId = calls[uuid]
		let call = CallManager.instance().callByCallId(callId: callId)
		if (call != nil) {
			do {
				// remove first, otherwise CXEndCallAction will be call more than one times
				uuids.removeValue(forKey: callId!)
				calls.removeValue(forKey: uuid)
				try call!.terminate()
			} catch {
			}
		}
		action.fulfill()
	}
	
	func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
		print("CallKit: Call answered.")
		let uuid = action.callUUID
		let callId = calls[uuid]
		let call = CallManager.instance().callByCallId(callId: callId)
		if (call == nil) {
			action.fulfill()
			return
		}
		CallManager.instance().acceptCall(call: call,hasVideo: false)
		action.fulfill()
	}
	
	func providerDidReset(_ provider: CXProvider) {
		// TODO not sure useful
		print("CallKit: did reset.")
		try? CallManager.instance().lc?.terminateAllCalls()
		uuids.removeAll()
		calls.removeAll()
	}

	func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
		print("CallKit: Call set held.")
		let uuid = action.callUUID
		let callId = calls[uuid]
		let call = CallManager.instance().callByCallId(callId: callId)
		if (call == nil) {
			action.fulfill()
			return
		}
		if (action.isOnHold) {
			try? call?.pause()
		}
		action.fulfill()
	}
	
	func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
		print("CallKit: Call started.")
		// TODO outgoing call
		self.provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: nil)
		action.fulfill()
	}
	
	
	func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
		print("CallKit: Call muted.")
	}
	
	func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
		print("CallKit: Call group .")
	}
	
	func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
		print("CallKit: Call dtmf .")
	}
	
	func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
		print("CallKit: Call time out.")
	}
	
	func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
		
	}
}

// MARK: - CXCallObserverDelegate
extension ProviderDelegate: CXCallObserverDelegate {
	func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
		print("CallKit, call changed")
		if call.hasConnected == true && call.hasEnded == false && call.isOnHold == false {
			print("Connected")
			
			let uuid = call.uuid
			let callId = calls[uuid]
			let holdcall = CallManager.instance().callByCallId(callId: callId)
			if (holdcall == nil) {
				return
			}
			let state: Call.State = holdcall!.state
			switch state {
			case .Paused:
				do {
					try holdcall?.resume()
				} catch {
					print("\(error)")
				}
				break
			default:
				break
			}
		}
	}
}
