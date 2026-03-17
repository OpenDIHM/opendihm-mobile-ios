# opendihm-mobile-ios
The iOS client-application for using OpenDIHM project. The application is a simple UI for controlling the microscope.
It is built using SwiftUI and Swift. It starts the communication with the firmware via Bluetooth and shares the WiFi
connection with the firmware. After the connection is established, the application displays the video stream from the
firmware and provides controls for the microscope. The controls are provided via HTTP API with basic authentication.

## Features
- UI for WiFi connection sharing via Bluetooth
- UI for microscope control
   - Laser control (on/off via relay)
   - Camera control (zoom (3-levels), v4l2 controls)
- UI for video stream display over RTSP
- UI for authentication of the user
- UI for logging out the user
- UI for configuration of the microscope
- UI for updating the configuration of the microscope
- UI for server status
- UI for server logs

## Connection Flow
- The Raspberry Pi boots up and broadcasts a Bluetooth Low Energy (BLE) signal.
- The iOS app connects to the Pi via Bluetooth.
- The iOS app securely sends the current Wi-Fi network's SSID and password over Bluetooth to the Pi.
- The iOS app displays the video stream from the Raspberry Pi over RTSP.

## Platform
- iOS 26.0
- Xcode 26.0
- Swift 6.2

## Project Architecture
```mermaid
graph TD
    subgraph UI_Layer ["View Layer (SwiftUI)"]
        Root["RootView (Navigation)"]
        CV["ConnectionView (BLE/WiFi)"]
        DV["DirectConnectView"]
        SV["StreamingView (Live Preview)"]
        CT["ControlView (Capture/Metadata)"]
    end

    subgraph Logic_Layer [ViewModel Layer]
        CVM["ConnectionViewModel"]
        DVM["DirectConnectViewModel"]
        SVM["StreamingViewModel"]
        TVM["ControlViewModel"]
    end

    subgraph Service_Layer [Service & Utility Layer]
        BLE["BLEManager (CoreBluetooth)"]
        API["MicroscopeAPIClient (REST)"]
        Parser["H264StreamParser (VTB Bridge)"]
        VTB["VideoToolbox (Hardware Decoding)"]
        Config["MicroscopeConfig (Local State)"]
    end

    %% Wiring
    Root --> CV & DV & SV & CT
    CV <--> CVM
    DV <--> DVM
    SV <--> SVM
    CT <--> TVM

    %% Service Integration
    CVM --> BLE
    DVM & TVM & SVM --> API
    SVM --> Parser
    Parser --> VTB
    CVM & DVM & TVM --> Config

    %% External Comm
    BLE -.-> |"Bluetooth"| Pi[Raspberry Pi]
    API -.-> |"HTTP"| Pi
    Parser -.-> |"Raw TCP:8888"| Pi

```