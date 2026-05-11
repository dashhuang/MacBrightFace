import CoreMediaIO
import Foundation
import OSLog

@MainActor
final class CameraActivityMonitor {
    var onActivityChanged: ((Bool) -> Void)? {
        didSet {
            onActivityChanged?(isCameraActive)
        }
    }

    private let logger = Logger(subsystem: "cn.huang.dash.DisplayFill", category: "CameraActivity")
    private let listenerQueue = DispatchQueue.main
    private let reconciliationInterval: TimeInterval = 60

    private var isMonitoring = false
    private var isCameraActive = false
    private var reconciliationTimer: Timer?
    private var systemDevicesAddress = CameraActivityMonitor.propertyAddress(kCMIOHardwarePropertyDevices)
    private var deviceRunningAddress = CameraActivityMonitor.propertyAddress(kCMIODevicePropertyDeviceIsRunningSomewhere)
    private var systemListener: CMIOObjectPropertyListenerBlock?
    private var deviceListeners: [CMIOObjectID: CMIOObjectPropertyListenerBlock] = [:]

    func start() {
        guard !isMonitoring else {
            synchronizeCameraActivity(reason: "restart")
            return
        }

        isMonitoring = true
        installSystemListener()
        synchronizeCameraActivity(reason: "start")
        startReconciliationTimer()
    }

    func stop() {
        isMonitoring = false
        reconciliationTimer?.invalidate()
        reconciliationTimer = nil
        removeDeviceListeners()
        removeSystemListener()
        setCameraActive(false)
    }

    private func startReconciliationTimer() {
        guard reconciliationTimer == nil else { return }

        let timer = Timer(timeInterval: reconciliationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.synchronizeCameraActivity(reason: "reconcile")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        reconciliationTimer = timer
    }

    private func installSystemListener() {
        guard systemListener == nil else { return }

        let listener: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleDeviceListChanged()
            }
        }

        var address = systemDevicesAddress
        let status = CMIOObjectAddPropertyListenerBlock(
            CMIOObjectID(kCMIOObjectSystemObject),
            &address,
            listenerQueue,
            listener
        )

        if status == noErr {
            systemListener = listener
        } else {
            logger.error("Failed to install camera device listener status=\(status)")
        }
    }

    private func removeSystemListener() {
        guard let listener = systemListener else { return }

        var address = systemDevicesAddress
        let status = CMIOObjectRemovePropertyListenerBlock(
            CMIOObjectID(kCMIOObjectSystemObject),
            &address,
            listenerQueue,
            listener
        )
        if status != noErr {
            logger.error("Failed to remove camera device listener status=\(status)")
        }
        systemListener = nil
    }

    private func handleDeviceListChanged() {
        guard isMonitoring else { return }

        synchronizeCameraActivity(reason: "devices")
    }

    private func synchronizeCameraActivity(reason: String) {
        guard isMonitoring else { return }

        let currentDevices = refreshDeviceListeners()
        let isActive = currentDevices.contains { isDeviceRunningSomewhere($0) }
        logger.debug("Camera activity synchronized reason=\(reason, privacy: .public) active=\(isActive)")
        setCameraActive(isActive)
    }

    @discardableResult
    private func refreshDeviceListeners() -> [CMIOObjectID] {
        let currentDevices = Set(devices())

        for device in Array(deviceListeners.keys) where !currentDevices.contains(device) {
            removeDeviceListener(device)
        }

        for device in currentDevices where deviceListeners[device] == nil {
            addDeviceListener(device)
        }

        return Array(currentDevices)
    }

    private func addDeviceListener(_ device: CMIOObjectID) {
        let listener: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleDeviceRunningStateChanged()
            }
        }

        var address = deviceRunningAddress
        let status = CMIOObjectAddPropertyListenerBlock(device, &address, listenerQueue, listener)
        if status == noErr {
            deviceListeners[device] = listener
        } else {
            logger.error("Failed to install camera running listener device=\(device) status=\(status)")
        }
    }

    private func removeDeviceListeners() {
        for device in Array(deviceListeners.keys) {
            removeDeviceListener(device)
        }
    }

    private func removeDeviceListener(_ device: CMIOObjectID) {
        guard let listener = deviceListeners.removeValue(forKey: device) else { return }

        var address = deviceRunningAddress
        let status = CMIOObjectRemovePropertyListenerBlock(device, &address, listenerQueue, listener)
        if status != noErr {
            logger.error("Failed to remove camera running listener device=\(device) status=\(status)")
        }
    }

    private func handleDeviceRunningStateChanged() {
        guard isMonitoring else { return }

        synchronizeCameraActivity(reason: "running")
    }

    private func devices() -> [CMIOObjectID] {
        var devicesAddress = Self.propertyAddress(kCMIOHardwarePropertyDevices)
        var dataSize: UInt32 = 0
        let sizeStatus = CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &devicesAddress,
            0,
            nil,
            &dataSize
        )
        guard sizeStatus == noErr, dataSize >= MemoryLayout<CMIOObjectID>.size else {
            if sizeStatus != noErr {
                logger.error("Failed to read camera device list size status=\(sizeStatus)")
            }
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: deviceCount)
        var dataUsed: UInt32 = 0
        let devicesStatus = devices.withUnsafeMutableBufferPointer { buffer in
            CMIOObjectGetPropertyData(
                CMIOObjectID(kCMIOObjectSystemObject),
                &devicesAddress,
                0,
                nil,
                dataSize,
                &dataUsed,
                buffer.baseAddress!
            )
        }
        guard devicesStatus == noErr else {
            logger.error("Failed to read camera device list status=\(devicesStatus)")
            return []
        }

        return devices
    }

    private func isDeviceRunningSomewhere(_ device: CMIOObjectID) -> Bool {
        var runningAddress = Self.propertyAddress(kCMIODevicePropertyDeviceIsRunningSomewhere)
        var isRunning: UInt32 = 0
        var dataUsed: UInt32 = 0
        let status = CMIOObjectGetPropertyData(
            device,
            &runningAddress,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &dataUsed,
            &isRunning
        )

        return status == noErr && isRunning != 0
    }

    private static func propertyAddress(_ selector: Int) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(selector),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
    }

    private func setCameraActive(_ isActive: Bool) {
        guard isCameraActive != isActive else { return }

        isCameraActive = isActive
        logger.info("Camera activity changed active=\(isActive)")
        onActivityChanged?(isActive)
    }
}
