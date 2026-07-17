import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { promptAction } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { systemShare } from '@kit.ShareKit';
import fs from '@ohos.file.fs';
import zlib from '@ohos.zlib';
import { DrinkReminderBean, FirmVersionBean, HealthDataSyncBean, PowerBean, RwBleDevice, RwBleSdk, SupportMenuBean } from 'rw_ble_sdk';
import { SavedDeviceStore } from '../model/SavedDeviceStore';

const TELINK_OTA_FILE_NAME = 'TL01V10_TL01_40010000_V2.2.6_HBAT_20260710_20594277.bin'
const PXI_OTA_FILE_NAME = 'SY14V10_SR16_30380000_V2.5.4_HBAT_20260521_17100805.bin'

@Entry
@Component
struct HomePage {
  @State private connected: boolean = false
  @State private deviceName: string = '未连接'
  @State private sdkVersion: string = ''
  @State private savedDeviceText: string = '无保存设备'
  @State private logText: string = ''
  @State private savedDevice: RwBleDevice | null = null
  @State private hrMeasuring: boolean = false
  @State private connecting: boolean = false
  @State private menu: SupportMenuBean | null = null
  @State private otaRunning: boolean = false
  @State private otaProgress: number = 0

  private context(): common.Context {
    return this.getUIContext().getHostContext() as common.Context
  }
  private realtimeUnsub: (() => void) | null = null

  aboutToAppear(): void {
    this.initPage()
  }

  onPageShow(): void {
    this.loadSavedDevice()
  }

  private async initPage(): Promise<void> {
    await this.loadSavedDevice()
    RwBleSdk.setConnectBleCallback({
      onRingConnecting: () => {
        this.connecting = true
        this.addLog('连接中...')
      },
      onRingConnected: () => {
        this.connected = true
        this.deviceName = this.savedDevice?.name ?? '设备'
        this.addLog('链路已连接，等待功能表')
      },
      onRingConnectFailed: (reason: string) => {
        this.connecting = false
        this.connected = false
        this.deviceName = '连接失败'
        this.addLog(`连接失败: ${reason}`)
        this.showToast(`连接失败: ${reason}`)
      },
      onRingDisconnected: (reason: string) => {
        this.connecting = false
        this.connected = false
        this.deviceName = '已断开'
        this.hrMeasuring = false
        this.menu = null
        this.addLog(`已断开: ${reason}`)
        this.showToast('设备已断开')
      },
      onRingDidFunctionMenu: async (menuBean: SupportMenuBean) => {
        this.connecting = false
        this.menu = menuBean
        this.connected = true
        this.deviceName = menuBean.name ?? this.savedDevice?.name ?? '设备'
        this.showToast('连接成功')
        if (this.savedDevice) {
          const updated: RwBleDevice = {
            deviceId: this.savedDevice.deviceId,
            name: menuBean.name ?? this.savedDevice.name,
            mac: menuBean.mac ?? this.savedDevice.mac,
            uuid: menuBean.uuid ?? this.savedDevice.uuid,
            rssi: this.savedDevice.rssi,
            brand: this.savedDevice.brand,
            data: this.savedDevice.data
          }
          await SavedDeviceStore.save(this.context(), updated)
          this.savedDevice = updated
          this.refreshSavedText()
        }
        this.addLog('设备就绪')
      }
    })
    RwBleSdk.initSDK(this.context())
    this.sdkVersion = RwBleSdk.getSDKVersion()
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 14 }) {
          Text('RW BLE Demo')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .width('100%')

          // 设备状态栏
          Column({ space: 6 }) {
            Text(this.deviceName).fontSize(20).fontWeight(FontWeight.Medium)
            Text(this.sdkVersion).fontSize(12).fontColor('#687076')
            Text(this.connected ? '已连接' : '未连接')
              .fontSize(14)
              .fontColor(this.connected ? '#087443' : '#9A3412')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(14)
          .backgroundColor('#F6F8FA')
          .borderRadius(8)

          this.ConnectionSection()
          this.DeviceInfoSection()
          this.OtaSection()
          this.RealtimeHealthSection()
          this.TimedHealthSection()
          this.HealthSyncSection()
          this.NavSection()
          this.LogSection()
        }
        .padding(16)
        .width('100%')
      }
      .height('100%')

      // Loading overlay
      if (this.connecting) {
        Column() {
          LoadingProgress().width(48).height(48).color('#FFFFFF')
          Text('连接中...').fontSize(14).fontColor('#FFFFFF').margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ConnectionSection() {
    Column({ space: 10 }) {
      Text('连接管理').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Text(this.savedDeviceText).fontSize(13).fontColor('#687076').width('100%')
      if (this.savedDevice) {
        Text(`MAC: ${this.savedDevice.mac ?? '-'}  deviceId: ${this.savedDevice.deviceId}`)
          .fontSize(11).fontColor('#9CA3AF').width('100%')
      }
      Row({ space: 8 }) {
        Button(this.savedDevice ? '重新搜索' : '搜索设备')
          .onClick(() => this.goScan())
          .layoutWeight(1)
        Button('重连设备')
          .enabled(!!this.savedDevice && !this.connected && !this.connecting)
          .onClick(() => this.reconnect())
          .layoutWeight(1)
        Button('解绑')
          .type(ButtonType.Normal)
          .enabled(!!this.savedDevice)
          .onClick(() => this.unbindAndSearch())
          .layoutWeight(1)
      }
      .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private DeviceInfoSection() {
    Column({ space: 10 }) {
      Text('设备信息').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Row({ space: 8 }) {
        Button('电量')
          .enabled(this.connected)
          .onClick(() => this.getPower())
          .layoutWeight(1)
        Button('固件版本')
          .enabled(this.connected)
          .onClick(() => this.getFirmware())
          .layoutWeight(1)
        Button('MAC地址')
          .enabled(this.connected)
          .onClick(() => this.getMac())
          .layoutWeight(1)
      }
      .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private OtaSection() {
    Column({ space: 10 }) {
      Text('OTA升级测试').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Text(`Telink: ${TELINK_OTA_FILE_NAME}`)
        .fontSize(11)
        .fontColor('#687076')
        .width('100%')
      Text(`PXI: ${PXI_OTA_FILE_NAME}`)
        .fontSize(11)
        .fontColor('#687076')
        .width('100%')
      Text('升级过程中请保持设备连接和电量充足，勿退出应用。')
        .fontSize(12)
        .fontColor('#B45309')
        .width('100%')
      Text(`进度: ${this.otaProgress}%`)
        .fontSize(13)
        .width('100%')
      Button(this.otaRunning ? 'OTA升级中...' : '使用 Telink 固件升级')
        .enabled(this.connected && !this.otaRunning)
        .onClick(() => this.startBundledOta(TELINK_OTA_FILE_NAME, 'Telink'))
        .width('100%')
      Button(this.otaRunning ? 'OTA升级中...' : '使用 PXI 固件升级')
        .enabled(this.connected && !this.otaRunning)
        .onClick(() => this.startBundledOta(PXI_OTA_FILE_NAME, 'PXI'))
        .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private RealtimeHealthSection() {
    Column({ space: 10 }) {
      Text('实时检测').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Row({ space: 8 }) {
        Button(this.hrMeasuring ? '停止心率' : '心率')
          .enabled(this.connected && this.menu?.isHr === true)
          .onClick(() => this.toggleRealtimeHr())
          .layoutWeight(1)
        Button('血氧')
          .enabled(this.connected && this.menu?.isBloodOxy === true)
          .onClick(() => this.startRealtimeBo())
          .layoutWeight(1)
        Button('HRV')
          .enabled(this.connected && this.menu?.isHrv === true)
          .onClick(() => this.startRealtimeHrv())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('压力')
          .enabled(this.connected && this.menu?.isPressure === true)
          .onClick(() => this.startRealtimeStress())
          .layoutWeight(1)
        Button('血糖')
          .enabled(this.connected && this.menu?.isBloodSugar === true)
          .onClick(() => this.startRealtimeBloodSugar())
          .layoutWeight(1)
        Button('体温')
          .enabled(this.connected && this.menu?.isDataTypeTemperature === true)
          .onClick(() => this.startRealtimeTemp())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('血压')
          .enabled(this.connected && this.menu?.isBloodPress === true)
          .onClick(() => this.startRealtimeBp())
          .layoutWeight(1)
      }
      .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private TimedHealthSection() {
    Column({ space: 10 }) {
      Text('定时检测').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Row({ space: 8 }) {
        Button('获取心率')
          .enabled(this.connected && this.menu?.isHr === true)
          .onClick(() => this.getTimedHr())
          .layoutWeight(1)
        Button('设心率60分')
          .enabled(this.connected && this.menu?.isHr === true)
          .onClick(() => this.setTimedHr())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('获取血氧')
          .enabled(this.connected && this.menu?.isBloodOxy === true)
          .onClick(() => this.getTimedBo())
          .layoutWeight(1)
        Button('设血氧开')
          .enabled(this.connected && this.menu?.isBloodOxy === true)
          .onClick(() => this.setTimedBo())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('获取HRV')
          .enabled(this.connected && this.menu?.isHrv === true)
          .onClick(() => this.getTimedHrv())
          .layoutWeight(1)
        Button('设HRV开')
          .enabled(this.connected && this.menu?.isHrv === true)
          .onClick(() => this.setTimedHrv())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('获取压力')
          .enabled(this.connected && this.menu?.isPressure === true)
          .onClick(() => this.getTimedStress())
          .layoutWeight(1)
        Button('设压力开')
          .enabled(this.connected && this.menu?.isPressure === true)
          .onClick(() => this.setTimedStress())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('获取血糖')
          .enabled(this.connected && this.menu?.isBloodSugar === true)
          .onClick(() => this.getTimedBloodSugar())
          .layoutWeight(1)
        Button('设血糖开')
          .enabled(this.connected && this.menu?.isBloodSugar === true)
          .onClick(() => this.setTimedBloodSugar())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('获取血压')
          .enabled(this.connected && this.menu?.isBloodPress === true)
          .onClick(() => this.getTimedBp())
          .layoutWeight(1)
        Button('设血压开')
          .enabled(this.connected && this.menu?.isBloodPress === true)
          .onClick(() => this.setTimedBp())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('获取体温')
          .enabled(this.connected && this.menu?.isDataTypeTemperature === true)
          .onClick(() => this.getTimedTemp())
          .layoutWeight(1)
        Button('设体温开')
          .enabled(this.connected && this.menu?.isDataTypeTemperature === true)
          .onClick(() => this.setTimedTemp())
          .layoutWeight(1)
      }
      .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private HealthSyncSection() {
    Column({ space: 10 }) {
      Text('健康数据同步').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Button('同步全部健康数据')
        .enabled(this.connected)
        .onClick(() => this.syncAllHealth())
        .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private NavSection() {
    Column({ space: 10 }) {
      Button('设置页（闹钟/震动/亮屏/LED等）')
        .enabled(this.connected)
        .onClick(() => this.goSettings())
        .width('100%')
      Button('运动页（Workout）')
        .enabled(this.connected && this.menu?.isNewSport !== false)
        .onClick(() => this.goWorkout())
        .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private LogSection() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('日志').fontSize(18).fontWeight(FontWeight.Medium).layoutWeight(1)
        Button('分享日志').type(ButtonType.Normal).onClick(() => this.shareLogs())
        Button('清空').type(ButtonType.Normal).onClick(() => this.logText = '')
      }
      Text(this.logText || '暂无日志')
        .fontSize(12)
        .fontColor('#444B53')
        .width('100%')
        .height(200)
    }
    .sectionStyle()
  }

  // ─── 实时检测 ──────────────────────────────────────────────────────

  private toggleRealtimeHr(): void {
    if (this.hrMeasuring) {
      this.realtimeUnsub?.()
      this.realtimeUnsub = null
      RwBleSdk.controlHealthData(0x03, 0) // HR off
      this.hrMeasuring = false
      this.addLog('心率检测已停止')
    } else {
      // Subscribe to realtime data
      const dataUnsub = RwBleSdk.onHealthRealtimeData((data: HealthDataSyncBean) => {
        this.addLog(this.formatRealtimeHealth(data))
      })
      // Subscribe to measurement complete event
      const ctrlUnsub = RwBleSdk.onHealthControlEvent((data: Object) => {
        const d = data as Record<string, number>
        if (d.healthType === 0x03 && d.status === 0) {
          this.hrMeasuring = false
          this.addLog('心率检测完成')
          dataUnsub()
          ctrlUnsub()
          this.realtimeUnsub = null
        }
      })
      this.realtimeUnsub = () => { dataUnsub(); ctrlUnsub() }
      RwBleSdk.controlHealthData(0x03, 1) // HR on
      this.hrMeasuring = true
      this.addLog('心率检测已启动')
    }
  }

  private startRealtimeBo(): void {
    this.startHealthMeasure(0x09, '血氧')
  }

  private startRealtimeHrv(): void {
    this.startHealthMeasure(0x0A, 'HRV')
  }

  private startRealtimeStress(): void {
    this.startHealthMeasure(0x0D, '压力')
  }

  private startRealtimeBloodSugar(): void {
    this.startHealthMeasure(0x10, '血糖')
  }

  private startRealtimeTemp(): void {
    this.startHealthMeasure(0x08, '体温')
  }

  private startRealtimeBp(): void {
    this.startHealthMeasure(0x04, '血压')
  }

  /** 通用启动健康检测：订阅实时数据 + 测量完成自动通知 */
  private startHealthMeasure(type: number, name: string): void {
    const dataUnsub = RwBleSdk.onHealthRealtimeData((data: HealthDataSyncBean) => {
      this.addLog(this.formatRealtimeHealth(data))
    })
    const ctrlUnsub = RwBleSdk.onHealthControlEvent((data: Object) => {
      const d = data as Record<string, number>
      if (d.healthType === type && d.status === 0) {
        this.addLog(`${name}检测完成`)
        dataUnsub()
        ctrlUnsub()
      }
    })
    RwBleSdk.controlHealthData(type, 1)
    this.addLog(`${name}检测已启动`)
  }

  private formatRealtimeHealth(data: HealthDataSyncBean): string {
    switch (data.dataType) {
      case 1:
        return `心率: ${data.hrValue ?? data.value ?? 0} bpm`
      case 3:
        return `血氧: ${data.boValue ?? data.value ?? 0}%`
      case 4:
        return `血压: ${data.bpSp ?? 0}/${data.bpDp ?? 0} mmHg`
      case 8:
        return `压力: ${data.pressureValue ?? data.value ?? 0}`
      case 9:
        return `血糖: ${data.bloodSugarValue ?? data.value ?? 0}`
      case 10:
        return `赞念: ${data.muslimCount ?? data.value ?? 0}`
      case 11:
        return `体温: ${data.temperature ?? ((data.tempValue ?? data.value ?? 0) / 10)}℃`
      case 13:
        return `HRV: ${data.hrvValue ?? data.value ?? 0}`
      case 20:
        return `步数: ${data.steps ?? data.value ?? 0}, 卡路里: ${data.calorie ?? 0}, 距离: ${data.distance ?? 0}`
      default:
        return `实时数据: ${JSON.stringify(data)}`
    }
  }

  // ─── 定时检测 ──────────────────────────────────────────────────────

  private async getTimedHr(): Promise<void> {
    try {
      const res = await RwBleSdk.getTimedHeartRate()
      this.addLog(`定时心率: ${JSON.stringify(res)}`)
    } catch (e) { this.addLog(`获取失败: ${JSON.stringify(e)}`) }
  }

  private async setTimedHr(): Promise<void> {
    try {
      const bean: DrinkReminderBean = { isOpen: true, remindDuration: 60, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
      await RwBleSdk.setTimedHeartRate(bean)
      this.addLog('定时心率设置成功 (开/60分)')
    } catch (e) { this.addLog(`设置失败: ${JSON.stringify(e)}`) }
  }

  private async getTimedBo(): Promise<void> {
    try {
      const res = await RwBleSdk.getTimedBloodOxygen()
      this.addLog(`定时血氧: ${JSON.stringify(res)}`)
    } catch (e) { this.addLog(`获取失败: ${JSON.stringify(e)}`) }
  }

  private async setTimedBo(): Promise<void> {
    try {
      const bean: DrinkReminderBean = { isOpen: true, remindDuration: 60, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
      await RwBleSdk.setTimedBloodOxygen(bean)
      this.addLog('定时血氧设置成功')
    } catch (e) { this.addLog(`设置失败: ${JSON.stringify(e)}`) }
  }

  private async getTimedHrv(): Promise<void> {
    try {
      const res = await RwBleSdk.getTimedHRV()
      this.addLog(`定时HRV: ${JSON.stringify(res)}`)
    } catch (e) { this.addLog(`获取失败: ${JSON.stringify(e)}`) }
  }

  private async setTimedHrv(): Promise<void> {
    try {
      const bean: DrinkReminderBean = { isOpen: true, remindDuration: 60, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
      await RwBleSdk.setTimedHRV(bean)
      this.addLog('定时HRV设置成功')
    } catch (e) { this.addLog(`设置失败: ${JSON.stringify(e)}`) }
  }

  private async getTimedStress(): Promise<void> {
    try {
      const res = await RwBleSdk.getTimedStress()
      this.addLog(`定时压力: ${JSON.stringify(res)}`)
    } catch (e) { this.addLog(`获取失败: ${JSON.stringify(e)}`) }
  }

  private async setTimedStress(): Promise<void> {
    try {
      const bean: DrinkReminderBean = { isOpen: true, remindDuration: 60, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
      await RwBleSdk.setTimedStress(bean)
      this.addLog('定时压力设置成功')
    } catch (e) { this.addLog(`设置失败: ${JSON.stringify(e)}`) }
  }

  private async getTimedBloodSugar(): Promise<void> {
    try {
      const res = await RwBleSdk.getTimedBloodSugar()
      this.addLog(`定时血糖: ${JSON.stringify(res)}`)
    } catch (e) { this.addLog(`获取失败: ${JSON.stringify(e)}`) }
  }

  private async setTimedBloodSugar(): Promise<void> {
    try {
      const bean: DrinkReminderBean = { isOpen: true, remindDuration: 60, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
      await RwBleSdk.setTimedBloodSugar(bean)
      this.addLog('定时血糖设置成功')
    } catch (e) { this.addLog(`设置失败: ${JSON.stringify(e)}`) }
  }

  private async getTimedBp(): Promise<void> {
    try {
      const res = await RwBleSdk.getTimedBloodPressure()
      this.addLog(`定时血压: ${JSON.stringify(res)}`)
    } catch (e) { this.addLog(`获取失败: ${JSON.stringify(e)}`) }
  }

  private async setTimedBp(): Promise<void> {
    try {
      const bean: DrinkReminderBean = { isOpen: true, remindDuration: 60, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
      await RwBleSdk.setTimedBloodPressure(bean)
      this.addLog('定时血压设置成功')
    } catch (e) { this.addLog(`设置失败: ${JSON.stringify(e)}`) }
  }

  private async getTimedTemp(): Promise<void> {
    try {
      const res = await RwBleSdk.getTimedBodyTemperature()
      this.addLog(`定时体温: ${JSON.stringify(res)}`)
    } catch (e) { this.addLog(`获取失败: ${JSON.stringify(e)}`) }
  }

  private async setTimedTemp(): Promise<void> {
    try {
      const bean: DrinkReminderBean = { isOpen: true, remindDuration: 60, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
      await RwBleSdk.setTimedBodyTemperature(bean)
      this.addLog('定时体温设置成功')
    } catch (e) { this.addLog(`设置失败: ${JSON.stringify(e)}`) }
  }

  // ─── 健康同步 ──────────────────────────────────────────────────────

  private syncAllHealth(): void {
    RwBleSdk.syncAllHealthData({
      onSyncProgress: (p: number) => this.addLog(`同步进度 ${p}%`),
      onSyncStep: (data: Array<Object>) => this.addLog(`步数: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncSleep: (data: Array<Object>) => this.addLog(`睡眠: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncHr: (data: Array<Object>) => this.addLog(`心率: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncBo: (data: Array<Object>) => this.addLog(`血氧: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncBp: (data: Array<Object>) => this.addLog(`血压: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncHrv: (data: Array<Object>) => this.addLog(`HRV: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncPressure: (data: Array<Object>) => this.addLog(`压力: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncBloodSugar: (data: Array<Object>) => this.addLog(`血糖: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncTemp: (data: Array<Object>) => this.addLog(`体温: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncMuslimCount: (data: Array<Object>) => this.addLog(`赞念: ${data.length}条 ${JSON.stringify(data).substring(0, 200)}`),
      onSyncFinish: () => this.addLog('同步完成'),
      onSyncError: (code: number) => this.addLog(`同步失败 code=${code}`)
    })
  }

  // ─── 连接管理 ──────────────────────────────────────────────────────

  private async loadSavedDevice(): Promise<void> {
    this.savedDevice = await SavedDeviceStore.load(this.context())
    this.refreshSavedText()
  }

  private refreshSavedText(): void {
    if (!this.savedDevice) {
      this.savedDeviceText = '无保存设备'
      return
    }
    this.savedDeviceText = `${this.savedDevice.name ?? '未命名'} (${this.savedDevice.deviceId})`
  }

  private async goScan(): Promise<void> {
    // Match the Android demo: searching again means replacing the bound device,
    // so discard both the live connection and the persisted device first.
    RwBleSdk.stopScan()
    RwBleSdk.disconnect()
    await SavedDeviceStore.clear(this.context())
    this.savedDevice = null
    this.menu = null
    this.connected = false
    this.connecting = false
    this.deviceName = '未连接'
    this.refreshSavedText()
    try { this.getUIContext().getRouter().pushUrl({ url: 'pages/ScanPage' }) } catch (_e) {}
  }

  private goSettings(): void {
    try { this.getUIContext().getRouter().pushUrl({ url: 'pages/SetPage' }) } catch (_e) {}
  }

  private goWorkout(): void {
    try { this.getUIContext().getRouter().pushUrl({ url: 'pages/WorkoutTypePage' }) } catch (_e) {}
  }

  private reconnect(): void {
    const saved = this.savedDevice
    if (!saved || this.connecting) return
    let matched = false
    this.connecting = true
    this.deviceName = '正在搜索设备'
    this.addLog(`搜索已保存设备: ${saved.mac ?? saved.deviceId}`)
    RwBleSdk.startScan({
      onScanDevice: (device: RwBleDevice) => {
        if (matched || !this.matchesSavedDevice(device, saved)) return
        matched = true
        RwBleSdk.stopScan()
        this.connectScannedDevice(saved, device)
      },
      onScanFinish: () => {
        if (matched) return
        this.connecting = false
        this.deviceName = '未发现设备'
        this.addLog('重连扫描超时，未发现已保存设备')
        this.showToast('未发现已保存设备，请确认设备在附近')
      },
      onError: (_code: number, error: Error) => {
        if (matched) return
        this.connecting = false
        this.deviceName = '扫描失败'
        this.addLog(`重连扫描失败: ${error.message}`)
        this.showToast('扫描失败，请检查蓝牙权限')
      }
    })
  }

  private matchesSavedDevice(device: RwBleDevice, saved: RwBleDevice): boolean {
    const deviceMac = this.normalizeDeviceAddress(device.mac)
    const savedMac = this.normalizeDeviceAddress(saved.mac)
    if (deviceMac && savedMac) return deviceMac === savedMac

    // Compatibility fallback for records created before manufacturer MAC
    // parsing was available.
    const currentIds: Array<string> = [device.deviceId, device.uuid ?? '', device.mac ?? '']
      .map((value: string) => this.normalizeDeviceAddress(value))
      .filter((value: string) => value.length > 0)
    const savedIds: Array<string> = [saved.deviceId, saved.uuid ?? '', saved.mac ?? '']
      .map((value: string) => this.normalizeDeviceAddress(value))
      .filter((value: string) => value.length > 0)
    return currentIds.some((value: string) => savedIds.includes(value))
  }

  private normalizeDeviceAddress(value?: string): string {
    return (value ?? '').replace(/[:-]/g, '').toUpperCase()
  }

  private async connectScannedDevice(saved: RwBleDevice, scanned: RwBleDevice): Promise<void> {
    const refreshed: RwBleDevice = {
      deviceId: scanned.deviceId,
      name: scanned.name ?? saved.name,
      mac: scanned.mac ?? saved.mac,
      uuid: scanned.uuid ?? scanned.deviceId,
      rssi: scanned.rssi,
      brand: scanned.brand ?? saved.brand,
      data: scanned.data
    }
    await SavedDeviceStore.save(this.context(), refreshed)
    this.savedDevice = refreshed
    this.refreshSavedText()
    this.addLog(`已找到保存设备: mac=${refreshed.mac ?? '-'} deviceId=${refreshed.deviceId}`)
    RwBleSdk.reconnectDevice(refreshed)
  }

  private async unbindAndSearch(): Promise<void> {
    await this.goScan()
  }

  private async getPower(): Promise<void> {
    try {
      const res: PowerBean = await RwBleSdk.getPower()
      this.addLog(`电量: ${res.power}%`)
    } catch (e) { this.addLog(`获取电量失败: ${JSON.stringify(e)}`) }
  }

  private async getFirmware(): Promise<void> {
    try {
      const res: FirmVersionBean = await RwBleSdk.getFirmwareVersion()
      this.addLog(`型号:${res.deviceClazz ?? '-'} 固件:${res.deviceNo} UI:${res.uiVersion ?? '-'} 屏幕:${res.screenWidth}x${res.screenHeight}`)
    } catch (e) { this.addLog(`获取固件失败: ${JSON.stringify(e)}`) }
  }

  private async getMac(): Promise<void> {
    try {
      const mac = await RwBleSdk.getMacAddress()
      this.addLog(`MAC地址: ${mac}`)
    } catch (e) { this.addLog(`获取MAC失败: ${JSON.stringify(e)}`) }
  }

  private async startBundledOta(fileName: string, platform: string): Promise<void> {
    if (!this.connected || this.otaRunning) return
    this.otaRunning = true
    this.otaProgress = 0
    this.addLog(`准备${platform} OTA固件: ${fileName}`)
    try {
      const ctx = this.context()
      const firmware = await ctx.resourceManager.getRawFileContent(fileName)
      const otaPath = `${ctx.cacheDir}/${fileName}`
      const file = fs.openSync(otaPath,
        fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY)
      try {
        const buffer = firmware.buffer.slice(firmware.byteOffset,
          firmware.byteOffset + firmware.byteLength)
        const written = fs.writeSync(file.fd, buffer)
        if (written !== firmware.byteLength) {
          throw new Error(`固件写入不完整: ${written}/${firmware.byteLength}`)
        }
      } finally {
        fs.closeSync(file.fd)
      }
      this.addLog(`开始${platform} OTA，固件大小: ${firmware.byteLength} bytes`)
      RwBleSdk.ringOtaWithFileData(otaPath, {
        onProgress: (progress: number) => {
          const percent = Math.min(100, Math.max(0, Math.floor(progress * 100)))
          if (percent === this.otaProgress) return
          this.otaProgress = percent
          if (percent % 10 === 0 || percent === 100) this.addLog(`OTA进度: ${percent}%`)
        },
        onSuccess: () => {
          this.otaProgress = 100
          this.otaRunning = false
          this.addLog('OTA升级完成')
          this.showToast('OTA升级完成')
        },
        onError: (code: number) => {
          this.otaRunning = false
          this.addLog(`OTA升级失败: code=${code}`)
          this.showToast(`OTA升级失败: ${code}`)
        }
      })
    } catch (e) {
      this.otaRunning = false
      this.addLog(`OTA固件准备失败: ${JSON.stringify(e)}`)
      this.showToast('OTA固件准备失败')
    }
  }

  private async setDate(): Promise<void> {
    try {
      await RwBleSdk.setDate()
      this.addLog('时间已同步')
    } catch (e) { this.addLog(`同步时间失败: ${JSON.stringify(e)}`) }
  }

  private async shareLogs(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const logDir = `${ctx.filesDir}/logger/devices`
      const zipPath = `${ctx.cacheDir}/rwsdk_logs.zip`
      // Persist the latest buffered BLE events before collecting the files.
      RwBleSdk.flushLog()
      // Check if log dir exists and has files
      if (!fs.accessSync(logDir)) {
        this.showToast('暂无日志文件')
        return
      }
      const files = fs.listFileSync(logDir)
      if (files.length === 0) {
        this.showToast('暂无日志文件')
        return
      }
      // Remove old zip if exists
      if (fs.accessSync(zipPath)) {
        fs.unlinkSync(zipPath)
      }
      // Zip the log directory
      await zlib.compressFile(logDir, zipPath, { level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION })
      // SystemShare authorizes this sandbox file URI for the selected receiver.
      const uri = fileUri.getUriFromPath(zipPath)
      const sharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.ZIP_ARCHIVE,
        uri,
        title: 'RW SDK 日志',
        description: `${files.length} 个日志文件`
      })
      const controller = new systemShare.ShareController(sharedData)
      await controller.show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      })
    } catch (e) {
      this.addLog(`分享日志失败: ${JSON.stringify(e)}`)
      this.showToast('分享日志失败')
    }
  }

  private showToast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2000 })
    } catch (_e) {}
  }

  private addLog(msg: string): void {
    hilog.info(0x0001, 'RWSDK', '[Demo] %{public}s', msg)
    const line = `[${new Date().toLocaleTimeString()}] ${msg}`
    this.logText = this.logText ? `${line}\n${this.logText}` : line
  }
}

@Extend(Column)
function sectionStyle() {
  .alignItems(HorizontalAlign.Start)
  .width('100%')
  .padding(14)
  .backgroundColor('#FFFFFF')
  .borderRadius(8)
  .border({ width: 1, color: '#E5E7EB' })
}
