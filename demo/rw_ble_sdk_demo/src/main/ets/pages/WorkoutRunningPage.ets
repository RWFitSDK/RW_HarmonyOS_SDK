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
      Column({ space: 14 }) {
        Row() {
          Button('← 返回').type(ButtonType.Normal)
            .onClick(() => { try { this.getUIContext().getRouter().back() } catch (_e) {} })
          Text('Real-time sports data')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 12 })
            .layoutWeight(1)
        }
        .width('100%')

        Column({ space: 8 }) {
          Text(`Type: ${this.workoutName}`)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          Text(this.statusText)
            .fontSize(13)
            .fontColor('#687076')
            .width('100%')
        }
        .sectionStyle()

        Column({ space: 10 }) {
          this.MetricRow('Time', this.timeText)
          this.MetricRow('Steps', this.stepText)
          this.MetricRow('Distance', this.distanceText)
          this.MetricRow('Calories', this.caloriesText)
          this.MetricRow('HeartRate', this.heartText)
        }
        .sectionStyle()

        Row({ space: 8 }) {
          Button('结束')
            .enabled(this.showEndButton())
            .onClick(() => this.finishWorkout())
            .layoutWeight(1)
          Button('暂停')
            .enabled(this.showPauseButton())
            .onClick(() => this.pauseWorkout())
            .layoutWeight(1)
          Button('继续')
            .enabled(this.showContinueButton())
            .onClick(() => this.continueWorkout())
            .layoutWeight(1)
        }
        .width('100%')

        if (this.syncingResult) {
          Row({ space: 8 }) {
            LoadingProgress().width(24).height(24)
            Text('同步运动结果中...').fontSize(14).fontColor('#687076')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .padding(16)
      .width('100%')
    }
    .height('100%')
  }

  @Builder
  private MetricRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#687076')
        .layoutWeight(1)
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
    }
    .width('100%')
    .height(36)
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
