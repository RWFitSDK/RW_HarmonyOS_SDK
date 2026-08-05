import { promptAction } from '@kit.ArkUI';
import { BleActivityMode, RwBleSdk, SportResultBean, WorkoutControlType } from 'rw_ble_sdk';

@Entry
@Component
struct WorkoutTypePage {
  @State private loading: boolean = false
  @State private statusText: string = '读取当前运动状态中...'
  @State private keyword: string = ''
  @State private reports: SportResultBean[] = []
  @State private reportsLoading: boolean = false

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

  aboutToAppear(): void {
    this.refreshSportStatus()
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 0 }) {
          Row({ space: 10 }) {
            Text('‹').fontSize(34).fontColor('#26312C').width(38)
              .onClick(() => { try { this.getUIContext().getRouter().back() } catch (_e) {} })
            Column({ space: 4 }) {
              Text('多运动').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#18221E')
              Text(this.statusText).fontSize(12).fontColor('#87928D')
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .margin({ top: 10, bottom: 22 })

          Row({ space: 10 }) {
            Text('⌕').fontSize(22).fontColor('#8E9994')
            TextInput({ placeholder: '搜索运动类型', text: this.keyword })
              .fontSize(14)
              .backgroundColor('#FFFFFF')
              .layoutWeight(1)
              .onChange((value: string) => this.keyword = value)
          }
          .width('100%')
          .height(52)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#FFFFFF')
          .borderRadius(18)

          Row({ space: 8 }) {
            Text('选择运动').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#1C2823')
            Text(`共 ${this.filteredWorkoutNames().length} 项`).fontSize(12).fontColor('#8A948F')
          }
          .width('100%')
          .margin({ top: 25, bottom: 13 })

          if (this.filteredWorkoutNames().length > 0) {
            Grid() {
              ForEach(this.filteredWorkoutNames(), (name: string) => {
                GridItem() {
                  Row({ space: 11 }) {
                    Text(name.substring(0, 1)).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#0B9066')
                      .textAlign(TextAlign.Center).width(38).height(38).backgroundColor('#E5F4ED').borderRadius(12)
                    Text(name).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#26312C')
                      .maxLines(2).layoutWeight(1)
                    Text(`${this.sportCodeForName(name)}`).fontSize(9).fontColor('#BAC2BE')
                  }
                  .width('100%')
                  .height(70)
                  .padding({ left: 12, right: 10 })
                  .backgroundColor('#FFFFFF')
                  .borderRadius(18)
                  .onClick(() => this.startWorkout(this.workoutNames.indexOf(name)))
                }
              }, (name: string) => name)
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(10)
            .rowsGap(10)
            .width('100%')
          } else {
            Column({ space: 8 }) {
              Text('没有匹配的运动').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1C2823')
              Text('请更换关键词后重试').fontSize(13).fontColor('#909A95')
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .height(130)
            .backgroundColor('#FFFFFF')
            .borderRadius(20)
          }

          Row() {
            Row({ space: 8 }) {
              Text('历史报告').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#1C2823')
              Text(`${this.reports.length} 条`).fontSize(12).fontColor('#8A948F')
            }
            .layoutWeight(1)
            Button(this.reportsLoading ? '加载中' : '从设备加载')
              .fontSize(12).fontColor('#087D59').backgroundColor('#E1F3EB').borderRadius(20)
              .enabled(!this.reportsLoading)
              .onClick(() => this.loadReports())
          }
          .width('100%')
          .margin({ top: 26, bottom: 13 })

          if (this.reports.length > 0) {
            Column() {
              ForEach(this.reports, (report: SportResultBean, index: number) => {
                Column() {
                  Row() {
                    Column({ space: 5 }) {
                      Text(`${this.nameForSport(report.workModel)} · ${(report.exerciseTime / 60).toFixed(0)} 分钟`)
                        .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#26312C')
                      Text(`${report.step} 步 · ${(report.distance / 1000).toFixed(2)} km · ${(report.calorie / 1000).toFixed(1)} kcal`)
                        .fontSize(11).fontColor('#8F9994')
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    Text(this.dateText(report.startTime)).fontSize(10).fontColor('#7F8A85')
                  }
                  .width('100%')
                  .padding(16)
                  if (index < this.reports.length - 1) Divider().strokeWidth(1).color('#EDF0EE')
                }
              }, (report: SportResultBean) => `${report.startTime}`)
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(20)
          } else {
            Column({ space: 8 }) {
              Text('暂无运动记录').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1C2823')
              Text('运动超过 2 分钟并正常结束后，设备才会保存报告。')
                .fontSize(13).fontColor('#909A95').textAlign(TextAlign.Center)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding({ top: 30, bottom: 30, left: 20, right: 20 })
            .backgroundColor('#FFFFFF')
            .borderRadius(20)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 30 })
      }
      .height('100%')

      if (this.loading) {
        Column() {
          LoadingProgress().width(46).height(46).color('#FFFFFF')
          Text('处理中...').fontSize(14).fontColor('#FFFFFF').margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7F5')
  }

  private filteredWorkoutNames(): string[] {
    const query = this.keyword.trim().toLowerCase()
    if (query.length === 0) return this.workoutNames
    return this.workoutNames.filter((name: string) => name.toLowerCase().includes(query))
  }

  private sportCodeForName(name: string): number {
    return BleActivityMode.BLE_ACTIVITY_START_INDEX + this.workoutNames.indexOf(name)
  }

  private async loadReports(): Promise<void> {
    if (this.reportsLoading) return
    this.reportsLoading = true
    try {
      this.reports = await RwBleSdk.getSportResult()
      this.showToast(this.reports.length > 0 ? `已加载 ${this.reports.length} 条报告` : '设备暂无新报告')
    } catch (error) {
      this.showToast(`报告加载失败: ${JSON.stringify(error)}`)
    } finally {
      this.reportsLoading = false
    }
  }

  private dateText(timestamp: number): string {
    if (timestamp <= 0) return '--'
    return new Date(timestamp * 1000).toLocaleString()
  }

  private async refreshSportStatus(): Promise<void> {
    try {
      const res = await RwBleSdk.getSportStatus()
      const sport = res as SportControlRouteParams
      if (this.isInRunning(sport.status)) {
        this.statusText = `设备运动中: ${this.nameForSport(sport.sportType)}`
        this.goRunning(sport.sportType, sport.status)
      } else {
        this.statusText = '请选择运动类型'
      }
    } catch (e) {
      this.statusText = `读取运动状态失败: ${JSON.stringify(e)}`
    }
  }

  private async startWorkout(index: number): Promise<void> {
    if (this.loading) return
    const sportType = BleActivityMode.BLE_ACTIVITY_START_INDEX + index
    this.loading = true
    try {
      const current = await RwBleSdk.getSportStatus()
      const status = current as SportControlRouteParams
      if (this.isInRunning(status.status)) {
        this.showToast('设备已有运动进行中')
        this.goRunning(status.sportType, status.status)
        return
      }
      await RwBleSdk.controlSport(sportType, WorkoutControlType.Workout_Begin)
      this.goRunning(sportType, WorkoutControlType.Workout_Begin)
    } catch (e) {
      this.showToast(`启动失败: ${JSON.stringify(e)}`)
    } finally {
      this.loading = false
    }
  }

  private isInRunning(status: number): boolean {
    return status >= WorkoutControlType.Workout_Begin && status < WorkoutControlType.Workout_Finish
  }

  private nameForSport(sportType: number): string {
    const index = sportType - BleActivityMode.BLE_ACTIVITY_START_INDEX
    return index >= 0 && index < this.workoutNames.length ? this.workoutNames[index] : `类型${sportType}`
  }

  private goRunning(sportType: number, controlType: number): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/WorkoutRunningPage',
        params: { sportType: sportType, controlType: controlType }
      })
    } catch (_e) {}
  }

  private showToast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2000 })
    } catch (_e) {}
  }
}

interface SportControlRouteParams {
  sportType: number
  status: number
  controlType?: number
}
