import { promptAction } from '@kit.ArkUI';
import { DevicePushType, HealthDataSyncBean, MuslimCountItemBean, PushData, RwBleSdk } from 'rw_ble_sdk';

interface HealthDetailRouteParams {
  type?: string
  title?: string
  value?: string
  measurementCode?: number
  records?: Array<HealthDisplayRecord>
}

interface HealthDisplayRecord {
  value: string
  summary: string
  time: string
  timestamp: number
}

@Entry
@Component
struct HealthDetailPage {
  @State private type: string = ''
  @State private title: string = '健康数据'
  @State private latestValue: string = '暂无数据'
  @State private latestTime: string = '连接设备同步后显示'
  @State private measurementCode: number = 0
  @State private connected: boolean = false
  @State private measuring: boolean = false
  @State private measurementBusy: boolean = false
  @State private records: Array<HealthDisplayRecord> = []

  private dataUnsub: (() => void) | null = null
  private pushUnsub: (() => void) | null = null
  private controlUnsub: (() => void) | null = null

  aboutToAppear(): void {
    this.loadParams()
    this.connected = RwBleSdk.isBleConnected()
    this.dataUnsub = RwBleSdk.onHealthRealtimeData((data: HealthDataSyncBean) => this.receiveRealtime(data))
    // 赞念计数实时上报走统一设备推送通道; 只刷新"最近一次"实时值, 不写入历史记录列表
    this.pushUnsub = RwBleSdk.subscribePush((data: PushData) => {
      if (data.type !== DevicePushType.MUSLIM_COUNT || this.type !== 'muslimCount') return
      const item = data.value as MuslimCountItemBean
      this.latestValue = `${item.count}`
      this.latestTime = `实时计数 · ${new Date().toLocaleTimeString()}`
    })
    this.controlUnsub = RwBleSdk.onHealthControlEvent((data: Object) => {
      const event = data as Record<string, number>
      if (event.healthType === this.measurementCode && event.status === 0) {
        this.measuring = false
        this.measurementBusy = false
        this.showToast(`${this.title}检测完成`)
      }
    })
  }

  aboutToDisappear(): void {
    if (this.measuring && this.measurementCode > 0) {
      RwBleSdk.controlHealthData(this.measurementCode, 0).catch((_e: Error) => {})
    }
    this.dataUnsub?.()
    this.controlUnsub?.()
    this.pushUnsub?.()
    this.dataUnsub = null
    this.controlUnsub = null
    this.pushUnsub = null
  }

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          Text('‹').fontSize(34).fontColor('#26312C').width(38)
            .onClick(() => this.getUIContext().getRouter().back())
          Text(`${this.title}详情`).fontSize(25).fontWeight(FontWeight.Bold).fontColor('#18221E')
        }
        .width('100%')
        .margin({ top: 10, bottom: 20 })

        Column({ space: 7 }) {
          Text(`最近一次${this.title}`).fontSize(13).fontColor('#B8D0C6').width('100%')
          Text(this.latestValue).fontSize(30).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').width('100%')
          Text(this.latestTime).fontSize(12).fontColor('#C9DDD5').width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(20)
        .backgroundColor('#164B3A')
        .borderRadius(22)
        .shadow({ radius: 18, color: '#260C674B', offsetY: 8 })

        if (this.measurementCode > 0) {
          this.SectionTitle('实时检测', '')
          Column({ space: 14 }) {
            Row() {
              Column({ space: 4 }) {
                Text(`${this.title}实时检测`).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1C2823')
                Text(this.measuring ? '检测中，实时数据会更新上方数值' : '进入详情后手动开始单次实时测量')
                  .fontSize(12).fontColor('#8B9690')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text(this.measuring ? '检测中' : '未开始').fontSize(11)
                .fontColor(this.measuring ? '#087D59' : '#7E8983')
                .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                .backgroundColor(this.measuring ? '#E1F3EB' : '#EEF1EF').borderRadius(13)
            }
            .width('100%')
            Button(this.measuring ? '结束检测' : '开始检测')
              .enabled(this.connected && !this.measurementBusy)
              .fontColor('#FFFFFF')
              .backgroundColor(this.measuring ? '#C65A5A' : '#0C9B6C')
              .borderRadius(22)
              .width('100%')
              .onClick(() => this.measuring ? this.stopMeasurement() : this.startMeasurement())
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .shadow({ radius: 12, color: '#10253C2D', offsetY: 4 })
        }

        this.SectionTitle('历史记录', this.records.length > 0 ? `${this.records.length} 条` : '暂无数据')
        if (this.records.length > 0) {
          List() {
            ForEach(this.records, (record: HealthDisplayRecord) => {
              ListItem() {
                Row({ space: 12 }) {
                  Circle().width(8).height(8).fill('#0C9B6C')
                  Column({ space: 4 }) {
                    Text(record.value).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1C2823')
                    Text(record.summary).fontSize(11).fontColor('#8B9690')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text(record.time).fontSize(11).fontColor('#929C97')
                }
                .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
              }
            })
          }
          .width('100%').margin({ top: 12 }).backgroundColor('#FFFFFF').borderRadius(20)
          .divider({ strokeWidth: 1, color: '#EDF0EE', startMargin: 36, endMargin: 16 })
        } else {
          Column({ space: 8 }) {
            Text(`暂无${this.title}记录`).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1C2823')
            Text('请返回首页下拉同步设备健康数据。').fontSize(13).fontColor('#909A95')
          }
          .justifyContent(FlexAlign.Center).width('100%')
          .padding({ top: 34, bottom: 34, left: 20, right: 20 })
          .backgroundColor('#FFFFFF').borderRadius(20).margin({ top: 12 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 30 })
    }
    .height('100%')
    .backgroundColor('#F4F7F5')
  }

  @Builder
  private SectionTitle(title: string, caption: string) {
    Row({ space: 8 }) {
      Text(title).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#1C2823')
      if (caption.length > 0) Text(caption).fontSize(12).fontColor('#8A948F')
    }.width('100%').margin({ top: 28, bottom: 13 })
  }

  private loadParams(): void {
    try {
      const params = this.getUIContext().getRouter().getParams() as HealthDetailRouteParams
      this.type = params.type ?? ''
      this.title = params.title ?? '健康数据'
      this.latestValue = params.value ?? '暂无数据'
      this.measurementCode = params.measurementCode ?? 0
      this.records = params.records?.slice() ?? []
      if (this.records.length > 0) {
        this.latestTime = this.records[0].time
      } else if (this.latestValue !== '暂无数据') {
        this.latestTime = '首页最近数据'
      }
    } catch (_e) {}
  }

  private async startMeasurement(): Promise<void> {
    if (!this.connected || this.measurementCode <= 0 || this.measurementBusy) return
    this.measurementBusy = true
    try {
      await RwBleSdk.controlHealthData(this.measurementCode, 1)
      this.measuring = true
      this.showToast('实时检测已开始')
    } catch (error) {
      this.showToast(`启动失败: ${error instanceof Error ? error.message : JSON.stringify(error)}`)
    } finally {
      this.measurementBusy = false
    }
  }

  private async stopMeasurement(): Promise<void> {
    if (!this.connected || this.measurementCode <= 0 || this.measurementBusy) return
    this.measurementBusy = true
    try {
      await RwBleSdk.controlHealthData(this.measurementCode, 0)
      this.measuring = false
      this.showToast('实时检测已结束')
    } catch (error) {
      this.showToast(`结束失败: ${error instanceof Error ? error.message : JSON.stringify(error)}`)
    } finally {
      this.measurementBusy = false
    }
  }

  private receiveRealtime(data: HealthDataSyncBean): void {
    if (data.dataType !== this.expectedDataType()) return
    const value = this.realtimeValue(data)
    const time = new Date().toLocaleTimeString()
    this.latestValue = value
    this.latestTime = `实时检测 · ${time}`
    const next: Array<HealthDisplayRecord> = [{
      value,
      summary: '实时检测数据',
      time,
      timestamp: Math.floor(Date.now() / 1000)
    }]
    next.push(...this.records.slice(0, 19))
    this.records = next
  }

  private expectedDataType(): number {
    switch (this.type) {
      case 'heartRate': return 1
      case 'bloodOxygen': return 3
      case 'bloodPressure': return 4
      case 'stress': return 8
      case 'bloodSugar': return 9
      case 'muslimCount': return 10
      case 'temperature': return 11
      case 'hrv': return 13
      default: return -1
    }
  }

  private realtimeValue(data: HealthDataSyncBean): string {
    switch (this.type) {
      case 'heartRate': return `${data.hrValue ?? data.value ?? 0} bpm`
      case 'bloodOxygen': return `${data.boValue ?? data.value ?? 0}%`
      case 'bloodPressure': return `${data.bpSp ?? 0}/${data.bpDp ?? 0} mmHg`
      case 'bloodSugar': return `${data.bloodSugarValue ?? data.value ?? 0}`
      case 'muslimCount': return `${data.muslimCount ?? data.value ?? 0}`
      case 'temperature': return `${data.temperature ?? ((data.tempValue ?? data.value ?? 0) / 10)} ℃`
      case 'hrv': return `${data.hrvValue ?? data.value ?? 0} ms`
      default: return `${data.value ?? 0}`
    }
  }

  private showToast(message: string): void {
    try { promptAction.showToast({ message, duration: 2000 }) } catch (_e) {}
  }
}
