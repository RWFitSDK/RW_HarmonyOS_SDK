import { promptAction } from '@kit.ArkUI';
import { BleActivityMode, RwBleSdk, WorkoutControlType } from 'rw_ble_sdk';

@Entry
@Component
struct WorkoutRunningPage {
  @State private sportType: number = BleActivityMode.RUNNING
  @State private controlType: number = WorkoutControlType.Workout_Begin
  @State private workoutName: string = '跑步'
  @State private timeText: string = '00:00:00'
  @State private stepText: string = '0'
  @State private distanceText: string = '0.00 Km'
  @State private caloriesText: string = '0.0 KCal'
  @State private heartText: string = '0 bpm'
  @State private statusText: string = '运动中'
  @State private syncingResult: boolean = false
  @State private connected: boolean = false

  private readonly workoutNames: string[] = [
    '跑步', '跑步机', '户外跑步', '骑行', '游泳', '健走', '登山', '瑜伽', '动感单车', '篮球',
    '足球', '羽毛球', '马拉松', '室内步行', '自由锻炼', '田径', '体能训练', '举重', '拳击', '跳绳',
    '爬楼梯', '滑雪', '滑冰', '轮滑', '室内骑行', '呼啦圈', '高尔夫', '棒球', '舞蹈', '乒乓球',
    '曲棍球', '普拉提', '跆拳道', '手球', '街舞', '排球', '网球', '飞镖', '体操', '踏步',
    '椭圆机', '尊巴', '板球', '徒步旅行', '有氧运动', '划船机', '橄榄球', '仰卧起坐', '哑铃', '健身操',
    '空手道', '击剑', '武术', '太极拳', '飞盘', '射箭', '骑马', '保龄球', '冲浪', '垒球',
    '壁球', '帆船', '引体向上', '滑板', '蹦床', '钓鱼', '钢管舞', '广场舞', '爵士舞', '芭蕾舞',
    '迪斯科', '踢踏舞', '现代舞', '俯卧撑', '滑板车', '平板支撑', '桌球', '攀岩', '铁饼', '赛马',
    '摔跤', '跳高', '跳伞', '铅球', '跳远', '标枪', '链球', '深蹲', '压腿', '越野自行车',
    '越野摩托车', '赛艇', 'Crossfit', '水上自行车', '皮划艇', '槌球', '地板球', '泰拳', '回力球', '网球(双打)',
    '背部训练', '水上排球', '滑水', '登山机', '高强度间歇性训练', 'BODY COMBAT', 'BODY BALANCE', '全身抗阻力锻炼', '跆搏', '小轮车',
    '拉伸', '室内健身', '柔韧训练', '上肢训练', '下肢训练', '自由体操', '杠铃训练', '体能训练', '硬拉', '波比跳',
    '功能性训练', '腰腹训练', '桌式足球', '打猎', '立桨冲浪', '皮艇漂流', '摩托艇', '跑酷', '沙滩车', '滑翔伞',
    '冰壶', '滑雪板', '滑雪双板', '高山滑雪', '越野滑雪', '雪地摩托', '雪车', '雪橇', '墙球', '冰球',
    '藤球', '水球', '肚皮舞', '交际舞', '民族舞', '拉丁舞', '柔道', '踢拳', '放风筝', '拔河',
    '毽球', '卡巴迪', '赛车', '石子游戏', '捉人游戏'
  ]
  private dataUnsub: (() => void) | null = null
  private controlUnsub: (() => void) | null = null

  aboutToAppear(): void {
    this.connected = RwBleSdk.isBleConnected()
    this.loadParams()
    this.updateWorkoutTitle()
    this.updateStatusText()
    this.dataUnsub = RwBleSdk.onSportDataPush((data: Object) => this.updateData(data as SportPushData))
    this.controlUnsub = RwBleSdk.onSportControl((data: Object) => this.handleControl(data as SportControlData))
    RwBleSdk.setExerciseNotify(1).catch((e: Error) => this.showToast(`进入运动界面失败: ${e.message}`))
  }

  aboutToDisappear(): void {
    this.dataUnsub?.()
    this.controlUnsub?.()
    this.dataUnsub = null
    this.controlUnsub = null
    RwBleSdk.setExerciseNotify(0).catch((_e: Error) => {})
  }

  build() {
    Scroll() {
      Column({ space: 0 }) {
        Row({ space: 10 }) {
          Text('‹').fontSize(34).fontColor('#26312C').width(38)
            .onClick(() => { try { this.getUIContext().getRouter().back() } catch (_e) {} })
          Text('实时运动数据').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#18221E')
        }
        .width('100%')
        .margin({ top: 10, bottom: 20 })

        Column({ space: 0 }) {
          Row() {
            Column({ space: 5 }) {
              Text('当前运动').fontSize(12).fontColor('#B8D0C6')
              Text(this.workoutName).fontSize(25).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text(this.statusText).fontSize(12).fontColor('#FFFFFF')
              .padding({ left: 11, right: 11, top: 6, bottom: 6 })
              .backgroundColor('#2FFFFFFF').borderRadius(16)
          }
          .width('100%')
          Text(this.timeText).fontSize(44).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .letterSpacing(3).textAlign(TextAlign.Center).width('100%').margin({ top: 30 })
          Text('运动时长').fontSize(11).fontColor('#B8D0C6').textAlign(TextAlign.Center).width('100%').margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 22, right: 22, top: 22, bottom: 28 })
        .backgroundColor(this.controlType === WorkoutControlType.Workout_Pause ? '#8A6B2D' : '#164B3A')
        .borderRadius(24)
        .shadow({ radius: 18, color: '#280C674B', offsetY: 8 })

        if (!this.connected) {
          Text('蓝牙已断开。设备上的运动不会自动结束，重新连接后可继续控制。')
            .fontSize(12).fontColor('#98651E').lineHeight(19).width('100%')
            .padding(14).backgroundColor('#FFF2DF').borderRadius(16).margin({ top: 16 })
        }

        Grid() {
          GridItem() { this.MetricCard(this.stepText, '步数 · 步', false) }
          GridItem() { this.MetricCard(this.distanceText.replace(' Km', ''), '距离 · km', false) }
          GridItem() { this.MetricCard(this.caloriesText.replace(' KCal', ''), '热量 · kcal', false) }
          GridItem() { this.MetricCard(this.heartText.replace(' bpm', ''), '心率 · bpm', true) }
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .width('100%')
        .margin({ top: 18 })

        Row({ space: 12 }) {
          if (this.showPauseButton()) {
            Button('暂停').fontSize(15).fontColor('#FFFFFF').backgroundColor('#D39A34').borderRadius(24)
              .enabled(this.connected).layoutWeight(1).onClick(() => this.pauseWorkout())
          }
          if (this.showContinueButton()) {
            Button('继续').fontSize(15).fontColor('#FFFFFF').backgroundColor('#0C9B6C').borderRadius(24)
              .enabled(this.connected).layoutWeight(1).onClick(() => this.continueWorkout())
          }
          if (this.showEndButton()) {
            Button('结束运动').fontSize(15).fontColor('#FFFFFF').backgroundColor('#D85B5B').borderRadius(24)
              .enabled(this.connected).layoutWeight(1).onClick(() => this.finishWorkout())
          }
        }
        .width('100%')
        .margin({ top: 22 })

        if (this.syncingResult) {
          Row({ space: 8 }) {
            LoadingProgress().width(24).height(24)
            Text('同步运动结果中...').fontSize(14).fontColor('#687076')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })
        }

        Column({ space: 8 }) {
          Text('运动说明').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#405149').width('100%')
          Text('离开此页面只会关闭实时数据通知，不会结束设备上的运动。运动超过 2 分钟后正常结束，设备才会保存运动报告。')
            .fontSize(12).fontColor('#77847E').lineHeight(20).width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor('#EEF5F1')
        .borderRadius(20)
        .margin({ top: 22, bottom: 28 })
      }
      .padding({ left: 18, right: 18 })
      .width('100%')
    }
    .height('100%')
    .backgroundColor('#F4F7F5')
  }

  @Builder
  private MetricCard(value: string, label: string, heart: boolean) {
    Column({ space: 6 }) {
      Text(value).fontSize(25).fontWeight(FontWeight.Bold).fontColor(heart ? '#D05A5A' : '#18221E')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      Text(label).fontSize(12).fontColor('#8B9690').width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
  }

  private loadParams(): void {
    try {
      const params = this.getUIContext().getRouter().getParams() as WorkoutRouteParams
      this.sportType = params?.sportType ?? BleActivityMode.RUNNING
      this.controlType = params?.controlType ?? WorkoutControlType.Workout_Begin
    } catch (_e) {
      this.sportType = BleActivityMode.RUNNING
      this.controlType = WorkoutControlType.Workout_Begin
    }
  }

  private updateWorkoutTitle(): void {
    const index = this.sportType - BleActivityMode.BLE_ACTIVITY_START_INDEX
    this.workoutName = index >= 0 && index < this.workoutNames.length ? this.workoutNames[index] : `类型${this.sportType}`
  }

  private updateStatusText(): void {
    if (this.controlType === WorkoutControlType.Workout_Pause) {
      this.statusText = '已暂停'
    } else if (this.controlType === WorkoutControlType.Workout_Finish) {
      this.statusText = '已结束'
    } else {
      this.statusText = '运动中'
    }
  }

  private updateData(data: SportPushData): void {
    const duration = data.activityTime ?? 0
    const hours = Math.floor(duration / 3600)
    const minutes = Math.floor((duration % 3600) / 60)
    const seconds = duration % 60
    this.timeText = `${this.pad2(hours)}:${this.pad2(minutes)}:${this.pad2(seconds)}`
    this.stepText = `${data.activitySteps ?? 0}`
    this.distanceText = `${((data.activityDistance ?? 0) / 1000).toFixed(2)} Km`
    this.caloriesText = `${((data.activityCalorie ?? 0) / 1000).toFixed(1)} KCal`
    this.heartText = `${data.activityHr ?? 0} bpm`
  }

  private handleControl(data: SportControlData): void {
    if (data.sportType > 0) {
      this.sportType = data.sportType
      this.updateWorkoutTitle()
    }
    this.controlType = data.status
    this.updateStatusText()
    if (data.status === WorkoutControlType.Workout_Finish) {
      this.startSyncWorkoutData()
    }
  }

  private async finishWorkout(): Promise<void> {
    await this.sendControl(WorkoutControlType.Workout_Finish)
  }

  private async pauseWorkout(): Promise<void> {
    await this.sendControl(WorkoutControlType.Workout_Pause)
  }

  private async continueWorkout(): Promise<void> {
    await this.sendControl(WorkoutControlType.Workout_Continue)
  }

  private async sendControl(status: number): Promise<void> {
    try {
      await RwBleSdk.controlSport(this.sportType, status)
      this.controlType = status
      this.updateStatusText()
      if (status === WorkoutControlType.Workout_Finish) {
        this.startSyncWorkoutData()
      }
    } catch (e) {
      this.showToast(`控制失败: ${JSON.stringify(e)}`)
    }
  }

  private async startSyncWorkoutData(): Promise<void> {
    if (this.syncingResult) return
    this.syncingResult = true
    try {
      await RwBleSdk.getSportResult()
      this.showToast('运动结果同步完成')
      try { this.getUIContext().getRouter().back() } catch (_e) {}
    } catch (e) {
      this.showToast(`同步运动结果失败: ${JSON.stringify(e)}`)
    } finally {
      this.syncingResult = false
    }
  }

  private showEndButton(): boolean {
    return this.controlType === WorkoutControlType.Workout_Begin ||
      this.controlType === WorkoutControlType.Workout_Continue ||
      this.controlType === WorkoutControlType.Workout_Pause
  }

  private showPauseButton(): boolean {
    return this.controlType === WorkoutControlType.Workout_Begin ||
      this.controlType === WorkoutControlType.Workout_Continue
  }

  private showContinueButton(): boolean {
    return this.controlType === WorkoutControlType.Workout_Pause
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private showToast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2000 })
    } catch (_e) {}
  }
}

interface WorkoutRouteParams {
  sportType?: number
  controlType?: number
}

interface SportControlData {
  sportType: number
  status: number
}

interface SportPushData {
  activityTime?: number
  activitySteps?: number
  activityDistance?: number
  activityCalorie?: number
  activityHr?: number
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
