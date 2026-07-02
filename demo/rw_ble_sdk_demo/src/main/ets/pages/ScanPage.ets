import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { access } from '@kit.ConnectivityKit';
import { RwBleDevice, RwBleSdk } from 'rw_ble_sdk';
import { SavedDeviceStore } from '../model/SavedDeviceStore';

@Entry
@Component
struct ScanPage {
  @State private devices: Array<RwBleDevice> = []
  @State private scanning: boolean = false
  @State private status: string = '已停止'
  @State private btOn: boolean = true

  private context(): common.Context {
    return this.getUIContext().getHostContext() as common.Context
  }

  // Track the Bluetooth adapter state for a UI indicator. (Querying current
  // state needs API 13's getState(); at API 12 we rely on the stateChange event.)
  private onBtState = (state: access.BluetoothState): void => {
    this.btOn = state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_BLE_ON
  }

  aboutToAppear(): void {
    try {
      access.on('stateChange', this.onBtState)
    } catch (_e) {
      // ignore registration errors
    }
  }

  aboutToDisappear(): void {
    try {
      access.off('stateChange', this.onBtState)
    } catch (_e) {
      // ignore
    }
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Normal)
          .onClick(() => this.getUIContext().getRouter().back())
        Text('扫描设备')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')

      Text(this.scanning ? '扫描中...' : this.status)
        .fontSize(14)
        .fontColor('#687076')
        .width('100%')

      Text(`蓝牙适配器: ${this.btOn ? '已开启' : '未开启'}`)
        .fontSize(12)
        .fontColor(this.btOn ? '#10b981' : '#ef4444')
        .width('100%')

      Row({ space: 8 }) {
        Button('开始扫描')
          .enabled(!this.scanning)
          .onClick(() => this.startScan())
          .layoutWeight(1)
        Button('停止扫描')
          .enabled(this.scanning)
          .onClick(() => this.stopScan())
          .layoutWeight(1)
      }
      .width('100%')

      List({ space: 8 }) {
        ForEach(this.devices, (device: RwBleDevice) => {
          ListItem() {
            Row() {
              Column({ space: 4 }) {
                Text(device.name ?? '未命名设备').fontSize(16).fontWeight(FontWeight.Medium)
                Text(`MAC: ${device.mac ?? '-'}`).fontSize(12).fontColor('#687076')
                Text(`deviceId: ${device.deviceId}`).fontSize(11).fontColor('#9CA3AF')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text(`${device.rssi ?? 0}`).fontSize(12).fontColor('#687076')
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .border({ width: 1, color: '#E5E7EB' })
            .onClick(() => this.connectDevice(device))
          }
        }, (device: RwBleDevice) => device.deviceId)
      }
      .layoutWeight(1)
      .width('100%')

      if (this.devices.length === 0) {
        Text(this.scanning ? '正在扫描...' : '未发现设备')
          .fontColor('#687076')
          .fontSize(14)
      }
    }
    .padding(16)
    .height('100%')
    .backgroundColor('#F6F8FA')
  }

  private async startScan(): Promise<void> {
    const granted = await this.ensureBluetoothGranted()
    if (!granted) {
      this.status = '需要蓝牙权限,请授权后重试'
      return
    }
    // Ensure the Bluetooth adapter is on before scanning (available since API 10; no-op if already on).
    try {
      access.enableBluetooth()
    } catch (_e) {
      // ignore; the scan below surfaces any real failure via onError
    }
    this.devices = []
    this.scanning = true
    this.status = '扫描中...'
    RwBleSdk.startScan({
      onScanDevice: (device: RwBleDevice) => this.upsert(device),
      onScanFinish: () => {
        this.scanning = false
        this.status = '已停止'
      },
      onError: (_code: number, error: Error) => {
        this.scanning = false
        this.status = `扫描失败: ${error.message}`
      }
    })
  }

  // ohos.permission.ACCESS_BLUETOOTH is a user_grant permission: declared in
  // module.json5 AND must be requested at runtime before ble.startBLEScan().
  private async ensureBluetoothGranted(): Promise<boolean> {
    const host = this.getUIContext().getHostContext()
    if (!host) return false
    const ctx = host as common.UIAbilityContext
    try {
      const perms: Array<Permissions> = ['ohos.permission.ACCESS_BLUETOOTH']
      const atm = abilityAccessCtrl.createAtManager()
      const res = await atm.requestPermissionsFromUser(ctx, perms)
      return res.authResults.every((r) => r === 0)
    } catch (_e) {
      return false
    }
  }

  private stopScan(): void {
    RwBleSdk.stopScan()
    this.scanning = false
    this.status = '已停止'
  }

  private async connectDevice(device: RwBleDevice): Promise<void> {
    this.stopScan()
    await SavedDeviceStore.save(this.context(), device)
    RwBleSdk.connectDeviceWithModel(device)
    this.getUIContext().getRouter().back()
  }

  private upsert(device: RwBleDevice): void {
    const key = device.uuid ?? device.mac ?? device.deviceId
    const next = this.devices.slice()
    const index = next.findIndex((it) => (it.uuid ?? it.mac ?? it.deviceId) === key)
    if (index >= 0) {
      next[index] = device
    } else {
      next.push(device)
    }
    next.sort((a, b) => (b.rssi ?? -999) - (a.rssi ?? -999))
    this.devices = next
  }
}
