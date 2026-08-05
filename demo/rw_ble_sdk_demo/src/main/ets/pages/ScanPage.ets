import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { access } from '@kit.ConnectivityKit';
import { RwBleDevice, RwBleSdk } from 'rw_ble_sdk';
import { SavedDeviceStore } from '../model/SavedDeviceStore';

@Entry
@Component
struct ScanPage {
  @State private devices: Array<RwBleDevice> = []
  @State private scanning: boolean = false
  @State private status: string = '搜索已暂停'
  @State private btOn: boolean = true
  @State private connectingId: string = ''

  private context(): common.Context {
    return this.getUIContext().getHostContext() as common.Context
  }

  private onBtState = (state: access.BluetoothState): void => {
    this.btOn = state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_BLE_ON
  }

  aboutToAppear(): void {
    try { access.on('stateChange', this.onBtState) } catch (_e) {}
    this.startScan()
  }

  aboutToDisappear(): void {
    this.stopScan()
    try { access.off('stateChange', this.onBtState) } catch (_e) {}
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 0 }) {
          Row({ space: 10 }) {
            Text('‹').fontSize(34).fontColor('#26312C').width(38)
              .onClick(() => this.getUIContext().getRouter().back())
            Text('搜索设备').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#18221E')
          }
          .width('100%')
          .margin({ top: 10 })

          Column({ space: 8 }) {
            Stack() {
              Circle().width(108).height(108).fill('#00000000').stroke('#80B8D8CA').strokeWidth(1)
              Circle().width(70).height(70).fill('#00000000').stroke('#A0CBE3D8').strokeWidth(1)
              Circle().width(28).height(28).fill(this.scanning ? '#0C9B6C' : '#9EAAA4')
            }
            .width(112)
            .height(112)
            Text(this.scanning ? '正在搜索附近设备' : this.status)
              .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#1C2823')
            Text(this.btOn ? '请保持戒指电量充足并靠近手机' : '请先开启手机蓝牙')
              .fontSize(13).fontColor(this.btOn ? '#8A948F' : '#C44C4C')
            Button(this.scanning ? '停止搜索' : '重新搜索')
              .fontSize(14)
              .fontColor('#087D59')
              .backgroundColor('#E4F2EC')
              .borderRadius(22)
              .margin({ top: 8 })
              .onClick(() => this.scanning ? this.stopScan() : this.startScan())
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .padding({ top: 24, bottom: 20 })

          Row({ space: 8 }) {
            Text('发现的设备').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#1C2823')
            Text(`${this.devices.length} 台`).fontSize(12).fontColor('#8A948F')
          }
          .width('100%')
          .margin({ top: 12, bottom: 13 })

          if (this.devices.length > 0) {
            List() {
              ForEach(this.devices, (device: RwBleDevice) => {
                ListItem() {
                  Column({ space: 10 }) {
                    Row({ space: 13 }) {
                      Stack() {
                        Circle().width(44).height(44).fill('#00000000').stroke('#7D968B').strokeWidth(5)
                        Circle().width(18).height(18).fill('#FFFFFF')
                      }
                      .width(46)
                      .height(46)
                      Text(device.name ?? '未命名设备').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1C2823')
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                      Column({ space: 4 }) {
                        Text(this.signalText(device.rssi ?? -100)).fontSize(12).fontColor('#46705F')
                        Text(`${device.rssi ?? 0} dBm`).fontSize(10).fontColor('#A0A8A4')
                      }
                      if (this.connectingId === device.deviceId) {
                        LoadingProgress().width(24).height(24).color('#0C9B6C')
                      } else {
                        Text('›').fontSize(26).fontColor('#BDC5C1')
                      }
                    }
                    .width('100%')
                    Column({ space: 5 }) {
                      Row() {
                        Text('MAC').fontSize(11).fontColor('#74827B').width(60)
                        Text(this.macText(device)).fontSize(11).fontColor('#56645D')
                          .maxLines(2).layoutWeight(1)
                      }
                      .width('100%')
                      Row() {
                        Text('deviceId').fontSize(11).fontColor('#74827B').width(60)
                        Text(this.deviceIdText(device)).fontSize(10).fontColor('#66736D')
                          .maxLines(2).layoutWeight(1)
                      }
                      .width('100%')
                    }
                    .alignItems(HorizontalAlign.Start)
                    .width('100%')
                    .padding({ left: 59 })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 15, bottom: 15 })
                  .backgroundColor('#FFFFFF')
                  .onClick(() => this.connectDevice(device))
                }
              }, (device: RwBleDevice) => device.deviceId)
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(20)
            .divider({ strokeWidth: 1, color: '#EDF0EE', startMargin: 16, endMargin: 16 })
          } else {
            Column({ space: 10 }) {
              Text(this.scanning ? '正在搜索...' : '暂未发现设备').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1C2823')
              Text('确认戒指未被其他手机连接，然后点击重新搜索。').fontSize(13).fontColor('#909A95').textAlign(TextAlign.Center)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding({ top: 42, bottom: 42, left: 24, right: 24 })
            .backgroundColor('#FFFFFF')
            .borderRadius(20)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 28 })
      }
      .height('100%')

      if (this.connectingId.length > 0) {
        Column({ space: 12 }) {
          LoadingProgress().width(50).height(50).color('#FFFFFF')
          Text('正在连接设备').fontSize(15).fontColor('#FFFFFF')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor('#8A000000')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7F5')
  }

  private async startScan(): Promise<void> {
    if (this.scanning) return
    const granted = await this.ensureBluetoothGranted()
    if (!granted) {
      this.status = '需要蓝牙权限，请授权后重试'
      return
    }
    try { access.enableBluetooth() } catch (_e) {}
    this.devices = []
    this.scanning = true
    this.status = '正在搜索附近设备'
    RwBleSdk.startScan({
      onScanDevice: (device: RwBleDevice) => this.upsert(device),
      onScanFinish: () => {
        this.scanning = false
        this.status = '搜索已暂停'
      },
      onError: (_code: number, error: Error) => {
        this.scanning = false
        this.status = `搜索失败: ${error.message}`
      }
    })
  }

  private async ensureBluetoothGranted(): Promise<boolean> {
    const host = this.getUIContext().getHostContext()
    if (!host) return false
    try {
      const permissions: Array<Permissions> = ['ohos.permission.ACCESS_BLUETOOTH']
      const result = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(host as common.UIAbilityContext, permissions)
      return result.authResults.every((value: number) => value === 0)
    } catch (_e) {
      return false
    }
  }

  private stopScan(): void {
    RwBleSdk.stopScan()
    this.scanning = false
    if (this.connectingId.length === 0) this.status = '搜索已暂停'
  }

  private async connectDevice(device: RwBleDevice): Promise<void> {
    if (this.connectingId.length > 0) return
    this.connectingId = device.deviceId
    RwBleSdk.stopScan()
    this.scanning = false
    try {
      await SavedDeviceStore.save(this.context(), device)
      RwBleSdk.connectDeviceWithModel(device)
      this.getUIContext().getRouter().back()
    } catch (error) {
      this.connectingId = ''
      this.showToast(`连接失败: ${JSON.stringify(error)}`)
    }
  }

  private upsert(device: RwBleDevice): void {
    const key = this.deviceKey(device)
    const next = this.devices.slice()
    const index = next.findIndex((item: RwBleDevice) => this.deviceKey(item) === key)
    if (index >= 0) next[index] = device
    else next.push(device)
    next.sort((first: RwBleDevice, second: RwBleDevice) => (second.rssi ?? -999) - (first.rssi ?? -999))
    this.devices = next
  }

  private deviceKey(device: RwBleDevice): string {
    const uuid = device.uuid?.trim() ?? ''
    const mac = device.mac?.trim() ?? ''
    const deviceId = device.deviceId.trim()
    return uuid || mac || deviceId
  }

  private macText(device: RwBleDevice): string {
    const mac = device.mac?.trim() ?? ''
    if (mac.length > 0) return mac
    return this.macFromDeviceId(device.deviceId) ?? '未从广播获取'
  }

  private deviceIdText(device: RwBleDevice): string {
    const deviceId = device.deviceId.trim()
    if (deviceId.length > 0) return deviceId
    const uuid = device.uuid?.trim() ?? ''
    return uuid.length > 0 ? uuid : '未获取'
  }

  private macFromDeviceId(deviceId: string): string | undefined {
    const normalized = deviceId.replace(/:/g, '').replace(/-/g, '').toUpperCase()
    if (normalized.length !== 12) return undefined
    const hex = '0123456789ABCDEF'
    for (let index = 0; index < normalized.length; index++) {
      if (!hex.includes(normalized[index])) return undefined
    }
    const parts: Array<string> = []
    for (let index = 0; index < normalized.length; index += 2) {
      parts.push(normalized.substring(index, index + 2))
    }
    return parts.join(':')
  }

  private signalText(rssi: number): string {
    if (rssi >= -60) return '信号强'
    if (rssi >= -75) return '信号良好'
    return '信号较弱'
  }

  private showToast(message: string): void {
    try { promptAction.showToast({ message, duration: 2000 }) } catch (_e) {}
  }
}
