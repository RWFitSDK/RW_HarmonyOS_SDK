import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { promptAction } from '@kit.ArkUI';
import { fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import fs from '@ohos.file.fs';
import zlib from '@ohos.zlib';
import {
  FirmVersionBean,
  BloodOxySyncBean,
  BloodPressSyncBean,
  BloodSugarSyncBean,
  BodyTempSyncBean,
  DevicePushType,
  HeartRateSyncBean,
  HrvSyncBean,
  MuslimCountSyncBean,
  PowerBean,
  PressureSyncBean,
  PushData,
  RwBleDevice,
  RwBleSdk,
  SleepSyncBean,
  StepSyncBean,
  SupportMenuBean
} from 'rw_ble_sdk';
import { SavedDeviceStore } from '../model/SavedDeviceStore';
import { DeviceSettingService } from '../model/DeviceSettingService';

interface HealthDisplayRecord {
  value: string
  summary: string
  time: string
  timestamp: number
}

@Entry
@Component
struct HomePage {
  @State private selectedTab: number = 0
  @State private connected: boolean = false
  @State private connecting: boolean = false
  @State private deviceName: string = '未连接'
  @State private sdkVersion: string = ''
  @State private savedDevice: RwBleDevice | null = null
  @State private menu: SupportMenuBean | null = null
  @State private powerText: string = '--'
  @State private modelText: string = '--'
  @State private firmwareText: string = '--'
  @State private healthRefreshing: boolean = false
  @State private healthSyncing: boolean = false
  @State private healthSyncProgress: number = 0
  @State private lastSyncText: string = '下拉同步全部健康数据'
  @State private stepsText: string = '暂无数据'
  @State private sleepText: string = '暂无数据'
  @State private heartRateText: string = '暂无数据'
  @State private bloodOxygenText: string = '暂无数据'
  @State private bloodPressureText: string = '暂无数据'
  @State private hrvText: string = '暂无数据'
  @State private pressureText: string = '暂无数据'
  @State private bloodSugarText: string = '暂无数据'
  @State private temperatureText: string = '暂无数据'
  @State private muslimCountText: string = '暂无数据'

  private initialized: boolean = false
  private pushUnsub: (() => void) | null = null
  private powerRequest: Promise<PowerBean> | null = null
  private syncedStepDays: Array<StepSyncBean> = []
  private stepsRecords: Array<HealthDisplayRecord> = []
  private sleepRecords: Array<HealthDisplayRecord> = []
  private heartRateRecords: Array<HealthDisplayRecord> = []
  private bloodOxygenRecords: Array<HealthDisplayRecord> = []
  private bloodPressureRecords: Array<HealthDisplayRecord> = []
  private hrvRecords: Array<HealthDisplayRecord> = []
  private pressureRecords: Array<HealthDisplayRecord> = []
  private bloodSugarRecords: Array<HealthDisplayRecord> = []
  private temperatureRecords: Array<HealthDisplayRecord> = []
  private muslimCountRecords: Array<HealthDisplayRecord> = []

  private context(): common.Context {
    return this.getUIContext().getHostContext() as common.Context
  }

  aboutToAppear(): void {
    this.subscribeDevicePush()
    this.initPage()
  }

  onPageShow(): void {
    this.refreshPageState()
  }

  aboutToDisappear(): void {
    this.pushUnsub?.()
    this.pushUnsub = null
  }

  private async initPage(): Promise<void> {
    if (this.initialized) return
    this.initialized = true
    await this.loadSavedDevice()
    RwBleSdk.setConnectBleCallback({
      onRingConnecting: () => {
        this.connecting = true
        this.deviceName = this.savedDevice?.name ?? '正在连接'
      },
      onRingConnected: () => {
        this.connected = true
        this.deviceName = this.savedDevice?.name ?? 'RW 智能戒指'
      },
      onRingConnectFailed: (reason: string) => {
        this.connecting = false
        this.connected = false
        this.showToast(`连接失败: ${reason}`)
      },
      onRingDisconnected: (_reason: string) => {
        this.connecting = false
        this.connected = false
        this.menu = null
        this.deviceName = this.savedDevice?.name ?? '已断开'
        this.showToast('设备已断开')
      },
      onRingDidFunctionMenu: async (menuBean: SupportMenuBean) => {
        this.connecting = false
        this.connected = true
        this.menu = menuBean
        this.deviceName = menuBean.name ?? this.savedDevice?.name ?? 'RW 智能戒指'
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
        }
        this.showToast('连接成功')
        this.refreshDeviceInfo()
      }
    })
    RwBleSdk.initSDK(this.context())
    // Demo演示密码。正式项目应在连接前传入当前账号对应的4位密码。
    RwBleSdk.prepareAutoPassword('1234')
    this.sdkVersion = RwBleSdk.getSDKVersion()
    this.refreshPageState()
  }

  private async refreshPageState(): Promise<void> {
    await this.loadSavedDevice()
    this.connected = RwBleSdk.isBleConnected()
    this.menu = RwBleSdk.getSupportMenu()
    if (this.savedDevice) this.deviceName = this.savedDevice.name ?? 'RW 智能戒指'
    if (this.connected) this.refreshDeviceInfo()
  }

  build() {
    Stack() {
      Column() {
        if (this.selectedTab === 0) {
          Refresh({ refreshing: $$this.healthRefreshing, promptText: this.healthSyncing ? '正在同步健康数据' : '下拉同步健康数据' }) {
            Scroll() { this.HomeContent() }.width('100%').height('100%')
          }
          .onRefreshing(() => this.syncAllHealth())
          .layoutWeight(1)
          .width('100%')
        } else {
          Scroll() { this.DeviceContent() }.layoutWeight(1).width('100%')
        }
        this.BottomBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F4F7F5')

      if (this.connecting) {
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
  }

  @Builder
  private HomeContent() {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 5 }) {
          Text('今天感觉怎么样？').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#18221E')
          Text('连接戒指，查看你的健康趋势').fontSize(14).fontColor('#87928D')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('RW')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0C9468')
          .width(48)
          .height(48)
          .textAlign(TextAlign.Center)
          .backgroundColor('#E1F3EB')
          .borderRadius(16)
      }
      .width('100%')
      .margin({ top: 12, bottom: 22 })

      if (this.savedDevice) {
        this.DeviceCard(true)
      } else {
        this.UnboundCard()
      }

      Row() {
        Text('健康数据').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1C2823')
        Blank()
        Text(this.healthSyncing ? `同步中 ${this.healthSyncProgress}%` : this.lastSyncText)
          .fontSize(12).fontColor(this.healthSyncing ? '#0C9468' : '#8A948F').margin({ left: 10 })
      }
      .width('100%')
      .margin({ top: 28, bottom: 14 })

      if (this.healthSyncing) {
        Progress({ value: this.healthSyncProgress, total: 100, type: ProgressType.Linear })
          .color('#0C9B6C')
          .backgroundColor('#DFE9E4')
          .width('100%')
          .height(5)
          .margin({ bottom: 14 })
      }

      if (this.savedDevice && this.hasHealthCards()) {
        Grid() {
          if (this.menu?.isStep === true) {
            GridItem() { this.HealthCard('步', '计步', 'steps', '点击查看详情', () => this.goHealthDetail('steps', '计步', this.stepsText, 0, this.stepsRecords)) }
          }
          if (this.menu?.isSleep === true) {
            GridItem() { this.HealthCard('眠', '睡眠', 'sleep', '点击查看详情', () => this.goHealthDetail('sleep', '睡眠', this.sleepText, 0, this.sleepRecords)) }
          }
          if (this.menu?.isHr === true) {
            GridItem() { this.HealthCard('心', '心率', 'heartRate', '点击查看详情', () => this.goHealthDetail('heartRate', '心率', this.heartRateText, 0x03, this.heartRateRecords)) }
          }
          if (this.menu?.isBloodOxy === true) {
            GridItem() { this.HealthCard('氧', '血氧', 'bloodOxygen', '点击查看详情', () => this.goHealthDetail('bloodOxygen', '血氧', this.bloodOxygenText, 0x09, this.bloodOxygenRecords)) }
          }
          if (this.menu?.isBloodPress === true) {
            GridItem() { this.HealthCard('压', '血压', 'bloodPressure', '点击查看详情', () => this.goHealthDetail('bloodPressure', '血压', this.bloodPressureText, 0x04, this.bloodPressureRecords)) }
          }
          if (this.menu?.isHrv === true) {
            GridItem() { this.HealthCard('HRV', 'HRV', 'hrv', '点击查看详情', () => this.goHealthDetail('hrv', 'HRV', this.hrvText, 0x0A, this.hrvRecords)) }
          }
          if (this.menu?.isPressure === true) {
            GridItem() { this.HealthCard('力', '压力', 'stress', '点击查看详情', () => this.goHealthDetail('stress', '压力', this.pressureText, 0x0D, this.pressureRecords)) }
          }
          if (this.menu?.isBloodSugar === true) {
            GridItem() { this.HealthCard('糖', '血糖', 'bloodSugar', '点击查看详情', () => this.goHealthDetail('bloodSugar', '血糖', this.bloodSugarText, 0x10, this.bloodSugarRecords)) }
          }
          if (this.menu?.isDataTypeTemperature === true) {
            GridItem() { this.HealthCard('温', '体温', 'temperature', '点击查看详情', () => this.goHealthDetail('temperature', '体温', this.temperatureText, 0x08, this.temperatureRecords)) }
          }
          if (this.menu?.isMuslimCountData === true) {
            GridItem() { this.HealthCard('念', '赞念', 'muslimCount', '点击查看详情', () => this.goHealthDetail('muslimCount', '赞念', this.muslimCountText, 0, this.muslimCountRecords)) }
          }
          if (this.menu?.isNewSport === true) {
            GridItem() { this.HealthCard('动', '多运动', 'workout', '选择运动或加载报告', () => this.goWorkout()) }
          }
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
      } else if (this.savedDevice) {
        this.EmptyCard('暂未获得健康能力', '请重新连接设备，获取功能配置表。', '重新连接', () => this.reconnect())
      } else {
        this.EmptyCard('绑定后显示健康数据', '首页会根据设备功能表展示计步、心率、睡眠、多运动等支持项目。', '添加设备', () => this.goScan())
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 18, right: 18, bottom: 30 })
  }

  @Builder
  private DeviceContent() {
    Column({ space: 0 }) {
      Text('我的设备').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#18221E').width('100%')
        .margin({ top: 14 })
      Text('管理连接、设备信息与支持功能').fontSize(14).fontColor('#87928D').width('100%')
        .margin({ top: 6, bottom: 22 })

      if (this.savedDevice) {
        this.DeviceCard(false)
        Row({ space: 10 }) {
          Button(this.connected ? '断开连接' : '重新连接')
            .fontSize(14)
            .fontColor(this.connected ? '#087E59' : '#FFFFFF')
            .backgroundColor(this.connected ? '#E4F2EC' : '#0C9B6C')
            .borderRadius(22)
            .layoutWeight(1)
            .onClick(() => this.connected ? this.disconnect() : this.reconnect())
          Button('解除绑定')
            .fontSize(14)
            .fontColor('#C64B4B')
            .backgroundColor('#FFF0F0')
            .borderRadius(22)
            .layoutWeight(1)
            .onClick(() => this.unbind())
        }
        .width('100%')
        .margin({ top: 14 })

        this.SectionTitle('设备信息', '')
        Column() {
          this.PowerInfoRow()
          this.DividerLine()
          this.InfoRow('设备型号', '', this.modelText, () => {})
          this.DividerLine()
          this.InfoRow('固件版本', '', this.firmwareText, () => {})
          this.DividerLine()
          this.DeviceIdentifierRow('MAC', this.savedDevice?.mac ?? '未从广播获取')
          this.DividerLine()
          this.DeviceIdentifierRow('deviceId', this.savedDevice?.deviceId ?? '未获取')
          this.DividerLine()
          this.InfoRow('固件升级', '选择厂家提供的 .bin 文件', this.connected ? '可操作' : '需连接', () => this.goFirmwareUpgrade())
        }
        .cardStyle()

        this.SectionTitle('设备功能', '按功能表显示')
        if (this.hasDeviceSettings()) {
          Column() {
            if (this.menu?.isAlarm === true) this.SupportedFeatureRow('alarm', '闹', '闹钟', '设备闹钟管理')
            if (this.menu?.isDND === true) this.SupportedFeatureRow('dnd', '勿', '勿扰模式', '设置勿扰开关与时段')
            if (this.menu?.isBrightScreenSleepTime === true) this.SupportedFeatureRow('screenSleep', '屏', '屏幕睡眠', '设置屏幕睡眠时段')
            if (this.menu?.isBrightScreenTime === true) this.SupportedFeatureRow('brightDuration', '亮', '亮屏时长', '设置屏幕保持点亮时间')
            if (this.menu?.isRaiseBrightScreen === true) this.SupportedFeatureRow('raiseToWake', '抬', '抬腕亮屏', '设置开关与生效时段')
            if (this.menu?.isLEDLight === true) this.SupportedFeatureRow('ledLevel', '灯', 'LED 亮度', '设置 LED 开关与亮度')
            if (this.menu?.isWearDir === true) this.SupportedFeatureRow('wearHand', '戴', '佩戴位置', '左手或右手佩戴')
            if (this.menu?.isFindDevice === true) {
              this.FeatureRow('找', '查找设备', '让戒指发出查找提示', '立即执行', () => this.findDevice())
              this.DividerLine()
            }
            if (this.menu?.isTakePhoto === true) this.SupportedFeatureRow('takePhoto', '拍', '遥控拍照', '接收戒指拍照事件')
            if (this.menu?.isHr === true) this.SupportedFeatureRow('heartRateMonitoring', '心', '全天心率', '设置全天监测开关与间隔')
            if (this.menu?.isBloodOxy === true) this.SupportedFeatureRow('bloodOxygenMonitoring', '氧', '全天血氧', '设置全天血氧监测')
            if (this.menu?.isHrv === true) this.SupportedFeatureRow('hrvMonitoring', '变', '全天 HRV', '设置全天 HRV 监测')
            if (this.menu?.isPressure === true) this.SupportedFeatureRow('stressMonitoring', '压', '全天压力', '设置全天压力监测')
            if (this.menu?.isBloodPress === true) this.SupportedFeatureRow('bloodPressureMonitoring', '血', '全天血压', '设置全天血压监测')
            if (this.menu?.isBloodSugar === true) this.SupportedFeatureRow('bloodSugarMonitoring', '糖', '全天血糖', '设置全天血糖监测')
            if (this.menu?.isSupportTemperatureMonitoring === true || this.menu?.isDataTypeTemperature === true) {
              this.SupportedFeatureRow('temperatureMonitoring', '温', '全天体温', '设置全天体温监测')
            }
            if (this.menu?.isSupportPPGMonitoring === true) this.SupportedFeatureRow('ppgMonitoring', 'P', 'PPG 定时监测', '设置 PPG 定时监测')
            if (this.menu?.isSupportHrReminder === true) this.SupportedFeatureRow('heartRateAlert', '警', '心率报警', '设置心率上下限')
            if (this.menu?.isSupportBoReminder === true) this.SupportedFeatureRow('bloodOxygenAlert', '警', '血氧报警', '设置血氧下限')
            if (this.menu?.isSupportMotoVibrationLevel === true) this.SupportedFeatureRow('vibrationCount', '震', '震动次数', '设置提醒震动次数')
            if (this.menu?.isSupportAlarmVibrationDuration === true) this.SupportedFeatureRow('alarmVibration', '震', '闹钟震动时长', '设置闹钟震动参数')
            if (this.menu?.isSupportVibrationInterval === true) this.SupportedFeatureRow('vibrationInterval', '隔', '震动间隔', '设置每次震动的间隔')
            if (this.menu?.isSupportCountReminder === true) this.SupportedFeatureRow('countReminder', '提', '计数提醒', '设置计数提醒间隔')
            if (this.menu?.isSupportFallDetect === true) this.SupportedFeatureRow('fallDetect', '落', '跌落提醒', '开启或关闭跌落检测')
            if (this.menu?.isRememberSwitch === true) this.SupportedFeatureRow('rememberSwitch', '念', '赞念开关', '开启或关闭赞念功能')
            if (this.menu?.isSupportMuslimTimeDisplayMode === true) this.SupportedFeatureRow('muslimTimeMode', '时', '赞念时间显示', '设置时间显示模式')
            if (this.menu?.isPowerOff === true || this.menu?.isRecovery === true) {
              this.FeatureRow('电', '关机与恢复出厂', '设备电源操作', '立即执行', () => this.openPowerMenu())
              this.DividerLine()
            }
          }
          .cardStyle()
        } else {
          this.EmptyCard('暂无可配置功能', '设备功能表未声明可配置项，重新连接后可再次获取。', '重新连接', () => this.reconnect())
        }

        this.SectionTitle('其他操作', '')
        Column() {
          this.FeatureRow('志', '分享 SDK 日志', '导出压缩日志用于问题排查', '', () => this.shareLogs())
        }.cardStyle()
      } else {
        this.UnboundCard()
        this.EmptyCard('还没有绑定戒指', '绑定后这里会根据功能配置表展示设备支持的全部设置。', '搜索设备', () => this.goScan())
      }

      Text(`SDK ${this.sdkVersion}`)
        .fontSize(11)
        .fontColor('#A0AAA5')
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 28, bottom: 24 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 18, right: 18 })
  }

  @Builder
  private DeviceCard(selectable: boolean) {
    Row({ space: 14 }) {
      Stack() {
        Circle().width(56).height(56).fill('#D8E6E0')
        Circle().width(25).height(25).fill('#164B3A')
      }
      .width(58)
      .height(58)
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(this.deviceName).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').maxLines(1).layoutWeight(1)
          Text(this.connecting ? '连接中' : this.connected ? '已连接' : '未连接')
            .fontSize(11)
            .fontColor(this.connected ? '#BCFFE0' : '#DCE8E3')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#2FFFFFFF')
            .borderRadius(12)
        }
        .width('100%')
        Text(`MAC：${this.savedDevice?.mac ?? '连接后获取'}`).fontSize(11).fontColor('#D0E1DA').maxLines(1)
        Text(`deviceId：${this.savedDevice?.deviceId ?? '-'}`).fontSize(10).fontColor('#AAC3B9').maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(selectable ? '›' : this.powerText === '--' ? '' : `电量 ${this.powerText}`)
        .fontSize(selectable ? 28 : 11)
        .fontColor('#D7E8E1')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#164B3A')
    .borderRadius(22)
    .shadow({ radius: 18, color: '#260C674B', offsetY: 8 })
    .onClick(() => { if (selectable) this.selectedTab = 1 })
  }

  @Builder
  private UnboundCard() {
    Row({ space: 14 }) {
      Text('+').fontSize(30).fontColor('#0C9B6C').textAlign(TextAlign.Center)
        .width(52).height(52).backgroundColor('#E2F3EC').borderRadius(26)
      Column({ space: 5 }) {
        Text('未绑定设备').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1C2823')
        Text('点击搜索并连接 RW 智能戒指').fontSize(13).fontColor('#8A958F')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›').fontSize(30).fontColor('#AEB9B4')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#F9FBFA')
    .border({ width: 1, color: '#B9C8C1', style: BorderStyle.Dashed })
    .borderRadius(22)
    .onClick(() => this.goScan())
  }

  @Builder
  private HealthCard(symbol: string, title: string, type: string, subtitle: string, action: () => void) {
    Column({ space: 0 }) {
      Row() {
        Text(symbol).fontSize(symbol.length > 1 ? 10 : 13).fontWeight(FontWeight.Bold).fontColor('#0B9467')
          .textAlign(TextAlign.Center).width(38).height(38).backgroundColor('#E7F5EF').borderRadius(12)
        Text('›').fontSize(24).fontColor('#BDC5C1').layoutWeight(1).textAlign(TextAlign.End)
      }
      .width('100%')
      Text(title).fontSize(14).fontColor('#53605A').margin({ top: 13 }).width('100%')
      Text(this.healthValueText(type)).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#18221E').maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').margin({ top: 5 })
      Text(subtitle).fontSize(10).fontColor('#9AA39F').maxLines(1).width('100%').margin({ top: 5 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height(156)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow({ radius: 12, color: '#12253C2D', offsetY: 4 })
    .onClick(action)
  }

  private healthValueText(type: string): string {
    switch (type) {
      case 'steps': return this.stepsText
      case 'sleep': return this.sleepText
      case 'heartRate': return this.heartRateText
      case 'bloodOxygen': return this.bloodOxygenText
      case 'bloodPressure': return this.bloodPressureText
      case 'hrv': return this.hrvText
      case 'stress': return this.pressureText
      case 'bloodSugar': return this.bloodSugarText
      case 'temperature': return this.temperatureText
      case 'muslimCount': return this.muslimCountText
      case 'workout': return '查看运动'
      default: return '暂无数据'
    }
  }

  @Builder
  private EmptyCard(title: string, text: string, buttonText: string, action: () => void) {
    Column({ space: 10 }) {
      Text(title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1C2823')
      Text(text).fontSize(13).fontColor('#909A95').textAlign(TextAlign.Center).lineHeight(20)
      Button(buttonText).fontSize(14).fontColor('#FFFFFF').backgroundColor('#0C9B6C').borderRadius(22)
        .margin({ top: 8 }).onClick(action)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: 38, bottom: 38, left: 24, right: 24 })
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ top: 12 })
  }

  @Builder
  private SectionTitle(title: string, caption: string) {
    Row({ space: 8 }) {
      Text(title).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#1C2823')
      if (caption.length > 0) Text(caption).fontSize(12).fontColor('#8A948F')
    }
    .width('100%')
    .margin({ top: 28, bottom: 13 })
  }

  @Builder
  private InfoRow(title: string, subtitle: string, value: string, action: () => void) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontColor('#1C2823')
        if (subtitle.length > 0) Text(subtitle).fontSize(12).fontColor('#929C97')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(value).fontSize(13).fontColor(title === '固件升级' ? '#0C9568' : '#66716C').maxLines(1)
      if (title === '设备电量' || title === '固件升级') Text('›').fontSize(24).fontColor('#BDC5C1')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 15, bottom: 15 })
    .onClick(action)
  }

  @Builder
  private PowerInfoRow() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text('设备电量').fontSize(16).fontColor('#1C2823')
        Text('点击刷新').fontSize(12).fontColor('#929C97')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(this.powerText).fontSize(13).fontColor('#66716C').maxLines(1)
      Text('›').fontSize(24).fontColor('#BDC5C1')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 15, bottom: 15 })
    .onClick(() => this.refreshPower(true))
  }

  @Builder
  private DeviceIdentifierRow(title: string, value: string) {
    Column({ space: 6 }) {
      Text(title).fontSize(14).fontColor('#59665F').width('100%')
      Text(value).fontSize(12).fontColor('#26312C').width('100%').maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 18, right: 18, top: 13, bottom: 13 })
  }

  @Builder
  private FeatureRow(symbol: string, title: string, subtitle: string, value: string, action: () => void) {
    Row({ space: 13 }) {
      Text(symbol).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#168662')
        .textAlign(TextAlign.Center).width(40).height(40).backgroundColor('#EDF6F2').borderRadius(12)
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontColor('#1C2823')
        Text(subtitle).fontSize(12).fontColor('#929C97')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (value.length > 0) Text(value).fontSize(12).fontColor('#0C9568')
      Text('›').fontSize(24).fontColor('#BDC5C1')
    }
    .width('100%')
    .padding({ left: 16, right: 18, top: 14, bottom: 14 })
    .onClick(action)
  }

  @Builder
  private SupportedFeatureRow(id: string, symbol: string, title: string, subtitle: string) {
    this.FeatureRow(symbol, title, subtitle, DeviceSettingService.canGet(id) ? '设置 / 获取' : '点击设置',
      () => this.openFeatureMenu(id, title))
    this.DividerLine()
  }

  @Builder
  private DividerLine() {
    Divider().strokeWidth(1).color('#EDF0EE').margin({ left: 18, right: 18 })
  }

  @Builder
  private BottomBar() {
    Row() {
      Column({ space: 3 }) {
        Text('⌂').fontSize(22).fontColor(this.selectedTab === 0 ? '#0C9B6C' : '#8A948F')
        Text('首页').fontSize(11).fontColor(this.selectedTab === 0 ? '#0C9B6C' : '#8A948F')
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .height('100%')
      .onClick(() => this.selectedTab = 0)
      Column({ space: 3 }) {
        Text('◉').fontSize(20).fontColor(this.selectedTab === 1 ? '#0C9B6C' : '#8A948F')
        Text('设备').fontSize(11).fontColor(this.selectedTab === 1 ? '#0C9B6C' : '#8A948F')
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .height('100%')
      .onClick(() => this.selectedTab = 1)
    }
    .width('100%')
    .height(64)
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#EDF0EE' })
  }

  private hasHealthCards(): boolean {
    const m = this.menu
    if (!m) return false
    return m.isStep === true || m.isSleep === true || m.isHr === true || m.isBloodOxy === true ||
      m.isBloodPress === true || m.isHrv === true || m.isPressure === true || m.isBloodSugar === true ||
      m.isDataTypeTemperature === true || m.isMuslimCountData === true || m.isNewSport === true
  }

  private hasDeviceSettings(): boolean {
    const m = this.menu
    if (!m) return false
    return m.isAlarm === true || m.isDND === true || m.isBrightScreenTime === true ||
      m.isBrightScreenSleepTime === true || m.isRaiseBrightScreen === true || m.isLEDLight === true ||
      m.isWearDir === true || m.isVideoHid === true || m.isFindDevice === true || m.isRecovery === true ||
      m.isPowerOff === true || m.isSupportMotoVibrationLevel === true || m.isSupportHrReminder === true ||
      m.isSupportBoReminder === true || m.isHr === true || m.isBloodOxy === true || m.isHrv === true ||
      m.isPressure === true || m.isBloodPress === true || m.isBloodSugar === true ||
      m.isSupportTemperatureMonitoring === true || m.isSupportPPGMonitoring === true ||
      m.isSupportAlarmVibrationDuration === true || m.isSupportVibrationInterval === true ||
      m.isSupportFallDetect === true || m.isSupportCountReminder === true || m.isRememberSwitch === true ||
      m.isTakePhoto === true || m.isSupportMuslimTimeDisplayMode === true
  }

  private syncAllHealth(): void {
    if (!this.connected || this.healthSyncing) {
      if (!this.connected) this.showToast('请先连接设备')
      if (!this.healthSyncing) this.healthRefreshing = false
      return
    }
    this.healthRefreshing = true
    this.healthSyncing = true
    this.healthSyncProgress = 0
    this.lastSyncText = '正在同步健康数据'
    this.syncedStepDays = []
    RwBleSdk.syncAllHealthData({
      onSyncProgress: (progress: number) => this.healthSyncProgress = progress,
      onSyncStep: (data: Array<StepSyncBean>) => this.receiveSteps(data),
      onSyncSleep: (data: Array<SleepSyncBean>) => this.receiveSleep(data),
      onSyncHr: (data: Array<HeartRateSyncBean>) => this.receiveHeartRate(data),
      onSyncBo: (data: Array<BloodOxySyncBean>) => this.receiveBloodOxygen(data),
      onSyncBp: (data: Array<BloodPressSyncBean>) => this.receiveBloodPressure(data),
      onSyncHrv: (data: Array<HrvSyncBean>) => this.receiveHrv(data),
      onSyncPressure: (data: Array<PressureSyncBean>) => this.receivePressure(data),
      onSyncBloodSugar: (data: Array<BloodSugarSyncBean>) => this.receiveBloodSugar(data),
      onSyncTemp: (data: Array<BodyTempSyncBean>) => this.receiveTemperature(data),
      onSyncMuslimCount: (data: Array<MuslimCountSyncBean>) => this.receiveMuslimCount(data),
      onSyncFinish: () => {
        this.healthRefreshing = false
        this.healthSyncing = false
        this.healthSyncProgress = 100
        this.lastSyncText = '刚刚同步'
        this.showToast('同步完成')
      },
      onSyncError: (code: number) => {
        this.healthRefreshing = false
        this.healthSyncing = false
        this.lastSyncText = '同步失败，请下拉重试'
        this.showToast(`同步失败: ${code}`)
      }
    })
  }

  private receiveSteps(data: Array<StepSyncBean>): void {
    for (const incoming of data) {
      const index = this.syncedStepDays.findIndex((saved: StepSyncBean) => saved.date === incoming.date)
      if (index < 0) {
        this.syncedStepDays.push(incoming)
      } else if (incoming.timestamp >= this.syncedStepDays[index].timestamp) {
        this.syncedStepDays[index] = incoming
      }
    }
    const days = this.syncedStepDays.slice()
      .sort((first: StepSyncBean, second: StepSyncBean) => second.timestamp - first.timestamp)
    const today = this.localDateText(new Date())
    const currentDay = days.find((day: StepSyncBean) => day.date === today)
    const homeDay = currentDay ?? (days.length > 0 ? days[0] : null)
    this.stepsText = homeDay ? `${homeDay.totalSteps} 步` : '暂无数据'
    const records: Array<HealthDisplayRecord> = []
    for (const day of days) {
      if (day.date === today) {
        records.push({
          value: `${day.totalSteps} 步`,
          summary: `今日累计步数 · 热量 ${day.totalCalorie} kcal`,
          time: this.formatRecordTime(day.timestamp),
          timestamp: day.timestamp
        })
      }
      if (day.items.length === 0) {
        if (day.date !== today) {
          records.push({
            value: `${day.totalSteps} 步`,
            summary: `当日累计 · 热量 ${day.totalCalorie} kcal`,
            time: day.date,
            timestamp: day.timestamp
          })
        }
        continue
      }
      for (const item of day.items) {
        records.push({
          value: `${item.steps} 步`,
          summary: `热量 ${item.calorie} kcal · 距离 ${item.distance}`,
          time: this.formatRecordTime(item.timestamp),
          timestamp: item.timestamp
        })
      }
    }
    this.stepsRecords = this.sortRecords(records)
  }

  private receiveSleep(data: Array<SleepSyncBean>): void {
    const sessions = data.slice().sort((first: SleepSyncBean, second: SleepSyncBean) =>
      (second.awakeTime || second.timestamp) - (first.awakeTime || first.timestamp))
    this.sleepText = sessions.length > 0 ? this.formatSleepDuration(sessions[0].totalSleepTime) : '暂无数据'
    const records: Array<HealthDisplayRecord> = []
    for (const session of sessions) {
      if (session.items.length === 0) {
        records.push({
          value: this.formatSleepDuration(session.totalSleepTime),
          summary: '睡眠记录',
          time: this.formatRecordTime(session.asleepTime || session.timestamp),
          timestamp: session.asleepTime || session.timestamp
        })
        continue
      }
      let stageTime = session.asleepTime
      for (const item of session.items) {
        records.push({
          value: this.sleepTypeText(item.sleepType),
          summary: `${item.len} 分钟${item.isTemporary ? ' · 临时数据' : ''}`,
          time: this.formatRecordTime(stageTime),
          timestamp: stageTime
        })
        stageTime += item.len * 60
      }
    }
    this.sleepRecords = this.sortRecords(records)
  }

  private receiveHeartRate(data: Array<HeartRateSyncBean>): void {
    const records: Array<HealthDisplayRecord> = []
    for (const day of data) {
      for (const item of day.items) {
        records.push({ value: `${item.hr} bpm`, summary: '心率', time: this.formatRecordTime(item.timestamp), timestamp: item.timestamp })
      }
    }
    this.heartRateRecords = this.sortRecords(records)
    this.heartRateText = this.latestValue(this.heartRateRecords)
  }

  private receiveBloodOxygen(data: Array<BloodOxySyncBean>): void {
    const records: Array<HealthDisplayRecord> = []
    for (const day of data) {
      for (const item of day.items) {
        records.push({ value: `${item.bloodOxy}%`, summary: '血氧', time: this.formatRecordTime(item.timestamp), timestamp: item.timestamp })
      }
    }
    this.bloodOxygenRecords = this.sortRecords(records)
    this.bloodOxygenText = this.latestValue(this.bloodOxygenRecords)
  }

  private receiveBloodPressure(data: Array<BloodPressSyncBean>): void {
    const records: Array<HealthDisplayRecord> = []
    for (const day of data) {
      for (const item of day.items) {
        records.push({ value: `${item.sp}/${item.dp} mmHg`, summary: '收缩压 / 舒张压', time: this.formatRecordTime(item.timestamp), timestamp: item.timestamp })
      }
    }
    this.bloodPressureRecords = this.sortRecords(records)
    this.bloodPressureText = this.latestValue(this.bloodPressureRecords)
  }

  private receiveHrv(data: Array<HrvSyncBean>): void {
    const records: Array<HealthDisplayRecord> = []
    for (const day of data) {
      for (const item of day.items) {
        records.push({ value: `${item.hrv} ms`, summary: 'HRV', time: this.formatRecordTime(item.timestamp), timestamp: item.timestamp })
      }
    }
    this.hrvRecords = this.sortRecords(records)
    this.hrvText = this.latestValue(this.hrvRecords)
  }

  private receivePressure(data: Array<PressureSyncBean>): void {
    const records: Array<HealthDisplayRecord> = []
    for (const day of data) {
      for (const item of day.items) {
        records.push({ value: `${item.pressure}`, summary: '压力', time: this.formatRecordTime(item.timestamp), timestamp: item.timestamp })
      }
    }
    this.pressureRecords = this.sortRecords(records)
    this.pressureText = this.latestValue(this.pressureRecords)
  }

  private receiveBloodSugar(data: Array<BloodSugarSyncBean>): void {
    const records: Array<HealthDisplayRecord> = []
    for (const day of data) {
      for (const item of day.items) {
        records.push({ value: `${item.sugar} mmol/L`, summary: '血糖', time: this.formatRecordTime(item.timestamp), timestamp: item.timestamp })
      }
    }
    this.bloodSugarRecords = this.sortRecords(records)
    this.bloodSugarText = this.latestValue(this.bloodSugarRecords)
  }

  private receiveTemperature(data: Array<BodyTempSyncBean>): void {
    const records: Array<HealthDisplayRecord> = []
    for (const day of data) {
      for (const item of day.items) {
        records.push({ value: `${item.temperature} ℃`, summary: '体温', time: this.formatRecordTime(item.timestamp), timestamp: item.timestamp })
      }
    }
    this.temperatureRecords = this.sortRecords(records)
    this.temperatureText = this.latestValue(this.temperatureRecords)
  }

  private receiveMuslimCount(data: Array<MuslimCountSyncBean>): void {
    const records: Array<HealthDisplayRecord> = []
    for (const day of data) {
      for (const item of day.items) {
        records.push({ value: `${item.count} 次`, summary: '赞念计数', time: this.formatRecordTime(item.timestamp), timestamp: item.timestamp })
      }
    }
    this.muslimCountRecords = this.sortRecords(records)
    this.muslimCountText = this.latestValue(this.muslimCountRecords)
  }

  private sortRecords(records: Array<HealthDisplayRecord>): Array<HealthDisplayRecord> {
    return records.sort((first: HealthDisplayRecord, second: HealthDisplayRecord) => second.timestamp - first.timestamp)
  }

  private latestValue(records: Array<HealthDisplayRecord>): string {
    return records.length > 0 ? records[0].value : '暂无数据'
  }

  private formatRecordTime(timestamp: number): string {
    if (timestamp <= 0) return '--'
    const value = new Date(timestamp * 1000)
    return `${this.twoDigits(value.getMonth() + 1)}-${this.twoDigits(value.getDate())} ` +
      `${this.twoDigits(value.getHours())}:${this.twoDigits(value.getMinutes())}`
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private localDateText(value: Date): string {
    return `${value.getFullYear()}-${this.twoDigits(value.getMonth() + 1)}-${this.twoDigits(value.getDate())}`
  }

  private formatSleepDuration(minutes: number): string {
    const hour = Math.floor(minutes / 60)
    const minute = minutes % 60
    return hour > 0 ? `${hour}小时${minute}分钟` : `${minute}分钟`
  }

  private sleepTypeText(type: number): string {
    switch (type) {
      case 1: return '浅睡'
      case 2: return '深睡'
      case 3: return 'REM'
      default: return '清醒'
    }
  }

  private async loadSavedDevice(): Promise<void> {
    this.savedDevice = await SavedDeviceStore.load(this.context())
  }

  private async goScan(): Promise<void> {
    RwBleSdk.stopScan()
    try { this.getUIContext().getRouter().pushUrl({ url: 'pages/ScanPage' }) } catch (_e) {}
  }

  private goHealthDetail(type: string, title: string, value: string, measurementCode: number,
    records: Array<HealthDisplayRecord>): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/HealthDetailPage',
        params: { type, title, value, measurementCode, records }
      })
    } catch (_e) {}
  }

  private reconnect(): void {
    const saved = this.savedDevice
    if (!saved || this.connecting) return
    let matched = false
    this.connecting = true
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
        this.showToast('未发现已保存设备，请确认设备在附近')
      },
      onError: (_code: number, error: Error) => {
        if (matched) return
        this.connecting = false
        this.showToast(`扫描失败: ${error.message}`)
      }
    })
  }

  private matchesSavedDevice(device: RwBleDevice, saved: RwBleDevice): boolean {
    const currentIds: Array<string> = [device.mac ?? '', device.uuid ?? '', device.deviceId]
      .map((value: string) => this.normalizeDeviceAddress(value)).filter((value: string) => value.length > 0)
    const savedIds: Array<string> = [saved.mac ?? '', saved.uuid ?? '', saved.deviceId]
      .map((value: string) => this.normalizeDeviceAddress(value)).filter((value: string) => value.length > 0)
    return currentIds.some((value: string) => savedIds.includes(value))
  }

  private normalizeDeviceAddress(value: string): string {
    return value.replace(/[:-]/g, '').toUpperCase()
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
    RwBleSdk.reconnectDevice(refreshed)
  }

  private disconnect(): void {
    RwBleSdk.disconnect()
    this.connected = false
  }

  private async unbind(): Promise<void> {
    RwBleSdk.disconnect()
    await SavedDeviceStore.clear(this.context())
    this.savedDevice = null
    this.menu = null
    this.connected = false
    this.deviceName = '未连接'
    this.powerText = '--'
    this.modelText = '--'
    this.firmwareText = '--'
  }

  private async refreshDeviceInfo(): Promise<void> {
    await this.refreshPower()
    try {
      const result: FirmVersionBean = await RwBleSdk.getFirmwareVersion()
      this.modelText = result.deviceClazz ?? '--'
      this.firmwareText = result.deviceNo ?? '--'
    } catch (_e) {}
  }

  private async refreshPower(showResult: boolean = false): Promise<void> {
    if (!this.connected) {
      if (showResult) this.showToast('请先连接设备')
      return
    }
    const request = this.powerRequest ?? RwBleSdk.getPower()
    this.powerRequest = request
    try {
      const result: PowerBean = await request
      this.powerText = `${result.power}%`
      if (showResult) this.showToast('电量已更新')
    } catch (error) {
      this.showToast(`电量获取失败: ${error instanceof Error ? error.message : JSON.stringify(error)}`)
    } finally {
      if (this.powerRequest === request) this.powerRequest = null
    }
  }

  private subscribeDevicePush(): void {
    if (this.pushUnsub) return
    this.pushUnsub = RwBleSdk.subscribePush((data: PushData) => {
      if (data.type !== DevicePushType.POWER) return
      const power = data.value as PowerBean
      this.powerText = `${power.power}%`
    })
  }

  private findDevice(): void {
    if (!this.connected) { this.showToast('请先连接设备'); return }
    RwBleSdk.controlFindDevice()
    this.showToast('查找指令已发送')
  }

  private async openFeatureMenu(id: string, title: string): Promise<void> {
    if (!this.connected) { this.showToast('请先连接设备'); return }
    if (!DeviceSettingService.canGet(id)) {
      this.openFeaturePicker(id, title)
      return
    }
    let selected = -1
    try {
      const result = await this.getUIContext().getPromptAction().showActionMenu({
        title,
        buttons: [{ text: '选择设置', color: '#0C9568' }, { text: '获取当前值', color: '#26312C' }]
      })
      selected = result.index
    } catch (_e) {
      return
    }
    if (selected === 0) this.openFeaturePicker(id, title)
    if (selected === 1) await this.getFeature(id, title)
  }

  private openFeaturePicker(id: string, title: string): void {
    if (id === 'alarm') {
      const selected = new Date()
      selected.setHours(7, 0, 0, 0)
      this.getUIContext().showTimePickerDialog({
        selected,
        useMilitaryTime: true,
        onAccept: (value: TimePickerResult) => this.setAlarmTime(value.hour, value.minute)
      })
      return
    }
    const options = DeviceSettingService.pickerOptions(id)
    if (options.length === 0) {
      this.showToast('此功能暂无可选配置')
      return
    }
    this.getUIContext().showTextPickerDialog({
      range: options,
      selected: DeviceSettingService.defaultPickerIndex(id),
      canLoop: false,
      onAccept: (value: TextPickerResult) => {
        const index = typeof value.index === 'number' ? value.index : (value.index[0] ?? 0)
        this.setFeatureSelection(id, index)
      }
    })
  }

  private async setFeatureSelection(id: string, index: number): Promise<void> {
    try {
      this.showToast(await DeviceSettingService.setSelected(id, index))
    } catch (error) {
      this.showToast(`设置失败: ${error instanceof Error ? error.message : JSON.stringify(error)}`)
    }
  }

  private async setAlarmTime(hour: number, minute: number): Promise<void> {
    try {
      this.showToast(await DeviceSettingService.setAlarmTime(hour, minute))
    } catch (error) {
      this.showToast(`设置失败: ${error instanceof Error ? error.message : JSON.stringify(error)}`)
    }
  }

  private async getFeature(id: string, title: string): Promise<void> {
    try {
      const value = await DeviceSettingService.get(id)
      await this.getUIContext().getPromptAction().showDialog({
        title: `${title}当前值`,
        message: value,
        buttons: [{ text: '知道了', color: '#0C9568' }]
      })
    } catch (error) {
      this.showToast(`获取失败: ${error instanceof Error ? error.message : JSON.stringify(error)}`)
    }
  }

  private async openPowerMenu(): Promise<void> {
    if (!this.connected) { this.showToast('请先连接设备'); return }
    let selected = -1
    try {
      const result = await this.getUIContext().getPromptAction().showActionMenu({
        title: '设备电源操作',
        buttons: [{ text: '设备关机', color: '#D84B4B' }, { text: '恢复出厂设置', color: '#D84B4B' }]
      })
      selected = result.index
    } catch (_e) {
      return
    }
    try {
      const confirmation = await this.getUIContext().getPromptAction().showDialog({
        title: selected === 1 ? '恢复出厂设置' : '设备关机',
        message: selected === 1 ? '设备数据将被清除，此操作不可撤销。' : '确定让设备关机吗？',
        buttons: [{ text: '取消', color: '#66716C' }, { text: '确定', color: '#D84B4B' }]
      })
      if (confirmation.index !== 1) return
    } catch (_e) {
      return
    }
    try {
      await RwBleSdk.setPowerOff(selected === 1 ? 2 : 1)
      this.showToast(selected === 1 ? '恢复出厂指令已发送' : '关机指令已发送')
    } catch (error) {
      this.showToast(`操作失败: ${error instanceof Error ? error.message : JSON.stringify(error)}`)
    }
  }

  private goWorkout(): void {
    if (!this.connected) { this.showToast('请先连接设备'); return }
    try { this.getUIContext().getRouter().pushUrl({ url: 'pages/WorkoutTypePage' }) } catch (_e) {}
  }

  private goFirmwareUpgrade(): void {
    if (!this.connected) { this.showToast('请先连接设备'); return }
    try { this.getUIContext().getRouter().pushUrl({ url: 'pages/FirmwareUpgradePage' }) } catch (_e) {}
  }

  private async shareLogs(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const logDir = `${ctx.filesDir}/logger/devices`
      const zipPath = `${ctx.cacheDir}/rwsdk_logs.zip`
      RwBleSdk.flushLog()
      if (!fs.accessSync(logDir) || fs.listFileSync(logDir).length === 0) {
        this.showToast('暂无日志文件')
        return
      }
      if (fs.accessSync(zipPath)) fs.unlinkSync(zipPath)
      await zlib.compressFile(logDir, zipPath, { level: zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION })
      const sharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.ZIP_ARCHIVE,
        uri: fileUri.getUriFromPath(zipPath),
        title: 'RW SDK 日志',
        description: 'RW BLE SDK 运行日志'
      })
      await new systemShare.ShareController(sharedData).show(ctx, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      })
    } catch (_e) {
      this.showToast('分享日志失败')
    }
  }

  private showToast(message: string): void {
    try { promptAction.showToast({ message, duration: 2000 }) } catch (_e) {}
  }
}

@Extend(Column)
function cardStyle() {
  .alignItems(HorizontalAlign.Start)
  .width('100%')
  .backgroundColor('#FFFFFF')
  .borderRadius(20)
  .shadow({ radius: 12, color: '#10253C2D', offsetY: 4 })
}
