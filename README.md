# ble_adv_packet_decode
Load recorded I/Q data, demodulate and decode.


# BLE Advertising Packet Recorder & Decoder (SDR to SigMF Ground Truth)

[![MATLAB](https://img.shields.io/badge/MATLAB-R2021a%2B-orange.svg)](https://www.mathworks.com/products/matlab.html)
[![Format: SigMF](https://img.shields.io/badge/Standard-SigMF%20v1.0.0-blue.svg)](https://github.com/sigmf/SigMF)
[![Hardware](https://img.shields.io/badge/Hardware-ADALM--Pluto-green.svg)](https://wiki.analog.com/university/tools/pluto)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An end-to-end SDR signal acquisition, baseband processing, and Link-Layer decoding pipeline implemented in MATLAB. This project captures raw over-the-air (OTA) RF I/Q samples on Bluetooth Low Energy (BLE) Advertising Channel 37 (2402 MHz) using an **ADALM-Pluto SDR** running **Maia-SDR**, archives the dataset in the open-standard **SigMF** format, and executes baseband demodulation, de-whitening, CRC-24 validation, and Link Layer PDU parsing.

Deterministic burst intervals and metadata extracted from CRC-verified packets are programmatically exported as **ground-truth SigMF annotations**, eliminating manual labeling bottlenecks and facilitating RF-ML / YOLO-based wideband signal detection on spectrograms.

---

## 📌 Abstract & Key Highlights

- **Low-IF Architecture Planning**: Tuned receiver LO to $2401\text{ MHz}$ ($1\text{ MHz}$ offset from Channel 37 at $2402\text{ MHz}$) across a $100\text{ ms}$ capture window to circumvent the inherent Zero-IF DC offset spike.
- **Robust Baseband DSP**: Incorporates Digital Down-Conversion (DDC), an order-50 Channel-Select Low-Pass Filter ($F_c = 1\text{ MHz}$), and a Double Sliding Window (DSW) detector for SNR-adaptive burst edge localization.
- **Non-Coherent Demodulation**: Employs a delay-and-multiply phase differentiator acting as a digital FM discriminator, coupled with matched-filter synchronization against the preamble (`0xAA`) and Access Address (`0x8E89BED6`).
- **Complete Link-Layer Protocol Dissection**: De-whitens using the channel 37 LFSR polynomial ($x^7 + x^4 + 1$), verifies 24-bit CRC, and decodes PDU headers, MAC address types (RPA / NRPA), and vendor payloads (Apple Continuity, Nearby Info/Action, Microsoft telemetry).
- **Automated RF-ML Ground Truth**: Uses Link Layer Length indicators and verified CRC boundaries to auto-generate bounding-box SigMF annotations for machine learning workflows.

---

## 🏗️ System Architecture & Processing Pipeline

```text
       ADALM-Pluto SDR (Maia-SDR Firmware, Fs = 8 MSPS, f_LO = 2401 MHz)
                                      │
                                      ▼
                      Raw I/Q Recording (.sigmf-data)
                                      │
                                      ▼
                      [f_read_sigmf.m] (SigMF Ingestion)
                                      │
                                      ▼
      Digital Down-Conversion (DDC) -> 1 MHz shift to Baseband DC
                                      │
                                      ▼
             Channel Low-Pass Filter (N = 50, Fc = 1 MHz)
                                      │
                                      ▼
               [dsw.m] Double Sliding Window Burst Detector
                                      │
                                      ▼
             Phase Differentiator (Delay-and-Multiply FM Discriminator)
                                      │
                                      ▼
             Matched Filter Sync (Preamble 0xAA + AA 0x8E89BED6)
                                      │
                                      ▼
                  Symbol Sampling & Slicing @ 1 Msps
                                      │
                                      ▼
                 [ble_whitener.m] (LFSR De-whitening, Ch 37)
                                      │
                                      ▼
                  [get_ble_pdu_info.m] (Header Parsing)
                                      │
                                      ▼
                 [ble_crc_check.m] (24-bit CRC Verification)
                                      │
                    ┌─────────────────┴─────────────────┐
           [Pass CRC-24]                       [Fail CRC-24]
                    │                                   │
                    ▼                                   ▼
   [ble_adv_pdu_payload_parser.m]                    Discard
   [ble_adv_pdu_payload_content.m]
   [apple_type.m] (Payload Breakdown)
                    │
                    ▼
       [write_sigmf_annotations.m]
  (Programmatic Ground-Truth for YOLO)

```

---

## ⚙️ Mathematical & Algorithmic Formulation

### 1. Digital Down-Conversion (DDC)

Following Low-IF reception at $f_{\text{LO}} = 2401\text{ MHz}$, received complex baseband samples $r(t) = I(t) + jQ(t)$ are mixed down to DC:

$$r_{\text{DDC}}(t) = r(t) \cdot \exp\left(-j 2\pi \frac{f_{\text{IF}}}{F_s} t\right)$$

Where $f_{\text{IF}} = f_c - f_{\text{LO}} = 1\text{ MHz}$ and $F_s = 7.999999\text{ MSPS} \approx 8\text{ MSPS}$.

### 2. Channel-Select Filtering

An order-$50$ FIR Low-Pass Filter attenuates the shifted hardware DC component, thermal noise, and adjacent-channel energy:

$$y(t) = \int_{0}^{T_L} h_{\text{LPF}}(\tau) \, r_{\text{DDC}}(t - \tau) \, d\tau \quad (N = 50, F_c = 1\text{ MHz})$$

### 3. De-whitening & CRC-24 Verification

* **De-whitener LFSR**: Polynomial $x^7 + x^4 + 1$, initialized with the 6-bit physical channel index 37 (`100101b` prepended with `1`).
* **CRC-24 Polynomial**: $x^{24} + x^{10} + x^9 + x^6 + x^4 + x^3 + x + 1$ with initial state `0x555555`.

---

## 📋 Protocol Layer & Frame Breakdown

```text
+-------------------+----------------------+--------------------+--------------------+
|  Preamble (1 Byte)| Access Address (4B)  |  PDU (2 - 257 B)   |    CRC (3 Bytes)   |
|   (0xAA or 0x55)  |  (0x8E89BED6 for Adv)|                    |                    |
+-------------------+----------------------+--------------------+--------------------+
                                           /                    \
    +-------------------------------------+                      +
    | Header (2 Bytes) | Payload (0 - 255 Bytes)                 |
    +------------------+-----------------------------------------+
    |  - PDU Type (4b) | AdvA (6 Bytes, Advertiser Address)      |
    |  - RFU (1b)      | AdvData (0 - 245 Bytes, AD Structures)  |
    |  - ChSel (1b)    |                                         |
    |  - TxAdd (1b)    |                                         |
    |  - RxAdd (1b)    |                                         |
    |  - Length (8b)   |                                         |
    +------------------+-----------------------------------------+

```

| Layer | Field | Size | Algorithmic Processing Logic |
| --- | --- | --- | --- |
| **PHY** | Preamble + Access Address | 1 B + 4 B | Cross-correlated against `10101010b` and `0x8E89BED6` to recover symbol timing and packet boundary. |
| **Link Layer (Header)** | PDU Type | 4 bits | Identifies PDU class (e.g., `0000` for `ADV_IND`, `0010` for `ADV_NONCONN_IND`). |
| **Link Layer (Header)** | TxAdd / RxAdd | 1 bit ea. | Distinguishes Public vs. Random (RPA / NRPA) MAC addresses. |
| **Link Layer (Header)** | Length | 6 bits | **Key Parameter**: Dynamically specifies payload length (6–37 Bytes), enabling exact boundary localization of the trailing CRC. |
| **Link Layer (Payload)** | ADV Address | 6 Bytes | Resolves broadcasting device 48-bit MAC address. |
| **GAP Profile** | AD Structures | Variable | Iteratively parses `[Length | Type | Data]`; isolates Manufacturer Specific Data (`0xFF`). |
| **Trailer** | CRC | 3 Bytes | Evaluates 24-bit polynomial syndrome; passes trigger automatic SigMF dataset annotation. |

---

## 📁 Repository Structure

```text
ble_adv_packet_decode/
├── 2026-10-07-17-57-16_recording.sigmf   # Sample SigMF dataset (Low-IF capture @ 2401 MHz)
├── main_record_ble_decode.m             # Top-level execution & processing coordinator
├── f_read_sigmf.m                       # SigMF I/Q data and JSON metadata reader
├── dsw.m                                # Double Sliding Window (DSW) burst edge detector
├── ble_whitener.m                       # 7-bit LFSR de-whitener (Polynomial: x^7 + x^4 + 1)
├── ble_crc_check.m                      # 24-bit CRC validator (Polynomial: x^24 + ... + 1)
├── get_ble_pdu_info.m                   # PDU header extractor (Type, TxAdd, RxAdd, Length)
├── ble_adv_pdu_payload_parser.m         # AD element chunk parser (TLV structure)
├── ble_adv_pdu_payload_content.m        # AD type mapper (Flags, Name, Tx Power, Vendor Data)
├── apple_type.m                         # Apple Continuity / Nearby Info / Action parser
├── write_sigmf_annotations.m            # Programmatic SigMF annotation exporter
└── README.md

```

---

## 📊 Experimental Results

Demodulating the sample recording (`2026-10-07-17-57-16_recording.sigmf`, $100\text{ ms}$ duration) successfully localized and decoded **7 distinct advertising bursts** without manual intervention:

| # | PDU Type | MAC Address | Address Type | Vendor / Payload Content | Status |
| --- | --- | --- | --- | --- | --- |
| **1** | `ADV_NONCONN_IND` | `1D:64:69:C0:B3:B3` | Non-Resolvable Private | Apple (Type 0x13, Length 8) | CRC Valid |
| **2** | `ADV_NONCONN_IND` | `32:7B:74:E9:A4:CE` | Non-Resolvable Private | Microsoft (`0x0006` telemetry payload) | CRC Valid |
| **3** | `ADV_IND` | `67:7F:94:24:E5:A8` | Resolvable Private (RPA) | Apple Nearby Info, Tx Power: 12 dBm | CRC Valid |
| **4** | `ADV_IND` | `58:44:88:B5:CB:0F` | Resolvable Private (RPA) | Apple Nearby Action + Nearby Info, Tx Power: 0 dBm | CRC Valid |
| **5** | `ADV_IND` | `58:44:88:B5:CB:0F` | Resolvable Private (RPA) | Apple Nearby Action + Nearby Info, Tx Power: 0 dBm | CRC Valid |
| **6** | `ADV_NONCONN_IND` | `64:AF:7D:56:FF:66` | Resolvable Private (RPA) | Apple (Type 0x09 & 0x16 Continuity) | CRC Valid |
| **7** | `ADV_IND` | `49:16:38:4A:0E:61` | Resolvable Private (RPA) | Apple Nearby Info, Tx Power: 17 dBm | CRC Valid |

---

## 🚀 Getting Started

### Prerequisites

* **MATLAB**: R2021a or newer recommended
* Toolboxes (recommended):
* Communications Toolbox™
* Signal Processing Toolbox™



### Quick Run

1. Clone the repository:
```bash
git clone [https://github.com/jorgecmc/ble_adv_packet_decode.git](https://github.com/jorgecmc/ble_adv_packet_decode.git)
cd ble_adv_packet_decode

```


2. Open MATLAB and navigate to the project directory.
3. Run the top-level script:
```matlab
main_record_ble_decode

```


4. Decoded packet details will print to the MATLAB command window, and deterministic packet boundaries will be written to the dataset annotations via `write_sigmf_annotations.m`.

---

## 🔗 References & Standards

* [Bluetooth Core Specification v6.x (Link Layer Specification)](https://www.bluetooth.com/specifications/specs/)
* [Supplement to the Bluetooth Core Specification (CSS v12)](https://www.bluetooth.com/specifications/specs/)
* [SigMF (Signal Metadata Format) Specification v1.0.0](https://github.com/sigmf/SigMF)
* [Bluetooth SIG Assigned Numbers - Company Identifiers](https://bitbucket.org/bluetooth-SIG/public/src/main/assigned_numbers/company_identifiers/company_identifiers.yaml)
* [Apple Continuity Protocol Reverse Engineering (seemoo-lab)](https://github.com/seemoo-lab/apple-continuity-tools)
* Technical Notes: [Record and Decode Bluetooth Advertising Packet](https://jorgechen.notion.site/Record-and-Decode-Bluetooth-Advertising-Packet-3f8ab7c06da58089b1c2d43f42c93cee)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://www.google.com/search?q=LICENSE) file for details.

```

```