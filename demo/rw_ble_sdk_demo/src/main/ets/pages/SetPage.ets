import { hilog } from '@kit.PerformanceAnalysisKit';
import { RwBleSdk, SupportMenuBean } from 'rw_ble_sdk';
import { AlarmRemainderBean, BrightScreenBean, BrightScreenLedBean, BrightScreenTimeBean, VideoHidBean } from 'rw_ble_sdk';

@Entry
@Component
struct SetPage {
  @State private logText: string = ''
  @State private menu: SupportMenuBean | null = null

  aboutToAppear(): void {
    this.menu = RwBleSdk.getSupportMenu()
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() {
          Button('← 返回').type(ButtonType.Normal)
            .onClick(() => { try { this.getUIContext().getRouter().back() } catch (_e) {} })
          Text('设置').fontSize(24).fontWeight(FontWeight.Bold).margin({ left: 12 })
        }
        .width('100%')

        this.UserInfoSection()
        this.AlarmSection()
        this.ScreenSection()
        this.DeviceControlSection()
        this.AlertSection()
        this.LogSection()
      }
      .padding(16)
      .width('100%')
    }
    .height('100%')
  }

  @Builder
  private UserInfoSection() {
    Column({ space: 10 }) {
      Text('用户信息').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Button('设置用户 (男/170cm/65kg/25岁)')
        .onClick(() => this.setUserInfo())
        .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private AlarmSection() {
    Column({ space: 10 }) {
      Text('闹钟').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Row({ space: 8 }) {
        Button('设置(7:00工作日)')
          .enabled(this.menu?.isAlarm !== false)
          .onClick(() => this.setAlarm())
          .layoutWeight(1)
        Button('获取')
          .enabled(this.menu?.isAlarm !== false)
          .onClick(() => this.getAlarm())
          .layoutWeight(1)
        Button('删除全部')
          .enabled(this.menu?.isAlarm !== false)
          .onClick(() => this.deleteAlarm())
          .layoutWeight(1)
      }
      .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private ScreenSection() {
    Column({ space: 10 }) {
      Text('屏幕/LED/震动').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Row({ space: 8 }) {
        Button('LED(开,2)')
          .enabled(this.menu?.isLEDLight !== false)
          .onClick(() => this.setLed())
          .layoutWeight(1)
        Button('获取LED')
          .enabled(this.menu?.isLEDLight !== false)
          .onClick(() => this.getLed())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('震动(1,3次)')
          .enabled(this.menu?.isSupportMotoVibrationLevel !== false)
          .onClick(() => this.setVibration())
          .layoutWeight(1)
        Button('获取震动')
          .enabled(this.menu?.isSupportMotoVibrationLevel !== false)
          .onClick(() => this.getVibration())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('亮屏10s')
          .enabled(this.menu?.isBrightScreenTime !== false)
          .onClick(() => this.setBrightTime())
          .layoutWeight(1)
        Button('获取亮屏')
          .enabled(this.menu?.isBrightScreenTime !== false)
          .onClick(() => this.getBrightTime())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('抬腕亮屏(开)')
          .enabled(this.menu?.isRaiseBrightScreen !== false)
          .onClick(() => this.setRaiseBright())
          .layoutWeight(1)
        Button('获取抬腕')
          .enabled(this.menu?.isRaiseBrightScreen !== false)
          .onClick(() => this.getRaiseBright())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('睡眠模式(开20-8)')
          .enabled(this.menu?.isBrightScreenSleepTime !== false)
          .onClick(() => this.setSleepMode())
          .layoutWeight(1)
        Button('获取睡眠模式')
          .enabled(this.menu?.isBrightScreenSleepTime !== false)
          .onClick(() => this.getSleepMode())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('视频HID(开)')
          .onClick(() => this.setHid())
          .layoutWeight(1)
        Button('获取HID')
          .onClick(() => this.getHid())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('佩戴左手')
          .enabled(this.menu?.isWearDir !== false)
          .onClick(() => this.setWear(false))
          .layoutWeight(1)
        Button('佩戴右手')
          .enabled(this.menu?.isWearDir !== false)
          .onClick(() => this.setWear(true))
          .layoutWeight(1)
        Button('获取佩戴')
          .enabled(this.menu?.isWearDir !== false)
          .onClick(() => this.getWear())
          .layoutWeight(1)
      }
      .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private DeviceControlSection() {
    Column({ space: 10 }) {
      Text('设备控制').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Row({ space: 8 }) {
        Button('24小时制')
          .onClick(() => this.setTimeFormat(0))
          .layoutWeight(1)
        Button('12小时制')
          .onClick(() => this.setTimeFormat(1))
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('查找设备')
          .onClick(() => { RwBleSdk.controlFindDevice(); this.addLog('已发送查找') })
          .layoutWeight(1)
        Button('关机')
          .onClick(() => this.powerOff(0))
          .layoutWeight(1)
        Button('恢复出厂')
          .onClick(() => this.powerOff(1))
          .layoutWeight(1)
      }
      .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private AlertSection() {
    Column({ space: 10 }) {
      Text('报警设置').fontSize(18).fontWeight(FontWeight.Medium).width('100%')
      Row({ space: 8 }) {
        Button('设HR报警(开,160)')
          .enabled(this.menu?.isSupportHrReminder !== false)
          .onClick(() => this.setHrAlert())
          .layoutWeight(1)
        Button('获取HR报警')
          .enabled(this.menu?.isSupportHrReminder !== false)
          .onClick(() => this.getHrAlert())
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 8 }) {
        Button('设BO报警(开,94)')
          .enabled(this.menu?.isSupportBoReminder !== false)
          .onClick(() => this.setBoAlert())
          .layoutWeight(1)
        Button('获取BO报警')
          .enabled(this.menu?.isSupportBoReminder !== false)
          .onClick(() => this.getBoAlert())
          .layoutWeight(1)
      }
      .width('100%')
    }
    .sectionStyle()
  }

  @Builder
  private LogSection() {
    Column({ space: 10 }) {
      Row() {
        Text('日志').fontSize(18).fontWeight(FontWeight.Medium).layoutWeight(1)
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

  // ─── Actions ───────────────────────────────────────────────────────

  private async setUserInfo(): Promise<void> {
    try {
      await RwBleSdk.setUserInfo({ gender: 1, height: 170, weight: 65, age: 25, measureUnit: 0 })
      this.addLog('用户信息设置成功')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setAlarm(): Promise<void> {
    try {
      const alarm: AlarmRemainderBean = {
        alarmId: 0, isOpen: true,
        repeatModel: [0, 1, 1, 1, 1, 1, 0],
        startHour: 7, startMin: 0, alarmTag: ''
      }
      await RwBleSdk.setAlarm([alarm])
      this.addLog('闹钟设置成功 7:00')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getAlarm(): Promise<void> {
    try {
      const res = await RwBleSdk.getAlarmRemind()
      this.addLog(`闹钟: ${JSON.stringify(res)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async deleteAlarm(): Promise<void> {
    try {
      await RwBleSdk.deleteAllAlarmRemind()
      this.addLog('闹钟已全部删除')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setLed(): Promise<void> {
    try {
      const b: BrightScreenLedBean = { isOpen: true, lcdLevel: 2 }
      await RwBleSdk.setRingLedLevel(b)
      this.addLog('LED设置成功')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getLed(): Promise<void> {
    try {
      const r = await RwBleSdk.getRingLedLevel()
      this.addLog(`LED: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setVibration(): Promise<void> {
    try {
      await RwBleSdk.setVibrationCount(1, 3)
      this.addLog('震动设置成功')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getVibration(): Promise<void> {
    try {
      const r = await RwBleSdk.getVibrationCount()
      this.addLog(`震动: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setBrightTime(): Promise<void> {
    try {
      await RwBleSdk.setBrightScreenTime(10)
      this.addLog('亮屏时长设置10s')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getBrightTime(): Promise<void> {
    try {
      const r = await RwBleSdk.getBrightScreenTime()
      this.addLog(`亮屏: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setRaiseBright(): Promise<void> {
    try {
      const b: BrightScreenBean = { isOpen: true, startHour: 8, startMin: 0, endHour: 20, endMin: 0 }
      await RwBleSdk.setRaiseBrightScreen(b)
      this.addLog('抬腕亮屏设置成功')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getRaiseBright(): Promise<void> {
    try {
      const r = await RwBleSdk.getRaiseBrightScreen()
      this.addLog(`抬腕: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setSleepMode(): Promise<void> {
    try {
      const b: BrightScreenTimeBean = { timeSecond: 10, isOpen: true, startHour: 20, startMin: 0, endHour: 8, endMin: 0 }
      await RwBleSdk.setRingBrightScreenSleepTime(b)
      this.addLog('睡眠模式设置成功')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getSleepMode(): Promise<void> {
    try {
      const r = await RwBleSdk.getRingBrightScreenSleepTime()
      this.addLog(`睡眠模式: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setHid(): Promise<void> {
    try {
      const b: VideoHidBean = { hidOpen: 1, isDefaultOpen: false }
      await RwBleSdk.setVideoHid(b)
      this.addLog('视频HID设置成功')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getHid(): Promise<void> {
    try {
      const r = await RwBleSdk.getVideoHid()
      this.addLog(`HID: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setWear(isRight: boolean): Promise<void> {
    try {
      await RwBleSdk.setRingWearHand(isRight)
      this.addLog(`佩戴设置: ${isRight ? '右手' : '左手'}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getWear(): Promise<void> {
    try {
      const r = await RwBleSdk.getRingWearDir()
      this.addLog(`佩戴: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setTimeFormat(type: number): Promise<void> {
    try {
      await RwBleSdk.setTimeFormat(type)
      this.addLog(`时间格式设置: ${type === 0 ? '24h' : '12h'}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async powerOff(type: number): Promise<void> {
    try {
      await RwBleSdk.setPowerOff(type)
      this.addLog(`${type === 0 ? '关机' : '恢复出厂'}指令已发送`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setHrAlert(): Promise<void> {
    try {
      await RwBleSdk.setHrAlert(1, 160, 0xFF)
      this.addLog('HR报警设置(开,160)')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getHrAlert(): Promise<void> {
    try {
      const r = await RwBleSdk.getHrAlert()
      this.addLog(`HR报警: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async setBoAlert(): Promise<void> {
    try {
      await RwBleSdk.setBoAlert(1, 94)
      this.addLog('BO报警设置(开,94)')
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
  }

  private async getBoAlert(): Promise<void> {
    try {
      const r = await RwBleSdk.getBoAlert()
      this.addLog(`BO报警: ${JSON.stringify(r)}`)
    } catch (e) { this.addLog(`失败: ${JSON.stringify(e)}`) }
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
