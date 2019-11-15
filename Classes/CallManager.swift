//
//  CallManager.swift
//  linphone
//
//  Created by Danmei Chen on 07/11/2019.
//

import Foundation
import linphonesw
import UserNotifications
import os
import CallKit

@objc class CallManager: NSObject {
	var providerDelegate: ProviderDelegate!
	static var theCallManager: CallManager?
	var lc: Core?
	var configDb: Config?
	
	
	let manager = CoreManager()
	
	override init() {
		providerDelegate = ProviderDelegate();
	}
	
	@objc static func instance() -> CallManager {
		//TODO @synchronized(self) {
			if (theCallManager == nil) {
				theCallManager = CallManager()
			}
		//}
		return theCallManager!
	}
	
	func displayIncomingCall(
	call:Call,
	uuid: UUID,
	handle: String,
	hasVideo: Bool = false,
	completion: ((Error?) -> Void)?
	) {
	providerDelegate.reportIncomingCall(
	call:call,
	uuid: uuid,
	handle: handle,
	hasVideo: hasVideo,
	completion: completion)
	}
	
	@objc func displayIncomingCall(
		uuid: UUID,
		handle: String,
		hasVideo: Bool = false,
		completion: ((Error?) -> Void)?
		) {
		providerDelegate.reportIncomingCall(
			call:nil,
			uuid: uuid,
			handle: handle,
			hasVideo: hasVideo,
			completion: completion)
	}
	
	 @objc func addCoreDelegate() {
		lc = Factory.Instance.core
		lc!.addDelegate(delegate: manager)
	}

	func acceptCall(call: Call?, hasVideo:Bool) {
		do {
			let callParams = try lc!.createCallParams(call: call)
			callParams.videoEnabled = hasVideo
			try call?.acceptWithParams(params: callParams)
		} catch {
			print("CallKit: error ... \(error)")
		}
	}
	
	func callByCallId(callId: String?) -> Call? {
		if (callId == nil) {
			return nil
		}
		let calls = lc?.calls
		if let callTmp = calls?.first(where: { $0.callLog?.callId == callId }) {
			return callTmp
		}
		return nil
	}
}

class CoreManager: CoreDelegate {
	//var instanceOfFastAddressBook: FastAddressBook = FastAddressBook()
	override func onCallStateChanged(lc: Core, call: Call, cstate: Call.State, message: String) {
		let addr = call.remoteAddress;
		let address = FastAddressBook.displayName(for: addr?.getCobject) ?? "Unknow"
		
		switch cstate {
		case .IncomingReceived:
			if UIApplication.shared.applicationState != UIApplication.State.active {
				let callLog = call.callLog
				let callId = callLog!.callId
				let uuid = UUID()
				CallManager.instance().providerDelegate.uuids.updateValue(uuid, forKey: callId)
				CallManager.instance().providerDelegate.calls.updateValue(callId, forKey: uuid)
				CallManager.instance().displayIncomingCall(call: call, uuid: uuid, handle: address, completion: nil)
			} 
			
			break
		case .End,
			 .Error:
			print("CallKit: onCallStateChanged, call end or error")
			let log = call.callLog
			if log == nil || log?.status == Call.Status.Missed || log?.status == Call.Status.Aborted || log?.status == Call.Status.EarlyAborted  {
				// Configure the notification's payload.
				let content = UNMutableNotificationContent()
				content.title = NSString.localizedUserNotificationString(forKey: NSLocalizedString("Missed call", comment: ""), arguments: nil)
				content.body = NSString.localizedUserNotificationString(forKey: address, arguments: nil)
				
				// Deliver the notification.
				let request = UNNotificationRequest(identifier: "call_request", content: content, trigger: nil) // Schedule the notification.
				let center = UNUserNotificationCenter.current()
				center.add(request) { (error : Error?) in
					if error != nil {
						print("CallKit: Error while adding notification request : \(error!.localizedDescription)")
					}
				}
			}
			
			// end CallKit
			let callId = log?.callId
			let uuid = CallManager.instance().providerDelegate.uuids["\(callId!)"]
			if (uuid != nil) {
				let controller = CXCallController()
				let transaction = CXTransaction(action:
					CXEndCallAction(call: uuid!))
				controller.request(transaction,completion: { error in })
				print("CallKit: send CXEndCallAction")
			} else {
				// TODO
				print("CallKit: can not send CXEndCallAction, because uuis is nil")
			}
			
			break
		default:
			break
		}
		
		// post Notification kLinphoneCallUpdate
		NotificationCenter.default.post(name: Notification.Name("LinphoneCallUpdate"), object: self, userInfo: [
			AnyHashable("call"): NSValue.init(pointer:UnsafeRawPointer(call.getCobject)),
			AnyHashable("state"): NSNumber(value: cstate.rawValue),
			AnyHashable("message"): message
			])
	}
	

}


