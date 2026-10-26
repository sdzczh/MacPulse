import Foundation
import Combine

public final class MetricsEngine: ObservableObject {
    @Published public private(set) var state = MetricsState()
    public let hardware: HardwareInfo

    private let queue = DispatchQueue(label: "com.sdzczh.macpulse.engine", qos: .utility)
    private let cpuSampler: CPUSampler
    private let sensorService: SensorService
    private let gpuSampler = GPUSampler()
    private let networkSampler = NetworkSampler()
    private let diskSampler = DiskSampler()
    private let batterySampler = BatterySampler()
    private let processSampler = ProcessSampler()

    private var timer: DispatchSourceTimer?
    private var interval: TimeInterval = 1
    private var tickCount = 0
    private var isDetailed = false
    private var isRunning = false
    private var lastError: String?

    private var latestSnapshot = SystemSnapshot()
    private var history = MetricsHistory()
    private var sampleCount = 0

    private var lastFans: [FanReading] = []
    private var lastThermal = ThermalSnapshot()
    private var lastGPU: GPUSnapshot?
    private var lastDisk = DiskSnapshot()
    private var lastBattery: BatterySnapshot?
    private var lastProcesses: [ProcessReading] = []
    private var lastProcessSampleAt = Date.distantPast
    private var lastBatterySampleAt = Date.distantPast

    public init(interval: TimeInterval = 1) {
        self.hardware = HardwareInfoProvider.load()
        self.cpuSampler = CPUSampler(hardware: hardware)
        self.sensorService = SensorService()
        self.interval = interval
        if !sensorService.isAvailable {
            lastError = "SMC 不可用，风扇与温度将隐藏"
        }
        var initialState = MetricsState()
        initialState.samplingInterval = interval
        initialState.lastError = lastError
        state = initialState
    }

    deinit {
        timer?.cancel()
    }

    public func start(interval: TimeInterval? = nil) {
        queue.async { [weak self] in
            guard let self else { return }
            if let interval {
                self.interval = max(0.5, interval)
            }
            self.startTimerLocked()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.isRunning = false
            self?.timer?.cancel()
            self?.timer = nil
        }
    }

    public func pause() {
        stop()
    }

    public func resume() {
        start()
    }

    public func setDetailed(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self, self.isDetailed != enabled else { return }
            self.isDetailed = enabled

            if enabled {
                _ = self.processSampler.sample()
                self.lastProcessSampleAt = Date()
                self.queue.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self, self.isDetailed else { return }
                    self.refreshProcessesLocked()
                }
            } else {
                self.lastProcesses = []
                var snapshot = self.latestSnapshot
                snapshot.processes = []
                snapshot.processSampled = false
                self.latestSnapshot = snapshot
                self.publish(snapshot: snapshot, appendHistory: false)
            }
        }
    }

    private func startTimerLocked() {
        isRunning = true
        timer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        let leeway = DispatchTimeInterval.milliseconds(min(200, max(20, Int(interval * 100))))
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: leeway)
        timer.setEventHandler { [weak self] in
            self?.tickLocked()
        }
        timer.resume()
        self.timer = timer

        if sampleCount == 0 {
            tickLocked()
        }
    }

    private func tickLocked() {
        guard isRunning else { return }
        let now = Date()
        tickCount += 1

        var snapshot = SystemSnapshot()
        snapshot.sampledAt = now
        snapshot.uptime = UptimeProvider.uptime()
        snapshot.cpu = cpuSampler.sample()
        snapshot.memory = MemorySampler.sample(totalBytes: hardware.totalMemoryBytes)
        snapshot.network = networkSampler.sample(now: now)

        // SMC 温度键较多，关闭面板时降频到 5 秒；其余 IOKit 指标保持 2 秒。
        let sensorSeconds = isDetailed ? 2.0 : 5.0
        let sensorFactor = max(1, Int((sensorSeconds / interval).rounded()))
        let sensorDue = tickCount == 1 || tickCount % sensorFactor == 0
        if sensorDue {
            let sensors = sensorService.sample()
            lastFans = sensors.fans
            lastThermal = sensors.thermal
        }
        snapshot.fans = lastFans
        snapshot.thermal = lastThermal

        let ioFactor = max(1, Int((2.0 / interval).rounded()))
        if tickCount == 1 || tickCount % ioFactor == 0 {
            lastGPU = gpuSampler.sample()
            lastDisk = diskSampler.sample(now: now)
        }
        snapshot.gpu = lastGPU
        snapshot.disk = lastDisk

        if tickCount == 1 || now.timeIntervalSince(lastBatterySampleAt) >= 10 {
            lastBattery = batterySampler.sample()
            lastBatterySampleAt = now
        }
        snapshot.battery = lastBattery

        if isDetailed && now.timeIntervalSince(lastProcessSampleAt) >= 3 {
            lastProcesses = processSampler.sample(now: now)
            lastProcessSampleAt = now
        }
        snapshot.processes = isDetailed ? lastProcesses : []
        snapshot.processSampled = isDetailed

        latestSnapshot = snapshot
        publish(snapshot: snapshot, appendHistory: true)
    }

    private func refreshProcessesLocked() {
        guard isDetailed else { return }
        let now = Date()
        lastProcesses = processSampler.sample(now: now)
        lastProcessSampleAt = now
        var snapshot = latestSnapshot
        snapshot.processes = lastProcesses
        snapshot.processSampled = true
        latestSnapshot = snapshot
        publish(snapshot: snapshot, appendHistory: false)
    }

    private func publish(snapshot: SystemSnapshot, appendHistory: Bool) {
        if appendHistory {
            history.append(snapshot: snapshot)
            sampleCount += 1
        }

        let newState = MetricsState(
            snapshot: snapshot,
            history: history,
            sampleCount: sampleCount,
            isDetailed: isDetailed,
            lastError: lastError,
            samplingInterval: interval
        )
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }
}
