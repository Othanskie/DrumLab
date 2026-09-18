import UIKit
import WebKit
import CoreMIDI
import CoreBluetooth

final class ViewController: UIViewController, WKScriptMessageHandler, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var webView: WKWebView!
    private var midiClient = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var bleCentral: CBCentralManager!
    private var blePeripheral: CBPeripheral?
    private var bleCharacteristic: CBCharacteristic?
    private let bleService = CBUUID(string: "03B80E5A-EDE8-4B4A-B5F4-221A8278229D")
    private let bleCharacteristicUUID = CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        ["listMidiInputs", "connectMidiInput", "pairBleMidi"].forEach { controller.add(self, name: $0) }
        controller.addUserScript(WKUserScript(source: nativeShim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = controller
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor), webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor), webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        webView.loadFileURL(Bundle.main.url(forResource: "index", withExtension: "html")!, allowingReadAccessTo: Bundle.main.bundleURL)
        bleCentral = CBCentralManager(delegate: self, queue: .main)
        setupMIDI()
    }

    private var nativeShim: String { """
      window.drumlabNative={
        listMidiInputs:()=>new Promise(r=>window.__iosMidiList=r),
        connectMidiInput:id=>window.webkit.messageHandlers.connectMidiInput.postMessage(id),
        pairBleMidi:()=>new Promise(r=>{window.__iosBlePair=r;window.webkit.messageHandlers.pairBleMidi.postMessage({});}),
        onMidiMessage:cb=>window.__iosMidiCallback=cb,
        onHardwareStatus:cb=>window.__iosHardwareCallback=cb,
        getVersion:()=>Promise.resolve('1.0')
      };
    """ }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "listMidiInputs":
            var result: [[String: String]] = []
            for i in 0..<MIDIGetNumberOfSources() { let endpoint = MIDIGetSource(i); result.append(["id":"midi:\(endpoint)", "name": midiName(endpoint)]) }
            sendJS("window.__iosMidiList && window.__iosMidiList(\(json(result)))")
        case "connectMidiInput": if let id = message.body as? String, let endpoint = id.split(separator: ":").last.flatMap({ Int32($0) }) { connect(endpoint: MIDIEndpointRef(endpoint)) }
        case "pairBleMidi":
            sendStatus(kind: "ble", ready: false, text: "BLE MIDI SCANNING...")
            if bleCentral.state == .poweredOn { bleCentral.scanForPeripherals(withServices: [bleService], options: nil) }
        default: break
        }
    }

    private func setupMIDI() {
        MIDIClientCreateWithBlock("DRUMLAB" as CFString, &midiClient) { _ in }
        MIDIInputPortCreateWithBlock(midiClient, "DRUMLAB Input" as CFString, &inputPort) { [weak self] packetList, _ in
            guard let self else { return }
            let packets = packetList.pointee
            var packet = packets.packet
            for _ in 0..<packets.numPackets {
                let bytes = withUnsafeBytes(of: packet) { Array($0.prefix(Int(packet.length))) }
                self.sendJS("window.__iosMidiCallback && window.__iosMidiCallback(\(self.json(bytes)))")
                packet = MIDIPacketNext(&packet).pointee
            }
        }
    }

    private func connect(endpoint: MIDIEndpointRef) {
        MIDIPortConnectSource(inputPort, endpoint, nil)
        sendStatus(kind: "midi", ready: true, text: "MIDI READY")
    }

    private func midiName(_ endpoint: MIDIEndpointRef) -> String { var text: Unmanaged<CFString>?; MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &text); return (text?.takeRetainedValue() as String?) ?? "iPad MIDI Device" }
    private func sendStatus(kind: String, ready: Bool, text: String) { sendJS("window.__iosHardwareCallback && window.__iosHardwareCallback(\(json(["kind":kind,"ready":ready,"text":text])))") }
    private func sendJS(_ script: String) { DispatchQueue.main.async { self.webView.evaluateJavaScript(script) } }
    private func json(_ value: Any) -> String { (try? JSONSerialization.data(withJSONObject: value)).flatMap { String(data: $0, encoding: .utf8) } ?? "null" }

    func centralManagerDidUpdateState(_ central: CBCentralManager) { if central.state != .poweredOn { sendStatus(kind: "bluetooth", ready: false, text: "Bluetooth \(central.state.rawValue)") } }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) { bleCentral.stopScan(); blePeripheral = peripheral; peripheral.delegate = self; bleCentral.connect(peripheral) }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) { peripheral.discoverServices([bleService]) }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) { peripheral.services?.first?.discoverCharacteristics([bleCharacteristicUUID], for: peripheral) }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) { bleCharacteristic = service.characteristics?.first; if let c = bleCharacteristic { peripheral.setNotifyValue(true, for: c) }; sendStatus(kind: "ble", ready: true, text: "BLE MIDI READY (\(peripheral.name ?? "Controller"))"); sendJS("window.__iosBlePair && window.__iosBlePair({name:\(json(peripheral.name ?? "BLE MIDI Controller"))})") }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) { if let value = characteristic.value { sendJS("window.__iosMidiCallback && window.__iosMidiCallback(\(json(Array(value))))") } }
}
